import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Wrapper around the Rust dynamic library used by this example.
class RustPaymentGateway {
  RustPaymentGateway() {
    try {
      _library = _openLibrary();
      _processPayment = _library.lookupFunction<_ProcessPaymentNative,
          _ProcessPaymentDart>('process_payment');
      _freeRustString =
          _library.lookupFunction<_FreeStringNative, _FreeStringDart>(
              'free_rust_string');
      _describeMethod = _library.lookupFunction<_DescribeMethodNative,
          _DescribeMethodDart>('describe_method');
      _initialized = true;
    } on Object catch (error) {
      _initializationError =
          'Falha ao carregar biblioteca Rust: ${error.toString()}';
    }
  }

  late final DynamicLibrary _library;
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
    _freeRustString(result.message);

    final String methodDescription = _describeAndFreeMethod(methodIndex);

    return RustPaymentOutcome(
      approved: result.status == 0,
      riskScore: result.riskScore,
      message: message,
      methodDescription: methodDescription,
    );
  }

  DynamicLibrary _openLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('librust_payment_engine.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('rust_payment_engine.dll');
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open('librust_payment_engine.dylib');
    }

    throw UnsupportedError('Plataforma não suportada para o FFI com Rust');
  }

  String _describeAndFreeMethod(int methodIndex) {
    final Pointer<Utf8> pointer = _describeMethod(methodIndex);
    final String description = pointer.toDartString();
    _freeRustString(pointer);
    return description;
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

/// Rust struct translated to an FFI-compatible Dart representation.
class FfiPaymentResult extends Struct {
  @Int32()
  external int status;

  @Double()
  external double riskScore;

  external Pointer<Utf8> message;
}

typedef _ProcessPaymentNative = FfiPaymentResult Function(
  Double amount,
  Double tip,
  Int32 method,
);
typedef _ProcessPaymentDart = FfiPaymentResult Function(
  double amount,
  double tip,
  int method,
);

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

typedef _DescribeMethodNative = Pointer<Utf8> Function(Int32 method);
typedef _DescribeMethodDart = Pointer<Utf8> Function(int method);
