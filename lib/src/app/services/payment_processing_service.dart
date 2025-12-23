/// Service para comunicação com o backend Rust
/// 
/// Gerencia as ações do estado EMVPayment
library;

import 'package:flutter_payment_app/src/app/services/rust_payment_service.dart';

class PaymentProcessingService {
  final _rustService = RustPaymentService();

  /// Inicia o processamento do pagamento EMV
  Future<String> processPayment() async {
    try {
      return await _rustService.processPayment();
    } catch (e) {
      throw Exception('Erro ao processar pagamento: $e');
    }
  }
  
  /// Completa o pagamento e retorna o resultado
  Future<PaymentResult> completePayment() async {
    try {
      // Simula tempo de processamento
      await Future.delayed(const Duration(seconds: 1));
      
      final now = DateTime.now();
      final transactionId = 'TXN${now.millisecondsSinceEpoch}';
      final authorizationCode = 'AUTH${now.millisecondsSinceEpoch % 100000}';
      
      // Chama a API Rust para completar o pagamento
      await _rustService.completePayment(
        transactionId: transactionId,
        authorizationCode: authorizationCode,
      );
      
      return PaymentResult(
        transactionId: transactionId,
        authorizationCode: authorizationCode,
        timestamp: now.toIso8601String(),
      );
    } catch (e) {
      throw Exception('Erro ao completar pagamento: $e');
    }
  }
}

/// Resultado do pagamento EMV
class PaymentResult {
  final String transactionId;
  final String authorizationCode;
  final String timestamp;
  
  PaymentResult({
    required this.transactionId,
    required this.authorizationCode,
    required this.timestamp,
  });
}
