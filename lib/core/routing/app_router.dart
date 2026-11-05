import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/admin/rep_management_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/sales/presentation/pages/sales_history_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loggingIn = state.matchedLocation == '/login';
    if (session == null && !loggingIn) return '/login';
    if (session != null && loggingIn) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/admin/reps',
      builder: (context, state) => RepManagementScreen(
          companyId: state.extra as String?),
    ),
    GoRoute(
      path: '/pos',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return PosPage(
          companyId: data['companyId'] as String,
          branchId: data['branchId'] as String,
        );
      },
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return SalesHistoryPage(
          companyId: data['companyId'] as String,
          salesRepId: data['salesRepId'] as String,
        );
      },
    ),
  ],
);
