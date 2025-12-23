/// Service para comunicação com o backend Rust
/// 
/// Separa a lógica de comunicação da UI
/// Este service gerencia as ações do estado AwaitingInfo
library;

class PaymentInfoService {
  /// Define o valor do pagamento
  Future<String> setAmount(double amount) async {
    // TODO: Chamar função Rust via FRB
    // return await setAmount(amount);
    
    // Simulação temporária
    await Future.delayed(const Duration(milliseconds: 100));
    if (amount <= 0) {
      throw Exception('Valor deve ser maior que zero');
    }
    return 'Valor definido: R\$ ${amount.toStringAsFixed(2)}';
  }
  
  /// Define o tipo de pagamento
  Future<String> setPaymentType(String paymentType) async {
    // TODO: Chamar função Rust via FRB
    // return await setPaymentType(paymentType);
    
    // Simulação temporária
    await Future.delayed(const Duration(milliseconds: 100));
    if (paymentType != 'debit' && paymentType != 'credit') {
      throw Exception('Tipo de pagamento inválido');
    }
    return 'Tipo definido: $paymentType';
  }
  
  /// Confirma as informações e avança para processamento
  Future<String> confirmPaymentInfo() async {
    // TODO: Chamar função Rust via FRB
    // return await confirmPaymentInfo();
    
    // Simulação temporária
    await Future.delayed(const Duration(milliseconds: 200));
    return 'Informações confirmadas, transitando para EMVPayment';
  }
}
