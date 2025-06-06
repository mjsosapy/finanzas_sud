import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth/login_screen.dart';
import 'database/db_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  await initializeDateFormatting('en_US', null); 
  await initializeDateFormatting('es', null); 

  // Inicialización normal de base de datos
  try {
    print("🔧 Inicializando base de datos...");
    await DBHelper.instance.debugDatabaseAndReset();
    await DBHelper.instance.checkForNullData();
    print("✅ Base de datos inicializada correctamente");
  } catch (e) {
    print("❌ Error inicializando base de datos: $e");
    try {
      await DBHelper.instance.deleteAppDatabase();
      print("🗑️ Base de datos limpiada debido a errores");
    } catch (deleteError) {
      print("❌ Error eliminando base de datos: $deleteError");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Fondos Diocesanos',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'), 
        Locale('es'),       
      ],
      locale: const Locale('en', 'US'), 
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', 
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3), 
          foregroundColor: Colors.white,
          elevation: 6, 
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50), 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), 
            ),
            elevation: 6, 
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF607D8B), 
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50], 
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), 
            borderSide: BorderSide.none, 
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1), 
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2), 
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIconColor: Colors.grey[600],
        ),
        cardTheme: CardTheme(
          elevation: 8, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), 
          ),
          margin: const EdgeInsets.all(12), 
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2196F3), fontFamily: 'Inter'),
          titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF37474F), fontFamily: 'Inter'),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF424242), fontFamily: 'Inter'),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF616161), fontFamily: 'Inter'),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white, fontFamily: 'Inter'),
        ),
      ),
      home: const LoginScreen(), 
    );
  }
}