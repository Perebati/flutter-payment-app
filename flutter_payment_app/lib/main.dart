import 'dart:math';

import 'package:flutter/material.dart';

enum PaymentStatus {
  idle,
  awaitingCard,
  processing,
  approved,
  declined,
  cancelled,
}

enum PaymentMethod {
  tap,
  chip,
  swipe,
  manual,
}

class PaymentTransaction {
  PaymentTransaction({
    required this.reference,
    required this.amount,
    required this.tip,
    required this.total,
    required this.method,
    required this.status,
    required this.timestamp,
    required this.cardMasked,
    required this.issuer,
    this.message,
  });

  final String reference;
  final double amount;
  final double tip;
  final double total;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime timestamp;
  final String cardMasked;
  final String issuer;
  final String? message;

  String get formattedMethod {
    switch (method) {
      case PaymentMethod.tap:
        return 'Aproximação';
      case PaymentMethod.chip:
        return 'Chip EMV';
      case PaymentMethod.swipe:
        return 'Tarja magnética';
      case PaymentMethod.manual:
        return 'Digitação manual';
    }
  }

  String get formattedStatus {
    switch (status) {
      case PaymentStatus.approved:
        return 'APROVADA';
      case PaymentStatus.declined:
        return 'NEGADA';
      case PaymentStatus.cancelled:
        return 'CANCELADA';
      case PaymentStatus.awaitingCard:
        return 'AGUARDANDO CARTÃO';
      case PaymentStatus.processing:
        return 'PROCESSANDO';
      case PaymentStatus.idle:
        return 'PRONTA';
    }
  }
}

void main() {
  runApp(const PaymentApp());
}

class PaymentApp extends StatelessWidget {
  const PaymentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: const TerminalHomePage(),
    );
  }
}

class TerminalHomePage extends StatefulWidget {
  const TerminalHomePage({super.key});

  @override
  State<TerminalHomePage> createState() => _TerminalHomePageState();
}

class _TerminalHomePageState extends State<TerminalHomePage> {
  final TextEditingController _amountController =
      TextEditingController(text: '125.50');
  PaymentMethod _selectedMethod = PaymentMethod.tap;
  PaymentStatus _status = PaymentStatus.idle;
  double _tipPercent = 10;
  String _statusMessage = 'Pronto para iniciar uma nova venda.';
  final List<PaymentTransaction> _history = <PaymentTransaction>[];
  bool _locked = false;

  double get _baseAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  double get _tipValue => (_baseAmount * _tipPercent) / 100;

  double get _totalAmount => _baseAmount + _tipValue;

  bool get _hasAmount => _baseAmount > 0;

  bool get _inProgress =>
      _status == PaymentStatus.processing || _status == PaymentStatus.awaitingCard;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _startPayment() {
    if (!_hasAmount) {
      _showSnack('Informe um valor maior que zero.');
      return;
    }
    if (_inProgress) {
      return;
    }

    setState(() {
      _status = PaymentStatus.awaitingCard;
      _statusMessage = 'Aproxime, insira ou passe o cartão para continuar.';
      _locked = true;
    });

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted || _status != PaymentStatus.awaitingCard) {
        return;
      }
      setState(() {
        _status = PaymentStatus.processing;
        _statusMessage = 'Lendo chip / aproximação...';
      });
    });

    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted || _status != PaymentStatus.processing) {
        return;
      }

      final bool success = Random().nextBool();
      final PaymentStatus finalStatus =
          success ? PaymentStatus.approved : PaymentStatus.declined;

      final PaymentTransaction transaction = PaymentTransaction(
        reference: 'TRX-${DateTime.now().millisecondsSinceEpoch}',
        amount: _baseAmount,
        tip: _tipValue,
        total: _totalAmount,
        method: _selectedMethod,
        status: finalStatus,
        timestamp: DateTime.now(),
        cardMasked: success ? '5482 •••• •••• 8821' : '4923 •••• •••• 0199',
        issuer: success ? 'Banco Azul' : 'Banco Terra',
        message:
            success ? 'Transação autorizada.' : 'Falha de comunicação com o emissor.',
      );

      setState(() {
        _history.insert(0, transaction);
        _status = finalStatus;
        _statusMessage = transaction.message ?? '';
        _locked = false;
      });
    });
  }

  void _cancelPayment() {
    if (!_inProgress) {
      return;
    }
    setState(() {
      _status = PaymentStatus.cancelled;
      _statusMessage = 'Operação cancelada antes da autorização.';
      _locked = false;
    });
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal de Pagamentos'),
        actions: const [
          _ConnectionIndicator(),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth > 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildLeftColumn()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildRightColumn()),
                          ],
                        )
                      : Column(
                          children: [
                            _buildLeftColumn(),
                            const SizedBox(height: 16),
                            _buildRightColumn(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        _TerminalInfoCard(status: _status, message: _statusMessage),
        const SizedBox(height: 16),
        _PaymentFormCard(
          amountController: _amountController,
          selectedMethod: _selectedMethod,
          tipPercent: _tipPercent,
          tipValue: _tipValue,
          total: _totalAmount,
          onMethodChanged: (PaymentMethod method) {
            setState(() => _selectedMethod = method);
          },
          onTipChanged: (double percent) {
            setState(() => _tipPercent = percent);
          },
          onSubmit: _startPayment,
          inProgress: _inProgress,
          locked: _locked,
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      children: [
        _ReceiptPreview(
          amount: _baseAmount,
          tip: _tipValue,
          total: _totalAmount,
          method: _selectedMethod,
          status: _status,
          statusMessage: _statusMessage,
          onCancel: _cancelPayment,
          inProgress: _inProgress,
        ),
        const SizedBox(height: 16),
        _HistoryCard(history: _history),
      ],
    );
  }
}

class _TerminalInfoCard extends StatelessWidget {
  const _TerminalInfoCard({
    required this.status,
    required this.message,
  });

  final PaymentStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(status, context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          color: statusColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'TERMINAL AURORA - 02',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                const _InfoChip(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Loja Aurora - Matriz',
                ),
                const _InfoChip(
                  icon: Icons.numbers,
                  label: 'Serial 9832-4412',
                ),
                const _InfoChip(
                  icon: Icons.wifi_tethering,
                  label: 'Rede segura - WPA2',
                ),
                const _InfoChip(
                  icon: Icons.cloud_done,
                  label: 'Sincronizado com gateway',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status, BuildContext context) {
    switch (status) {
      case PaymentStatus.approved:
        return Colors.green.shade700;
      case PaymentStatus.declined:
        return Colors.red.shade700;
      case PaymentStatus.cancelled:
        return Colors.orange.shade700;
      case PaymentStatus.processing:
        return Colors.blue.shade700;
      case PaymentStatus.awaitingCard:
        return Colors.indigo.shade700;
      case PaymentStatus.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _PaymentFormCard extends StatelessWidget {
  const _PaymentFormCard({
    required this.amountController,
    required this.selectedMethod,
    required this.tipPercent,
    required this.tipValue,
    required this.total,
    required this.onMethodChanged,
    required this.onTipChanged,
    required this.onSubmit,
    required this.inProgress,
    required this.locked,
  });

  final TextEditingController amountController;
  final PaymentMethod selectedMethod;
  final double tipPercent;
  final double tipValue;
  final double total;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final ValueChanged<double> onTipChanged;
  final VoidCallback onSubmit;
  final bool inProgress;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detalhes da venda',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !locked,
              decoration: const InputDecoration(
                labelText: 'Valor da cobrança',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Forma de captura do cartão',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: PaymentMethod.values.map((PaymentMethod method) {
                return ChoiceChip(
                  label: Text(_methodLabel(method)),
                  selected: selectedMethod == method,
                  onSelected: locked
                      ? null
                      : (_) {
                          onMethodChanged(method);
                        },
                  avatar: Icon(_methodIcon(method), size: 18),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Gorjeta: ${tipPercent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Slider(
              value: tipPercent,
              max: 20,
              divisions: 20,
              label: '${tipPercent.toStringAsFixed(0)}%',
              onChanged: locked ? null : onTipChanged,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Gorjeta: R\$ ${tipValue.toStringAsFixed(2)}'),
                  Text(
                    'Total a cobrar: R\$ ${total.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: inProgress ? null : onSubmit,
                icon: const Icon(Icons.lock_open),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(inProgress ? 'Processando...' : 'Simular cobrança'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.tap:
        return 'NFC / Aproximação';
      case PaymentMethod.chip:
        return 'Chip';
      case PaymentMethod.swipe:
        return 'Tarja';
      case PaymentMethod.manual:
        return 'Digitação';
    }
  }

  IconData _methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.tap:
        return Icons.nfc;
      case PaymentMethod.chip:
        return Icons.credit_card;
      case PaymentMethod.swipe:
        return Icons.swipe;
      case PaymentMethod.manual:
        return Icons.keyboard_alt_outlined;
    }
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.amount,
    required this.tip,
    required this.total,
    required this.method,
    required this.status,
    required this.statusMessage,
    required this.onCancel,
    required this.inProgress,
  });

  final double amount;
  final double tip;
  final double total;
  final PaymentMethod method;
  final PaymentStatus status;
  final String statusMessage;
  final VoidCallback onCancel;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Resumo do comprovante',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            _ReceiptRow(label: 'Valor do produto', value: amount),
            _ReceiptRow(label: 'Gorjeta', value: tip),
            Divider(color: Colors.grey.shade300),
            _ReceiptRow(
              label: 'Total a cobrar',
              value: total,
              isEmphasis: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_methodIcon(method), color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(_methodLabel(method)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: inProgress ? onCancel : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    label: const Text('Compartilhar recibo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.tap:
        return 'Aproximação NFC';
      case PaymentMethod.chip:
        return 'Chip EMV';
      case PaymentMethod.swipe:
        return 'Tarja magnética';
      case PaymentMethod.manual:
        return 'Digitação manual';
    }
  }

  IconData _methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.tap:
        return Icons.nfc;
      case PaymentMethod.chip:
        return Icons.credit_card;
      case PaymentMethod.swipe:
        return Icons.swipe;
      case PaymentMethod.manual:
        return Icons.keyboard_alt_outlined;
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  final String label;
  final double value;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: baseStyle,
            ),
          ),
          Text(
            'R\$ ${value.toStringAsFixed(2)}',
            style: isEmphasis
                ? baseStyle?.copyWith(fontWeight: FontWeight.bold)
                : baseStyle,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<PaymentTransaction> history;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Últimas operações',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              Text(
                'Nenhuma transação simulada ainda.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ListView.builder(
                itemCount: history.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (BuildContext context, int index) {
                  final PaymentTransaction transaction = history[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _HistoryTile(transaction: transaction),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(transaction.status, context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.15),
            child: Icon(_methodIcon(transaction.method), color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.formattedMethod,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  transaction.cardMasked,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${transaction.timestamp.hour.toString().padLeft(2, '0')}:${transaction.timestamp.minute.toString().padLeft(2, '0')} - ${transaction.issuer}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
               'R\$ ${transaction.total.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _StatusPill(status: transaction.status, color: statusColor),
            ],
          ),
        ],
      ),
    );
  }

  IconData _methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.tap:
        return Icons.nfc;
      case PaymentMethod.chip:
        return Icons.credit_card;
      case PaymentMethod.swipe:
        return Icons.swipe;
      case PaymentMethod.manual:
        return Icons.keyboard_alt_outlined;
    }
  }

  Color _statusColor(PaymentStatus status, BuildContext context) {
    switch (status) {
      case PaymentStatus.approved:
        return Colors.green.shade700;
      case PaymentStatus.declined:
        return Colors.red.shade700;
      case PaymentStatus.cancelled:
        return Colors.orange.shade700;
      case PaymentStatus.processing:
        return Colors.blue.shade700;
      case PaymentStatus.awaitingCard:
        return Colors.indigo.shade700;
      case PaymentStatus.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = _badgeColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style:
            Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.idle:
        return 'PRONTO';
      case PaymentStatus.awaitingCard:
        return 'AGUARDANDO CARTÃO';
      case PaymentStatus.processing:
        return 'PROCESSANDO';
      case PaymentStatus.approved:
        return 'APROVADA';
      case PaymentStatus.declined:
        return 'NEGADA';
      case PaymentStatus.cancelled:
        return 'CANCELADA';
    }
  }

  Color _badgeColor(PaymentStatus status, BuildContext context) {
    switch (status) {
      case PaymentStatus.approved:
        return Colors.green.shade700;
      case PaymentStatus.declined:
        return Colors.red.shade700;
      case PaymentStatus.cancelled:
        return Colors.orange.shade700;
      case PaymentStatus.processing:
        return Colors.blue.shade700;
      case PaymentStatus.awaitingCard:
        return Colors.indigo.shade700;
      case PaymentStatus.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final PaymentStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _label(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
        return 'Aprovada';
      case PaymentStatus.declined:
        return 'Negada';
      case PaymentStatus.cancelled:
        return 'Cancelada';
      case PaymentStatus.processing:
        return 'Processando';
      case PaymentStatus.awaitingCard:
        return 'Aguardando';
      case PaymentStatus.idle:
        return 'Pronta';
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.grey.shade700),
      label: Text(label),
      backgroundColor: Colors.grey.shade100,
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_done, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Text(
            'Gateway conectado',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }
}
