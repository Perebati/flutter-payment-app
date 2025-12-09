part of rust_gateway;

/// Resultado de pagamento exposto para o código Dart.
///
/// Empacota o struct FFI retornado pelo Rust em um objeto imutável e idiomático.
///
/// {@category Payment Operations}
class RustPaymentOutcome {
  /// Cria um novo resultado de pagamento.
  const RustPaymentOutcome({
    required this.approved,
    required this.riskScore,
    required this.message,
    required this.methodDescription,
  });

  /// Indica se a transação foi aprovada pelo motor de risco.
  final bool approved;

  /// Score de risco normalizado (0.0 a 1.0).
  final double riskScore;

  /// Mensagem descritiva retornada pelo backend Rust.
  final String message;

  /// Descrição textual do método de pagamento utilizado.
  final String methodDescription;

  @override
  String toString() => 'PaymentOutcome('
      'approved: $approved, '
      'riskScore: ${(riskScore * 100).toStringAsFixed(1)}%, '
      'method: $methodDescription'
      ')';
}

/// Resultado da validação de um cartão de crédito.
///
/// Contém informações sobre a validade e tipo do cartão.
///
/// {@category Card Validation}
class CardValidationResult {
  /// Cria um novo resultado de validação.
  const CardValidationResult({
    required this.isValid,
    required this.cardType,
    required this.message,
  });

  /// Indica se o cartão passou na validação Luhn.
  final bool isValid;

  /// Bandeira identificada (Visa, Mastercard, Elo, etc.).
  final String cardType;

  /// Mensagem descritiva sobre a validação.
  final String message;

  @override
  String toString() => 'CardValidation('
      'valid: $isValid, '
      'type: $cardType'
      ')';
}

/// Detalhamento de taxas calculado pelo backend Rust.
///
/// {@category Fee Calculation}
class FeeBreakdownResult {
  /// Cria um novo detalhamento de taxas.
  const FeeBreakdownResult({
    required this.fixedFee,
    required this.percentageFee,
    required this.totalFee,
    required this.netAmount,
    required this.grossAmount,
  });

  /// Valor bruto da transação (antes das taxas).
  final double grossAmount;

  /// Taxa fixa cobrada (em reais).
  final double fixedFee;

  /// Taxa percentual calculada sobre o valor bruto.
  final double percentageFee;

  /// Soma de todas as taxas.
  final double totalFee;

  /// Valor líquido que o comerciante receberá.
  final double netAmount;

  /// Taxa percentual efetiva aplicada.
  double get effectiveRate =>
      grossAmount > 0 ? (totalFee / grossAmount) * 100 : 0;

  @override
    String toString() => 'FeeBreakdown('
      'gross: R\$ ${grossAmount.toStringAsFixed(2)}, '
      'fees: R\$ ${totalFee.toStringAsFixed(2)}, '
      'net: R\$ ${netAmount.toStringAsFixed(2)}, '
      'rate: ${effectiveRate.toStringAsFixed(2)}%'
      ')';
}
