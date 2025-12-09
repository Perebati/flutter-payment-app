import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../rust_gateway.dart';
import 'transaction_record.dart';

/// Página principal do terminal de pagamentos.
///
/// Interface simplificada focada nas funcionalidades essenciais:
/// - Campo de valor da transação
/// - Campo de número do cartão (com validação em tempo real)
/// - Botão de processamento
/// - Exibição de resultados e histórico
class PaymentTerminalPage extends StatefulWidget {
  const PaymentTerminalPage({super.key});

  @override
  State<PaymentTerminalPage> createState() => _PaymentTerminalPageState();
}

class _PaymentTerminalPageState extends State<PaymentTerminalPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final RustPaymentGateway _gateway = RustPaymentGateway();

  bool _processing = false;
  CardValidationResult? _cardValidation;
  FeeBreakdownResult? _currentFees;
  RustPaymentOutcome? _lastResult;
  final List<TransactionRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateFees);
    _cardController.addListener(_validateCardRealtime);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal de Pagamentos'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _gateway.isInitialized ? Icons.check_circle : Icons.error,
                  color: _gateway.isInitialized ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _gateway.isInitialized ? 'Rust OK' : 'Rust Error',
                  style: TextStyle(
                    color: _gateway.isInitialized ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWideScreen = constraints.maxWidth > 900;

            if (isWideScreen) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTransactionPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildHistoryPanel()),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTransactionPanel(),
                  const SizedBox(height: 16),
                  _buildHistoryPanel(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateFees() {
    final double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount > 0 && _gateway.isInitialized) {
      setState(() {
        _currentFees = _gateway.calculateTransactionFees(
          amount: amount,
          methodIndex: 1,
        );
      });
    } else {
      setState(() {
        _currentFees = null;
      });
    }
  }

  void _validateCardRealtime() {
    final String cardNumber = _cardController.text.replaceAll(' ', '');
    if (cardNumber.length >= 13 && _gateway.isInitialized) {
      setState(() {
        _cardValidation = _gateway.validateCard(cardNumber);
      });
    } else {
      setState(() {
        _cardValidation = null;
      });
    }
  }

  Future<void> _processPayment() async {
    final double amount = double.tryParse(_amountController.text) ?? 0;
    final String cardNumber = _cardController.text.replaceAll(' ', '');

    if (amount <= 0) {
      _showSnackbar('Informe um valor válido', isError: true);
      return;
    }

    if (cardNumber.length < 13) {
      _showSnackbar('Informe um número de cartão válido', isError: true);
      return;
    }

    final CardValidationResult validation = _gateway.validateCard(cardNumber);
    if (!validation.isValid) {
      _showSnackbar('Cartão inválido: ${validation.message}', isError: true);
      return;
    }

    setState(() {
      _processing = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));

    final RustPaymentOutcome outcome = _gateway.authorizePayment(
      amount: amount,
      tip: 0.0,
      methodIndex: 1,
    );

    final String txnId = _gateway.generateUniqueTransactionId();

    final FeeBreakdownResult fees = _gateway.calculateTransactionFees(
      amount: amount,
      methodIndex: 1,
    );

    final TransactionRecord record = TransactionRecord(
      id: txnId,
      amount: amount,
      cardType: validation.cardType,
      cardMasked: _maskCard(cardNumber),
      approved: outcome.approved,
      riskScore: outcome.riskScore,
      message: outcome.message,
      timestamp: DateTime.now(),
      fees: fees,
    );

    setState(() {
      _processing = false;
      _lastResult = outcome;
      _history.insert(0, record);
    });

    _showSnackbar(
      outcome.approved ? 'Transação aprovada!' : 'Transação negada',
      isError: !outcome.approved,
    );
  }

  Widget _buildTransactionPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTransactionForm(),
          const SizedBox(height: 16),
          if (_currentFees != null) _buildFeesDisplay(),
          const SizedBox(height: 16),
          if (_lastResult != null) _buildResultCard(),
        ],
      ),
    );
  }

  Widget _buildTransactionForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nova Transação',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor da Transação',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
                helperText: 'Digite o valor em reais (ex: 100.50)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              enabled: !_processing,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cardController,
              decoration: InputDecoration(
                labelText: 'Número do Cartão',
                border: const OutlineInputBorder(),
                helperText: 'Validação em tempo real via Rust FFI',
                suffixIcon: _cardValidation != null
                    ? Icon(
                        _cardValidation!.isValid ? Icons.check_circle : Icons.error,
                        color: _cardValidation!.isValid ? Colors.green : Colors.red,
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
              ],
              enabled: !_processing,
            ),
            if (_cardValidation != null) ...[
              const SizedBox(height: 8),
              Text(
                _cardValidation!.isValid
                    ? '✓ Cartão ${_cardValidation!.cardType} válido'
                    : '✗ ${_cardValidation!.message}',
                style: TextStyle(
                  color: _cardValidation!.isValid ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _processing ? null : _processPayment,
              icon: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.payment),
              label: Text(_processing ? 'Processando...' : 'Confirmar Pagamento'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesDisplay() {
    if (_currentFees == null) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Cálculo de Taxas (Rust)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildFeeRow('Valor bruto:', _currentFees!.grossAmount),
            _buildFeeRow('Taxa fixa:', _currentFees!.fixedFee, isDeduction: true),
            _buildFeeRow('Taxa %:', _currentFees!.percentageFee, isDeduction: true),
            const Divider(),
            _buildFeeRow(
              'Você recebe:',
              _currentFees!.netAmount,
              isBold: true,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            Text(
              'Taxa efetiva: ${_currentFees!.effectiveRate.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, double value,
      {bool isBold = false, bool isDeduction = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}R\$ ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isDeduction ? Colors.red.shade700 : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_lastResult == null) return const SizedBox.shrink();

    final bool approved = _lastResult!.approved;
    final Color statusColor = approved ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      color: approved ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              approved ? Icons.check_circle : Icons.cancel,
              color: statusColor,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              approved ? 'TRANSAÇÃO APROVADA' : 'TRANSAÇÃO NEGADA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lastResult!.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Score de Risco: ${(_lastResult!.riskScore * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_history.isNotEmpty) ...[
            _buildStatsCard(),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Histórico',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_history.length} transações',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_history.isEmpty)
                    const Text('Nenhuma transação registrada até o momento.'),
                  if (_history.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      itemBuilder: (BuildContext context, int index) =>
                          _buildHistoryItem(_history[index]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final String? stats = _calculateHistoryStats();
    if (stats == null) return const SizedBox.shrink();

    final RegExp totalRegex = RegExp(r'"total":([\d.]+)');
    final RegExp avgRegex = RegExp(r'"average":([\d.]+)');
    final RegExp maxRegex = RegExp(r'"max":([\d.]+)');
    final RegExp minRegex = RegExp(r'"min":([\d.]+)');

    final double total = double.tryParse(totalRegex.firstMatch(stats)?.group(1) ?? '0') ?? 0;
    final double avg = double.tryParse(avgRegex.firstMatch(stats)?.group(1) ?? '0') ?? 0;
    final double max = double.tryParse(maxRegex.firstMatch(stats)?.group(1) ?? '0') ?? 0;
    final double min = double.tryParse(minRegex.firstMatch(stats)?.group(1) ?? '0') ?? 0;

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Estatísticas do Lote',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', total),
                _buildStatItem('Média', avg),
                _buildStatItem('Máx', max),
                _buildStatItem('Mín', min),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'R\$ ${value.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(TransactionRecord record) {
    final Color statusColor = record.approved ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            record.approved ? Icons.check : Icons.close,
            color: statusColor,
          ),
        ),
        title: Text(
          'R\$ ${record.amount.toStringAsFixed(2)} - ${record.cardType}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.cardMasked),
            Text(
              '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')} • ${record.id}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.approved ? 'APROVADA' : 'NEGADA',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              'Score: ${(record.riskScore * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String? _calculateHistoryStats() {
    if (_history.isEmpty || !_gateway.isInitialized) return null;

    final List<double> amounts = _history.map((TransactionRecord r) => r.amount).toList();
    return _gateway.calculateBatchStatistics(amounts);
  }

  String _maskCard(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    final String last4 = cardNumber.substring(cardNumber.length - 4);
    return '•••• •••• •••• $last4';
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }
}
