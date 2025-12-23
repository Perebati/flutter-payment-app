import 'package:flutter/material.dart';
import 'package:flutter_payment_app/src/app/app.dart';
import 'package:flutter_payment_app/src/app/services/rust_payment_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa a API Rust
  await RustPaymentService().initialize();
  
  runApp(const PaymentApp());
}
