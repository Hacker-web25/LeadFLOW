import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lf_chip.dart';
import '../../../core/widgets/lf_segmented.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../../leads/domain/lead.dart';
import '../domain/question_spec.dart';
import '../domain/scan_flow_controller.dart';
import '../../../core/theme/lf_colors.dart';

/// Step 4: the 7-question qualification, one question per page.
/// Chips and segmented controls only — single-choice answers advance
/// automatically, so a lead can be qualified in seven taps.
class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  final _page = PageController();
  final _noteController = TextEditingController();
  int _index = 0;

  List<QuestionSpec> get _questions => exhibitionQuestionnaire;

  @override
  void dispose() {
    _page.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _questions.length - 1) {
      _page.nextPage(duration: AppMotion.slow, curve: AppMotion.enter);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    final controller = ref.read(scanFlowProvider.notifier);
    final draft = ref.read(scanFlowProvider).draft;
    if (draft == null) return;
    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      controller.updateDraft(draft.copyWith(additionalNotes: note));
    }
    final result = await controller.save();
    if (!mounted) return;
    result.when(
      ok: (lead) {
        controller.reset();
        context.go(Routes.dashboard);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lead.contact.fullName} saved to your leads')),
        );
      },
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(scanFlowProvider);
    final draft = flow.draft;
    final text = Theme.of(context).textTheme;

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Qualify')),
        body: LfErrorState(
          message: 'The scan session expired. Start again from the dashboard.',
          onRetry: () => context.go(Routes.dashboard),
        ),
      );
    }

    final saving = flow.step == ScanStep.saving;

    return Scaffold(
      appBar: AppBar(
        title: Text('Qualify ${draft.contact.fullName.split(' ').first}'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: const Text('Skip & save'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x5),
            child: Row(
              children: [
                for (var i = 0; i < _questions.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _index ? AppColors.iris : context.lf.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < _questions.length - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _questions.length,
              itemBuilder: (context, i) => _QuestionPage(
                spec: _questions[i],
                draft: draft,
                noteController: _noteController,
                onAnswered: (updated) {
                  ref.read(scanFlowProvider.notifier).updateDraft(updated);
                  _next();
                },
              ),
            ),
          ),

          // Back / note-continue
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x4),
              child: Row(
                children: [
                  if (_index > 0)
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => _page.previousPage(
                              duration: AppMotion.slow, curve: AppMotion.enter),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(100, 52)),
                      child: const Text('Back'),
                    ),
                  if (_index > 0) const SizedBox(width: AppSpacing.x3),
                  if (_questions[_index] is NoteQuestion)
                    Expanded(
                      child: FilledButton(
                        onPressed: saving ? null : _save,
                        child: saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save lead'),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        'Tap an answer to continue',
                        textAlign: TextAlign.center,
                        style: text.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.spec,
    required this.draft,
    required this.noteController,
    required this.onAnswered,
  });

  final QuestionSpec spec;
  final Lead draft;
  final TextEditingController noteController;
  final ValueChanged<Lead> onAnswered;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      children: [
        const SizedBox(height: AppSpacing.x4),
        Text(spec.title, style: text.headlineSmall),
        if (spec.subtitle != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(spec.subtitle!, style: text.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.x6),
        switch (spec) {
          final ChoiceQuestion<LeadTemperature> q => _choice(q),
          final ChoiceQuestion<RequirementTimeline> q => _choice(q),
          final ChoiceQuestion<CustomerType> q => _choice(q),
          final BoolQuestion q => LfSegmented<bool>(
              options: const [true, false],
              labelOf: (v) => v ? 'Yes' : 'No',
              value: q.read(draft),
              onChanged: (v) => onAnswered(q.write(draft, v)),
            ),
          NoteQuestion() => TextField(
              controller: noteController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'e.g. Needs 5k units/mo, pricing by Friday'),
            ),
          ChoiceQuestion() => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _choice<T>(ChoiceQuestion<T> q) {
    if (q.segmented) {
      return LfSegmented<T>(
        options: q.options,
        labelOf: q.labelOf,
        value: q.read(draft),
        onChanged: (v) => onAnswered(q.write(draft, v)),
      );
    }
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        for (final option in q.options)
          LfChoiceChip(
            label: q.labelOf(option),
            selected: q.read(draft) == option,
            onTap: () => onAnswered(q.write(draft, option)),
          ),
      ],
    );
  }
}
