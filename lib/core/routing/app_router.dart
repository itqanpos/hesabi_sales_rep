import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/admin/rep_management_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/pos/presentation/pages/pos_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final loggingIn = state.matchedLocation == '/login';

    // إذا لم يكن هناك جلسة ولم يكن في صفحة الدخول، انتقل للدخول
    if (session == null && !loggingIn) return '/login';
    
    // إذا كان مسجلاً بالفعل وهو في صفحة الدخول، انتقل للرئيسية
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
        
        // التحقق من وجود البيانات المطلوبة
        if (data == null || data['companyId'] == null || data['branchId'] == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                'خطأ: لم يتم تمرير بيانات الشركة والفرع',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          );
        }
        
        return PosPage(
          companyId: data['companyId'] as String,
          branchId: data['branchId'] as String,
        );
      },
    ),
  ],
);
