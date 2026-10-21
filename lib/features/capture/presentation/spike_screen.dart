import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart';
import '../../../core/eval/question_set.dart';
import '../../../core/storage/hand_offs.dart';
import '../../../core/theme/app_theme.dart';
import '../../search/data/search_repository.dart';
import '../../warranty/data/purchase_links.dart';
import '../data/card_repository.dart' show databaseProvider;
import '../domain/eval_runner.dart';
import '../domain/spike_runner.dart';

/// The Phase 0 gate, as a screen.
///
/// Pick a stack of real cards, run all three OCR strategies over each, export
/// the results, then grade them on a laptop with `tool/spike/score.dart`.
///
/// This is throwaway scaffolding and should read that way — it exists to answer
/// one question before the rest of the app is built on top of the answer.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final SpikeRunner _runner = SpikeRunner();
  final ImagePicker _picker = ImagePicker();

  List<SpikeCard> _cards = <SpikeCard>[];
  bool _running = false;
  String _status = 'Pick the cards you want to test.';
  double _progress = 0;
  String? _exportPath;
  Map<String, bool>? _availability;

  /// The last question set's table (PLAN §6: retrieval, Ask, links).
  String? _evalSummary;

  @override
  void initState() {
    super.initState();
    unawaited(_checkAvailability());
  }

  @override
  void dispose() {
    unawaited(_runner.dispose());
    super.dispose();
  }

  /// Engine availability up front, because "Tesseract is missing" explains a
  /// zero score far better than a page of empty results does.
  Future<void> _checkAvailability() async {
    final Map<String, bool> found = <String, bool>{
      for (final engine in _runner.engines)
        engine.id: await engine.isAvailable(),
    };
    if (mounted) setState(() => _availability = found);
  }

  /// Plays a labelled question set (`lib/core/eval/question_set.dart`)
  /// against this phone's wallet, shows the table and shares the report.
  /// Reads only; the wallet is not changed.
  Future<void> _runQuestionSet() async {
    // Resolved before any await: the screen may be gone by the end.
    final ProviderContainer providers = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final AppDatabase db = providers.read(databaseProvider);
    final SearchRepository search = providers.read(searchRepositoryProvider);

    final fs.XFile? file = await fs.openFile(
      acceptedTypeGroups: <fs.XTypeGroup>[
        const fs.XTypeGroup(
          label: 'Question set',
          extensions: <String>['json'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    setState(() {
      _running = true;
      _evalSummary = null;
      _status = 'Running the question set…';
    });
    try {
      final EvalReport report = await EvalRunner(
        db: db,
        search: search,
        links: PurchaseLinks(db),
      ).run(EvalSet.parse(await file.readAsString()));
      final File out = File(
        p.join((await outboxDirectory()).path, 'recallos_eval_report.json'),
      );
      await out.writeAsString(report.toJson());
      if (mounted) {
        setState(() {
          _evalSummary = report.format();
          _status = 'Question set done.';
        });
      }
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: <XFile>[XFile(out.path, mimeType: 'application/json')],
            subject: 'RecallOS evaluation',
          ),
        );
      } finally {
        await discardHandOff(out);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(
          () => _status = 'The question set could not be read: ${e.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _pickAndRun() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() {
      _running = true;
      _cards = <SpikeCard>[];
      _progress = 0;
      _exportPath = null;
      _status =
          'Running ${picked.length} cards through '
          '${_runner.engines.length} engines…';
    });

    final List<SpikeCard> results = await _runner.run(
      picked.map((XFile x) => File(x.path)).toList(),
      onProgress: (int done, int total, String label) {
        if (!mounted) return;
        setState(() {
          _progress = total == 0 ? 0 : done / total;
          _status = label;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _cards = results;
      _running = false;
      _status = '${results.length} cards done.';
    });
  }

  Future<void> _export() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File out = File(p.join(dir.path, 'spike_results.json'));
    await out.writeAsString(SpikeRunner.toJsonReport(_cards));

    if (!mounted) return;
    setState(() => _exportPath = out.path);

    // The device path is what you need for `adb pull` / the Files app, so make
    // it copyable rather than just readable.
    await Clipboard.setData(ClipboardData(text: out.path));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Path copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR spike'),
        // Declared rather than relying on the implied leading: go_router pushes
        // this onto a nested navigator, and the automatic back button does not
        // always resolve there.
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_availability != null) _AvailabilityBanner(_availability!),
            const SizedBox(height: Gap.md),
            FilledButton.icon(
              onPressed: _running ? null : _pickAndRun,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pick cards and run'),
            ),
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              onPressed: _running ? null : _runQuestionSet,
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Run a question set'),
            ),
            if (_evalSummary case final String summary) ...<Widget>[
              const SizedBox(height: Gap.sm),
              SelectableText(
                summary,
                style: AppText.small(AppColors.of(context)),
              ),
            ],
            if (_cards.isNotEmpty && !_running) ...<Widget>[
              const SizedBox(height: Gap.sm),
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.ios_share),
                label: const Text('Export results JSON'),
              ),
            ],
            const SizedBox(height: Gap.md),
            // A determinate rail rather than a Material bar: this one has a
            // real fraction to show, which is the only kind of progress the
            // design allows on screen at all.
            if (_running)
              SizedBox(
                height: 2,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) => Stack(
                    children: <Widget>[
                      Container(
                        height: 2,
                        color: AppColors.of(context).hairline,
                      ),
                      Container(
                        height: 2,
                        width: box.maxWidth * _progress.clamp(0, 1),
                        color: AppColors.of(context).ochre,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Gap.sm),
            Text(_status, style: AppText.small(AppColors.of(context))),
            if (_exportPath != null) ...<Widget>[
              const SizedBox(height: Gap.sm),
              SelectableText(
                _exportPath!,
                style: AppText.small(AppColors.of(context)),
              ),
            ],
            const SizedBox(height: Gap.md),
            Expanded(
              child: ListView.separated(
                itemCount: _cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                itemBuilder: (_, int i) => _CardComparison(card: _cards[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner(this.availability);

  final Map<String, bool> availability;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    final List<String> missing = availability.entries
        .where((MapEntry<String, bool> e) => !e.value)
        .map((MapEntry<String, bool> e) => e.key)
        .toList();

    if (missing.isEmpty) {
      return Text(
        'All engines available.',
        style: AppText.small(c).copyWith(color: c.ochreInk),
      );
    }
    return Card(
      color: c.vermilion.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Text(
          'Unavailable: ${missing.join(", ")}.\n'
          'No engine in this build reads Bengali, so Bengali cards will '
          'score empty — that is the finding, not a fault.',
          style: AppText.small(c).copyWith(color: c.vermilion),
        ),
      ),
    );
  }
}

class _CardComparison extends StatelessWidget {
  const _CardComparison({required this.card});

  final SpikeCard card;

  @override
  Widget build(BuildContext context) {
    final AppColors c = AppColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(card.imageName, style: AppText.rowTitle(c)),
            const SizedBox(height: Gap.sm),
            for (final SpikeCardResult r in card.results) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(r.engineId, style: AppText.micro(c))),
                  Text(
                    '${r.durationMs}ms · ${r.blockCount} blocks',
                    style: AppText.small(c),
                  ),
                ],
              ),
              if (r.failure != null)
                Text(
                  r.failure!,
                  style: AppText.small(c).copyWith(color: c.vermilion),
                ),
              if (r.fields.isNotEmpty)
                Text(
                  r.fields.entries
                      .map(
                        (MapEntry<String, String> e) => '${e.key}: ${e.value}',
                      )
                      .join('\n'),
                  style: AppText.small(c),
                ),
              const SizedBox(height: Gap.sm),
            ],
          ],
        ),
      ),
    );
  }
}
