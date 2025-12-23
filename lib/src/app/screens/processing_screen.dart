/// Tela de processamento do pagamento EMV
/// Estado: EMVPayment
library;

import 'package:flutter/material.dart';
import '../services/payment_processing_service.dart';
import '../core/hal_navigator.dart';
import '../core/state_listener.dart';

class ProcessingScreen extends StatefulWidget {
  final double amount;
  final String paymentType;

  const ProcessingScreen({
    super.key,
    required this.amount,
    required this.paymentType,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final PaymentProcessingService _service = PaymentProcessingService();
  final HalNavigator _hal = HalNavigator();
  bool _isProcessing = true;
  String _statusMessage = 'Iniciando processamento...';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _processPayment();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    try {
      // Inicia processamento
      setState(() => _statusMessage = 'Processando pagamento...');
      await _service.processPayment();
      
      // Aguarda simulação
      await Future.delayed(const Duration(seconds: 2));
      
      // Completa pagamento - transiciona EMVPayment -> PaymentSuccess
      setState(() => _statusMessage = 'Finalizando...');
      final result = await _service.completePayment();
      
      // Guarda resultado no HAL
      _hal.setPaymentData(
        transactionId: result.transactionId,
        authCode: result.authorizationCode,
      );
      
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Concluído!';
      });
      
      // Aguarda um pouco antes de transicionar
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Simula transição de estado (remover quando FRB estiver integrado)
      _hal.simulateStateChange(PaymentStateType.paymentSuccess);
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Erro no processamento';
      });
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erro'),
          content: Text('Falha ao processar pagamento: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _hal.simulateStateChange(PaymentStateType.awaitingInfo);
              },
              child: const Text('Voltar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone animado
                RotationTransition(
                  turns: _animationController,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Status
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Informações do pagamento
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Valor',
                        value: 'R\$ ${widget.amount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Tipo',
                        value: widget.paymentType == 'credit' 
                            ? 'Crédito' 
                            : 'Débito',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Indicador
                if (_isProcessing)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                
                if (!_isProcessing)
                  const Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
