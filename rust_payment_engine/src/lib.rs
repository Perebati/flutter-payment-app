use std::ffi::CString;
use std::os::raw::c_char;
use std::sync::atomic::{AtomicU64, Ordering};

/// Contador global para gerar IDs únicos de transações
static TRANSACTION_COUNTER: AtomicU64 = AtomicU64::new(1);

/// Resultado de uma operação de pagamento processada pelo motor Rust.
///
/// Este struct é compatível com FFI (C ABI) e pode ser transferido
/// diretamente para Dart através de `dart:ffi`.
#[repr(C)]
pub struct PaymentResult {
    /// Status da transação: 0 = Aprovado, 1 = Negado
    pub status: i32,
    /// Score de risco calculado (0.0 a 1.0)
    pub risk_score: f64,
    /// Mensagem descritiva alocada em Rust (deve ser liberada com free_rust_string)
    pub message: *mut c_char,
}

/// Informações sobre taxas calculadas para uma transação.
#[repr(C)]
pub struct FeeBreakdown {
    /// Taxa fixa cobrada (em reais)
    pub fixed_fee: f64,
    /// Taxa percentual aplicada (ex: 0.029 = 2.9%)
    pub percentage_fee: f64,
    /// Valor total das taxas
    pub total_fee: f64,
    /// Valor líquido que o comerciante receberá
    pub net_amount: f64,
}

/// Resultado da validação de um número de cartão.
#[repr(C)]
pub struct CardValidation {
    /// 1 = válido, 0 = inválido
    pub is_valid: i32,
    /// Tipo de cartão identificado (Visa, Mastercard, etc.)
    pub card_type: *mut c_char,
    /// Mensagem explicativa sobre a validação
    pub message: *mut c_char,
}

#[no_mangle]
pub extern "C" fn process_payment(amount: f64, tip: f64, method: i32) -> PaymentResult {
    let total = amount + tip;

    // Score is intentionally simple so it is easy to inspect from Dart/Flutter.
    // The value is clamped to [0, 1] so it can be rendered as a percentage if desired.
    let base_score = (amount / (total + 1.0)).abs().min(1.0);
    let method_weight = match method {
        0 => 0.85, // tap
        1 => 0.90, // chip
        2 => 0.70, // swipe
        _ => 0.60, // manual or unknown
    };

    let risk_score = (base_score * method_weight).min(1.0);
    let approved = risk_score >= 0.35;

    let message = if approved {
        format!("Autorizado com score {:.2}%.", risk_score * 100.0)
    } else {
        format!(
            "Recusado pelo motor de risco (score {:.2}%).",
            risk_score * 100.0
        )
    };

    let c_string = CString::new(message).unwrap_or_else(|_| CString::new("Mensagem inválida").unwrap());

    PaymentResult {
        status: if approved { 0 } else { 1 },
        risk_score,
        message: c_string.into_raw(),
    }
}

/// Valida um número de cartão usando o algoritmo de Luhn.
///
/// Esta função verifica a integridade do número do cartão e identifica
/// a bandeira baseado nos primeiros dígitos (BIN).
///
/// # Segurança
/// Esta é uma validação básica educacional. Em produção, nunca processe
/// números de cartão completos sem PCI-DSS compliance.
///
/// # Retorno
/// Retorna um `CardValidation` struct contendo:
/// - `is_valid`: 1 se válido, 0 se inválido
/// - `card_type`: String identificando a bandeira
/// - `message`: Mensagem descritiva
#[no_mangle]
pub extern "C" fn validate_card_number(card_number: *const c_char) -> CardValidation {
    if card_number.is_null() {
        return CardValidation {
            is_valid: 0,
            card_type: CString::new("Desconhecido").unwrap().into_raw(),
            message: CString::new("Número de cartão nulo").unwrap().into_raw(),
        };
    }

    let card_str = unsafe {
        match std::ffi::CStr::from_ptr(card_number).to_str() {
            Ok(s) => s,
            Err(_) => {
                return CardValidation {
                    is_valid: 0,
                    card_type: CString::new("Desconhecido").unwrap().into_raw(),
                    message: CString::new("Formato inválido").unwrap().into_raw(),
                }
            }
        }
    };

    // Remove espaços e caracteres não numéricos
    let digits: Vec<u32> = card_str
        .chars()
        .filter(|c| c.is_numeric())
        .filter_map(|c| c.to_digit(10))
        .collect();

    if digits.len() < 13 || digits.len() > 19 {
        return CardValidation {
            is_valid: 0,
            card_type: CString::new("Desconhecido").unwrap().into_raw(),
            message: CString::new("Comprimento inválido (deve ter entre 13-19 dígitos)")
                .unwrap()
                .into_raw(),
        };
    }

    // Algoritmo de Luhn
    let mut sum = 0;
    let mut double = false;

    for &digit in digits.iter().rev() {
        let mut value = digit;
        if double {
            value *= 2;
            if value > 9 {
                value -= 9;
            }
        }
        sum += value;
        double = !double;
    }

    let is_valid = sum % 10 == 0;

    // Identificar bandeira pelo BIN (primeiros dígitos)
    let card_type = if digits.len() >= 2 {
        let first_two = digits[0] * 10 + digits[1];
        let first_four = if digits.len() >= 4 {
            digits[0] * 1000 + digits[1] * 100 + digits[2] * 10 + digits[3]
        } else {
            0
        };

        if digits[0] == 4 {
            "Visa"
        } else if (51..=55).contains(&first_two) || (2221..=2720).contains(&first_four) {
            "Mastercard"
        } else if first_two == 36 || first_two == 38 || (300..=305).contains(&first_four) {
            "Diners Club"
        } else if first_two == 34 || first_two == 37 {
            "American Express"
        } else if (506099..=506198).contains(&first_four)
            || (636368..=636369).contains(&first_four)
            || (509000..=509999).contains(&first_four)
        {
            "Elo"
        } else if (6011..=6019).contains(&first_four) || first_two == 65 {
            "Discover"
        } else {
            "Desconhecido"
        }
    } else {
        "Desconhecido"
    };

    let message = if is_valid {
        format!("Cartão {} válido (Luhn check passed)", card_type)
    } else {
        "Falha na verificação Luhn - número inválido".to_string()
    };

    CardValidation {
        is_valid: if is_valid { 1 } else { 0 },
        card_type: CString::new(card_type).unwrap().into_raw(),
        message: CString::new(message).unwrap().into_raw(),
    }
}

/// Calcula o detalhamento de taxas para uma transação.
///
/// As taxas variam baseado no método de pagamento:
/// - Aproximação (NFC): 2.5% + R$ 0.10
/// - Chip EMV: 2.9% + R$ 0.15
/// - Tarja Magnética: 3.5% + R$ 0.20
/// - Manual: 4.5% + R$ 0.30
///
/// # Parâmetros
/// - `amount`: Valor bruto da transação
/// - `method`: Método de pagamento (0=NFC, 1=Chip, 2=Tarja, 3=Manual)
///
/// # Retorno
/// Struct `FeeBreakdown` contendo todas as taxas calculadas
#[no_mangle]
pub extern "C" fn calculate_fees(amount: f64, method: i32) -> FeeBreakdown {
    let (percentage, fixed) = match method {
        0 => (0.025, 0.10), // NFC/Tap
        1 => (0.029, 0.15), // Chip
        2 => (0.035, 0.20), // Swipe
        3 => (0.045, 0.30), // Manual
        _ => (0.040, 0.25), // Default/Unknown
    };

    let percentage_fee = amount * percentage;
    let total_fee = percentage_fee + fixed;
    let net_amount = amount - total_fee;

    FeeBreakdown {
        fixed_fee: fixed,
        percentage_fee,
        total_fee,
        net_amount: net_amount.max(0.0),
    }
}

/// Gera um ID único de transação.
///
/// Utiliza um contador atômico thread-safe para garantir unicidade.
/// O formato retornado é: "TXN-{timestamp}-{counter}"
///
/// # Retorno
/// Ponteiro para string C alocada em Rust (deve ser liberada com free_rust_string)
#[no_mangle]
pub extern "C" fn generate_transaction_id() -> *mut c_char {
    let counter = TRANSACTION_COUNTER.fetch_add(1, Ordering::SeqCst);
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let id = format!("TXN-{}-{:06}", timestamp, counter);
    CString::new(id).unwrap().into_raw()
}

/// Calcula estatísticas de um lote de transações.
///
/// Processa um array de valores de transações e retorna estatísticas agregadas.
///
/// # Parâmetros
/// - `amounts`: Array de valores das transações
/// - `count`: Número de elementos no array
///
/// # Retorno
/// String JSON com estatísticas (total, média, máximo, mínimo)
#[no_mangle]
pub extern "C" fn calculate_batch_stats(amounts: *const f64, count: usize) -> *mut c_char {
    if amounts.is_null() || count == 0 {
        return CString::new(r#"{"error":"Invalid input"}"#)
            .unwrap()
            .into_raw();
    }

    let slice = unsafe { std::slice::from_raw_parts(amounts, count) };

    let total: f64 = slice.iter().sum();
    let average = total / count as f64;
    let max = slice.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let min = slice.iter().cloned().fold(f64::INFINITY, f64::min);

    let stats = format!(
        r#"{{"total":{:.2},"average":{:.2},"max":{:.2},"min":{:.2},"count":{}}}"#,
        total, average, max, min, count
    );

    CString::new(stats).unwrap().into_raw()
}

/// Libera memória alocada por Rust para uma string C.
///
/// **CRÍTICO**: Toda string retornada por funções Rust FFI deve ser
/// liberada usando esta função para evitar memory leaks.
///
/// # Segurança
/// - Não chame esta função duas vezes no mesmo ponteiro
/// - Não use o ponteiro após liberá-lo
/// - Ponteiros nulos são ignorados com segurança
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }

    unsafe {
        drop(CString::from_raw(ptr));
    }
}

/// Libera memória de um struct CardValidation.
///
/// Deve ser chamado após consumir os dados do struct para evitar leaks
/// dos campos `card_type` e `message`.
#[no_mangle]
pub extern "C" fn free_card_validation(validation: CardValidation) {
    free_rust_string(validation.card_type);
    free_rust_string(validation.message);
}

/// Retorna uma descrição textual do método de pagamento.
///
/// Útil para exibição na UI sem hardcode no lado Dart.
///
/// # Parâmetros
/// - `method`: Código do método (0-3)
///
/// # Retorno
/// String C descrevendo o método (deve ser liberada com free_rust_string)
#[no_mangle]
pub extern "C" fn describe_method(method: i32) -> *mut c_char {
    let description = match method {
        0 => "Aproximação NFC",
        1 => "Chip EMV",
        2 => "Tarja magnética",
        3 => "Digitação manual",
        _ => "Desconhecido",
    };

    CString::new(description)
        .unwrap_or_else(|_| CString::new("Desconhecido").unwrap())
        .into_raw()
}
