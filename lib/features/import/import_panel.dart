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
import 'other_payment_review.dart';

class ImportPanel extends ConsumerStatefulWidget {
  final VoidCallback onManual, onCancel;
  final ValueChanged<DateTime>? onOtherSpending;
  final ValueChanged<List<Entry>>? onStagedImport;
  final List<Entry> pendingEntries;
  final DateTime? openingDate;
  final ValueChanged<DateTime>? onImported;
  final void Function(DateTime start, DateTime end)? onImportedRange;
  final bool showFollowUp;
  final VoidCallback? onNewImport;
  const ImportPanel({
    super.key,
    required this.onManual,
    required this.onCancel,
    this.onOtherSpending,
    this.onStagedImport,
    this.pendingEntries = const [],
    this.openingDate,
    this.onImported,
    this.onImportedRange,
    this.showFollowUp = true,
    this.onNewImport,
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
  DateTime? _periodStart, _periodEnd;
  final phone = TextEditingController();
  bool phoneLoaded = false, phoneEdited = false, editingPhone = false;
  int processedTotal = 0;
  final _reviewScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final saved = await TngPhone().read();
      if (mounted && !phoneEdited) phone.text = saved ?? '';
    } catch (_) {
      if (mounted) setState(() => error = context.tr('tng_phone_setup.001'));
    } finally {
      if (mounted) setState(() => phoneLoaded = true);
    }
  }

  @override
  void dispose() {
    _reviewScroll.dispose();
    phone.dispose();
    super.dispose();
  }

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
  int get statementTotal => rows
      .where((row) => types[row.fingerprint] == 'expense')
      .fold<int>(0, (sum, row) => sum + row.amount);
  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final unlockPhone = TngPhone.normalize(phone.text);
      FocusScope.of(context).unfocus();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null) return;
      if (!mounted) return;
      final f = result.files.single;
      if (f.bytes == null || f.size > 20 * 1024 * 1024) {
        throw FormatException(tr('import_panel.002'));
      }
      if (imported) widget.onNewImport?.call();
      setState(() {
        imported = false;
        ready = false;
        details = false;
        rows = [];
        selected.clear();
        types.clear();
      });
      fileHash = sha256.convert(f.bytes!).toString();
      final statement = await TngPdf.extractStatement(
        f.bytes!,
        TngPhone.password(unlockPhone),
      );
      if (!mounted) return;
      final parsed = statement.transactions;
      if (parsed.isEmpty) {
        throw FormatException(tr('import_panel.003'));
      }
      if (parsed.any(
        (row) => DateTime.parse(row.date).isAfter(day(DateTime.now())),
      )) {
        throw FormatException(tr('import_panel.004'));
      }
      // A corrected number is remembered only after it successfully unlocks a file.
      try {
        await TngPhone().save(unlockPhone);
      } catch (_) {
        if (mounted) notice(context, context.tr('import_panel.phoneSaveError'));
      }
      if (!mounted) return;
      phone.text = unlockPhone;
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
          _periodStart = statement.start;
          _periodEnd = statement.end;
          ready = true;
          editingPhone = false;
          details = false;
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
    final spendingTotal = statementTotal;
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
            importData: {
              ...r.metadata,
              'fileHash': fileHash,
              if (_periodStart != null)
                'statementStart': dateKey(_periodStart!),
              if (_periodEnd != null) 'statementEnd': dateKey(_periodEnd!),
            },
          ),
        )
        .toList();
    if (widget.onStagedImport == null &&
        !await confirm(
          context,
          context.tr('import_panel.007', {
            'p0': entries.length,
            'p1': money(total),
            'p2': widget.onStagedImport != null
                ? context.tr('transaction_form.includedInBalance')
                : historical
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
          final last = _periodEnd ?? DateTime.parse(rows.last.date);
          final today = day(DateTime.now());
          importedDate = last.isAfter(today) ? today : last;
          processedTotal = spendingTotal;
        });
        widget.onImported?.call(importedDate!);
        widget.onImportedRange?.call(
          _periodStart ?? importedDate!,
          importedDate!,
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = context.tr('import_panel.011'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (ref.read(ledgerProvider).requireValue.profile != null) {
        await ref.read(ledgerProvider.notifier).change((l) {
          final dates = Set<String>.from(l.profile!['recordedDays'] ?? []);
          final start = _periodStart ?? importedDate!;
          final end = importedDate!;
          for (
            var date = start;
            !date.isAfter(end);
            date = DateTime(date.year, date.month, date.day + 1)
          ) {
            dates.add(dateKey(date));
          }
          l.profile!['recordedDays'] = dates.toList();
        });
      }
      if (mounted) widget.onCancel();
    } catch (_) {
      if (mounted) notice(context, context.tr('import_panel.012'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _acceptPhone() {
    try {
      phone.text = TngPhone.normalize(phone.text);
      FocusScope.of(context).unfocus();
      setState(() => editingPhone = false);
    } catch (error) {
      notice(context, error);
    }
  }

  Widget _phoneLabel() {
    if (!phoneLoaded || phone.text.isEmpty || editingPhone) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              enableSuggestions: false,
              readOnly: busy || !phoneLoaded,
              autofocus: editingPhone,
              onChanged: (_) {
                phoneEdited = true;
                if (!editingPhone) setState(() => editingPhone = true);
              },
              onSubmitted: (_) => _acceptPhone(),
              decoration: InputDecoration(
                labelText: context.tr('tng_phone_setup.005'),
                hintText: context.tr('tng_phone_setup.005'),
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('import_panel.done'),
            icon: const Icon(Icons.check),
            onPressed: busy || !phoneLoaded ? null : _acceptPhone,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text('${context.tr('tng_phone_setup.005')}: ${phone.text}'),
        ),
        IconButton(
          tooltip: context.tr('tng_phone_setup.008'),
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: busy ? null : () => setState(() => editingPhone = true),
        ),
      ],
    );
  }

  static const _reviewColumns = <int, TableColumnWidth>{
    0: FixedColumnWidth(36),
    1: FlexColumnWidth(),
    2: FixedColumnWidth(80),
  };

  Widget _reviewCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: child,
  );

  Widget _reviewTable() {
    final knownRows = known;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Table(
              columnWidths: _reviewColumns,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    _reviewCell(
                      Text(
                        context.tr('records.details'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    _reviewCell(
                      Text(
                        context.tr('transaction_form.006'),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: Scrollbar(
              controller: _reviewScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _reviewScroll,
                primary: false,
                child: Table(
                  columnWidths: _reviewColumns,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: .3),
                    ),
                  ),
                  children: rows.map((row) {
                    final duplicate = knownRows.contains(row.fingerprint);
                    final category = types[row.fingerprint];
                    return TableRow(
                      key: ValueKey(row.fingerprint),
                      children: [
                        Checkbox(
                          value: selected[row.fingerprint] ?? false,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: busy || imported || duplicate
                              ? null
                              : (value) => setState(
                                  () => selected[row.fingerprint] =
                                      value ?? false,
                                ),
                        ),
                        _reviewCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                row.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${row.date}\n${tngLabel(row.transactionType)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (duplicate && !imported)
                                Text(
                                  context.tr('import_panel.duplicate'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              else if (imported)
                                Text(
                                  category == null ? '—' : typeLabel(category),
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              else ...[
                                if (possibleManual.contains(row.fingerprint))
                                  Text(
                                    context.tr(
                                      'import_panel.possibleDuplicate',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('type_${row.fingerprint}'),
                                  initialValue: category,
                                  isExpanded: true,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.all(8),
                                    hintText: context.tr(
                                      'import_panel.chooseCategory',
                                    ),
                                  ),
                                  items: ['expense', 'refund', 'income']
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(
                                            typeLabel(type),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: busy
                                      ? null
                                      : (value) => setState(
                                          () => types[row.fingerprint] = value,
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _reviewCell(
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              money(row.amount),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsReview =
        possibleManual.isNotEmpty ||
        rows.any((row) => types[row.fingerprint] == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('import_panel.018'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _phoneLabel(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy || !phoneLoaded ? null : pick,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    context.tr(busy ? 'import_panel.020' : 'import_panel.021'),
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (ready || imported) ...[
                  const SizedBox(height: 16),
                  if (_periodStart != null &&
                      _periodEnd != null &&
                      _periodStart != _periodEnd)
                    Text(
                      '${dateKey(_periodStart!)} – ${dateKey(_periodEnd!)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  Text(context.tr('import_panel.totalSpending')),
                  Text(
                    money(imported ? processedTotal : statementTotal),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => setState(() => details = !details),
                    icon: Icon(
                      details
                          ? Icons.expand_less
                          : needsReview
                          ? Icons.info_outline
                          : Icons.table_chart_outlined,
                    ),
                    label: Text(
                      context.tr(
                        details
                            ? 'import_panel.hideReview'
                            : 'import_panel.review',
                      ),
                    ),
                  ),
                  if (details) ...[_reviewTable(), const SizedBox(height: 12)],
                  if (!imported)
                    FilledButton(
                      onPressed: busy ? null : commit,
                      child: Text(context.tr('import_panel.addRecords')),
                    ),
                ],
                if (!imported)
                  TextButton(
                    onPressed: busy ? null : widget.onCancel,
                    child: Text(context.tr('import_panel.037')),
                  ),
              ],
            ),
          ),
        ),
        if (imported && widget.showFollowUp)
          OtherPaymentReview(
            date: _periodStart ?? importedDate!,
            endDate: importedDate!,
            enabled: !busy,
            onYes: () => widget.onOtherSpending != null
                ? widget.onOtherSpending!(importedDate!)
                : widget.onManual(),
            onNo: finish,
          ),
      ],
    );
  }
}
