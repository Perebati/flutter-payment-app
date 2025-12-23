/// Service para comunicação com o backend Rust
/// 
/// Separa a lógica de comunicação da UI
/// Este service gerencia as ações do estado AwaitingInfo
library;

import 'package:flutter_payment_app/src/app/services/rust_payment_service.dart';
import 'package:flutter_payment_app/bridge_generated.dart/state_machine/states/awaiting_info.dart';

class PaymentInfoService {
  final _rustService = RustPaymentService();

  /// Define o valor do pagamento
  Future<String> setAmount(double amount) async {
    try {
      return await _rustService.setAmount(amount);
    } catch (e) {
      throw Exception('Erro ao definir valor: $e');
    }
  }
  
  /// Define o tipo de pagamento
  Future<String> setPaymentType(String paymentType) async {
    try {
      final type = paymentType.toLowerCase() == 'credit' 
          ? PaymentType.credit 
          : PaymentType.debit;
      return await _rustService.setPaymentType(type);
    } catch (e) {
      throw Exception('Erro ao definir tipo de pagamento: $e');
    }
  }
  
  /// Confirma as informações e avança para processamento
  Future<String> confirmPaymentInfo() async {
    try {
      return await _rustService.confirmInfo();
    } catch (e) {
      throw Exception('Erro ao confirmar informações: $e');
    }
  }
}
