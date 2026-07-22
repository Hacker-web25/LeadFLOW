import '../../follow_ups/domain/follow_up.dart';
import '../domain/lead.dart';

/// Mapping between Supabase rows and domain entities.
/// Kept in the data layer so the domain stays persistence-agnostic.
abstract final class LeadDto {
  static Lead fromJoinedRow(Map<String, dynamic> row) {
    final contact = row['contacts'] as Map<String, dynamic>;
    final company = row['companies'] as Map<String, dynamic>?;
    return Lead(
      id: row['id'] as String,
      contact: Contact(
        id: contact['id'] as String,
        fullName: contact['full_name'] as String,
        designation: contact['designation'] as String?,
        email: contact['email'] as String?,
        phone: contact['phone'] as String?,
        altPhone: contact['alt_phone'] as String?,
        address: contact['address'] as String?,
      ),
      company: company == null
          ? null
          : Company(
              id: company['id'] as String,
              name: company['name'] as String,
              website: company['website'] as String?,
              city: company['city'] as String?,
              country: company['country'] as String?,
            ),
      eventName: row['event_name'] as String?,
      status: _statusFrom(row['status'] as String?),
      temperature: _enumFrom(LeadTemperature.values, row['temperature'] as String?),
      timeline: _timelineFrom(row['timeline'] as String?),
      customerType: _customerFrom(row['customer_type'] as String?),
      isDecisionMaker: row['is_decision_maker'] as bool?,
      exportRequirement: row['export_requirement'] as bool?,
      salesTeamRequired: row['sales_team_required'] as bool?,
      additionalNotes: row['additional_notes'] as String?,
      capturedAt: DateTime.parse(row['captured_at'] as String).toLocal(),
    );
  }

  static Map<String, dynamic> toRow(Lead lead, {required String ownerId}) => {
        'id': lead.id,
        'owner_id': ownerId,
        'contact_id': lead.contact.id,
        'company_id': lead.company?.id,
        'event_name': lead.eventName,
        'status': _statusTo(lead.status),
        'temperature': lead.temperature?.name,
        'timeline': _timelineTo(lead.timeline),
        'customer_type': _customerTo(lead.customerType),
        'is_decision_maker': lead.isDecisionMaker,
        'export_requirement': lead.exportRequirement,
        'sales_team_required': lead.salesTeamRequired,
        'additional_notes': lead.additionalNotes,
        'captured_at': lead.capturedAt.toUtc().toIso8601String(),
      };

  static FollowUp followUpFromRow(Map<String, dynamic> row) {
    final lead = row['leads'] as Map<String, dynamic>;
    final contact = lead['contacts'] as Map<String, dynamic>;
    final company = lead['companies'] as Map<String, dynamic>?;
    return FollowUp(
      id: row['id'] as String,
      leadId: row['lead_id'] as String,
      leadName: contact['full_name'] as String,
      companyName: (company?['name'] as String?) ?? '—',
      dueAt: DateTime.parse(row['due_at'] as String).toLocal(),
      status: FollowUpStatus.values.byName(row['status'] as String),
      note: row['note'] as String?,
    );
  }

  // ── enum <-> snake_case column values ──
  static T? _enumFrom<T extends Enum>(List<T> values, String? name) =>
      name == null ? null : values.asNameMap()[name];

  static LeadStatus _statusFrom(String? v) => switch (v) {
        'contacted' => LeadStatus.contacted,
        'qualified' => LeadStatus.qualified,
        'won' => LeadStatus.won,
        'lost' => LeadStatus.lost,
        _ => LeadStatus.newLead,
      };
  static String _statusTo(LeadStatus s) =>
      switch (s) { LeadStatus.newLead => 'new', _ => s.name };

  static RequirementTimeline? _timelineFrom(String? v) => switch (v) {
        'immediate' => RequirementTimeline.immediate,
        'one_to_three_months' => RequirementTimeline.oneToThreeMonths,
        'three_to_six_months' => RequirementTimeline.threeToSixMonths,
        'exploring' => RequirementTimeline.exploring,
        _ => null,
      };
  static String? _timelineTo(RequirementTimeline? t) => switch (t) {
        null => null,
        RequirementTimeline.immediate => 'immediate',
        RequirementTimeline.oneToThreeMonths => 'one_to_three_months',
        RequirementTimeline.threeToSixMonths => 'three_to_six_months',
        RequirementTimeline.exploring => 'exploring',
      };

  static CustomerType? _customerFrom(String? v) => switch (v) {
        'end_user' => CustomerType.endUser,
        'distributor' => CustomerType.distributor,
        'retailer' => CustomerType.retailer,
        'oem' => CustomerType.oem,
        'consultant' => CustomerType.consultant,
        'other' => CustomerType.other,
        _ => null,
      };
  static String? _customerTo(CustomerType? c) => switch (c) {
        null => null,
        CustomerType.endUser => 'end_user',
        _ => c.name,
      };
}
