/// Gateway FFI para o motor de pagamentos implementado em Rust.
///
/// Este arquivo demonstra a integração entre Dart e Rust usando `dart:ffi`,
/// permitindo que aplicações Flutter chamem código nativo de alto desempenho.
///
/// ## Arquitetura FFI
///
/// O FFI (Foreign Function Interface) permite que Dart invoque funções de
/// bibliotecas nativas compiladas (`.so`, `.dll`, `.dylib`). O fluxo é:
///
/// ```
/// Flutter/Dart  →  dart:ffi  →  Rust Library  →  Sistema Operacional
/// ```
///
/// ## Gerenciamento de Memória
///
/// **CRÍTICO**: Rust aloca memória para strings que são transferidas para Dart.
/// É responsabilidade do código Dart liberar essa memória chamando as funções
/// `free_*` apropriadas. Falha em fazer isso resulta em memory leaks.
///
/// ## Exemplo de Uso
///
/// ```dart
/// final gateway = RustPaymentGateway();
///
/// // Processar um pagamento
/// final result = gateway.authorizePayment(
///   amount: 100.50,
///   tip: 10.0,
///   methodIndex: 1, // Chip EMV
/// );
/// print('Aprovado: ${result.approved}');
///
/// // Validar número de cartão
/// final validation = gateway.validateCard('4532015112830366');
/// print('Válido: ${validation.isValid}, Tipo: ${validation.cardType}');
/// ```
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

/// Representa o resultado de uma transação processada pelo backend Rust.
///
/// Este struct é compatível com FFI e mapeia diretamente para o struct
/// `PaymentResult` definido em `rust_payment_engine/src/lib.rs`.
///
/// ## Rust Backend Correspondence
///
/// ```rust
/// #[repr(C)]
/// pub struct PaymentResult {
///     pub status: i32,
///     pub risk_score: f64,
///     pub message: *mut c_char,
/// }
/// ```
///
/// ## Memory Safety
///
/// O campo `message` é um ponteiro para memória alocada em Rust.
/// Após consumir o valor, **sempre** chame `free_rust_string(message)`
/// para evitar memory leaks.
///
/// {@category FFI Structs}
final class FfiPaymentResult extends ffi.Struct {
  /// Status da transação.
  ///
  /// - `0`: Transação aprovada
  /// - `1`: Transação negada
  /// - Outros valores: Erros diversos
  @ffi.Int32()
  external int status;

  /// Score de risco calculado pelo motor antifraude (0.0 a 1.0).
  ///
  /// Valores mais altos indicam menor risco. Este valor pode ser
  /// multiplicado por 100 para exibir como porcentagem.
  @ffi.Double()
  external double riskScore;

  /// Ponteiro para mensagem descritiva alocada em Rust.
  ///
  /// **ATENÇÃO**: Deve ser liberado com `free_rust_string` após o uso.
  external ffi.Pointer<pkg_ffi.Utf8> message;
}

/// Detalhamento de taxas cobradas em uma transação.
///
/// Corresponde ao struct Rust `FeeBreakdown`. Contém informações sobre
/// taxas fixas, percentuais e o valor líquido que o comerciante receberá.
///
/// ## Rust Backend Correspondence
///
/// ```rust
/// #[repr(C)]
/// pub struct FeeBreakdown {
///     pub fixed_fee: f64,
///     pub percentage_fee: f64,
///     pub total_fee: f64,
///     pub net_amount: f64,
/// }
/// ```
///
/// {@category FFI Structs}
final class FfiFeeBreakdown extends ffi.Struct {
  /// Taxa fixa cobrada (em reais), independente do valor da transação.
  @ffi.Double()
  external double fixedFee;

  /// Taxa percentual aplicada sobre o valor da transação.
  ///
  /// Exemplo: Se a transação é R$ 100 e a taxa é 2.9%, este valor será R$ 2.90.
  @ffi.Double()
  external double percentageFee;

  /// Soma de todas as taxas (fixedFee + percentageFee).
  @ffi.Double()
  external double totalFee;

  /// Valor líquido que o comerciante receberá após dedução das taxas.
  ///
  /// Calculado como: `amount - totalFee`
  @ffi.Double()
  external double netAmount;
}

/// Resultado da validação de um número de cartão de crédito.
///
/// Contém informações sobre a validade do cartão (via algoritmo de Luhn)
/// e identificação da bandeira baseado no BIN (Bank Identification Number).
///
/// ## Rust Backend Correspondence
///
/// ```rust
/// #[repr(C)]
/// pub struct CardValidation {
///     pub is_valid: i32,
///     pub card_type: *mut c_char,
///     pub message: *mut c_char,
/// }
/// ```
///
/// ## Memory Safety
///
/// Os campos `card_type` e `message` são ponteiros alocados em Rust
/// e devem ser liberados com `free_card_validation` após o uso.
///
/// {@category FFI Structs}
final class FfiCardValidation extends ffi.Struct {
  /// Indicador de validade do cartão.
  ///
  /// - `1`: Cartão válido (passou no algoritmo de Luhn)
  /// - `0`: Cartão inválido
  @ffi.Int32()
  external int isValid;

  /// Ponteiro para string identificando a bandeira do cartão.
  ///
  /// Exemplos: "Visa", "Mastercard", "Elo", "American Express"
  external ffi.Pointer<pkg_ffi.Utf8> cardType;

  /// Ponteiro para mensagem descritiva sobre a validação.
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

/// Gateway principal para comunicação entre Flutter e o motor Rust.
///
/// Esta classe encapsula toda a lógica FFI, carregamento de biblioteca nativa,
/// e conversão entre tipos Dart e C. Fornece uma API type-safe e idiomática
/// para Dart, abstraindo os detalhes de baixo nível do FFI.
///
/// ## Inicialização
///
/// O gateway tenta carregar a biblioteca nativa no construtor. Se falhar,
/// todas as chamadas retornarão valores de erro sem crashar a aplicação.
///
/// Verifique [isInitialized] antes de operações críticas:
///
/// ```dart
/// final gateway = RustPaymentGateway();
/// if (!gateway.isInitialized) {
///   print('Erro: ${gateway.initializationError}');
///   return;
/// }
/// ```
///
/// ## Thread Safety
///
/// O backend Rust usa operações atômicas thread-safe. É seguro chamar
/// métodos deste gateway de múltiplas isolates Dart.
///
/// ## Lifecycle
///
/// A biblioteca nativa permanece carregada durante toda a vida da aplicação.
/// Não há necessidade de dispose ou cleanup manual.
///
/// {@category Payment Gateway}
/// {@category FFI}
class RustPaymentGateway {
  /// Cria uma nova instância do gateway e carrega a biblioteca Rust.
  ///
  /// O carregamento da biblioteca é feito no construtor. Se falhar,
  /// [isInitialized] será `false` e [initializationError] conterá
  /// informações sobre o erro.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final gateway = RustPaymentGateway();
  /// if (gateway.isInitialized) {
  ///   print('✓ Motor de pagamentos carregado');
  /// } else {
  ///   print('✗ Falha: ${gateway.initializationError}');
  /// }
  /// ```
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

  /// Processa um pagamento através do motor antifraude Rust.
  ///
  /// Envia os dados da transação para análise de risco e retorna
  /// a decisão de aprovação/negação junto com o score calculado.
  ///
  /// ## Parâmetros
  ///
  /// - [amount]: Valor base da transação em reais (ex: 100.50)
  /// - [tip]: Valor de gorjeta em reais (ex: 10.0)
  /// - [methodIndex]: Método de pagamento:
  ///   - `0`: NFC/Aproximação (menor risco)
  ///   - `1`: Chip EMV (risco médio-baixo)
  ///   - `2`: Tarja magnética (risco médio-alto)
  ///   - `3`: Digitação manual (maior risco)
  ///
  /// ## Retorno
  ///
  /// Retorna um [RustPaymentOutcome] contendo:
  /// - `approved`: Booleano indicando aprovação
  /// - `riskScore`: Score de 0.0 a 1.0 (maior = mais seguro)
  /// - `message`: Mensagem descritiva do backend
  /// - `methodDescription`: Descrição textual do método usado
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final outcome = gateway.authorizePayment(
  ///   amount: 150.00,
  ///   tip: 0.0,
  ///   methodIndex: 1, // Chip
  /// );
  ///
  /// if (outcome.approved) {
  ///   print('✓ Transação aprovada!');
  ///   print('  Score: ${(outcome.riskScore * 100).toStringAsFixed(1)}%');
  /// } else {
  ///   print('✗ Transação negada: ${outcome.message}');
  /// }
  /// ```
  ///
  /// ## Rust Backend
  ///
  /// Chama a função `process_payment` que implementa um motor de risco
  /// simplificado para fins educacionais. Em produção, esta função se
  /// comunicaria com serviços de adquirência reais (Stone, Cielo, etc.).
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

  /// Valida um número de cartão de crédito usando o algoritmo de Luhn.
  ///
  /// Verifica a integridade matemática do número do cartão e identifica
  /// a bandeira baseado no BIN (primeiros dígitos).
  ///
  /// ## Parâmetros
  ///
  /// - [cardNumber]: String contendo o número do cartão. Pode incluir
  ///   espaços ou hífens que serão automaticamente removidos.
  ///
  /// ## Retorno
  ///
  /// Retorna um [CardValidationResult] com:
  /// - `isValid`: `true` se passou no algoritmo de Luhn
  /// - `cardType`: Bandeira identificada (Visa, Mastercard, etc.)
  /// - `message`: Descrição detalhada do resultado
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final validation = gateway.validateCard('4532 0151 1283 0366');
  ///
  /// if (validation.isValid) {
  ///   print('✓ Cartão ${validation.cardType} válido');
  /// } else {
  ///   print('✗ ${validation.message}');
  /// }
  /// ```
  ///
  /// ## Segurança e PCI-DSS
  ///
  /// **AVISO**: Esta validação é apenas educacional. Em ambiente de produção:
  /// - Nunca armazene números de cartão completos
  /// - Use tokenização fornecida pelo adquirente
  /// - Siga todas as normas PCI-DSS
  /// - Processe dados sensíveis apenas em ambientes certificados
  ///
  /// ## Rust Backend
  ///
  /// Chama `validate_card_number` que implementa:
  /// 1. Algoritmo de Luhn para validação matemática
  /// 2. Identificação de bandeira via BIN ranges
  /// 3. Validação de comprimento (13-19 dígitos)
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

  /// Calcula o detalhamento de taxas para uma transação.
  ///
  /// As taxas variam baseado no método de pagamento, refletindo o custo
  /// operacional e o risco de cada modalidade.
  ///
  /// ## Parâmetros
  ///
  /// - [amount]: Valor bruto da transação em reais
  /// - [methodIndex]: Método de pagamento (0-3)
  ///
  /// ## Tabela de Taxas
  ///
  /// | Método       | Taxa %  | Taxa Fixa |
  /// |--------------|---------|-----------|
  /// | NFC/Tap (0)  | 2.5%    | R$ 0.10   |
  /// | Chip (1)     | 2.9%    | R$ 0.15   |
  /// | Tarja (2)    | 3.5%    | R$ 0.20   |
  /// | Manual (3)   | 4.5%    | R$ 0.30   |
  ///
  /// ## Retorno
  ///
  /// Retorna um [FeeBreakdownResult] contendo:
  /// - `fixedFee`: Taxa fixa em reais
  /// - `percentageFee`: Taxa percentual calculada
  /// - `totalFee`: Soma de todas as taxas
  /// - `netAmount`: Valor líquido para o comerciante
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final fees = gateway.calculateTransactionFees(
  ///   amount: 1000.00,
  ///   methodIndex: 1, // Chip: 2.9% + R$ 0.15
  /// );
  ///
  /// print('Valor bruto: R\$ ${fees.grossAmount.toStringAsFixed(2)}');
  /// print('Taxa fixa: R\$ ${fees.fixedFee.toStringAsFixed(2)}');
  /// print('Taxa %: R\$ ${fees.percentageFee.toStringAsFixed(2)}');
  /// print('Total taxas: R\$ ${fees.totalFee.toStringAsFixed(2)}');
  /// print('Você recebe: R\$ ${fees.netAmount.toStringAsFixed(2)}');
  /// // Saída:
  /// // Valor bruto: R$ 1000.00
  /// // Taxa fixa: R$ 0.15
  /// // Taxa %: R$ 29.00
  /// // Total taxas: R$ 29.15
  /// // Você recebe: R$ 970.85
  /// ```
  ///
  /// ## Rust Backend
  ///
  /// Chama `calculate_fees` que aplica a fórmula:
  /// ```
  /// taxa_percentual = amount * percentual
  /// taxa_total = taxa_percentual + taxa_fixa
  /// valor_liquido = amount - taxa_total
  /// ```
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

  /// Gera um ID único para uma transação.
  ///
  /// Utiliza um contador atômico thread-safe combinado com timestamp Unix
  /// para garantir unicidade mesmo em cenários concorrentes.
  ///
  /// ## Formato do ID
  ///
  /// ```
  /// TXN-{unix_timestamp}-{counter_6_digits}
  /// ```
  ///
  /// Exemplo: `TXN-1733789456-000042`
  ///
  /// ## Retorno
  ///
  /// String contendo o ID único gerado.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final txnId = gateway.generateUniqueTransactionId();
  /// print('Nova transação: $txnId');
  /// // Saída: Nova transação: TXN-1733789456-000001
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// Esta função é thread-safe e pode ser chamada de múltiplas isolates
  /// simultaneamente. O backend Rust usa `AtomicU64` para sincronização.
  ///
  /// ## Rust Backend
  ///
  /// Chama `generate_transaction_id` que:
  /// 1. Obtém timestamp Unix atual
  /// 2. Incrementa contador atômico global
  /// 3. Formata string com zero-padding
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

  /// Calcula estatísticas agregadas de um lote de transações.
  ///
  /// Processa múltiplas transações de uma vez e retorna métricas úteis
  /// para relatórios e análise de tendências.
  ///
  /// ## Parâmetros
  ///
  /// - [amounts]: Lista de valores de transações em reais
  ///
  /// ## Retorno
  ///
  /// String JSON contendo:
  /// - `total`: Soma de todas as transações
  /// - `average`: Média aritmética
  /// - `max`: Maior valor
  /// - `min`: Menor valor
  /// - `count`: Número de transações
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final stats = gateway.calculateBatchStatistics([
  ///   100.0, 250.50, 75.30, 500.0, 150.25
  /// ]);
  ///
  /// print(stats);
  /// // Saída: {"total":1076.05,"average":215.21,"max":500.00,"min":75.30,"count":5}
  /// ```
  ///
  /// ## Performance
  ///
  /// O cálculo é feito em Rust, sendo significativamente mais rápido que
  /// implementação equivalente em Dart para grandes volumes (>1000 items).
  ///
  /// ## Rust Backend
  ///
  /// Chama `calculate_batch_stats` que:
  /// 1. Recebe ponteiro para array de doubles
  /// 2. Calcula métricas em uma única passada
  /// 3. Serializa resultado como JSON
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

  /// Carrega a biblioteca dinâmica Rust baseado na plataforma atual.
  ///
  /// ## Nomes de Biblioteca por Plataforma
  ///
  /// - **Linux/Android**: `librust_payment_engine.so`
  /// - **Windows**: `rust_payment_engine.dll`
  /// - **macOS/iOS**: `librust_payment_engine.dylib`
  ///
  /// ## Localização
  ///
  /// A biblioteca deve estar em um dos seguintes locais:
  /// 1. Diretório de trabalho atual
  /// 2. System library path (LD_LIBRARY_PATH, PATH, DYLD_LIBRARY_PATH)
  /// 3. Para Flutter: Empacotada no bundle da aplicação
  ///
  /// ## Compilação
  ///
  /// Compile a biblioteca antes de executar:
  /// ```bash
  /// cd rust_payment_engine
  /// cargo build --release
  /// ```
  ///
  /// A biblioteca estará em `target/release/`.
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

/// Resultado de uma operação de pagamento em formato Dart idiomático.
///
/// Esta classe encapsula os dados retornados do backend Rust em um
/// formato type-safe e conveniente para uso em Dart/Flutter.
///
/// ## Diferença entre FfiPaymentResult e RustPaymentOutcome
///
/// - `FfiPaymentResult`: Struct FFI de baixo nível que espelha o layout C
/// - `RustPaymentOutcome`: Value object Dart de alto nível, imutável e idiomático
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

/// Detalhamento de taxas de uma transação.
///
/// Fornece visibilidade completa sobre custos operacionais.
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