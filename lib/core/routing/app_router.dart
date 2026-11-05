import 'package:flutter/material.dart'; // <-- هذا السطر كان ناقصاً
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/admin/rep_management_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/pos/pos_screen.dart'; // تأكد من وجود هذا الملف

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
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/admin/reps',
      builder: (context, state) {
        final companyId = state.extra as String?;
        return RepManagementScreen(companyId: companyId);
      },
    ),
    GoRoute(
      path: '/pos',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(
            body: Center(child: Text('خطأ: لم يتم تمرير بيانات الشركة والفرع')),
          );
        }
        return PosScreen(
          companyId: data['companyId'] as String,
          branchId: data['branchId'] as String,
        );
      },
    ),
  ],
);
