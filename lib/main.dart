import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/delivery_detail_screen.dart';
import 'presentation/screens/order_delivery_screen.dart';
import 'presentation/screens/delivery_history_screen.dart';
import 'data/models/delivery_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق السائق',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/history': (context) => const DeliveryHistoryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/delivery-detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) =>
                DeliveryDetailScreen(deliveryId: args['deliveryId']),
          );
        }
        if (settings.name == '/order-delivery') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => OrderDeliveryScreen(
              order: args['order'] as DeliveryOrderModel,
              deliveryId: args['deliveryId'] as int,
            ),
          );
        }
        return null;
      },
    );
  }
}
