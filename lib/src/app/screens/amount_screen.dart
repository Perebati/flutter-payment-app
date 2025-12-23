/// Tela para inserir o valor do pagamento
/// Estado: AwaitingInfo
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/payment_info_service.dart';
import '../core/hal_navigator.dart';
import 'payment_type_screen.dart';

class AmountScreen extends StatefulWidget {
  const AmountScreen({super.key});

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final PaymentInfoService _service = PaymentInfoService();
  final HalNavigator _hal = HalNavigator();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() => _isLoading = true);
    
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      
      // Chama service para definir valor no Rust
      await _service.setAmount(amount);
      
      // Guarda no HAL
      _hal.setPaymentData(amount: amount);
      
      if (!mounted) return;
      
      // Navega para próxima tela (ainda no mesmo estado AwaitingInfo)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaymentTypeScreen(amount: amount),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valor do Pagamento'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.attach_money,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Digite o valor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                  helperText: 'Ex: 100.00',
                ),
                style: const TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite um valor';
                  }
                  
                  final amount = double.tryParse(value.replaceAll(',', '.'));
                  if (amount == null) {
                    return 'Valor inválido';
                  }
                  
                  if (amount <= 0) {
                    return 'Valor deve ser maior que zero';
                  }
                  
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _onContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
