/// Tela de comprovante do pagamento
/// Estado: PaymentSuccess
library;

import 'package:flutter/material.dart';
import '../core/hal_navigator.dart';
import '../core/state_listener.dart';

class ReceiptScreen extends StatelessWidget {
  final double amount;
  final String paymentType;
  final String transactionId;
  final String authorizationCode;

  const ReceiptScreen({
    super.key,
    required this.amount,
    required this.paymentType,
    required this.transactionId,
    required this.authorizationCode,
  });

  void _onNewPayment(BuildContext context) {
    final hal = HalNavigator();
    
    // Simula reset - transiciona PaymentSuccess -> AwaitingInfo
    hal.simulateStateChange(PaymentStateType.awaitingInfo);
    
    // HAL Navigator detectará mudança e navegará automaticamente
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade700,
              Colors.green.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      
                      // Ícone de sucesso
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 60,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Título
                      const Text(
                        'Pagamento Aprovado!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Comprovante
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                'COMPROVANTE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 16),
                            
                            // Valor
                            Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'Valor',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'R\$ ${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            
                            // Detalhes da transação
                            _ReceiptRow(
                              label: 'Tipo',
                              value: paymentType == 'credit' 
                                  ? 'Crédito' 
                                  : 'Débito',
                            ),
                            const SizedBox(height: 12),
                            _ReceiptRow(
                              label: 'Data',
                              value: formattedDate,
                            ),
                            const SizedBox(height: 12),
                            _ReceiptRow(
                              label: 'Hora',
                              value: formattedTime,
                            ),
                            const SizedBox(height: 12),
                            _ReceiptRow(
                              label: 'ID Transação',
                              value: transactionId,
                            ),
                            const SizedBox(height: 12),
                            _ReceiptRow(
                              label: 'Código Autorização',
                              value: authorizationCode,
                            ),
                            
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            
                            // Nota de rodapé
                            const Center(
                              child: Text(
                                'Guarde este comprovante',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Botão de nova transação
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _onNewPayment(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Nova Transação'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
