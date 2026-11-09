import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/spending/spending_export.dart';
import '../../../core/spending/spending_totals.dart';
import '../../../core/storage/hand_offs.dart';

final spendingShareProvider = Provider<SpendingShare>(
  (Ref ref) => SpendingShare(),
);

/// Hands a receipt total to the share sheet: the spreadsheet as a file, the
/// note as the message (B4). What goes is built by [SpendingExport].
class SpendingShare {
  /// True when the share sheet opened on it.
  Future<bool> share(SpendingSummary s) async {
    File? out;
    try {
      final DateTime now = DateTime.now();
      final Directory dir = await outboxDirectory();
      out = File(p.join(dir.path, SpendingExport.fileName(s)));
      await out.writeAsString(SpendingExport.csv(s));
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(out.path, mimeType: 'text/csv')],
          subject: 'RecallOS receipt totals — ${s.period.label}',
          text: SpendingExport.note(s, sharedOn: now),
        ),
      );
      return true;
    } on Object {
      return false;
    } finally {
      // share_plus keeps its own copy, cleared by the launch sweep.
      if (out != null) await discardHandOff(out);
    }
  }
}
