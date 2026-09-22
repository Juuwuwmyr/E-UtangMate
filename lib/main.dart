import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/store_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/pin_login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/customers/customer_list_screen.dart';
import 'screens/customers/add_edit_customer_screen.dart';
import 'screens/customers/customer_detail_screen.dart';
import 'screens/transactions/add_debt_screen.dart';
import 'screens/payments/record_payment_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/reminders/reminders_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait + landscape (allow both for tablets)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const UtangMateApp());
}

class UtangMateApp extends StatelessWidget {
  const UtangMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<StoreProvider>(
        builder: (context, storeProvider, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                storeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fade(const SplashScreen());

      case AppRoutes.pin:
        return _slide(const PinLoginScreen());

      case AppRoutes.pinSetup:
        return _slide(const PinSetupScreen());

      case AppRoutes.dashboard:
        return _fade(const MainShell());

      case AppRoutes.customers:
        return _slide(const CustomerListScreen());

      case AppRoutes.addCustomer:
        return _slide(const AddEditCustomerScreen());

      case AppRoutes.editCustomer:
        final customer = settings.arguments;
        return _slide(AddEditCustomerScreen(customer: customer as dynamic));

      case AppRoutes.customerDetail:
        final customerId = settings.arguments as int;
        return _slide(CustomerDetailScreen(customerId: customerId));

      case AppRoutes.addDebt:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(AddDebtScreen(
          customerId: args?['customerId'] as int?,
          customerName: args?['customerName'] as String?,
        ));

      case AppRoutes.recordPayment:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(RecordPaymentScreen(
          transactionId: args['transactionId'] as int,
          customerId: args['customerId'] as int,
          customerName: args['customerName'] as String,
          txTransactionId: args['txTransactionId'] as String,
          remainingBalance: args['remainingBalance'] as double,
        ));

      case AppRoutes.reports:
        return _slide(const ReportsScreen());

      case AppRoutes.settings:
        return _slide(const SettingsScreen());

      case AppRoutes.reminders:
        return _slide(const RemindersScreen());

      default:
        return _fade(const SplashScreen());
    }
  }

  PageRoute _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: AppDurations.animation,
      );

  PageRoute _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
        transitionDuration: AppDurations.animation,
      );
}

// ─── Main Shell with Bottom Navigation ───────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardScreen(),
    CustomerListScreen(),
    RemindersScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
