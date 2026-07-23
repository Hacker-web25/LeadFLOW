import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_radii.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/lf_colors.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/lf_avatar.dart';
import '../../../../core/widgets/lf_card.dart';
import '../../../../core/widgets/platform_image.dart';
import '../../../../core/widgets/temperature_badge.dart';
import '../../domain/lead.dart';
import '../providers/leads_providers.dart';

/// Lead row for lists: thumbnail of the card, avatar, name/role/company,
/// temperature, time. The thumbnail is loaded lazily and never blocks the
/// row — the row renders fully before the image URL arrives.
class LeadCard extends ConsumerWidget {
  const LeadCard({super.key, required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final subtitle = [
      if (lead.contact.designation != null) lead.contact.designation!,
      lead.companyName,
    ].join(' · ');

    return LfCard(
      onTap: () => context.push(Routes.leadDetailPath(lead.id)),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        children: [
          _CardThumbnail(leadId: lead.id, fullName: lead.contact.fullName),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.contact.fullName, style: text.titleMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodyMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TemperatureBadge(lead.temperature),
              const SizedBox(height: 6),
              Text(lead.capturedAt.relativeLabel, style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// 60×38 thumbnail slot — shows the scanned card if we have one,
/// falls back to a small initials avatar so the row never has an empty spot.
///
/// The fallback avatar is explicitly sized (28 px) so it never overflows
/// the 38 px slot — an oversize avatar was the cause of the mouse-tracker /
/// box.dart hit-test assertion spam.
class _CardThumbnail extends ConsumerWidget {
  const _CardThumbnail({required this.leadId, required this.fullName});

  final String leadId;
  final String fullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(cardImageUrlProvider(leadId));
    final c = context.lf;

    Widget fallbackChild() => Container(
          color: c.surfaceSunken,
          alignment: Alignment.center,
          child: LfAvatar(fullName, size: 28),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox(
        width: 60,
        height: 38,
        child: urlAsync.when(
          loading: fallbackChild,
          error: (_, __) => fallbackChild(),
          data: (url) {
            if (url == null || url.isEmpty) return fallbackChild();
            return Container(
              color: c.surfaceSunken,
              child: PlatformImage(path: url),
            );
          },
        ),
      ),
    );
  }
}

/// Compact tile for grid view.
class LeadGridTile extends ConsumerWidget {
  const LeadGridTile({super.key, required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return LfCard(
      onTap: () => context.push(Routes.leadDetailPath(lead.id)),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card image on top — the whole point of the grid is to see
          // what the card looked like at a glance.
          _GridThumbnail(leadId: lead.id, fullName: lead.contact.fullName),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x3, 8, AppSpacing.x3, AppSpacing.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(lead.contact.fullName,
                          style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    TemperatureBadge(lead.temperature, dense: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(lead.companyName,
                    style: text.bodyMedium
                        ?.copyWith(color: context.lf.inkTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card-shaped thumbnail that lives at the top of every grid tile.
/// Same cached signed URL as the list-row thumbnail, so we don't burn
/// two round-trips per lead.
class _GridThumbnail extends ConsumerWidget {
  const _GridThumbnail({required this.leadId, required this.fullName});

  final String leadId;
  final String fullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(cardImageUrlProvider(leadId));
    final c = context.lf;

    Widget fallback() => Container(
          color: c.surfaceSunken,
          alignment: Alignment.center,
          child: LfAvatar(fullName, size: 40),
        );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg)),
      child: AspectRatio(
        aspectRatio: 85.6 / 54, // real business-card ratio
        child: urlAsync.when(
          loading: fallback,
          error: (_, __) => fallback(),
          data: (url) {
            if (url == null || url.isEmpty) return fallback();
            return Container(
              color: c.surfaceSunken,
              child: PlatformImage(path: url),
            );
          },
        ),
      ),
    );
  }
}
