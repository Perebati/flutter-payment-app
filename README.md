# Flutter Payment App

Este projeto é uma demonstração de uma aplicação de pagamentos construída com **Flutter** para o frontend e **Rust** para o motor de regras de negócio e segurança, integrados via `dart:ffi`.

## Pré-requisitos

Antes de começar, certifique-se de ter as seguintes ferramentas instaladas no seu ambiente:

1.  **Flutter SDK**: [Instalação do Flutter](https://docs.flutter.dev/get-started/install)
2.  **Rust Toolchain**: [Instalação do Rust](https://www.rust-lang.org/tools/install)

## Configuração Inicial

Para preparar o projeto, execute os seguintes comandos na raiz do repositório:

```bash
# Baixa as dependências do Flutter
flutter pub get

# (Opcional) Limpa builds anteriores para garantir um ambiente limpo
flutter clean
```

## Executando a Aplicação

### Linux

No Linux, o processo de build da biblioteca Rust foi automatizado via CMake. Você **não** precisa compilar o Rust manualmente.

Basta rodar:

```bash
flutter run -d linux
```

### Outras Plataformas (Windows, macOS, Android, iOS)

⚠️ **Atenção:** A automação de build via CMake está configurada apenas para Linux no momento.

Se você deseja rodar em outras plataformas, será necessário:
1.  Compilar o Rust manualmente (`cargo build --release` dentro de `rust_payment_engine/`).
2.  Mover o binário gerado (`.dll`, `.dylib` ou `.so`) para o local apropriado onde o Flutter possa carregá-lo.
3.  Ajustar o código em `lib/rust_gateway.dart` para garantir que o caminho de carregamento da biblioteca dinâmica esteja correto para a plataforma alvo.

## Documentação do Projeto

O projeto utiliza o `dart doc` para gerar documentação técnica detalhada, incluindo notas sobre a integração com o backend Rust.

Para gerar e visualizar a documentação:

1.  Verifique as dependências e analise o código:
    ```bash
    dart pub get
    dart analyze
    ```

2.  Gere a documentação HTML:
    ```bash
    dart doc .
    ```

A documentação será gerada na pasta `doc/api`. Abra o arquivo `doc/api/index.html` no seu navegador para visualizar.

## Arquitetura e Fluxo de Dados

A comunicação entre Flutter e Rust acontece da seguinte forma:

1.  **Frontend (Flutter)**: O usuário inicia uma transação. O método `_startPayment` chama `RustPaymentGateway.authorizePayment`.
2.  **FFI Bridge**: Os dados (valor, método, gorjeta) são passados para a camada nativa.
3.  **Backend (Rust)**: A função `process_payment` no Rust calcula um score de risco e determina se a transação é aprovada ou recusada.
4.  **Retorno**: O Rust retorna uma struct `PaymentResult` (status, risco, mensagem) que é convertida de volta para objetos Dart.

> **Nota:** A função `free_rust_string` é utilizada para garantir que a memória alocada pelo Rust (para strings de mensagem) seja liberada corretamente, evitando memory leaks.

## Arquitetura do Projeto

```
┌─────────────────────────────────────────┐
│         Flutter/Dart Frontend           │
│  ┌─────────────────────────────────┐   │
│  │       main.dart (UI)             │   │
│  └──────────────┬──────────────────┘   │
│                 │ Chama                 │
│  ┌──────────────▼──────────────────┐   │
│  │  rust_gateway.dart (FFI Bridge) │   │
│  └──────────────┬──────────────────┘   │
└─────────────────┼───────────────────────┘
                  │ dart:ffi
┌─────────────────▼───────────────────────┐
│     Rust Backend (Native Library)       │
│  ┌─────────────────────────────────┐   │
│  │  • process_payment()             │   │
│  │  • validate_card_number()        │   │
│  │  • calculate_fees()              │   │
│  │  • generate_transaction_id()     │   │
│  │  • calculate_batch_stats()       │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```