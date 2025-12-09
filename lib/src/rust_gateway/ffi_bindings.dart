part of rust_gateway;

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

// =============================================================================
// FFI Function Signatures (Dart ↔ Rust)
// =============================================================================

typedef _ProcessPaymentNative = FfiPaymentResult Function(
  ffi.Double amount,
  ffi.Double tip,
  ffi.Int32 method,
);

typedef _ProcessPaymentDart = FfiPaymentResult Function(
  double amount,
  double tip,
  int method,
);

typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<ffi.Char>);

typedef _FreeStringDart = void Function(ffi.Pointer<ffi.Char>);

typedef _DescribeMethodNative = ffi.Pointer<ffi.Char> Function(ffi.Int32 method);

typedef _DescribeMethodDart = ffi.Pointer<ffi.Char> Function(int method);

typedef _ValidateCardNative = FfiCardValidation Function(
  ffi.Pointer<pkg_ffi.Utf8> cardNumber,
);

typedef _ValidateCardDart = FfiCardValidation Function(
  ffi.Pointer<pkg_ffi.Utf8> cardNumber,
);

typedef _FreeCardValidationNative = ffi.Void Function(FfiCardValidation validation);

typedef _FreeCardValidationDart = void Function(FfiCardValidation validation);

typedef _CalculateFeesNative = FfiFeeBreakdown Function(
  ffi.Double amount,
  ffi.Int32 method,
);

typedef _CalculateFeesDart = FfiFeeBreakdown Function(
  double amount,
  int method,
);

typedef _GenerateTransactionIdNative = ffi.Pointer<ffi.Char> Function();

typedef _GenerateTransactionIdDart = ffi.Pointer<ffi.Char> Function();

typedef _CalculateBatchStatsNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Double> amounts,
  ffi.Size count,
);

typedef _CalculateBatchStatsDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<ffi.Double> amounts,
  int count,
);
