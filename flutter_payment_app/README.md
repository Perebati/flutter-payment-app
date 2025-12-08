# flutter_payment_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Integração com Rust via FFI

Este exemplo inclui um motor de autorização em `rust_payment_engine/` escrito em Rust. Ele expõe funções com ABI C para que o Flutter possa consumir via `dart:ffi`.

### Como compilar a biblioteca nativa

1. Certifique-se de ter o Rust instalado (https://www.rust-lang.org/tools/install).
2. Compile a biblioteca dinâmica:
   ```bash
   cd rust_payment_engine
   cargo build --release
   ```
3. Copie o artefato gerado para o diretório esperado pelo app Flutter:
   - Linux/Android: `target/release/librust_payment_engine.so`
   - macOS/iOS: `target/release/librust_payment_engine.dylib`
   - Windows: `target/release/rust_payment_engine.dll`

Coloque o arquivo resultante em um local que o app consiga carregar (por exemplo, ao lado do binário desktop ou dentro do `android/app/src/main/jniLibs/<abi>` para Android). O caminho é configurado na `RustPaymentGateway` usando `DynamicLibrary.open`.

### Fluxo de dados

1. `_startPayment` chama `RustPaymentGateway.authorizePayment` passando valor, gorjeta e método.
2. A função Rust `process_payment` calcula um score de risco e devolve `PaymentResult` (status, risco, mensagem).
3. O Flutter monta a mensagem de status e histórico de transações com base na resposta do Rust.

A função `free_rust_string` garante que as strings alocadas em Rust sejam liberadas corretamente após a conversão para Dart.
