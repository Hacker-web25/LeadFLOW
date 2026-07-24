import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

import '../domain/lead.dart';

/// Which lead each parsed spreadsheet row targeted, and the patched Lead
/// ready to be written back. Callers decide how to batch the writes.
class LeadPatch {
  const LeadPatch({required this.source, required this.patched});
  final Lead source;
  final Lead patched;

  bool get changed =>
      source.contact.fullName != patched.contact.fullName ||
      source.contact.firstName != patched.contact.firstName ||
      source.contact.designation != patched.contact.designation ||
      source.contact.email != patched.contact.email ||
      source.contact.phone != patched.contact.phone ||
      source.contact.altPhone != patched.contact.altPhone ||
      source.contact.address != patched.contact.address ||
      source.company?.name != patched.company?.name ||
      source.company?.website != patched.company?.website ||
      source.company?.city != patched.company?.city ||
      source.company?.state != patched.company?.state ||
      source.company?.postalCode != patched.company?.postalCode ||
      source.company?.country != patched.company?.country ||
      source.temperature != patched.temperature ||
      source.timeline != patched.timeline ||
      source.customerType != patched.customerType ||
      source.isDecisionMaker != patched.isDecisionMaker ||
      source.exportRequirement != patched.exportRequirement ||
      source.salesTeamRequired != patched.salesTeamRequired ||
      source.additionalNotes != patched.additionalNotes;
}

/// Round-trip Leads ↔ Excel. Uses a stable, self-documenting column layout
/// so an exported file re-imports cleanly even if the user manually
/// reorders / hides columns in Excel (we match by header name, not index).
abstract final class LeadsXlsx {
  /// One tuple per column: (field key, header shown in Excel, column width).
  /// The ID column is first + read-only in intent; import matches on it.
  /// `First Name` sits next to `Name` so a Zoho import can map either.
  static const List<(String, String, double)> _columns = [
    ('id',                  'ID (do not edit)', 36),
    ('first_name',          'First Name',        18),
    ('name',                'Name',              22),
    ('designation',         'Designation',       18),
    ('company',             'Company',           24),
    ('website',             'Website',           18),
    ('mobile',              'Mobile',            16),
    ('phone',               'Phone',             16),
    ('email',               'Email',             26),
    ('address',             'Address',           30),
    ('city',                'City',              14),
    ('state',               'State',             14),
    ('postal_code',         'Postal Code',       12),
    ('country',             'Country',           14),
    ('temperature',         'Temperature',       12),
    ('timeline',            'Timeline',          14),
    ('customer_type',       'Customer Type',     15),
    ('decision_maker',      'Decision Maker',    14),
    ('export_requirement',  'Export',            10),
    ('sales_team_required', 'Sales Team',        12),
    ('notes',               'Notes',             40),
    ('captured_at',         'Captured',          22),
  ];

  static const _uuid = Uuid();

  // ─── Export ─────────────────────────────────────────────────────────────
  static Uint8List export(List<Lead> leads) {
    final excel = Excel.createExcel();
    // The package auto-creates "Sheet1"; rename to "Leads" so imports
    // (which look for "Leads" first) round-trip cleanly.
    excel.rename('Sheet1', 'Leads');
    final sheet = excel['Leads'];

    // Header row.
    sheet.appendRow(
      _columns.map((c) => TextCellValue(c.$2)).toList(),
    );
    // Column widths for readability in Excel.
    for (var i = 0; i < _columns.length; i++) {
      sheet.setColumnWidth(i, _columns[i].$3);
    }
    // Data rows.
    for (final lead in leads) {
      sheet.appendRow(
        _rowFromLead(lead)
            .map((v) => TextCellValue(v ?? ''))
            .toList(),
      );
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? const []);
  }

  static List<String?> _rowFromLead(Lead l) => [
        l.id,
        l.contact.firstName ?? Contact.deriveFirstName(l.contact.fullName),
        l.contact.fullName,
        l.contact.designation,
        l.company?.name,
        l.company?.website,
        l.contact.phone,
        l.contact.altPhone,
        l.contact.email,
        l.contact.address,
        l.company?.city,
        l.company?.state,
        l.company?.postalCode,
        l.company?.country,
        l.temperature?.label,
        l.timeline?.label,
        l.customerType?.label,
        _yn(l.isDecisionMaker),
        _yn(l.exportRequirement),
        _yn(l.salesTeamRequired),
        l.additionalNotes,
        l.capturedAt.toIso8601String(),
      ];

  static String? _yn(bool? b) => b == null ? '' : (b ? 'Yes' : 'No');

  // ─── Import ─────────────────────────────────────────────────────────────
  /// Parse an uploaded xlsx and return one [LeadPatch] per row whose ID
  /// matches an existing lead. Rows with missing / unknown / new IDs are
  /// skipped — this is a targeted UPDATE tool, not an insert tool.
  static List<LeadPatch> parse(Uint8List bytes, List<Lead> existing) {
    final excel = Excel.decodeBytes(bytes);
    // Prefer a sheet literally named "Leads", else fall back to the first one.
    final sheet = excel.tables['Leads'] ?? excel.tables.values.first;
    if (sheet.rows.isEmpty) return const [];

    // Build a header → column index map from row 0 so column order in the
    // uploaded file is irrelevant. Header text is normalised (case-insensitive,
    // trimmed) to survive Excel's small edits.
    final header = <String, int>{};
    final firstRow = sheet.rows.first;
    for (var i = 0; i < firstRow.length; i++) {
      final raw = firstRow[i]?.value?.toString();
      if (raw == null) continue;
      final norm = raw.toLowerCase().trim();
      // Map both the human label ("Name") and the field key ("name") so
      // both flavours of edited files resolve correctly.
      for (final col in _columns) {
        if (norm == col.$1.toLowerCase() || norm == col.$2.toLowerCase()) {
          header[col.$1] = i;
          break;
        }
      }
    }

    // Fast lookup for the source leads.
    final byId = {for (final l in existing) l.id: l};

    final patches = <LeadPatch>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];

      /// Was this column present in the uploaded sheet?
      bool has(String key) => header.containsKey(key);

      /// Trimmed cell value, or null when the cell is empty. Only meaningful
      /// after `has(key)` returns true — for a missing column it's always null.
      String? cell(String key) {
        final idx = header[key];
        if (idx == null || idx >= row.length) return null;
        final v = row[idx]?.value;
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      final id = cell('id');
      if (id == null) continue;
      final source = byId[id];
      if (source == null) continue;

      patches.add(LeadPatch(
          source: source, patched: _applyRow(source, has: has, cell: cell)));
    }
    return patches;
  }

  /// Build a fresh Lead directly (no copyWith) so the "column present with an
  /// empty cell" case sets the field to `null`, while "column missing" keeps
  /// the source value. This is the source of the earlier "some fields update,
  /// some don't" bug: copyWith's `x ?? this.x` treats both cases as "no change".
  static Lead _applyRow(
    Lead source, {
    required bool Function(String) has,
    required String? Function(String) cell,
  }) {
    // Pick "source if the column isn't there, else the (possibly-null) cell".
    T? read<T>(String key, T? source, T? Function(String? raw) parse) {
      if (!has(key)) return source;
      return parse(cell(key));
    }

    String? readStr(String key, String? source) =>
        !has(key) ? source : cell(key);

    final contact = Contact(
      id: source.contact.id,
      // Name is required — never allow blanking it out.
      fullName: has('name')
          ? (cell('name') ?? source.contact.fullName)
          : source.contact.fullName,
      firstName: readStr('first_name', source.contact.firstName),
      designation: readStr('designation', source.contact.designation),
      email: readStr('email', source.contact.email),
      phone: readStr('mobile', source.contact.phone),
      altPhone: readStr('phone', source.contact.altPhone),
      address: readStr('address', source.contact.address),
    );

    // Company: only build if we have a non-empty name.
    final companyName = has('company') ? cell('company') : source.company?.name;
    final company = (companyName == null || companyName.isEmpty)
        ? null
        : Company(
            id: source.company?.id ?? _uuid.v4(),
            name: companyName,
            website: readStr('website', source.company?.website),
            city: readStr('city', source.company?.city),
            state: readStr('state', source.company?.state),
            postalCode: readStr('postal_code', source.company?.postalCode),
            country: readStr('country', source.company?.country),
          );

    return Lead(
      id: source.id,
      contact: contact,
      company: company,
      eventName: source.eventName,
      status: source.status,
      temperature: read<LeadTemperature>('temperature', source.temperature,
          (v) => _matchEnum(v, LeadTemperature.values, (e) => e.label)),
      timeline: read<RequirementTimeline>('timeline', source.timeline,
          (v) => _matchEnum(v, RequirementTimeline.values, (e) => e.label)),
      customerType: read<CustomerType>('customer_type', source.customerType,
          (v) => _matchEnum(v, CustomerType.values, (e) => e.label)),
      isDecisionMaker:
          read<bool>('decision_maker', source.isDecisionMaker, _parseBool),
      exportRequirement:
          read<bool>('export_requirement', source.exportRequirement, _parseBool),
      salesTeamRequired:
          read<bool>('sales_team_required', source.salesTeamRequired, _parseBool),
      additionalNotes: readStr('notes', source.additionalNotes),
      capturedAt: source.capturedAt,
      cardImagePath: source.cardImagePath,
    );
  }

  static T? _matchEnum<T>(String? v, List<T> values, String Function(T) label) {
    if (v == null) return null;
    final t = v.toLowerCase();
    for (final e in values) {
      if (label(e).toLowerCase() == t) return e;
    }
    return null;
  }

  static bool? _parseBool(String? v) {
    if (v == null) return null;
    final t = v.toLowerCase();
    if (t == 'yes' || t == 'y' || t == 'true' || t == '1') return true;
    if (t == 'no' || t == 'n' || t == 'false' || t == '0') return false;
    return null;
  }
}
