part of rust_gateway;

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
