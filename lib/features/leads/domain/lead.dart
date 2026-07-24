import 'package:flutter/foundation.dart';

/// Lead temperature — the core qualification signal.
enum LeadTemperature {
  hot('Hot'),
  warm('Warm'),
  cold('Cold');

  const LeadTemperature(this.label);
  final String label;
}

enum RequirementTimeline {
  immediate('Immediate'),
  oneToThreeMonths('1–3 months'),
  threeToSixMonths('3–6 months'),
  exploring('Just exploring');

  const RequirementTimeline(this.label);
  final String label;
}

enum CustomerType {
  endUser('End user'),
  distributor('Distributor'),
  retailer('Retailer'),
  oem('OEM'),
  consultant('Consultant'),
  other('Other');

  const CustomerType(this.label);
  final String label;
}

enum LeadStatus {
  newLead('New'),
  contacted('Contacted'),
  qualified('Qualified'),
  won('Won'),
  lost('Lost');

  const LeadStatus(this.label);
  final String label;
}

/// Contact captured from a business card.
@immutable
class Contact {
  const Contact({
    required this.id,
    required this.fullName,
    this.firstName,
    this.designation,
    this.email,
    this.phone,
    this.altPhone,
    this.address,
  });

  final String id;
  final String fullName;

  /// First name as its own column so CRMs like Zoho (which expect
  /// `First Name` / `Last Name` split) get clean values.
  /// Not shown in the app UI; auto-derived from [fullName] when the
  /// extractor doesn't populate it directly.
  final String? firstName;

  final String? designation;
  final String? email;
  final String? phone;
  final String? altPhone;
  final String? address;

  /// Best-effort derivation of a first name when one wasn't supplied.
  static String? deriveFirstName(String? fullName) {
    if (fullName == null) return null;
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  Contact copyWith({String? fullName, String? firstName, String? designation,
      String? email, String? phone, String? altPhone, String? address}) =>
      Contact(
        id: id,
        fullName: fullName ?? this.fullName,
        firstName: firstName ?? this.firstName,
        designation: designation ?? this.designation,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        altPhone: altPhone ?? this.altPhone,
        address: address ?? this.address,
      );
}

@immutable
class Company {
  const Company({
    required this.id,
    required this.name,
    this.website,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  final String id;
  final String name;
  final String? website;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  Company copyWith({
    String? name,
    String? website,
    String? city,
    String? state,
    String? postalCode,
    String? country,
  }) =>
      Company(
        id: id,
        name: name ?? this.name,
        website: website ?? this.website,
        city: city ?? this.city,
        state: state ?? this.state,
        postalCode: postalCode ?? this.postalCode,
        country: country ?? this.country,
      );
}

/// Aggregate the app works with: contact + company + qualification.
@immutable
class Lead {
  const Lead({
    required this.id,
    required this.contact,
    this.company,
    this.eventName,
    this.status = LeadStatus.newLead,
    this.temperature,
    this.timeline,
    this.customerType,
    this.isDecisionMaker,
    this.exportRequirement,
    this.salesTeamRequired,
    this.additionalNotes,
    required this.capturedAt,
    this.cardImagePath,
  });

  final String id;
  final Contact contact;
  final Company? company;
  final String? eventName;
  final LeadStatus status;
  final LeadTemperature? temperature;
  final RequirementTimeline? timeline;
  final CustomerType? customerType;
  final bool? isDecisionMaker;
  final bool? exportRequirement;
  final bool? salesTeamRequired;
  final String? additionalNotes;
  final DateTime capturedAt;
  final String? cardImagePath;

  String get companyName => company?.name ?? '—';

  Lead copyWith({
    LeadStatus? status,
    LeadTemperature? temperature,
    RequirementTimeline? timeline,
    CustomerType? customerType,
    bool? isDecisionMaker,
    bool? exportRequirement,
    bool? salesTeamRequired,
    String? additionalNotes,
  }) =>
      Lead(
        id: id,
        contact: contact,
        company: company,
        eventName: eventName,
        status: status ?? this.status,
        temperature: temperature ?? this.temperature,
        timeline: timeline ?? this.timeline,
        customerType: customerType ?? this.customerType,
        isDecisionMaker: isDecisionMaker ?? this.isDecisionMaker,
        exportRequirement: exportRequirement ?? this.exportRequirement,
        salesTeamRequired: salesTeamRequired ?? this.salesTeamRequired,
        additionalNotes: additionalNotes ?? this.additionalNotes,
        capturedAt: capturedAt,
        cardImagePath: cardImagePath,
      );

  Lead withContact(Contact c) => Lead(id: id, contact: c, company: company,
      eventName: eventName, status: status, temperature: temperature,
      timeline: timeline, customerType: customerType,
      isDecisionMaker: isDecisionMaker, exportRequirement: exportRequirement,
      salesTeamRequired: salesTeamRequired, additionalNotes: additionalNotes,
      capturedAt: capturedAt, cardImagePath: cardImagePath);

  Lead withCompany(Company? c) => Lead(id: id, contact: contact, company: c,
      eventName: eventName, status: status, temperature: temperature,
      timeline: timeline, customerType: customerType,
      isDecisionMaker: isDecisionMaker, exportRequirement: exportRequirement,
      salesTeamRequired: salesTeamRequired, additionalNotes: additionalNotes,
      capturedAt: capturedAt, cardImagePath: cardImagePath);
}

/// Timeline entry on a lead.
@immutable
class Activity {
  const Activity({
    required this.id,
    required this.leadId,
    required this.summary,
    required this.type,
    required this.occurredAt,
  });

  final String id;
  final String leadId;
  final String summary;
  final ActivityType type;
  final DateTime occurredAt;
}

enum ActivityType { scan, note, call, email, meeting, statusChange, followUpDone }

/// Aggregate dashboard statistics.
@immutable
class LeadStats {
  const LeadStats({
    required this.total,
    required this.today,
    required this.hot,
    required this.followUpsDueToday,
  });

  final int total;
  final int today;
  final int hot;
  final int followUpsDueToday;
}
