/// Hardware Abstraction Layer (HAL) para navegação
/// 
/// Gerencia a navegação entre telas baseado nos estados do Rust
library;

import 'package:flutter/material.dart';
import 'state_listener.dart';
import '../screens/amount_screen.dart';
import '../screens/processing_screen.dart';
import '../screens/receipt_screen.dart';

/// HAL Navigator - Gerencia navegação baseada em estados
class HalNavigator {
  static final HalNavigator _instance = HalNavigator._internal();
  factory HalNavigator() => _instance;
  HalNavigator._internal();
  
  final StateListener _stateListener = StateListener();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Dados temporários do pagamento
  double? _amount;
  String? _paymentType;
  String? _transactionId;
  String? _authCode;
  
  /// Inicializa o HAL e começa a escutar mudanças de estado
  void initialize() {
    _stateListener.initialize();
    _stateListener.stateChanges.listen(_handleStateChange);
  }
  
  /// Manipula mudanças de estado e navega para tela apropriada
  void _handleStateChange(StateChangeEvent event) {
    print('Estado mudou: ${event.fromState} -> ${event.toState}');
    
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    switch (event.toState) {
      case PaymentStateType.awaitingInfo:
        _navigateToAwaitingInfo(context);
        break;
        
      case PaymentStateType.emvPayment:
        _navigateToProcessing(context);
        break;
        
      case PaymentStateType.paymentSuccess:
        _navigateToReceipt(context);
        break;
    }
  }
  
  /// Navega para telas do estado AwaitingInfo
  void _navigateToAwaitingInfo(BuildContext context) {
    // Reset dados
    _amount = null;
    _paymentType = null;
    _transactionId = null;
    _authCode = null;
    
    // Volta para a primeira tela
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AmountScreen()),
      (route) => false,
    );
  }
  
  /// Navega para tela de processamento (EMVPayment)
  void _navigateToProcessing(BuildContext context) {
    if (_amount == null || _paymentType == null) {
      print('Erro: Dados de pagamento não disponíveis');
      return;
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          amount: _amount!,
          paymentType: _paymentType!,
        ),
      ),
    );
  }
  
  /// Navega para tela de comprovante (PaymentSuccess)
  void _navigateToReceipt(BuildContext context) {
    if (_amount == null || _paymentType == null) {
      print('Erro: Dados de pagamento não disponíveis');
      return;
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          amount: _amount!,
          paymentType: _paymentType!,
          transactionId: _transactionId ?? 'TXN_UNKNOWN',
          authorizationCode: _authCode ?? 'AUTH_UNKNOWN',
        ),
      ),
    );
  }
  
  /// Define dados do pagamento (chamado pelas telas)
  void setPaymentData({
    double? amount,
    String? paymentType,
    String? transactionId,
    String? authCode,
  }) {
    if (amount != null) _amount = amount;
    if (paymentType != null) _paymentType = paymentType;
    if (transactionId != null) _transactionId = transactionId;
    if (authCode != null) _authCode = authCode;
  }
  
  /// Obtém estado atual
  PaymentStateType get currentState => _stateListener.currentState;
  
  /// Simula mudança de estado (para testes)
  void simulateStateChange(PaymentStateType newState) {
    _stateListener.simulateStateChange(newState);
  }
}
