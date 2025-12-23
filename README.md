# Flutter Payment App 💳

Sistema de pagamento modular desenvolvido em Flutter com backend Rust, implementando uma **máquina de estados escalável** com eventos específicos por estado.

## 🎯 Características Principais

- ✅ **Arquitetura Escalável** - Cada estado tem apenas os eventos que fazem sentido
- ✅ **Type-Safe** - Impossível enviar evento errado para estado errado (compile-time)
- ✅ **Documentação Automática** - Comentários /// viram dartdoc via FRB
- ✅ **Comunicação Bidirecional** Flutter ↔ Rust
  - Funções específicas por estado
  - Stream para mudanças de estado
- ✅ **Telas Modulares** - Services separados da UI
- ✅ **Thread-Safe** - StateManager com proteções de concorrência

## 🎨 Nova Arquitetura (v2)

### Estados com Eventos Específicos

```
AwaitingInfo        EMVPayment           PaymentSuccess
├─ SetAmount        ├─ ProcessPayment    ├─ Reset
├─ SetPaymentType   ├─ CompletePayment   └─ (apenas 1 evento)
└─ ConfirmInfo      └─ CancelPayment
   (3 eventos)         (3 eventos)
```

**Vantagem:** Com 100 estados, você tem ~300 casos no total, não 10.000! 🚀

### Backend Rust

```
rust_payment_engine/src/state_machine/
├── types.rs                   # Enums de ações específicos
├── state_trait.rs             # Trait simples (sem transition gigante)
├── state_manager.rs           # Métodos por tipo de ação
├── states/
│   ├── awaiting_info.rs       # execute_action(AwaitingInfoAction)
│   ├── emv_payment.rs         # execute_action(EmvPaymentAction)
│   └── payment_success.rs     # execute_action(PaymentSuccessAction)
└── api.rs                     # Funções documentadas com ///
```

### Frontend Flutter

```
lib/src/app/
├── core/
│   ├── state_listener.dart    # Escuta mudanças de estado
│   └── hal_navigator.dart     # Navegação automática
├── services/
│   ├── payment_info_service.dart      # Lógica AwaitingInfo
│   ├── payment_processing_service.dart # Lógica EMVPayment
│   └── payment_reset_service.dart     # Lógica Reset
└── screens/
    ├── amount_screen.dart
    ├── payment_type_screen.dart
    ├── processing_screen.dart
    └── receipt_screen.dart
```

## 🚀 Como Executar

### Pré-requisitos

```bash
flutter --version   # Flutter SDK 3.10+
rustc --version     # Rust 1.70+
```

### Instalação

```bash
# 1. Clonar repositório
git clone <repo>
cd flutter-payment-app

# 2. Gerar bindings FRB
flutter_rust_bridge_codegen generate

# 3. Instalar dependências Flutter
flutter pub get

# 4. Executar
flutter run
```

## 📚 Documentação

### Documentos Principais

- **[SPECIFIC_EVENTS_ARCHITECTURE.md](SPECIFIC_EVENTS_ARCHITECTURE.md)** - ⭐ Arquitetura completa com eventos específicos
- **[DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md)** - Como gerar documentação FRB
- **[REFACTORED_ARCHITECTURE.md](REFACTORED_ARCHITECTURE.md)** - Histórico da refatoração
- **[STATE_MACHINE.md](STATE_MACHINE.md)** - Detalhes da máquina de estados
- **[STATE_DIAGRAM.md](STATE_DIAGRAM.md)** - Diagramas de transição

### Gerar Documentação HTML

```bash
# Gerar bindings Rust → Dart
flutter_rust_bridge_codegen generate

# Gerar docs HTML
dart doc

# Servir localmente
python3 -m http.server --directory doc/api 8080
# Abra http://localhost:8080
```

Todos os comentários `///` do Rust são convertidos automaticamente para dartdoc! 🎉

### Instalação

```bash
# Dependências Flutter
flutter pub get

# Compilar Rust
cd rust_payment_engine
cargo build --release
cd ..
```

### Executar

```bash
flutter run
```

## 📱 Fluxo da Aplicação

1. **Tela de Valor** → Usuário digita o valor
2. **Tela de Tipo** → Escolhe Débito/Crédito → Envia para Rust
3. **Tela de Processamento** → Processa pagamento
4. **Tela de Comprovante** → Exibe resultado

## 📚 Documentação

- [**ARCHITECTURE.md**](ARCHITECTURE.md) - Arquitetura completa
- [**STATE_DIAGRAM.md**](STATE_DIAGRAM.md) - Diagramas visuais
- [**API_EXAMPLES.md**](API_EXAMPLES.md) - Exemplos de uso

## 🔌 API Principal

```rust
// Enviar informações
send_payment_info(amount: f64, payment_type: String) -> Result<String>

// Processar pagamento
process_emv_payment() -> Result<EmvResultDto>

// Stream de estados
state_change_stream() -> Stream<StateChangeEventDto>
```

## 📊 Diagrama de Estados

```
   AwaitingInfo
        ↓
  send_payment_info()
        ↓
    EMVPayment
        ↓
 process_emv_payment()
        ↓
  PaymentSuccess
```

## 🧪 Testes

```bash
flutter test
cd rust_payment_engine && cargo test
```

## 📄 Licença

MIT License - Veja [LICENSE](LICENSE)
