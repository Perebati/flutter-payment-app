import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as pkg_ffi;

/// Rust struct translated to an FFI-compatible Dart representation.
final class FfiPaymentResult extends ffi.Struct {
  @ffi.Int32()
  external int status;

  @ffi.Double()
  external double riskScore;

  external ffi.Pointer<pkg_ffi.Utf8> message;
}

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

/// Wrapper around the Rust dynamic library used by this example.
class RustPaymentGateway {
  RustPaymentGateway() {
    try {
      _library = _openLibrary();
      _processPayment = _library.lookupFunction<_ProcessPaymentNative,
          _ProcessPaymentDart>('process_payment');
      _freeRustString = _library.lookupFunction<_FreeStringNative,
          _FreeStringDart>('free_rust_string');
      _describeMethod = _library.lookupFunction<_DescribeMethodNative,
          _DescribeMethodDart>('describe_method');
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

  bool _initialized = false;
  String? _initializationError;

  /// Calls the Rust engine and converts the FFI struct into a Dart-friendly
  /// value object.
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

  String _describeAndFreeMethod(int methodIndex) {
    final ffi.Pointer<ffi.Char> pointer = _describeMethod(methodIndex);
    try {
      final ffi.Pointer<pkg_ffi.Utf8> utf8Ptr = pointer.cast<pkg_ffi.Utf8>();
      return utf8Ptr.toDartString();
    } finally {
      _freeRustString(pointer);
    }
  }

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

class RustPaymentOutcome {
  RustPaymentOutcome({
    required this.approved,
    required this.riskScore,
    required this.message,
    required this.methodDescription,
  });

  final bool approved;
  final double riskScore;
  final String message;
  final String methodDescription;
}
