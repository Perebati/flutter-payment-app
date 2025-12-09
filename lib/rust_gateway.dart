/// Dart bindings para o motor de pagamentos escrito em Rust.
///
/// Este arquivo centraliza os imports e expõe as partes responsáveis pelos
/// bindings FFI, objetos de domínio e gateway de alto nível. Utilize as
/// classes públicas exportadas para interagir com a biblioteca nativa.
///
/// {@category Payment Processing}

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as pkg_ffi;

part 'src/rust_gateway/ffi_bindings.dart';
part 'src/rust_gateway/models.dart';
part 'src/rust_gateway/payment_gateway.dart';
