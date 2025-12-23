import 'package:flutter/material.dart';
import 'package:flutter_payment_app/src/app/services/rust_payment_service.dart';
import 'package:flutter_payment_app/bridge_generated.dart/state_machine/types.dart';
import 'package:flutter_payment_app/bridge_generated.dart/state_machine/states/awaiting_info.dart';

/// Tela de teste da integração Rust
class RustIntegrationTest extends StatefulWidget {
  const RustIntegrationTest({super.key});

  @override
  State<RustIntegrationTest> createState() => _RustIntegrationTestState();
}

class _RustIntegrationTestState extends State<RustIntegrationTest> {
  final _rustService = RustPaymentService();
  String _result = 'Pronto para testar';
  StateType? _currentState;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  Future<void> _refreshState() async {
    try {
      final state = await _rustService.getCurrentState();
      setState(() {
        _currentState = state;
      });
    } catch (e) {
      _showError('Erro ao obter estado: $e');
    }
  }

  Future<void> _executeAction(String name, Future<String> Function() action) async {
    setState(() {
      _loading = true;
      _result = 'Executando $name...';
    });

    try {
      final result = await action();
      await _refreshState();
      setState(() {
        _result = 'Sucesso: $result';
      });
    } catch (e) {
      _showError('Erro em $name: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _result = message;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getStateLabel(StateType state) {
    switch (state) {
      case StateType.awaitingInfo:
        return 'AwaitingInfo';
      case StateType.emvPayment:
        return 'EMVPayment';
      case StateType.paymentSuccess:
        return 'PaymentSuccess';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste de Integração Rust'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado Atual
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado Atual',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentState != null 
                          ? _getStateLabel(_currentState!) 
                          : 'Carregando...',
                      style: const TextStyle(fontSize: 24, color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _refreshState,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar Estado'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Resultado
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_result),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ações - AwaitingInfo
            const Text(
              'Ações - AwaitingInfo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'SetAmount',
                        () => _rustService.setAmount(150.50),
                      ),
              child: const Text('Definir Valor (R\$ 150,50)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'SetPaymentType',
                        () => _rustService.setPaymentType(PaymentType.credit),
                      ),
              child: const Text('Definir Tipo (Crédito)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'ConfirmInfo',
                        () => _rustService.confirmInfo(),
                      ),
              child: const Text('Confirmar Informações'),
            ),
            const SizedBox(height: 16),

            // Ações - EMVPayment
            const Text(
              'Ações - EMVPayment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'ProcessPayment',
                        () => _rustService.processPayment(),
                      ),
              child: const Text('Processar Pagamento'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'CompletePayment',
                        () => _rustService.completePayment(
                          transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
                          authorizationCode: 'AUTH${DateTime.now().millisecondsSinceEpoch % 100000}',
                        ),
                      ),
              child: const Text('Completar Pagamento'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'CancelPayment',
                        () => _rustService.cancelPayment(),
                      ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancelar Pagamento'),
            ),
            const SizedBox(height: 16),

            // Descrições
            const Text(
              'Descrições',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => _executeAction(
                        'GetDescription',
                        () async {
                          switch (_currentState) {
                            case StateType.awaitingInfo:
                              return await _rustService.getAwaitingInfoDescription();
                            case StateType.emvPayment:
                              return await _rustService.getEmvPaymentDescription();
                            case StateType.paymentSuccess:
                              return await _rustService.getPaymentSuccessDescription();
                            default:
                              return 'Estado desconhecido';
                          }
                        },
                      ),
              child: const Text('Obter Descrição do Estado Atual'),
            ),
            const SizedBox(height: 32),

            if (_loading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
