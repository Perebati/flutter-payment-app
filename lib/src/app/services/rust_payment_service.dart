import 'package:flutter_payment_app/bridge_generated.dart/frb_generated.dart';
import 'package:flutter_payment_app/bridge_generated.dart/api.dart';
import 'package:flutter_payment_app/bridge_generated.dart/state_machine/types.dart';
import 'package:flutter_payment_app/bridge_generated.dart/state_machine/states/awaiting_info.dart';

/// Serviço singleton para gerenciar a API Rust de pagamentos
class RustPaymentService {
  static final RustPaymentService _instance = RustPaymentService._internal();
  factory RustPaymentService() => _instance;
  RustPaymentService._internal();

  RustPaymentApi? _api;
  bool _initialized = false;

  /// Inicializa a biblioteca Rust
  Future<void> initialize() async {
    if (_initialized) return;
    
    await RustLib.init();
    _api = await RustPaymentApi.newInstance();
    _initialized = true;
  }

  /// Garante que a API está inicializada
  RustPaymentApi get api {
    if (!_initialized || _api == null) {
      throw StateError('RustPaymentService não foi inicializado. Chame initialize() primeiro.');
    }
    return _api!;
  }

  /// Define o valor do pagamento
  Future<String> setAmount(double amount) async {
    return await api.setAmount(amount: amount);
  }

  /// Define o tipo de pagamento
  Future<String> setPaymentType(PaymentType paymentType) async {
    return await api.setPaymentType(paymentType: paymentType);
  }

  /// Confirma as informações e inicia o pagamento
  Future<String> confirmInfo() async {
    return await api.confirmInfo();
  }

  /// Processa o pagamento EMV
  Future<String> processPayment() async {
    return await api.processPayment();
  }

  /// Completa o pagamento com sucesso
  Future<String> completePayment({
    required String transactionId,
    required String authorizationCode,
  }) async {
    return await api.completePayment(
      transactionId: transactionId,
      authorizationCode: authorizationCode,
    );
  }

  /// Cancela o pagamento atual
  Future<String> cancelPayment() async {
    return await api.cancelPayment();
  }

  /// Retorna o estado atual
  Future<StateType> getCurrentState() async {
    return await api.getCurrentState();
  }

  /// Obtém descrição do estado AwaitingInfo
  Future<String> getAwaitingInfoDescription() async {
    return await api.getAwaitingInfoDescription();
  }

  /// Obtém descrição do estado EMVPayment
  Future<String> getEmvPaymentDescription() async {
    return await api.getEmvPaymentDescription();
  }

  /// Obtém descrição do estado PaymentSuccess
  Future<String> getPaymentSuccessDescription() async {
    return await api.getPaymentSuccessDescription();
  }
}
