/// Dart bindings para o motor de pagamentos escrito em Rust.
///
/// O gateway carrega a biblioteca compartilhada produzida em `rust_payment_engine`,
/// publica as funções nativas via `dart:ffi` e disponibiliza wrappers idiomáticos
/// para uso em Flutter.
///
/// Sempre libere as strings vindas de Rust com as funções auxiliares definidas
/// neste arquivo para evitar vazamentos de memória.
///
/// {@category FFI}
/// {@category Payment Processing}
library;

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as pkg_ffi;

// ============================================================================
// FFI Struct Definitions (devem corresponder aos structs Rust)
// ============================================================================

/// Layout nativo retornado por `process_payment` no lado Rust.
///
/// Espelha o struct `PaymentResult` da crate `rust_payment_engine`. O campo
/// [message] aponta para memória alocada em Rust e precisa ser liberado com
/// `_freeRustString` após a conversão para `String`.
///
/// {@category FFI Structs}
final class FfiPaymentResult extends ffi.Struct {
  /// Código de status bruto. `0` indica aprovação.
  @ffi.Int32()
  external int status;

  /// Score de risco normalizado (0.0 a 1.0) calculado em Rust.
  @ffi.Double()
  external double riskScore;

  /// Ponteiro UTF-8 para mensagem detalhada; libere com `_freeRustString`.
  external ffi.Pointer<pkg_ffi.Utf8> message;
}

/// Estrutura C exposta por `calculate_fees` para detalhar custos.
///
/// Espelha `FeeBreakdown` em Rust, contendo taxas fixas, percentuais e
/// o valor líquido calculado.
///
/// {@category FFI Structs}
final class FfiFeeBreakdown extends ffi.Struct {
  /// Taxa fixa aplicada à transação.
  @ffi.Double()
  external double fixedFee;

  /// Parcela correspondente ao percentual cobrado.
  @ffi.Double()
  external double percentageFee;

  /// Soma total das taxas.
  @ffi.Double()
  external double totalFee;

  /// Valor líquido entregue ao comerciante.
  @ffi.Double()
  external double netAmount;
}

/// Estrutura nativa retornada por `validate_card_number`.
///
/// Indica se um cartão passou no algoritmo de Luhn, a bandeira inferida e
/// mensagens de diagnóstico. Use `_freeCardValidation` para liberar memória
/// depois de converter os ponteiros para `String`.
///
/// {@category FFI Structs}
final class FfiCardValidation extends ffi.Struct {
  /// `1` quando o cartão é válido, `0` caso contrário.
  @ffi.Int32()
  external int isValid;

  /// Ponteiro UTF-8 com a bandeira detectada.
  external ffi.Pointer<pkg_ffi.Utf8> cardType;

  /// Ponteiro UTF-8 com mensagem explicativa.
  external ffi.Pointer<pkg_ffi.Utf8> message;
}

// ============================================================================
// FFI Function Signatures (Dart ↔ Rust)
// ============================================================================

/// Assinatura nativa (C ABI) da função Rust `process_payment`.
typedef _ProcessPaymentNative = FfiPaymentResult Function(
  ffi.Double amount,
  ffi.Double tip,
  ffi.Int32 method,
);

/// Assinatura Dart da função `process_payment`.
typedef _ProcessPaymentDart = FfiPaymentResult Function(
  double amount,
  double tip,
  int method,
);

/// Assinatura nativa da função Rust `free_rust_string`.
typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<ffi.Char>);

/// Assinatura Dart da função `free_rust_string`.
typedef _FreeStringDart = void Function(ffi.Pointer<ffi.Char>);

/// Assinatura nativa da função Rust `describe_method`.
typedef _DescribeMethodNative = ffi.Pointer<ffi.Char> Function(ffi.Int32 method);

/// Assinatura Dart da função `describe_method`.
typedef _DescribeMethodDart = ffi.Pointer<ffi.Char> Function(int method);

/// Assinatura nativa da função Rust `validate_card_number`.
typedef _ValidateCardNative = FfiCardValidation Function(
  ffi.Pointer<pkg_ffi.Utf8> cardNumber,
);

/// Assinatura Dart da função `validate_card_number`.
typedef _ValidateCardDart = FfiCardValidation Function(
  ffi.Pointer<pkg_ffi.Utf8> cardNumber,
);

/// Assinatura nativa da função Rust `free_card_validation`.
typedef _FreeCardValidationNative = ffi.Void Function(FfiCardValidation validation);

/// Assinatura Dart da função `free_card_validation`.
typedef _FreeCardValidationDart = void Function(FfiCardValidation validation);

/// Assinatura nativa da função Rust `calculate_fees`.
typedef _CalculateFeesNative = FfiFeeBreakdown Function(
  ffi.Double amount,
  ffi.Int32 method,
);

/// Assinatura Dart da função `calculate_fees`.
typedef _CalculateFeesDart = FfiFeeBreakdown Function(
  double amount,
  int method,
);

/// Assinatura nativa da função Rust `generate_transaction_id`.
typedef _GenerateTransactionIdNative = ffi.Pointer<ffi.Char> Function();

/// Assinatura Dart da função `generate_transaction_id`.
typedef _GenerateTransactionIdDart = ffi.Pointer<ffi.Char> Function();

/// Assinatura nativa da função Rust `calculate_batch_stats`.
typedef _CalculateBatchStatsNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Double> amounts,
  ffi.Size count,
);

/// Assinatura Dart da função `calculate_batch_stats`.
typedef _CalculateBatchStatsDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Double> amounts,
  int count,
);

// ============================================================================
// Gateway Principal
// ============================================================================

/// Ponto de entrada para o motor de pagamentos nativo.
///
/// Carrega a biblioteca dinâmica do Rust, registra as funções FFI e expõe
/// métodos de mais alto nível prontos para uso em Flutter. Consulte
/// [isInitialized] antes de fazer chamadas para garantir que o native binding
/// foi carregado com sucesso.
///
/// {@category Payment Gateway}
/// {@category FFI}
class RustPaymentGateway {
  /// Tenta carregar a biblioteca Rust e mapear as funções expostas.
  ///
  /// Em caso de falha, [isInitialized] permanece `false` e
  /// [initializationError] descreve o motivo.
  RustPaymentGateway() {
    try {
      _library = _openLibrary();
      _processPayment = _library.lookupFunction<_ProcessPaymentNative,
          _ProcessPaymentDart>('process_payment');
      _freeRustString = _library.lookupFunction<_FreeStringNative,
          _FreeStringDart>('free_rust_string');
      _describeMethod = _library.lookupFunction<_DescribeMethodNative,
          _DescribeMethodDart>('describe_method');
      _validateCard = _library.lookupFunction<_ValidateCardNative,
          _ValidateCardDart>('validate_card_number');
      _freeCardValidation = _library.lookupFunction<
          _FreeCardValidationNative,
          _FreeCardValidationDart>('free_card_validation');
      _calculateFees = _library.lookupFunction<_CalculateFeesNative,
          _CalculateFeesDart>('calculate_fees');
      _generateTxnId = _library.lookupFunction<_GenerateTransactionIdNative,
          _GenerateTransactionIdDart>('generate_transaction_id');
      _calculateBatchStats = _library.lookupFunction<
          _CalculateBatchStatsNative,
          _CalculateBatchStatsDart>('calculate_batch_stats');
      _initialized = true;
    } on Object catch (error) {
      _initializationError =
          'Falha ao carregar biblioteca Rust: ${error.toString()}';
    }
  }

  late final ffi.DynamicLibrary _library;
  late final _ProcessPaymentDart _processPayment;
  late final _FreeStringDart _freeRustString;
  late final _DescribeMethodDart _describeMethod;
  late final _ValidateCardDart _validateCard;
  late final _FreeCardValidationDart _freeCardValidation;
  late final _CalculateFeesDart _calculateFees;
  late final _GenerateTransactionIdDart _generateTxnId;
  late final _CalculateBatchStatsDart _calculateBatchStats;

  bool _initialized = false;
  String? _initializationError;

  /// Indica se a biblioteca Rust foi carregada com sucesso.
  ///
  /// Se `false`, todas as operações retornarão valores de erro.
  bool get isInitialized => _initialized;

  /// Mensagem de erro caso a inicialização tenha falhado.
  ///
  /// Será `null` se [isInitialized] for `true`.
  String? get initializationError => _initializationError;

  /// Solicita autorização de pagamento ao motor Rust.
  ///
  /// Retorna um [RustPaymentOutcome] com aprovação, score de risco e mensagem
  /// explicativa. O [methodIndex] segue o mapeamento nativo (`0` NFC, `1` Chip,
  /// `2` Tarja, `3` Manual).
  ///
  /// {@category Payment Operations}
  RustPaymentOutcome authorizePayment({
    required double amount,
    required double tip,
    required int methodIndex,
  }) {
    if (!_initialized) {
      return RustPaymentOutcome(
        approved: false,
        riskScore: 0,
        message: _initializationError ??
            'Biblioteca Rust não carregada. Compile primeiro com cargo build.',
        methodDescription: _methodLabel(methodIndex),
      );
    }

    final FfiPaymentResult result = _processPayment(amount, tip, methodIndex);
    final String message = result.message.toDartString();
    _freeRustString(result.message.cast<ffi.Char>());

    final String methodDescription = _describeAndFreeMethod(methodIndex);

    return RustPaymentOutcome(
      approved: result.status == 0,
      riskScore: result.riskScore,
      message: message,
      methodDescription: methodDescription,
    );
  }

  /// Valida um número de cartão no backend Rust usando Luhn e identificação de bandeira.
  ///
  /// Limpa espaços e hífens automaticamente e retorna um [CardValidationResult]
  /// com status, bandeira e mensagem. Destina-se a testes e protótipos; para
  /// produção siga as exigências PCI-DSS.
  ///
  /// {@category Card Validation}
  /// {@category Security}
  CardValidationResult validateCard(String cardNumber) {
    if (!_initialized) {
      return CardValidationResult(
        isValid: false,
        cardType: 'Desconhecido',
        message: _initializationError ?? 'Motor não inicializado',
      );
    }

    final ffi.Pointer<pkg_ffi.Utf8> cardPtr = cardNumber.toNativeUtf8();

    try {
      final FfiCardValidation validation = _validateCard(cardPtr);
      final String cardType = validation.cardType.toDartString();
      final String message = validation.message.toDartString();
      final bool isValid = validation.isValid == 1;

      _freeCardValidation(validation);

      return CardValidationResult(
        isValid: isValid,
        cardType: cardType,
        message: message,
      );
    } finally {
      pkg_ffi.malloc.free(cardPtr);
    }
  }

  /// Calcula taxas e valor líquido da transação conforme regras do backend Rust.
  ///
  /// Usa [methodIndex] para definir as alíquotas aplicadas e retorna um
  /// [FeeBreakdownResult] com os valores fixos, percentuais e montante líquido.
  ///
  /// {@category Fee Calculation}
  /// {@category Financial}
  FeeBreakdownResult calculateTransactionFees({
    required double amount,
    required int methodIndex,
  }) {
    if (!_initialized) {
      return FeeBreakdownResult(
        fixedFee: 0,
        percentageFee: 0,
        totalFee: 0,
        netAmount: amount,
        grossAmount: amount,
      );
    }

    final FfiFeeBreakdown fees = _calculateFees(amount, methodIndex);

    return FeeBreakdownResult(
      fixedFee: fees.fixedFee,
      percentageFee: fees.percentageFee,
      totalFee: fees.totalFee,
      netAmount: fees.netAmount,
      grossAmount: amount,
    );
  }

  /// Gera um identificador único de transação no backend Rust.
  ///
  /// O formato usa o prefixo `TXN-`, timestamp Unix e contador sequencial.
  /// Seguro para chamadas concorrentes.
  ///
  /// {@category Transaction Management}
  /// {@category Utilities}
  String generateUniqueTransactionId() {
    if (!_initialized) {
      return 'TXN-ERROR-${DateTime.now().millisecondsSinceEpoch}';
    }

    final ffi.Pointer<ffi.Char> idPtr = _generateTxnId();
    try {
      return idPtr.cast<pkg_ffi.Utf8>().toDartString();
    } finally {
      _freeRustString(idPtr);
    }
  }

  /// Calcula estatísticas agregadas para um lote de valores via Rust.
  ///
  /// Retorna uma string JSON com soma, média, valores extremos e quantidade.
  /// Caso o motor não esteja inicializado ou a lista esteja vazia, devolve um
  /// JSON com erro.
  ///
  /// {@category Analytics}
  /// {@category Batch Operations}
  String calculateBatchStatistics(List<double> amounts) {
    if (!_initialized || amounts.isEmpty) {
      return '{"error":"Motor não inicializado ou lista vazia"}';
    }

    final ffi.Pointer<ffi.Double> arrayPtr =
        pkg_ffi.malloc.allocate<ffi.Double>(amounts.length * ffi.sizeOf<ffi.Double>());

    try {
      for (int i = 0; i < amounts.length; i++) {
        arrayPtr[i] = amounts[i];
      }

      final ffi.Pointer<ffi.Char> resultPtr =
          _calculateBatchStats(arrayPtr, amounts.length);

      try {
        return resultPtr.cast<pkg_ffi.Utf8>().toDartString();
      } finally {
        _freeRustString(resultPtr);
      }
    } finally {
      pkg_ffi.malloc.free(arrayPtr);
    }
  }

  // ==========================================================================
  // Métodos Auxiliares Privados
  // ==========================================================================

  /// Carrega a biblioteca dinâmica do Rust conforme a plataforma nativa.
  ///
  /// Lança [UnsupportedError] se a plataforma não tiver binário configurado.
  ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('librust_payment_engine.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('rust_payment_engine.dll');
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return ffi.DynamicLibrary.open('librust_payment_engine.dylib');
    }

    throw UnsupportedError('Plataforma não suportada para o FFI com Rust');
  }

  /// Obtém descrição de método e libera memória.
  String _describeAndFreeMethod(int methodIndex) {
    final ffi.Pointer<ffi.Char> pointer = _describeMethod(methodIndex);
    try {
      final ffi.Pointer<pkg_ffi.Utf8> utf8Ptr = pointer.cast<pkg_ffi.Utf8>();
      return utf8Ptr.toDartString();
    } finally {
      _freeRustString(pointer);
    }
  }

  /// Fallback para descrição de método caso Rust não esteja disponível.
  String _methodLabel(int methodIndex) {
    switch (methodIndex) {
      case 0:
        return 'Aproximação NFC';
      case 1:
        return 'Chip EMV';
      case 2:
        return 'Tarja magnética';
      case 3:
        return 'Digitação manual';
      default:
        return 'Método desconhecido';
    }
  }
}

// ============================================================================
// Dart Value Objects (API Type-Safe)
// ============================================================================

/// Resultado de pagamento exposto para o código Dart.
///
/// Empacota o struct FFI retornado pelo Rust em um objeto imutável e idiomático.
///
/// {@category Payment Operations}
class RustPaymentOutcome {
  /// Cria um novo resultado de pagamento.
  ///
  /// Todos os campos são obrigatórios e imutáveis após criação.
  const RustPaymentOutcome({
    required this.approved,
    required this.riskScore,
    required this.message,
    required this.methodDescription,
  });

  /// Indica se a transação foi aprovada pelo motor de risco.
  final bool approved;

  /// Score de risco normalizado (0.0 a 1.0).
  ///
  /// Valores mais altos indicam transações mais seguras.
  /// Pode ser convertido para porcentagem: `(riskScore * 100).toStringAsFixed(1)`
  final double riskScore;

  /// Mensagem descritiva retornada pelo backend Rust.
  ///
  /// Contém informações sobre o motivo da aprovação/negação.
  final String message;

  /// Descrição textual do método de pagamento utilizado.
  ///
  /// Exemplos: "Aproximação NFC", "Chip EMV"
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
  ///
  /// Calculada como: `(totalFee / grossAmount) * 100`
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