import 'package:flutter/foundation.dart';

import 'lead.dart';

enum LeadSort {
  newest('Newest first'),
  company('Company A–Z');

  const LeadSort(this.label);
  final String label;
}

/// list | grid tiles | folders (grouped by exhibition).
enum LeadViewMode { list, grid, folders }

/// Immutable filter/sort/search criteria for the lead list & dashboard.
/// Tri-state booleans: null = any.
@immutable
class LeadFilters {
  const LeadFilters({
    this.query = '',
    this.temperatures = const {},
    this.timelines = const {},
    this.customerTypes = const {},
    this.companies = const {},
    this.decisionMaker,
    this.exportRequirement,
    this.salesTeamRequired,
    this.sort = LeadSort.newest,
  });

  final String query;
  final Set<LeadTemperature> temperatures;
  final Set<RequirementTimeline> timelines;
  final Set<CustomerType> customerTypes;
  final Set<String> companies;
  final bool? decisionMaker;
  final bool? exportRequirement;
  final bool? salesTeamRequired;
  final LeadSort sort;

  int get activeCount =>
      temperatures.length +
      timelines.length +
      customerTypes.length +
      companies.length +
      (decisionMaker != null ? 1 : 0) +
      (exportRequirement != null ? 1 : 0) +
      (salesTeamRequired != null ? 1 : 0);

  bool matches(Lead lead) {
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final hay = '${lead.contact.fullName} ${lead.companyName} '
              '${lead.contact.email ?? ''} ${lead.contact.designation ?? ''}'
          .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (temperatures.isNotEmpty && !temperatures.contains(lead.temperature)) return false;
    if (timelines.isNotEmpty && !timelines.contains(lead.timeline)) return false;
    if (customerTypes.isNotEmpty && !customerTypes.contains(lead.customerType)) return false;
    if (companies.isNotEmpty && !companies.contains(lead.companyName)) return false;
    if (decisionMaker != null && lead.isDecisionMaker != decisionMaker) return false;
    if (exportRequirement != null && lead.exportRequirement != exportRequirement) return false;
    if (salesTeamRequired != null && lead.salesTeamRequired != salesTeamRequired) return false;
    return true;
  }

  List<Lead> apply(List<Lead> leads) {
    final out = leads.where(matches).toList();
    switch (sort) {
      case LeadSort.newest:
        out.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      case LeadSort.company:
        out.sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
    }
    return out;
  }

  LeadFilters copyWith({
    String? query,
    Set<LeadTemperature>? temperatures,
    Set<RequirementTimeline>? timelines,
    Set<CustomerType>? customerTypes,
    Set<String>? companies,
    Object? decisionMaker = _sentinel,
    Object? exportRequirement = _sentinel,
    Object? salesTeamRequired = _sentinel,
    LeadSort? sort,
  }) =>
      LeadFilters(
        query: query ?? this.query,
        temperatures: temperatures ?? this.temperatures,
        timelines: timelines ?? this.timelines,
        customerTypes: customerTypes ?? this.customerTypes,
        companies: companies ?? this.companies,
        decisionMaker: decisionMaker == _sentinel ? this.decisionMaker : decisionMaker as bool?,
        exportRequirement:
            exportRequirement == _sentinel ? this.exportRequirement : exportRequirement as bool?,
        salesTeamRequired:
            salesTeamRequired == _sentinel ? this.salesTeamRequired : salesTeamRequired as bool?,
        sort: sort ?? this.sort,
      );

  static const _sentinel = Object();

  static const LeadFilters none = LeadFilters();
}
