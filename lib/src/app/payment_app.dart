import 'package:flutter/material.dart';

import 'terminal/payment_terminal_page.dart';

/// Aplicação principal do terminal de pagamentos.
///
/// Configura o tema Material 3 e inicializa a home page.
class PaymentApp extends StatelessWidget {
  const PaymentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal POS - Rust FFI Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PaymentTerminalPage(),
    );
  }
}
