#!/usr/bin/env python3
"""Export potion-base-8M into assets the Dart runtime can read.

Model2Vec distils a sentence transformer into a plain lookup table, so at
runtime there is no neural network: tokenise, look up each token's vector,
average, normalise. That is why semantic search can run on a 3 GB phone.

This script is the build-time half. It runs once on a laptop and writes four
things into assets/embedding/:

    matrix.bin       int8 embedding matrix + per-row scales  (~7.7 MB)
    vocab.txt        29,528 WordPiece tokens, id = line index
    normalizer.json  case-fold / accent-strip map + punctuation set
    parity.json      fixtures proving the Dart port matches this reference

Nothing in the app depends on Python. Run it again only when changing models.

    .venv/bin/python tool/embeddings/export_potion.py
"""

from __future__ import annotations

import base64
import json
import struct
import sys
import unicodedata
from pathlib import Path

import numpy as np
from model2vec import StaticModel

MODEL_ID = "minishlab/potion-base-8M"
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "embedding"
FIXTURE_DIR = Path(__file__).resolve().parents[2] / "test" / "fixtures"

MAGIC = b"RCLM2V\x00\x00"
FORMAT_VERSION = 1

# Strings the parity test replays through the Dart implementation. Chosen to
# exercise the parts most likely to diverge: casing, accents, punctuation
# splitting, digit sub-wording, subword continuation, and empty input.
PARITY_SAMPLES = [
    "",
    "   ",
    "cheap t-shirt printing",
    "Cheap T-Shirt PRINTING",
    "Medica Books Dhanmondi",
    "Médica Bóoks",
    "01711-223344",
    "+8801711223344",
    "info@medicabooks.com.bd",
    "www.medicabooks.com.bd",
    "who printed our fest shirts cheaply",
    "screen printing press, low cost",
    "dental clinic appointment",
    "Sonar Bangla Press",
    "wholesale winter hoodie supplier",
    "zzzqqqxxx",
    "a",
    "Rahim Uddin — Senior Sales Manager",
    "GameWave Events: stage lighting & LED decor",
    "House 42, Road 7, Dhanmondi, Dhaka 1209",
]


def build_fold_map() -> dict[str, str]:
    """Codepoints that BertNormalizer rewrites, as a plain lookup table.

    `BertNormalizer(lowercase=True, strip_accents=None)` means: NFD-decompose,
    drop combining marks, then lowercase. Dart has no Unicode normalisation in
    its core library, so rather than port NFD we precompute the answer for every
    character that actually changes.

    Scanning the BMP finds on the order of a couple of thousand entries, which
    is a few tens of KB of JSON — far cheaper than shipping a normalisation
    library.
    """
    fold: dict[str, str] = {}
    for cp in range(0x20, 0x2FFFF):
        ch = chr(cp)
        decomposed = unicodedata.normalize("NFD", ch)
        stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
        folded = stripped.lower()
        if folded != ch:
            fold[str(cp)] = folded
    return fold


def build_punctuation_set() -> list[int]:
    """Characters BertPreTokenizer splits out as standalone tokens.

    BERT treats every ASCII symbol as punctuation — including `@`, `+` and `$`,
    which Unicode does not categorise as such — plus anything in a Unicode `P*`
    category. Getting this wrong silently changes tokenisation, so it is
    generated here rather than hand-written.
    """
    punct: list[int] = []
    for cp in range(0x20, 0x2FFFF):
        if (
            (33 <= cp <= 47)
            or (58 <= cp <= 64)
            or (91 <= cp <= 96)
            or (123 <= cp <= 126)
            or unicodedata.category(chr(cp)).startswith("P")
        ):
            punct.append(cp)
    return punct


def build_whitespace_set() -> list[int]:
    """Characters BertNormalizer's clean_text collapses into a plain space.

    BERT counts tab, newline and carriage return as whitespace rather than as
    control characters, plus everything in Unicode category `Zs`.
    """
    ws = [0x09, 0x0A, 0x0D]
    ws += [
        cp
        for cp in range(0x20, 0x2FFFF)
        if unicodedata.category(chr(cp)) == "Zs"
    ]
    return sorted(set(ws))


def build_format_control_set() -> list[int]:
    """Category `Cf` characters, which clean_text drops entirely.

    Zero-width joiners and directional marks live here and do show up in text
    pasted from the web. The other control categories — `Cc`, `Cs`, `Co` — are
    contiguous enough to test by range in Dart, so only this one needs a table.
    """
    return [
        cp
        for cp in range(0x20, 0x2FFFF)
        if unicodedata.category(chr(cp)) == "Cf"
    ]


def quantize(matrix: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Symmetric per-row int8 quantisation.

    Per-row rather than a single global scale: token vectors vary a lot in
    magnitude, and one shared scale would crush the small ones into a handful of
    levels. A per-row float32 scale costs 118 KB and keeps the error negligible.
    """
    scales = np.abs(matrix).max(axis=1) / 127.0
    scales[scales == 0] = 1.0  # all-zero rows would divide by zero
    quantized = np.rint(matrix / scales[:, None]).clip(-127, 127).astype(np.int8)
    return quantized, scales.astype(np.float32)


def write_matrix(path: Path, quantized: np.ndarray, scales: np.ndarray) -> None:
    rows, dims = quantized.shape
    with path.open("wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<III", FORMAT_VERSION, rows, dims))
        f.write(scales.astype("<f4").tobytes())
        f.write(quantized.tobytes())


def encode_reference(model: StaticModel, text: str) -> np.ndarray:
    """Mean pool over token vectors, then L2 normalise.

    Verified to match `StaticModel.encode` exactly — the frequency and SIF
    weighting Model2Vec applies is baked into the stored vectors at distillation
    time, so there is nothing to reproduce at runtime.
    """
    ids = model.tokenizer.encode(text, add_special_tokens=False).ids
    if not ids:
        return np.zeros(model.embedding.shape[1], dtype=np.float32)
    pooled = model.embedding[ids].mean(axis=0)
    norm = float(np.linalg.norm(pooled))
    return (pooled / norm if norm > 0 else pooled).astype(np.float32)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)

    print(f"loading {MODEL_ID} …")
    model = StaticModel.from_pretrained(MODEL_ID)
    matrix = np.asarray(model.embedding, dtype=np.float32)
    rows, dims = matrix.shape
    print(f"  matrix {rows} x {dims}")

    tokenizer_cfg = json.loads(model.tokenizer.to_str())
    wordpiece = tokenizer_cfg["model"]
    assert wordpiece["type"] == "WordPiece", wordpiece["type"]

    # --- vocabulary, ordered by id ---------------------------------------
    vocab = sorted(wordpiece["vocab"].items(), key=lambda kv: kv[1])
    assert [i for _, i in vocab] == list(range(len(vocab))), "vocab ids not dense"
    tokens = [t for t, _ in vocab]
    assert len(tokens) == rows, f"{len(tokens)} tokens vs {rows} rows"
    assert not any("\n" in t for t in tokens), "token contains a newline"

    (OUT_DIR / "vocab.txt").write_text("\n".join(tokens), encoding="utf-8")

    # --- quantised matrix -------------------------------------------------
    quantized, scales = quantize(matrix)
    write_matrix(OUT_DIR / "matrix.bin", quantized, scales)

    dequantized = quantized.astype(np.float32) * scales[:, None]
    row_err = np.abs(dequantized - matrix).max()
    print(f"  quantisation: max abs error {row_err:.5f}")

    # --- normalisation tables --------------------------------------------
    fold = build_fold_map()
    punct = build_punctuation_set()
    whitespace = build_whitespace_set()
    formatControls = build_format_control_set()
    (OUT_DIR / "normalizer.json").write_text(
        json.dumps(
            {
                "lowercase": tokenizer_cfg["normalizer"]["lowercase"],
                "unkToken": wordpiece["unk_token"],
                "continuingSubwordPrefix": wordpiece["continuing_subword_prefix"],
                "maxInputCharsPerWord": wordpiece["max_input_chars_per_word"],
                "fold": fold,
                "punctuation": punct,
                "whitespace": whitespace,
                "formatControls": formatControls,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    print(
        f"  fold {len(fold)}, punctuation {len(punct)}, "
        f"whitespace {len(whitespace)}, format-controls {len(formatControls)}"
    )

    # --- parity fixtures ---------------------------------------------------
    # Both the exact float32 reference and the vector the Dart side should
    # reproduce from quantised weights. The test asserts against the quantised
    # expectation and separately checks the two stay cosine-close, so a real
    # tokenisation bug fails loudly while quantisation noise does not.
    samples = []
    worst_cos = 1.0
    for text in PARITY_SAMPLES:
        exact = encode_reference(model, text)

        ids = model.tokenizer.encode(text, add_special_tokens=False).ids
        if ids:
            pooled = dequantized[ids].mean(axis=0)
            norm = float(np.linalg.norm(pooled))
            approx = (pooled / norm if norm > 0 else pooled).astype(np.float32)
            worst_cos = min(worst_cos, float(exact @ approx))
        else:
            approx = np.zeros(dims, dtype=np.float32)

        samples.append(
            {
                "text": text,
                "tokens": model.tokenizer.encode(text, add_special_tokens=False).tokens,
                "ids": ids,
                "vector": base64.b64encode(approx.astype("<f4").tobytes()).decode(),
            }
        )

    (FIXTURE_DIR / "embedding_parity.json").write_text(
        json.dumps(
            {
                "model": MODEL_ID,
                "rows": rows,
                "dims": dims,
                "samples": samples,
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    print(f"  parity: {len(samples)} samples, worst quantised cosine {worst_cos:.6f}")

    if worst_cos < 0.999:
        print("  ERROR: quantisation degraded a sample below 0.999 cosine")
        return 1

    total = sum(p.stat().st_size for p in OUT_DIR.iterdir())
    print(f"\nwrote {OUT_DIR} — {total / 1e6:.2f} MB total")
    for p in sorted(OUT_DIR.iterdir()):
        print(f"  {p.name:18} {p.stat().st_size / 1e6:7.3f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
