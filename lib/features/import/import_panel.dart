import '../../core/localization/context.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/models/ledger.dart';
import '../../core/services/tng_parser.dart';
import '../../core/services/tng_pdf.dart';
import '../../core/services/tng_phone.dart';
import 'tng_phone_setup.dart';

class ImportPanel extends ConsumerStatefulWidget {
  final VoidCallback onManual, onCancel;
  final ValueChanged<DateTime>? onOtherSpending;
  final ValueChanged<List<Entry>>? onStagedImport;
  final List<Entry> pendingEntries;
  final DateTime? openingDate;
  const ImportPanel({
    super.key,
    required this.onManual,
    required this.onCancel,
    this.onOtherSpending,
    this.onStagedImport,
    this.pendingEntries = const [],
    this.openingDate,
  });
  @override
  ConsumerState<ImportPanel> createState() => _ImportPanelState();
}

class _ImportPanelState extends ConsumerState<ImportPanel> {
  bool busy = false, ready = false, imported = false, details = false;
  String? error;
  String fileHash = '';
  List<TngTransaction> rows = [];
  final selected = <String, bool>{};
  final types = <String, String?>{};
  final possibleManual = <String>{};
  DateTime? importedDate;
  Set<String> get known => {
    ...ref.read(ledgerProvider).requireValue.fingerprints,
    ...widget.pendingEntries.map((e) => e.fingerprint),
  };
  List<TngTransaction> get included => rows
      .where(
        (r) =>
            selected[r.fingerprint] == true && !known.contains(r.fingerprint),
      )
      .toList();
  int get total => included
      .where((r) => types[r.fingerprint] == 'expense')
      .fold(0, (n, r) => n + r.amount);
  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
      ready = false;
      rows = [];
    });
    try {
      final phone = await TngPhone().read();
      if (phone == null) {
        throw FormatException(tr('import_panel.001'));
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null) return;
      final f = result.files.single;
      if (f.bytes == null || f.size > 20 * 1024 * 1024) {
        throw FormatException(tr('import_panel.002'));
      }
      fileHash = sha256.convert(f.bytes!).toString();
      final parsed = await TngPdf.extract(f.bytes!, TngPhone.password(phone));
      if (parsed.map((r) => r.date).toSet().length != 1) {
        throw FormatException(tr('import_panel.003'));
      }
      if (DateTime.parse(parsed.first.date).isAfter(day(DateTime.now()))) {
        throw FormatException(tr('import_panel.004'));
      }
      final l = ref.read(ledgerProvider).requireValue;
      possibleManual.clear();
      for (final r in parsed) {
        final duplicate = known.contains(r.fingerprint);
        final possibleManualDuplicate = [...l.entries, ...widget.pendingEntries]
            .any(
              (e) =>
                  e.method == 'TNG' &&
                  e.date == r.date &&
                  e.amount == r.amount &&
                  e.fingerprint.isEmpty,
            );
        selected[r.fingerprint] =
            !duplicate && !possibleManualDuplicate && r.suggestedType != null;
        if (possibleManualDuplicate) possibleManual.add(r.fingerprint);
        types[r.fingerprint] = r.suggestedType;
      }
      if (mounted) {
        setState(() {
          rows = parsed;
          ready = true;
          details =
              parsed.any((r) => r.suggestedType == null) ||
              possibleManual.isNotEmpty;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = context.tr('import_panel.005'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> commit() async {
    final items = included;
    if (items.any((r) => types[r.fingerprint] == null)) {
      notice(context, context.tr('import_panel.006'));
      return;
    }
    final l = ref.read(ledgerProvider).requireValue;
    final opening =
        widget.openingDate ??
        (l.profile == null ? null : DateTime.parse(l.profile!['openingDate']));
    final historical =
        opening != null &&
        items.any((r) => DateTime.parse(r.date).isBefore(opening));
    final entries = items
        .map(
          (r) => Entry(
            id: const Uuid().v4(),
            date: r.date,
            type: types[r.fingerprint]!,
            amount: r.amount,
            method: 'TNG',
            description: r.description,
            source: 'tng-pdf',
            fingerprint: r.fingerprint,
            importData: {...r.metadata, 'fileHash': fileHash},
          ),
        )
        .toList();
    if (!await confirm(
      context,
      context.tr('import_panel.007', {
        'p0': entries.length,
        'p1': money(total),
        'p2': historical
            ? context.tr('import_panel.008')
            : context.tr('import_panel.009'),
      }),
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      if (widget.onStagedImport != null) {
        widget.onStagedImport!(entries);
      } else {
        await ref.read(ledgerProvider.notifier).change((ledger) {
          for (final e in entries) {
            if (ledger.fingerprints.contains(e.fingerprint)) {
              throw FormatException(context.tr('import_panel.010'));
            }
            ledger.entries.add(e);
            ledger.fingerprints.add(e.fingerprint);
            ledger.achievements.add('record:${e.date}');
          }
        });
      }
      if (mounted) {
        setState(() {
          imported = true;
          importedDate = DateTime.parse(rows.first.date);
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = context.tr('import_panel.011'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish() async {
    try {
      if (ref.read(ledgerProvider).requireValue.profile != null) {
        await ref.read(ledgerProvider.notifier).change((l) {
          final dates = Set<String>.from(l.profile!['recordedDays'] ?? []);
          dates.add(dateKey(importedDate!));
          l.profile!['recordedDays'] = dates.toList();
        });
      }
      widget.onCancel();
    } catch (_) {
      if (mounted) notice(context, context.tr('import_panel.012'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imported) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              Text(
                context.tr('import_panel.013', {'p0': dateKey(importedDate!)}),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('import_panel.014'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(context.tr('import_panel.015')),
              FilledButton(
                onPressed: () => widget.onOtherSpending != null
                    ? widget.onOtherSpending!(importedDate!)
                    : widget.onManual(),
                child: Text(context.tr('import_panel.016')),
              ),
              OutlinedButton(
                onPressed: finish,
                child: Text(context.tr('import_panel.017')),
              ),
            ],
          ),
        ),
      );
    }
    final newRows = included;
    final duplicates = rows.where((r) => known.contains(r.fingerprint)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('import_panel.018'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(context.tr('import_panel.019')),
            const TngPhoneSetup(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            OutlinedButton.icon(
              onPressed: busy ? null : pick,
              icon: const Icon(Icons.upload_file),
              label: Text(
                busy
                    ? context.tr('import_panel.020')
                    : context.tr('import_panel.021'),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (ready) ...[
              if (possibleManual.isNotEmpty)
                Text(
                  context.tr('import_panel.022', {'p0': possibleManual.length}),
                ),
              Text(
                context.tr('import_panel.023', {
                  'p0': rows.first.date,
                  'p1': rows.length,
                  'p2': duplicates,
                }),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('import_panel.024', {'p0': money(total)}),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(context.tr('import_panel.025', {'p0': newRows.length})),
              Text(context.tr('import_panel.026')),
              TextButton(
                onPressed: () => setState(() => details = !details),
                child: Text(
                  details
                      ? context.tr('import_panel.027')
                      : context.tr('import_panel.028'),
                ),
              ),
              if (details)
                for (final r in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: selected[r.fingerprint] ?? false,
                            onChanged: known.contains(r.fingerprint)
                                ? null
                                : (v) => setState(
                                    () => selected[r.fingerprint] = v!,
                                  ),
                            title: Text(
                              '${money(r.amount)} · ${r.description}',
                            ),
                            subtitle: Text(
                              '${tngLabel(r.transactionType)} · ${tngLabel(r.status)}${known.contains(r.fingerprint) ? context.tr('import_panel.029') : ''}',
                            ),
                          ),
                          if (!known.contains(r.fingerprint))
                            DropdownButtonFormField<String>(
                              initialValue: types[r.fingerprint],
                              decoration: InputDecoration(
                                labelText: context.tr('import_panel.030'),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'expense',
                                  child: Text(context.tr('import_panel.031')),
                                ),
                                DropdownMenuItem(
                                  value: 'refund',
                                  child: Text(context.tr('import_panel.032')),
                                ),
                                DropdownMenuItem(
                                  value: 'income',
                                  child: Text(context.tr('import_panel.033')),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => types[r.fingerprint] = v),
                            ),
                        ],
                      ),
                    ),
                  ),
              FilledButton(
                onPressed: busy ? null : commit,
                child: Text(
                  newRows.isEmpty
                      ? context.tr('import_panel.034')
                      : context.tr('import_panel.035'),
                ),
              ),
            ],
            TextButton(
              onPressed: busy ? null : widget.onManual,
              child: Text(context.tr('import_panel.036')),
            ),
            TextButton(
              onPressed: busy ? null : widget.onCancel,
              child: Text(context.tr('import_panel.037')),
            ),
          ],
        ),
      ),
    );
  }
}
