use std::ffi::CString;
use std::os::raw::c_char;

#[repr(C)]
pub struct PaymentResult {
    pub status: i32,
    pub risk_score: f64,
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

#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }

    unsafe {
        drop(CString::from_raw(ptr));
    }
}

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
