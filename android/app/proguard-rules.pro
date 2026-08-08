# google_mlkit_text_recognition's plugin references a recognizer class for every
# script ML Kit supports — Chinese, Devanagari, Japanese, Korean — and picks one
# at runtime. We only depend on the Latin bundle, so the other four classes are
# genuinely absent and R8 fails the build over it.
#
# Suppressing rather than adding the dependencies is deliberate: each script
# bundle is several MB, and RecallOS is Latin-only by design (see the plan's
# "Future work: other languages"). The code path that would touch them is never
# reached, because the OCR engine always requests Script.latin.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
