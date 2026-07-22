import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../domain/scan_flow_controller.dart';

/// Step 3: confirm extracted details. Fields are grouped by meaning
/// (Person / Company / Contact / Location) inside soft cards so the
/// page reads like a profile, not a survey.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final d = ref.read(scanFlowProvider).draft;
    _c['name'] = TextEditingController(text: d?.contact.fullName ?? '');
    _c['designation'] = TextEditingController(text: d?.contact.designation ?? '');
    _c['company'] = TextEditingController(text: d?.company?.name ?? '');
    _c['website'] = TextEditingController(text: d?.company?.website ?? '');
    _c['mobile'] = TextEditingController(text: d?.contact.phone ?? '');
    _c['phone'] = TextEditingController(text: d?.contact.altPhone ?? '');
    _c['email'] = TextEditingController(text: d?.contact.email ?? '');
    _c['address'] = TextEditingController(text: d?.contact.address ?? '');
    _c['city'] = TextEditingController(text: d?.company?.city ?? '');
    _c['country'] = TextEditingController(text: d?.company?.country ?? '');
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(String key, String? v) {
    final s = (v ?? '').trim();
    switch (key) {
      case 'name':
        return s.isEmpty ? 'Name is required' : null;
      case 'email':
        if (s.isEmpty) return null;
        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
            ? null : 'Enter a valid email';
      case 'mobile':
      case 'phone':
        if (s.isEmpty) return null;
        return RegExp(r'^[+\d][\d\s\-()]{5,}$').hasMatch(s)
            ? null : 'Enter a valid number';
      default:
        return null;
    }
  }

  TextInputType? _keyboard(String key) => switch (key) {
        'email' => TextInputType.emailAddress,
        'mobile' || 'phone' => TextInputType.phone,
        'website' => TextInputType.url,
        'address' => TextInputType.streetAddress,
        'name' => TextInputType.name,
        _ => TextInputType.text,
      };

  void _continue() {
    if (!_form.currentState!.validate()) return;
    String? t(String k) {
      final s = _c[k]!.text.trim();
      return s.isEmpty ? null : s;
    }
    final controller = ref.read(scanFlowProvider.notifier);
    final draft = ref.read(scanFlowProvider).draft;
    if (draft == null) return;
    controller.updateContact(draft.contact.copyWith(
      fullName: _c['name']!.text.trim(),
      designation: t('designation'),
      email: t('email'),
      phone: t('mobile'),
      altPhone: t('phone'),
      address: t('address'),
    ));
    controller.updateCompany(
      name: _c['company']!.text,
      website: _c['website']!.text,
      city: _c['city']!.text,
      country: _c['country']!.text,
    );
    controller.confirmReview();
    context.push(Routes.scanQuestionnaire);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(scanFlowProvider);
    if (flow.draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: LfErrorState(
          message: 'The scan session expired. Start again from the dashboard.',
          onRetry: () => context.go(Routes.dashboard),
        ),
      );
    }
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Review details'), centerTitle: false),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x6),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x6),
              child: Text(
                "We've pulled what we could read. Fix anything that looks off before continuing.",
                style: text.bodyMedium,
              ),
            ),

            const LfSectionHeader('Person'),
            LfCard(padding: EdgeInsets.zero, child: Column(children: [
              _Row(label: 'Full name', controller: _c['name']!,
                  validator: (v) => _validate('name', v),
                  keyboardType: _keyboard('name'),
                  textInputAction: TextInputAction.next),
              const _Divider(),
              _Row(label: 'Designation', controller: _c['designation']!,
                  keyboardType: _keyboard('designation'),
                  textInputAction: TextInputAction.next, last: true),
            ])),
            const SizedBox(height: AppSpacing.x6),

            const LfSectionHeader('Company'),
            LfCard(padding: EdgeInsets.zero, child: Column(children: [
              _Row(label: 'Company', controller: _c['company']!,
                  textInputAction: TextInputAction.next),
              const _Divider(),
              _Row(label: 'Website', controller: _c['website']!,
                  keyboardType: _keyboard('website'),
                  textInputAction: TextInputAction.next, last: true),
            ])),
            const SizedBox(height: AppSpacing.x6),

            const LfSectionHeader('Contact'),
            LfCard(padding: EdgeInsets.zero, child: Column(children: [
              _Row(label: 'Mobile', controller: _c['mobile']!,
                  validator: (v) => _validate('mobile', v),
                  keyboardType: _keyboard('mobile'),
                  textInputAction: TextInputAction.next),
              const _Divider(),
              _Row(label: 'Phone', controller: _c['phone']!,
                  validator: (v) => _validate('phone', v),
                  keyboardType: _keyboard('phone'),
                  textInputAction: TextInputAction.next),
              const _Divider(),
              _Row(label: 'Email', controller: _c['email']!,
                  validator: (v) => _validate('email', v),
                  keyboardType: _keyboard('email'),
                  textInputAction: TextInputAction.next, last: true),
            ])),
            const SizedBox(height: AppSpacing.x6),

            const LfSectionHeader('Location'),
            LfCard(padding: EdgeInsets.zero, child: Column(children: [
              _Row(label: 'Address', controller: _c['address']!,
                  keyboardType: _keyboard('address'),
                  textInputAction: TextInputAction.next),
              const _Divider(),
              _Row(label: 'City', controller: _c['city']!,
                  textInputAction: TextInputAction.next),
              const _Divider(),
              _Row(label: 'Country', controller: _c['country']!,
                  textInputAction: TextInputAction.done, last: true),
            ])),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x4),
          child: FilledButton(onPressed: _continue, child: const Text('Continue')),
        ),
      ),
    );
  }
}

/// One row inside a grouped card: label on the left, borderless input on
/// the right. Reads like a settings row, not a form field.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.last = false,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
      child: Row(children: [
        SizedBox(width: 96, child: Text(label, style: text.bodyMedium)),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: text.bodyLarge?.copyWith(color: c.ink, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true, filled: false, fillColor: Colors.transparent,
              border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none, errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: '—',
              hintStyle: text.bodyLarge?.copyWith(color: c.inkTertiary),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 128),
        child: Divider(height: 1, color: context.lf.hairline),
      );
}
