import '../../leads/domain/lead.dart';

/// The questionnaire is data, not screens. Each spec describes one
/// question and how to read/write it on the draft lead. Adding a
/// question is a list entry, not a new widget tree.
sealed class QuestionSpec {
  const QuestionSpec({required this.id, required this.title, this.subtitle});
  final String id;
  final String title;
  final String? subtitle;
}

/// Single-choice question rendered as chips or a segmented control.
class ChoiceQuestion<T> extends QuestionSpec {
  const ChoiceQuestion({
    required super.id,
    required super.title,
    super.subtitle,
    required this.options,
    required this.labelOf,
    required this.read,
    required this.write,
    this.segmented = false,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T? Function(Lead) read;
  final Lead Function(Lead, T) write;

  /// Render as segmented control (2–4 short options) instead of chips.
  final bool segmented;
}

/// Yes/No question rendered as a two-option segmented control.
class BoolQuestion extends QuestionSpec {
  const BoolQuestion({
    required super.id,
    required super.title,
    super.subtitle,
    required this.read,
    required this.write,
  });

  final bool? Function(Lead) read;
  final Lead Function(Lead, bool) write;
}

/// Free-text note (the only typing in the flow, and it's optional).
class NoteQuestion extends QuestionSpec {
  const NoteQuestion({required super.id, required super.title, super.subtitle});
}

/// The 7-step exhibition questionnaire.
final List<QuestionSpec> exhibitionQuestionnaire = [
  ChoiceQuestion<LeadTemperature>(
    id: 'temperature',
    title: 'How hot is this lead?',
    subtitle: 'Your gut read from the conversation.',
    options: LeadTemperature.values,
    labelOf: (t) => t.label,
    read: (l) => l.temperature,
    write: (l, v) => l.copyWith(temperature: v),
    segmented: true,
  ),
  ChoiceQuestion<RequirementTimeline>(
    id: 'timeline',
    title: 'When do they need it?',
    options: RequirementTimeline.values,
    labelOf: (t) => t.label,
    read: (l) => l.timeline,
    write: (l, v) => l.copyWith(timeline: v),
  ),
  BoolQuestion(
    id: 'decision_maker',
    title: 'Are they the decision maker?',
    read: (l) => l.isDecisionMaker,
    write: (l, v) => l.copyWith(isDecisionMaker: v),
  ),
  ChoiceQuestion<CustomerType>(
    id: 'customer_type',
    title: 'What kind of customer?',
    options: CustomerType.values,
    labelOf: (t) => t.label,
    read: (l) => l.customerType,
    write: (l, v) => l.copyWith(customerType: v),
  ),
  BoolQuestion(
    id: 'export',
    title: 'Export requirement?',
    subtitle: 'Do they need goods shipped outside India?',
    read: (l) => l.exportRequirement,
    write: (l, v) => l.copyWith(exportRequirement: v),
  ),
  BoolQuestion(
    id: 'sales_team',
    title: 'Sales team discussion required?',
    read: (l) => l.salesTeamRequired,
    write: (l, v) => l.copyWith(salesTeamRequired: v),
  ),
  const NoteQuestion(
    id: 'notes',
    title: 'Anything to remember?',
    subtitle: 'Optional. One line is plenty.',
  ),
];
