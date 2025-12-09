import '../../../rust_gateway.dart';

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
