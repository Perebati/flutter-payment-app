/// Service para gerenciar resets e reinicializações
library;

class PaymentResetService {
  /// Reinicia a máquina de estados
  Future<String> resetPayment() async {
    // TODO: Chamar função Rust via FRB
    // return await resetPayment();
    
    // Simulação temporária
    await Future.delayed(const Duration(milliseconds: 100));
    return 'Máquina de estados reiniciada';
  }
}
