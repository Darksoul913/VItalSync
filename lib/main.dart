import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/vitals_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase App Check — ensures only the official app can access Firebase
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VitalSyncApp());
}

class VitalSyncApp extends StatelessWidget {
  const VitalSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, VitalsProvider>(
          create: (_) => VitalsProvider(),
          update: (_, auth, vitals) => vitals!..updateLanguage(auth.language),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider()..setApiKey(AppConstants.geminiApiKey),
        ),
      ],
      child: MaterialApp(
        title: 'VitalSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
        routes: AppRoutes.routes,
      ),
    );
  }
}
