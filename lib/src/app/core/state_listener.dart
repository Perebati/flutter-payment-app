/// Listener para mudanças de estado vindas do Rust
/// 
/// Escuta a stream de eventos e notifica listeners
library;

import 'dart:async';

/// Tipos de estado possíveis
enum PaymentStateType {
  awaitingInfo,
  emvPayment,
  paymentSuccess,
}

/// Evento de mudança de estado
class StateChangeEvent {
  final PaymentStateType fromState;
  final PaymentStateType toState;
  final String timestamp;
  
  StateChangeEvent({
    required this.fromState,
    required this.toState,
    required this.timestamp,
  });
}

/// Listener que escuta mudanças de estado do Rust
class StateListener {
  static final StateListener _instance = StateListener._internal();
  factory StateListener() => _instance;
  StateListener._internal();
  
  final StreamController<StateChangeEvent> _controller = 
      StreamController<StateChangeEvent>.broadcast();
  
  /// Stream de eventos de mudança de estado
  Stream<StateChangeEvent> get stateChanges => _controller.stream;
  
  /// Estado atual (mantido em sincronia com Rust)
  PaymentStateType _currentState = PaymentStateType.awaitingInfo;
  PaymentStateType get currentState => _currentState;
  
  /// Inicializa o listener conectando à stream do Rust
  Future<void> initialize() async {
    // TODO: Conectar à stream do Rust via FRB
    // final rustStream = stateChangeStream();
    // rustStream.listen(_onRustStateChange);
    
    print('StateListener inicializado');
  }
  
  /// Callback quando recebe evento do Rust
  void _onRustStateChange(dynamic event) {
    // TODO: Converter evento do Rust para StateChangeEvent
    // final stateEvent = StateChangeEvent(
    //   fromState: _convertRustState(event.fromState),
    //   toState: _convertRustState(event.toState),
    //   timestamp: event.timestamp,
    // );
    
    // _currentState = stateEvent.toState;
    // _controller.add(stateEvent);
  }
  
  /// Simula mudança de estado (para testes sem Rust)
  void simulateStateChange(PaymentStateType newState) {
    final event = StateChangeEvent(
      fromState: _currentState,
      toState: newState,
      timestamp: DateTime.now().toIso8601String(),
    );
    
    _currentState = newState;
    _controller.add(event);
  }
  
  /// Obtém estado atual do Rust
  Future<PaymentStateType> fetchCurrentState() async {
    // TODO: Chamar getCurrentState() do Rust
    // final state = await getCurrentState();
    // return _convertRustState(state);
    
    return _currentState;
  }
  
  /// Converte estado do Rust para enum Dart
  PaymentStateType _convertRustState(dynamic rustState) {
    // TODO: Implementar conversão real
    switch (rustState.toString()) {
      case 'AwaitingInfo':
        return PaymentStateType.awaitingInfo;
      case 'EmvPayment':
        return PaymentStateType.emvPayment;
      case 'PaymentSuccess':
        return PaymentStateType.paymentSuccess;
      default:
        return PaymentStateType.awaitingInfo;
    }
  }
  
  void dispose() {
    _controller.close();
  }
}
