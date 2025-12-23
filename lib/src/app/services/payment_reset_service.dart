/// Service para gerenciar resets e reinicializações
library;

import 'package:flutter_payment_app/src/app/services/rust_payment_service.dart';

class PaymentResetService {
  final _rustService = RustPaymentService();

  /// Reinicia a máquina de estados cancelando o pagamento atual
  Future<String> resetPayment() async {
    try {
      return await _rustService.cancelPayment();
    } catch (e) {
      throw Exception('Erro ao reiniciar pagamento: $e');
    }
  }
}
