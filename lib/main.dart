/// Demonstração de terminal de pagamentos Flutter com backend Rust via FFI.
///
/// O app reúne processamento de transações, validação de cartões, cálculo de
/// taxas e geração de estatísticas usando as APIs expostas pelo gateway FFI.
///
/// {@category Demo Application}
import 'package:flutter/material.dart';

import 'src/app/payment_app.dart';

void main() {
  runApp(const PaymentApp());
}
