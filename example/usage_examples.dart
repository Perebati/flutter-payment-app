/// Exemplos de Uso - Flutter Payment App
///
/// Este arquivo contém exemplos práticos de como usar todas as funcionalidades
/// da integração Flutter + Rust FFI implementada neste projeto.
///
/// Execute este arquivo em um projeto Dart standalone ou copie os exemplos
/// para seu código Flutter.

import 'package:flutter_payment_app/rust_gateway.dart';

/// Demonstra todas as funcionalidades do RustPaymentGateway
void main() {
  print('=== Flutter Payment App - Exemplos de Uso FFI ===\n');

  // Inicializar o gateway
  final RustPaymentGateway gateway = RustPaymentGateway();

  // Verificar se o motor Rust foi carregado com sucesso
  if (!gateway.isInitialized) {
    print('❌ ERRO: ${gateway.initializationError}');
    print('   Certifique-se de compilar o backend Rust primeiro!');
    print('   Execute: cd rust_payment_engine && cargo build --release');
    return;
  }

  print('✅ Motor Rust carregado com sucesso!\n');

  // =========================================================================
  // EXEMPLO 1: Validação de Cartão (Algoritmo de Luhn)
  // =========================================================================

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📋 EXEMPLO 1: Validação de Números de Cartão');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Lista de cartões de teste (alguns válidos, alguns inválidos)
  final Map<String, String> testCards = {
    'Visa válido': '4532015112830366',
    'Mastercard válido': '5425233430109903',
    'Elo válido': '6362970000457013',
    'American Express válido': '378282246310005',
    'Número inválido': '1234567890123456',
    'Comprimento inválido': '123456',
  };

  for (final MapEntry<String, String> entry in testCards.entries) {
    final CardValidationResult result = gateway.validateCard(entry.value);

    print('${entry.key}: ${entry.value}');
    print('  └─ ${result.isValid ? "✓" : "✗"} ${result.message}');
    if (result.isValid) {
      print('     Bandeira: ${result.cardType}');
    }
    print('');
  }

  // =========================================================================
  // EXEMPLO 2: Cálculo de Taxas por Método de Pagamento
  // =========================================================================

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('💰 EXEMPLO 2: Cálculo de Taxas');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  final double transactionAmount = 1000.00;
  final Map<int, String> paymentMethods = {
    0: 'NFC/Aproximação',
    1: 'Chip EMV',
    2: 'Tarja Magnética',
    3: 'Digitação Manual',
  };

  print('Valor da transação: R\$ ${transactionAmount.toStringAsFixed(2)}\n');

  for (final MapEntry<int, String> method in paymentMethods.entries) {
    final FeeBreakdownResult fees = gateway.calculateTransactionFees(
      amount: transactionAmount,
      methodIndex: method.key,
    );

    print('${method.value} (método ${method.key}):');
    print('  ├─ Taxa fixa:      R\$ ${fees.fixedFee.toStringAsFixed(2)}');
    print('  ├─ Taxa %:         R\$ ${fees.percentageFee.toStringAsFixed(2)}');
    print('  ├─ Total de taxas: R\$ ${fees.totalFee.toStringAsFixed(2)}');
    print('  ├─ Taxa efetiva:   ${fees.effectiveRate.toStringAsFixed(2)}%');
    print('  └─ Você recebe:    R\$ ${fees.netAmount.toStringAsFixed(2)}');
    print('');
  }

  // =========================================================================
  // EXEMPLO 3: Processamento de Pagamento (Análise de Risco)
  // =========================================================================

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔒 EXEMPLO 3: Processamento de Pagamentos');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Diferentes cenários de transação
  final List<Map<String, dynamic>> transactions = [
    {'amount': 100.0, 'tip': 0.0, 'method': 0, 'description': 'Pequeno valor, NFC'},
    {'amount': 500.0, 'tip': 50.0, 'method': 1, 'description': 'Valor médio com gorjeta, Chip'},
    {'amount': 50.0, 'tip': 0.0, 'method': 2, 'description': 'Baixo valor, Tarja'},
    {'amount': 10.0, 'tip': 0.0, 'method': 3, 'description': 'Valor muito baixo, Manual'},
  ];

  for (final Map<String, dynamic> txn in transactions) {
    final RustPaymentOutcome result = gateway.authorizePayment(
      amount: txn['amount'] as double,
      tip: txn['tip'] as double,
      methodIndex: txn['method'] as int,
    );

    print('${txn["description"]}:');
    print('  Valor: R\$ ${(txn["amount"] as double).toStringAsFixed(2)}');
    print('  Método: ${result.methodDescription}');
    print('  Score de Risco: ${(result.riskScore * 100).toStringAsFixed(1)}%');
    print('  Resultado: ${result.approved ? "✓ APROVADA" : "✗ NEGADA"}');
    print('  Mensagem: ${result.message}');
    print('');
  }

  // =========================================================================
  // EXEMPLO 4: Geração de IDs Únicos
  // =========================================================================

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🆔 EXEMPLO 4: Geração de IDs Únicos (Thread-Safe)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  print('Gerando 10 IDs únicos sequenciais:\n');

  for (int i = 0; i < 10; i++) {
    final String id = gateway.generateUniqueTransactionId();
    print('  ${i + 1}. $id');
  }

  print('\n⚡ Garantia: Cada ID é único mesmo em execução concorrente!');
  print('   O backend Rust usa AtomicU64 para sincronização.\n');

  // =========================================================================
  // EXEMPLO 5: Análise Estatística de Lote
  // =========================================================================

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 EXEMPLO 5: Análise Estatística de Lotes');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Simular um lote de transações do dia
  final List<double> dailyTransactions = [
    45.99, 120.50, 89.90, 250.00, 35.50,
    180.75, 95.00, 420.00, 67.30, 145.20,
    310.00, 55.80, 199.99, 88.40, 275.50,
  ];

  print('Analisando ${dailyTransactions.length} transações...\n');

  final String stats = gateway.calculateBatchStatistics(dailyTransactions);
  print('Resultado JSON do Rust:\n$stats\n');

  // Parse simplificado (em produção, use dart:convert)
  final RegExp totalRegex = RegExp(r'"total":([\d.]+)');
  final RegExp avgRegex = RegExp(r'"average":([\d.]+)');
  final RegExp maxRegex = RegExp(r'"max":([\d.]+)');
  final RegExp minRegex = RegExp(r'"min":([\d.]+)');

  final double total = double.parse(totalRegex.firstMatch(stats)?.group(1) ?? '0');
  final double avg = double.parse(avgRegex.firstMatch(stats)?.group(1) ?? '0');
  final double max = double.parse(maxRegex.firstMatch(stats)?.group(1) ?? '0');
  final double min = double.parse(minRegex.firstMatch(stats)?.group(1) ?? '0');

  print('Resumo do dia:');
  print('  ├─ Total faturado:    R\$ ${total.toStringAsFixed(2)}');
  print('  ├─ Ticket médio:      R\$ ${avg.toStringAsFixed(2)}');
  print('  ├─ Maior transação:   R\$ ${max.toStringAsFixed(2)}');
  print('  └─ Menor transação:   R\$ ${min.toStringAsFixed(2)}');
  print('');

  // =========================================================================
  // EXEMPLO 6: Fluxo Completo de uma Transação
  // =========================================================================

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔄 EXEMPLO 6: Fluxo Completo de uma Transação');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Simular entrada do usuário
  const String userCardNumber = '4532015112830366';
  const double userAmount = 350.75;

  print('🧑 Cliente inseriu:');
  print('   Cartão: $userCardNumber');
  print('   Valor: R\$ ${userAmount.toStringAsFixed(2)}\n');

  // Passo 1: Validar cartão
  print('📝 Passo 1: Validando cartão via Rust...');
  final CardValidationResult cardCheck = gateway.validateCard(userCardNumber);
  if (!cardCheck.isValid) {
    print('   ❌ Cartão inválido: ${cardCheck.message}');
    return;
  }
  print('   ✅ Cartão ${cardCheck.cardType} válido!\n');

  // Passo 2: Calcular taxas
  print('💵 Passo 2: Calculando taxas via Rust...');
  final FeeBreakdownResult feeCalc = gateway.calculateTransactionFees(
    amount: userAmount,
    methodIndex: 1, // Chip
  );
  print('   Taxas: R\$ ${feeCalc.totalFee.toStringAsFixed(2)}');
  print('   Líquido: R\$ ${feeCalc.netAmount.toStringAsFixed(2)}\n');

  // Passo 3: Gerar ID da transação
  print('🔢 Passo 3: Gerando ID único via Rust...');
  final String txnId = gateway.generateUniqueTransactionId();
  print('   ID: $txnId\n');

  // Passo 4: Processar pagamento
  print('🔐 Passo 4: Analisando risco e processando via Rust...');
  final RustPaymentOutcome outcome = gateway.authorizePayment(
    amount: userAmount,
    tip: 0.0,
    methodIndex: 1,
  );
  print('   Score: ${(outcome.riskScore * 100).toStringAsFixed(1)}%');
  print('   Status: ${outcome.approved ? "✅ APROVADA" : "❌ NEGADA"}');
  print('   Mensagem: ${outcome.message}\n');

  // Resultado final
  if (outcome.approved) {
    print('🎉 Transação $txnId concluída com sucesso!');
    print('   O cliente pagou R\$ ${userAmount.toStringAsFixed(2)}');
    print('   Você receberá R\$ ${feeCalc.netAmount.toStringAsFixed(2)}');
  } else {
    print('⚠️  Transação $txnId foi negada pelo motor de risco.');
  }

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // =========================================================================
  // Conclusão
  // =========================================================================

  print('✨ Todos os exemplos foram executados com sucesso!');
  print('');
  print('🔍 Observações Importantes:');
  print('   • Todas as operações acima chamaram código Rust via FFI');
  print('   • Nenhuma lógica de negócio foi executada em Dart');
  print('   • O gerenciamento de memória foi feito corretamente');
  print('   • Todas as strings Rust foram liberadas após uso');
  print('');
  print('📚 Para mais informações, consulte:');
  print('   • doc/api/index.html (documentação DartDoc gerada)');
  print('   • rust_payment_engine/src/lib.rs (código-fonte Rust)');
  print('   • lib/rust_gateway.dart (bindings FFI documentados)');
  print('');
  print('🎓 Este projeto demonstra boas práticas de:');
  print('   ✓ Integração Flutter + Rust via dart:ffi');
  print('   ✓ Documentação técnica com DartDoc');
  print('   ✓ Gerenciamento seguro de memória entre linguagens');
  print('   ✓ Separação de responsabilidades (UI vs Lógica)');
  print('');
}
