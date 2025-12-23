use crate::state_machine::{PaymentStateApi, StateType, StateChangeEvent};
use crate::state_machine::{AwaitingInfoAction, EmvPaymentAction, PaymentSuccessAction, PaymentType, EmvResult};

/// API pública para o Flutter
/// 
/// Esta é a interface que será exposta via FFI para o Flutter
pub struct RustPaymentApi {
    api: PaymentStateApi,
}

impl RustPaymentApi {
    /// Cria uma nova instância da API
    pub fn new() -> Self {
        Self {
            api: PaymentStateApi::new(),
        }
    }
    
    /// Define o valor do pagamento
    pub async fn set_amount(&self, amount: f64) -> Result<String, String> {
        self.api
            .execute(AwaitingInfoAction::SetAmount { amount })
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Define o tipo de pagamento
    pub async fn set_payment_type(&self, payment_type: PaymentType) -> Result<String, String> {
        self.api
            .execute(AwaitingInfoAction::SetPaymentType { payment_type })
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Confirma as informações e inicia o pagamento
    pub async fn confirm_info(&self) -> Result<String, String> {
        self.api
            .execute(AwaitingInfoAction::ConfirmInfo)
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Processa o pagamento EMV
    pub async fn process_payment(&self) -> Result<String, String> {
        self.api
            .execute(EmvPaymentAction::ProcessPayment)
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Completa o pagamento com sucesso
    pub async fn complete_payment(
        &self,
        transaction_id: String,
        authorization_code: String,
    ) -> Result<String, String> {
        let result = EmvResult {
            transaction_id,
            authorization_code,
            timestamp: chrono::Utc::now().to_rfc3339(),
        };
        
        self.api
            .execute(EmvPaymentAction::CompletePayment { result })
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Cancela o pagamento atual
    pub async fn cancel_payment(&self) -> Result<String, String> {
        self.api
            .execute(EmvPaymentAction::CancelPayment)
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Retorna o estado atual
    pub async fn get_current_state(&self) -> StateType {
        self.api.current_state().await
    }
    
    /// Obtém descrição do estado AwaitingInfo
    pub async fn get_awaiting_info_description(&self) -> Result<String, String> {
        self.api
            .get_awaiting_info_description()
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Obtém descrição do estado EMVPayment
    pub async fn get_emv_payment_description(&self) -> Result<String, String> {
        self.api
            .get_emv_payment_description()
            .await
            .map_err(|e| e.to_string())
    }
    
    /// Obtém descrição do estado PaymentSuccess
    pub async fn get_payment_success_description(&self) -> Result<String, String> {
        self.api
            .get_payment_success_description()
            .await
            .map_err(|e| e.to_string())
    }
}

impl Default for RustPaymentApi {
    fn default() -> Self {
        Self::new()
    }
}
