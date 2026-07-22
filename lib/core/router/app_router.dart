import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/leads/presentation/bulk_edit_screen.dart';
import '../../features/leads/presentation/lead_detail_screen.dart';
import '../../features/leads/presentation/lead_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/scan/presentation/post_scan_screen.dart';
import '../../features/scan/presentation/questionnaire_screen.dart';
import '../../features/scan/presentation/review_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../../features/voice_note/presentation/voice_note_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../constants/app_durations.dart';
import '../supabase/app_providers.dart';
import 'app_router_refresh.dart';
import 'app_shell.dart';

/// Route names — referenced everywhere instead of raw paths.
abstract final class Routes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/';
  static const leads = '/leads';
  static const leadsBulkEdit = '/leads/bulk-edit';
  static const leadDetail = '/leads/:id';
  static const search = '/search';
  static const settings = '/settings';
  static const scan = '/scan';
  static const scanReview = '/scan/review';
  static const scanPost = '/scan/post';
  static const scanQuestionnaire = '/scan/questionnaire';
  static const voiceNote = '/voice-note';
  static const notifications = '/notifications';
  static const profile = '/profile';

  static String leadDetailPath(String id) => '/leads/$id';
}

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.dashboard,
    refreshListenable: GoRouterRefreshStream(auth.watchUser()),
    redirect: (context, state) {
      final signedIn = auth.currentUser != null;
      final path = state.matchedLocation;
      final authPaths = {Routes.signIn, Routes.signUp, Routes.forgotPassword};
      final onAuth = authPaths.contains(path);
      if (!signedIn && !onAuth) return Routes.signIn;
      if (signedIn && onAuth) return Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _fade(s, const SignInScreen()),
      ),
      GoRoute(
        path: Routes.signUp,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s, const SignUpScreen()),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s, const ForgotPasswordScreen()),
      ),
      // Tab shell — each branch keeps its own stack & scroll state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.dashboard,
              pageBuilder: (c, s) => _fade(s, const DashboardScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.leads,
              pageBuilder: (c, s) => _fade(s, const LeadListScreen()),
              routes: [
                GoRoute(
                  path: 'bulk-edit',
                  parentNavigatorKey: _rootKey,
                  pageBuilder: (c, s) => _slide(s, const BulkEditScreen()),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  pageBuilder: (c, s) =>
                      _slide(s, LeadDetailScreen(leadId: s.pathParameters['id']!)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.search,
              pageBuilder: (c, s) => _fade(s, const SearchScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              pageBuilder: (c, s) => _fade(s, const SettingsScreen()),
            ),
          ]),
        ],
      ),

      // Capture pipeline — full-screen, above the shell.
      GoRoute(
        path: Routes.scan,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slideUp(s, const ScanScreen()),
      ),
      GoRoute(
        path: Routes.scanReview,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s, const ReviewScreen()),
      ),
      GoRoute(
        path: Routes.scanPost,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s,
            PostScanScreen(leadId: s.uri.queryParameters['leadId'] ?? '')),
      ),
      GoRoute(
        path: Routes.scanQuestionnaire,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s, const QuestionnaireScreen()),
      ),
      GoRoute(
        path: Routes.voiceNote,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slideUp(s,
            VoiceNoteScreen(leadId: s.uri.queryParameters['leadId'] ?? '')),
      ),

      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s, const NotificationsScreen()),
      ),
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: _rootKey,
        pageBuilder: (c, s) => _slide(s, const ProfileScreen()),
      ),
    ],
  );
});

// ── Page transitions: fade for tabs, slide for pushes, slide-up for scan ──
CustomTransitionPage<void> _fade(GoRouterState s, Widget child) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: AppMotion.base,
      transitionsBuilder: (c, a, sa, child) => FadeTransition(opacity: a, child: child),
    );

CustomTransitionPage<void> _slide(GoRouterState s, Widget child) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: AppMotion.slow,
      transitionsBuilder: (c, a, sa, child) => SlideTransition(
        position: a.drive(
          Tween(begin: const Offset(0.06, 0), end: Offset.zero).chain(CurveTween(curve: AppMotion.enter)),
        ),
        child: FadeTransition(opacity: a, child: child),
      ),
    );

CustomTransitionPage<void> _slideUp(GoRouterState s, Widget child) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: AppMotion.slow,
      fullscreenDialog: true,
      transitionsBuilder: (c, a, sa, child) => SlideTransition(
        position: a.drive(
          Tween(begin: const Offset(0, 0.08), end: Offset.zero).chain(CurveTween(curve: AppMotion.enter)),
        ),
        child: FadeTransition(opacity: a, child: child),
      ),
    );
