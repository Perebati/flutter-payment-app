/// Tela para selecionar o tipo de pagamento (Débito ou Crédito)
/// Estado: AwaitingInfo (mesma estado que AmountScreen)
library;

import 'package:flutter/material.dart';
import '../services/payment_info_service.dart';
import '../core/hal_navigator.dart';
import '../core/state_listener.dart';

class PaymentTypeScreen extends StatefulWidget {
  final double amount;

  const PaymentTypeScreen({
    super.key,
    required this.amount,
  });

  @override
  State<PaymentTypeScreen> createState() => _PaymentTypeScreenState();
}

class _PaymentTypeScreenState extends State<PaymentTypeScreen> {
  String? _selectedType;
  final PaymentInfoService _service = PaymentInfoService();
  final HalNavigator _hal = HalNavigator();
  bool _isProcessing = false;

  Future<void> _onSelectPaymentType(String type) async {
    if (_isProcessing) return;
    
    setState(() {
      _selectedType = type;
      _isProcessing = true;
    });

    try {
      // Define tipo de pagamento no Rust
      await _service.setPaymentType(type);
      
      // Confirma informações - transiciona AwaitingInfo -> EMVPayment
      await _service.confirmPaymentInfo();
      
      // Guarda dados no HAL para navegação automática
      _hal.setPaymentData(paymentType: type);
      
      // O HAL Navigator irá detectar a mudança de estado via listener
      // e navegar automaticamente para ProcessingScreen
      
      // Simula transição de estado (remover quando FRB estiver integrado)
      await Future.delayed(const Duration(milliseconds: 500));
      _hal.simulateStateChange(
        PaymentStateType.emvPayment
      );
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _selectedType = null;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipo de Pagamento'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.credit_card,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            Text(
              'Valor: R\$ ${widget.amount.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecione o tipo de pagamento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            _PaymentTypeCard(
              icon: Icons.credit_card,
              title: 'Crédito',
              subtitle: 'Pagamento no crédito',
              isSelected: _selectedType == 'credit',
              isDisabled: _isProcessing,
              onTap: () => _onSelectPaymentType('credit'),
            ),
            const SizedBox(height: 16),
            _PaymentTypeCard(
              icon: Icons.account_balance_wallet,
              title: 'Débito',
              subtitle: 'Pagamento no débito',
              isSelected: _selectedType == 'debit',
              isDisabled: _isProcessing,
              onTap: () => _onSelectPaymentType('debit'),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PaymentTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.blue.shade700 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                    size: 32,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
