import 'package:flutter/material.dart';
import 'package:flutter_payment_app/src/app/screens/amount_screen.dart';
import 'package:flutter_payment_app/src/app/core/hal_navigator.dart';

class PaymentApp extends StatelessWidget {
  const PaymentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final halNavigator = HalNavigator();
    
    // Inicializa HAL Navigator
    halNavigator.initialize();
    
    return MaterialApp(
      title: 'Payment App',
      navigatorKey: halNavigator.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AmountScreen(),
    );
  }
}
