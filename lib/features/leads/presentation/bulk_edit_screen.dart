import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/lf_chip.dart';
import '../../../core/widgets/lf_search_field.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../data/leads_xlsx.dart';
import '../domain/lead.dart';
import '../domain/needs_review.dart';
import 'providers/leads_providers.dart';

/// True spreadsheet view over all leads.
///
/// - Click any cell to edit (Excel-like), Tab / arrow keys to move
/// - Frozen "Name" column so orientation is never lost during horizontal scroll
/// - Dropdowns for typed enums (temperature, timeline, customer type)
/// - Auto-save on cell commit (Tab / Enter / blur) — no explicit save
/// - Filter chips: Needs review (default), Today, Hot, All
/// - Search bar filters across all columns
class BulkEditScreen extends ConsumerStatefulWidget {
  const BulkEditScreen({super.key});

  @override
  ConsumerState<BulkEditScreen> createState() => _BulkEditScreenState();
}

enum _Bucket { all, today, needsReview, hot }

extension on _Bucket {
  String get label => switch (this) {
        _Bucket.all => 'All',
        _Bucket.today => 'Today',
        _Bucket.needsReview => 'Needs review',
        _Bucket.hot => 'Hot',
      };
}

class _BulkEditScreenState extends ConsumerState<BulkEditScreen> {
  _Bucket _bucket = _Bucket.needsReview;
  String _query = '';

  PlutoGridStateManager? _sm;
  // Row key (uuid) → source Lead. Lets us map a cell-change event back to a
  // full Lead object so we can rebuild it and hit updateLead.
  final Map<String, Lead> _rowLeadIndex = {};
  Timer? _saveDebounce;

  static const _colName = 'name';
  static const _colDesignation = 'designation';
  static const _colCompany = 'company';
  static const _colWebsite = 'website';
  static const _colMobile = 'mobile';
  static const _colPhone = 'phone';
  static const _colEmail = 'email';
  static const _colAddress = 'address';
  static const _colCity = 'city';
  static const _colCountry = 'country';
  static const _colTemperature = 'temperature';
  static const _colTimeline = 'timeline';
  static const _colCustomerType = 'customerType';
  static const _colDecisionMaker = 'decisionMaker';
  static const _colCapturedAt = 'capturedAt';

  static const _uuid = Uuid();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Lock landscape while this screen is on top — the grid needs the
    // width. On web this is a no-op; on mobile it forces rotation and
    // restores portrait when we leave.
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk edit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Export to Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _busy
                ? null
                : () => _exportToExcel(leadsAsync.valueOrNull ?? const []),
          ),
          IconButton(
            tooltip: 'Import from Excel',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _busy
                ? null
                : () => _importFromExcel(leadsAsync.valueOrNull ?? const []),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x3),
          child: LfSearchField(onChanged: (q) => setState(() => _query = q)),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            scrollDirection: Axis.horizontal,
            children: [
              for (final b in _Bucket.values) ...[
                LfChoiceChip(
                  label: b.label,
                  selected: _bucket == b,
                  onTap: () => setState(() => _bucket = b),
                ),
                const SizedBox(width: AppSpacing.x2),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Expanded(
          child: leadsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => LfErrorState(
              message: 'Could not load your leads.',
              onRetry: () => ref.invalidate(leadsStreamProvider),
            ),
            data: (all) {
              final leads = _filter(all);
              if (leads.isEmpty) {
                return LfEmptyState(
                  icon: Icons.check_circle_outline,
                  title: _bucket == _Bucket.needsReview
                      ? 'Nothing to review'
                      : 'No leads match',
                  message: _bucket == _Bucket.needsReview
                      ? 'Every scanned lead has the essentials filled in.'
                      : 'Try a different filter or clear the search.',
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                child: _Grid(
                  leads: leads,
                  columns: _buildColumns(),
                  buildRows: _buildRows,
                  onCellChanged: _onCellChanged,
                  onLoaded: (sm) => _sm = sm,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  List<Lead> _filter(List<Lead> all) {
    final q = _query.trim().toLowerCase();
    return all.where((l) {
      switch (_bucket) {
        case _Bucket.today:
          if (!l.capturedAt.isToday) return false;
          break;
        case _Bucket.needsReview:
          if (!NeedsReview.check(l)) return false;
          break;
        case _Bucket.hot:
          if (l.temperature != LeadTemperature.hot) return false;
          break;
        case _Bucket.all:
          break;
      }
      if (q.isEmpty) return true;
      final hay = [
        l.contact.fullName,
        l.contact.designation ?? '',
        l.contact.email ?? '',
        l.contact.phone ?? '',
        l.company?.name ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  // ── Columns ─────────────────────────────────────────────────────────────
  List<PlutoColumn> _buildColumns() => [
        PlutoColumn(
          title: '', field: '_flag',
          type: PlutoColumnType.text(),
          width: 40, minWidth: 40, enableEditingMode: false,
          enableColumnDrag: false, enableSorting: false, enableFilterMenuItem: false,
          renderer: (r) {
            final flagged = r.cell.value == 'y';
            return Center(
              child: flagged
                  ? const Icon(Icons.error_outline_rounded,
                      color: AppColors.hot, size: 18)
                  : const SizedBox.shrink(),
            );
          },
        ),
        PlutoColumn(
          title: 'Name', field: _colName,
          type: PlutoColumnType.text(),
          width: 170, frozen: PlutoColumnFrozen.start,
        ),
        PlutoColumn(
            title: 'Designation', field: _colDesignation,
            type: PlutoColumnType.text(), width: 160),
        PlutoColumn(
            title: 'Company', field: _colCompany,
            type: PlutoColumnType.text(), width: 180),
        PlutoColumn(
          title: 'Temp', field: _colTemperature,
          type: PlutoColumnType.select(<String>[
            '',
            ...LeadTemperature.values.map((e) => e.label),
          ]),
          width: 90,
        ),
        PlutoColumn(
          title: 'Timeline', field: _colTimeline,
          type: PlutoColumnType.select(<String>[
            '',
            ...RequirementTimeline.values.map((e) => e.label),
          ]),
          width: 130,
        ),
        PlutoColumn(
          title: 'Customer', field: _colCustomerType,
          type: PlutoColumnType.select(<String>[
            '',
            ...CustomerType.values.map((e) => e.label),
          ]),
          width: 130,
        ),
        PlutoColumn(
          title: 'DM', field: _colDecisionMaker,
          type: PlutoColumnType.select(const ['', 'Yes', 'No']),
          width: 70,
        ),
        PlutoColumn(
            title: 'Mobile', field: _colMobile,
            type: PlutoColumnType.text(), width: 150),
        PlutoColumn(
            title: 'Phone', field: _colPhone,
            type: PlutoColumnType.text(), width: 150),
        PlutoColumn(
            title: 'Email', field: _colEmail,
            type: PlutoColumnType.text(), width: 220),
        PlutoColumn(
            title: 'Website', field: _colWebsite,
            type: PlutoColumnType.text(), width: 160),
        PlutoColumn(
            title: 'Address', field: _colAddress,
            type: PlutoColumnType.text(), width: 260),
        PlutoColumn(
            title: 'City', field: _colCity,
            type: PlutoColumnType.text(), width: 120),
        PlutoColumn(
            title: 'Country', field: _colCountry,
            type: PlutoColumnType.text(), width: 120),
        PlutoColumn(
          title: 'Captured', field: _colCapturedAt,
          type: PlutoColumnType.text(),
          width: 100, enableEditingMode: false,
        ),
      ];

  // ── Rows ────────────────────────────────────────────────────────────────
  List<PlutoRow> _buildRows(List<Lead> leads) {
    _rowLeadIndex.clear();
    return leads.map((l) {
      final key = _uuid.v4();
      _rowLeadIndex[key] = l;
      return PlutoRow(
        key: ValueKey(key),
        cells: {
          '_flag': PlutoCell(value: NeedsReview.check(l) ? 'y' : ''),
          _colName: PlutoCell(value: l.contact.fullName),
          _colDesignation: PlutoCell(value: l.contact.designation ?? ''),
          _colCompany: PlutoCell(value: l.company?.name ?? ''),
          _colTemperature: PlutoCell(value: l.temperature?.label ?? ''),
          _colTimeline: PlutoCell(value: l.timeline?.label ?? ''),
          _colCustomerType: PlutoCell(value: l.customerType?.label ?? ''),
          _colDecisionMaker: PlutoCell(
              value: switch (l.isDecisionMaker) {
                true => 'Yes', false => 'No', null => '',
              }),
          _colMobile: PlutoCell(value: l.contact.phone ?? ''),
          _colPhone: PlutoCell(value: l.contact.altPhone ?? ''),
          _colEmail: PlutoCell(value: l.contact.email ?? ''),
          _colWebsite: PlutoCell(value: l.company?.website ?? ''),
          _colAddress: PlutoCell(value: l.contact.address ?? ''),
          _colCity: PlutoCell(value: l.company?.city ?? ''),
          _colCountry: PlutoCell(value: l.company?.country ?? ''),
          _colCapturedAt: PlutoCell(value: l.capturedAt.relativeLabel),
        },
      );
    }).toList();
  }

  // ── Save ────────────────────────────────────────────────────────────────
  void _onCellChanged(PlutoGridOnChangedEvent e) {
    // Debounce so rapid Tab-across-row edits merge into one write.
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () => _persist(e));
  }

  Future<void> _persist(PlutoGridOnChangedEvent e) async {
    final key = (e.row.key as ValueKey).value as String;
    final source = _rowLeadIndex[key];
    if (source == null) return;

    final cells = e.row.cells;
    String? s(String col) {
      final v = (cells[col]?.value ?? '').toString().trim();
      return v.isEmpty ? null : v;
    }

    final contact = source.contact.copyWith(
      fullName: (cells[_colName]?.value ?? '').toString().trim().isEmpty
          ? source.contact.fullName
          : (cells[_colName]!.value as String).trim(),
      designation: s(_colDesignation),
      email: s(_colEmail),
      phone: s(_colMobile),
      altPhone: s(_colPhone),
      address: s(_colAddress),
    );
    final companyName = (cells[_colCompany]?.value ?? '').toString().trim();
    final company = companyName.isEmpty
        ? null
        : Company(
            id: source.company?.id ?? _uuid.v4(),
            name: companyName,
            website: s(_colWebsite),
            city: s(_colCity),
            country: s(_colCountry),
          );

    final next = source
        .withContact(contact)
        .withCompany(company)
        .copyWith(
          temperature: _matchEnum<LeadTemperature>(
              cells[_colTemperature]?.value, LeadTemperature.values, (e) => e.label),
          timeline: _matchEnum<RequirementTimeline>(
              cells[_colTimeline]?.value, RequirementTimeline.values, (e) => e.label),
          customerType: _matchEnum<CustomerType>(
              cells[_colCustomerType]?.value, CustomerType.values, (e) => e.label),
          isDecisionMaker: switch ((cells[_colDecisionMaker]?.value ?? '').toString()) {
            'Yes' => true, 'No' => false, _ => null,
          },
        );

    final r = await ref.read(leadRepositoryProvider).updateLead(next);
    if (!mounted) return;
    r.when(
      ok: (_) {
        _rowLeadIndex[key] = next;
        // Refresh the flag icon in-place — the review status may have flipped.
        e.row.cells['_flag']?.value = NeedsReview.check(next) ? 'y' : '';
        _sm?.notifyListeners();
      },
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  T? _matchEnum<T>(Object? cellValue, List<T> values, String Function(T) label) {
    final s = (cellValue ?? '').toString().trim();
    if (s.isEmpty) return null;
    for (final v in values) {
      if (label(v) == s) return v;
    }
    return null;
  }

  // ── Excel export / import ───────────────────────────────────────────────
  Future<void> _exportToExcel(List<Lead> all) async {
    final leads = _filter(all);
    if (leads.isEmpty) {
      _snack('Nothing to export in the current filter.');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = LeadsXlsx.export(leads);
      final now = DateTime.now();
      final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      // file_saver: web downloads via anchor, mobile writes to Downloads.
      await FileSaver.instance.saveFile(
        name: 'leadflow-$stamp',
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) _snack('Exported ${leads.length} leads to Excel.');
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromExcel(List<Lead> existing) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      _snack("Could not read the file.");
      return;
    }

    setState(() => _busy = true);
    List<LeadPatch> patches;
    try {
      patches = LeadsXlsx.parse(bytes, existing);
    } catch (e) {
      if (mounted) _snack('Could not parse this file: $e');
      if (mounted) setState(() => _busy = false);
      return;
    }

    final changed = patches.where((p) => p.changed).toList();
    if (changed.isEmpty) {
      _snack(
          'Nothing changed. Rows must have an ID matching an existing lead.');
      if (mounted) setState(() => _busy = false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apply Excel changes?'),
        content: Text(
            '${changed.length} lead${changed.length == 1 ? '' : 's'} will be updated. '
            'Rows with missing or unknown IDs are ignored.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    final repo = ref.read(leadRepositoryProvider);
    var ok = 0, failed = 0;
    for (final p in changed) {
      final r = await repo.updateLead(p.patched);
      r.when(ok: (_) => ok++, err: (_) => failed++);
    }

    // Force the leads stream to re-subscribe + refetch so the grid updates
    // immediately, even when the user's Supabase project doesn't have
    // realtime enabled on the tables we upserted.
    ref.invalidate(leadsStreamProvider);
    // Best-effort: wait one tick so the invalidated stream has a chance
    // to emit the fresh list before the grid rebuilds.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      setState(() => _busy = false);
      _snack(failed == 0
          ? 'Applied changes to $ok lead${ok == 1 ? '' : 's'}.'
          : 'Applied $ok · Failed $failed.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Isolated widget so column/row reconstruction only happens when the lead
/// list truly changes — not on filter chip taps.
class _Grid extends StatefulWidget {
  const _Grid({
    required this.leads,
    required this.columns,
    required this.buildRows,
    required this.onCellChanged,
    required this.onLoaded,
  });

  final List<Lead> leads;
  final List<PlutoColumn> columns;
  final List<PlutoRow> Function(List<Lead>) buildRows;
  final ValueChanged<PlutoGridOnChangedEvent> onCellChanged;
  final ValueChanged<PlutoGridStateManager> onLoaded;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  late List<PlutoRow> _rows = widget.buildRows(widget.leads);
  PlutoGridStateManager? _sm;

  @override
  void didUpdateWidget(covariant _Grid old) {
    super.didUpdateWidget(old);
    if (!identical(old.leads, widget.leads)) {
      _rows = widget.buildRows(widget.leads);
      // Reset the grid to the new rows without dropping keyboard focus.
      _sm?.removeAllRows();
      _sm?.appendRows(_rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PlutoGrid(
      columns: widget.columns,
      rows: _rows,
      onLoaded: (event) {
        _sm = event.stateManager;
        widget.onLoaded(event.stateManager);
      },
      onChanged: widget.onCellChanged,
      configuration: PlutoGridConfiguration(
        columnSize: const PlutoGridColumnSizeConfig(
          autoSizeMode: PlutoAutoSizeMode.none,
        ),
        style: PlutoGridStyleConfig(
          gridBackgroundColor: c.surface,
          rowColor: c.surface,
          activatedColor: AppColors.iris.withValues(alpha: 0.12),
          activatedBorderColor: AppColors.iris,
          borderColor: c.hairline,
          gridBorderColor: c.hairline,
          columnTextStyle: theme.textTheme.labelLarge!
              .copyWith(color: c.inkSecondary, fontWeight: FontWeight.w600),
          cellTextStyle: theme.textTheme.bodyMedium!.copyWith(color: c.ink),
          iconColor: c.inkTertiary,
          menuBackgroundColor: c.surface,
          rowHeight: 44,
          columnHeight: 44,
          enableGridBorderShadow: false,
          gridBorderRadius: BorderRadius.circular(12),
          enableColumnBorderVertical: true,
          gridPopupBorderRadius: BorderRadius.circular(12),
          evenRowColor: isDark
              ? c.surfaceSunken.withValues(alpha: 0.4)
              : c.surfaceSunken,
        ),
      ),
    );
  }
}
