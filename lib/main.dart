import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'auth_service.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  String initialRoute = '/login';
  
  // Only auto-login if remember me is true AND user didn't explicitly logout
  if (prefs.getBool('remember_me') == true && 
      prefs.getBool('explicit_logout') != true) {
    try {
      if (await AuthService.validateSession()) {
        initialRoute = '/home';
      }
    } catch (e) {
      await AuthService.logout(); // Clean up if validation fails
    }
  }

  // Clear the explicit logout flag on app start
  await prefs.remove('explicit_logout');
  
  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(),
      },
      title: 'IoT App',
      theme: ThemeData(
        primaryColor: Color(0xFF7086C7), 
        scaffoldBackgroundColor: Color(0xFF465172), 
        textTheme: TextTheme(
          bodyText1: TextStyle(color: Colors.white),
          bodyText2: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            primary: Color(0xFF7086C7), 
            onPrimary: Colors.white,
          ),
        ),
      ),
      home: LoginPage(),
    );
  }
}