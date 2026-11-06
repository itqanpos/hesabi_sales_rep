import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/admin/rep_management_screen.dart';
import '../../features/collections/presentation/pages/collections_page.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/customers/presentation/pages/customer_statement_page.dart';
import '../../features/home/home_screen.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/returns/presentation/pages/returns_page.dart';
import '../../features/sales/presentation/pages/sales_history_page.dart';
import '../../features/visits/presentation/pages/visits_page.dart'; // ⬅️ جديد

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
    GoRoute(
      path: '/collections',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return CollectionsPage(
          companyId: data['companyId'] as String,
          salesRepId: data['salesRepId'] as String,
        );
      },
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return CustomersPage(companyId: data['companyId'] as String);
      },
    ),
    GoRoute(
      path: '/customer-statement',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return CustomerStatementPage(
          companyId: data['companyId'] as String,
          customerId: data['customerId'] as String,
          customerName: data['customerName'] as String? ?? 'عميل',
          customerPhone: data['customerPhone'] as String?,
          customerBalance:
              (data['customerBalance'] as num?)?.toDouble() ?? 0.0,
        );
      },
    ),
    GoRoute(
      path: '/returns',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return ReturnsPage(
          companyId: data['companyId'] as String,
          salesRepId: data['salesRepId'] as String,
        );
      },
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return ReportsPage(
          companyId: data['companyId'] as String,
          salesRepId: data['salesRepId'] as String,
        );
      },
    ),
    // ⬇️⬇️ جديد: الزيارات
    GoRoute(
      path: '/visits',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        }
        return VisitsPage(
          companyId: data['companyId'] as String,
          salesRepId: data['salesRepId'] as String,
        );
      },
    ),
  ],
);
