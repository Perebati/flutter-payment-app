/// Terminal de Pagamentos - Demonstração Flutter + Rust FFI
///
/// Este aplicativo demonstra a integração entre Flutter e Rust usando dart:ffi,
/// implementando um terminal de pagamentos simplificado com recursos de:
///
/// - Processamento de transações via motor Rust
/// - Validação de cartões com algoritmo de Luhn
/// - Cálculo de taxas em tempo real
/// - Geração de IDs únicos thread-safe
/// - Análise estatística de lotes de transações
///
/// {@category Demo Application}
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rust_gateway.dart';

void main() {
  runApp(const PaymentApp());
}

/// Aplicação principal do terminal de pagamentos.
///
/// Configura o tema Material 3 e inicializa a home page.
class PaymentApp extends StatelessWidget {
  const PaymentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal POS - Rust FFI Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PaymentTerminalPage(),
    );
  }
}

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

  // Estado da aplicação
  bool _processing = false;
  CardValidationResult? _cardValidation;
  FeeBreakdownResult? _currentFees;
  RustPaymentOutcome? _lastResult;
  final List<TransactionRecord> _history = [];

  @override
  void initState() {
    super.initState();

    // Listener para recalcular taxas quando o valor mudar
    _amountController.addListener(_updateFees);

    // Listener para validar cartão em tempo real
    _cardController.addListener(_validateCardRealtime);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  /// Atualiza o cálculo de taxas em tempo real via Rust.
  void _updateFees() {
    final double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount > 0 && _gateway.isInitialized) {
      setState(() {
        // Método padrão: Chip (1)
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

  /// Valida número do cartão em tempo real usando algoritmo de Luhn (Rust).
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

  /// Processa o pagamento através do motor Rust.
  Future<void> _processPayment() async {
    final double amount = double.tryParse(_amountController.text) ?? 0;
    final String cardNumber = _cardController.text.replaceAll(' ', '');

    // Validações básicas
    if (amount <= 0) {
      _showSnackbar('Informe um valor válido', isError: true);
      return;
    }

    if (cardNumber.length < 13) {
      _showSnackbar('Informe um número de cartão válido', isError: true);
      return;
    }

    // Valida cartão via Rust
    final CardValidationResult validation = _gateway.validateCard(cardNumber);
    if (!validation.isValid) {
      _showSnackbar('Cartão inválido: ${validation.message}', isError: true);
      return;
    }

    setState(() {
      _processing = true;
    });

    // Simula latência de rede (opcional)
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // Processa pagamento via Rust
    final RustPaymentOutcome outcome = _gateway.authorizePayment(
      amount: amount,
      tip: 0.0,
      methodIndex: 1, // Chip EMV
    );

    // Gera ID único via Rust
    final String txnId = _gateway.generateUniqueTransactionId();

    // Calcula taxas via Rust
    final FeeBreakdownResult fees = _gateway.calculateTransactionFees(
      amount: amount,
      methodIndex: 1,
    );

    // Registra no histórico
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

  /// Mascara o número do cartão (exibe apenas últimos 4 dígitos).
  String _maskCard(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    final String last4 = cardNumber.substring(cardNumber.length - 4);
    return '•••• •••• •••• $last4';
  }

  /// Calcula estatísticas do histórico via Rust.
  String? _calculateHistoryStats() {
    if (_history.isEmpty || !_gateway.isInitialized) return null;

    final List<double> amounts = _history.map((TransactionRecord r) => r.amount).toList();
    return _gateway.calculateBatchStatistics(amounts);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal de Pagamentos'),
        centerTitle: true,
        actions: [
          // Indicador de status do motor Rust
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
            // Layout responsivo: coluna única em telas pequenas, duas colunas em telas grandes
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
            } else {
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
            }
          },
        ),
      ),
    );
  }

  /// Painel de transação (esquerda/topo): entrada de dados e processamento.
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

  /// Formulário de entrada de transação.
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

            // Campo de valor
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

            // Campo de número do cartão
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

            // Informação de validação do cartão
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

            // Botão de processar pagamento
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

  /// Exibição de taxas calculadas pelo Rust.
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

  Widget _buildFeeRow(String label, double value, {bool isBold = false, bool isDeduction = false, Color? color}) {
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
            '${isDeduction ? "-" : ""}R\$ ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isDeduction ? Colors.red.shade700 : null),
            ),
          ),
        ],
      ),
    );
  }

  /// Card de resultado da última transação.
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

  /// Painel de histórico (direita/baixo): lista de transações e estatísticas.
  Widget _buildHistoryPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Estatísticas agregadas (calculadas via Rust)
          if (_history.isNotEmpty) ...[
            _buildStatsCard(),
            const SizedBox(height: 16),
          ],

          // Lista de transações
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history),
                      const SizedBox(width: 8),
                      Text(
                        'Histórico de Transações',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (_history.isNotEmpty)
                        Text(
                          '${_history.length} transações',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  const Divider(),
                  if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Nenhuma transação ainda',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...(_history.map(_buildHistoryItem)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card de estatísticas agregadas (calculadas via Rust).
  Widget _buildStatsCard() {
    final String? stats = _calculateHistoryStats();
    if (stats == null) return const SizedBox.shrink();

    // Parse simplificado do JSON
    // Em produção, use dart:convert
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
                  'Estatísticas (Calculadas via Rust)',
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

  /// Item individual do histórico.
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
}

/// Registro de uma transação processada.
///
/// Armazena todos os dados relevantes de uma transação para exibição
/// no histórico e cálculo de estatísticas.
class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.amount,
    required this.cardType,
    required this.cardMasked,
    required this.approved,
    required this.riskScore,
    required this.message,
    required this.timestamp,
    required this.fees,
  });

  /// ID único gerado pelo Rust.
  final String id;

  /// Valor da transação.
  final double amount;

  /// Tipo de cartão (Visa, Mastercard, etc.).
  final String cardType;

  /// Número mascarado do cartão.
  final String cardMasked;

  /// Status de aprovação.
  final bool approved;

  /// Score de risco (0.0 a 1.0).
  final double riskScore;

  /// Mensagem do processador.
  final String message;

  /// Data/hora da transação.
  final DateTime timestamp;

  /// Detalhamento de taxas.
  final FeeBreakdownResult fees;
}
