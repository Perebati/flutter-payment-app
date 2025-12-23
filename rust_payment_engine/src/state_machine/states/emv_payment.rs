use anyhow::Result;
use serde::{Deserialize, Serialize};
use super::awaiting_info::{PaymentInfo, AwaitingInfo};
use super::payment_success::PaymentSuccess;

// ==================== TYPES DESTE ESTADO ====================

/// Dados do resultado do pagamento EMV
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmvResult {
    pub transaction_id: String,
    pub authorization_code: String,
    pub timestamp: String,
}

/// Ações válidas no estado EMVPayment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EmvPaymentAction {
    ProcessPayment,
    CompletePayment { result: EmvResult },
    CancelPayment,
}

// ==================== ESTADO ====================

/// Estado de processamento do pagamento EMV
#[derive(Debug, Clone)]
pub struct EMVPayment {
    pub payment_info: PaymentInfo,
    pub processing: bool,
    pub emv_result: Option<EmvResult>,
}

// ==================== IMPLEMENTAÇÃO DO TRAIT ====================

use super::super::state_trait::PaymentState;

impl PaymentState<EmvPaymentAction> for EMVPayment {
    /// Executa ação - CONSTRÓI próximo estado se houver transição
    fn execute_action_with_transition(
        &mut self, 
        action: EmvPaymentAction
    ) -> Result<Option<(super::super::StateType, Box<dyn std::any::Any + Send + Sync>)>> {
        use super::super::StateType;
        
        match action {
            EmvPaymentAction::ProcessPayment => {
                if self.processing {
                    return Err(anyhow::anyhow!("Pagamento já está sendo processado"));
                }
                self.processing = true;
                Ok(None)
            }
            
            EmvPaymentAction::CompletePayment { result } => {
                if !self.processing {
                    return Err(anyhow::anyhow!("Pagamento ainda não foi iniciado"));
                }
                
                // CONSTRÓI o próximo estado AQUI
                let next_state = PaymentSuccess {
                    payment_info: self.payment_info.clone(),
                    result,
                };
                
                Ok(Some((
                    StateType::PaymentSuccess,
                    Box::new(next_state)
                )))
            }
            
            EmvPaymentAction::CancelPayment => {
                // CONSTRÓI estado de retorno AQUI
                let next_state = AwaitingInfo::initial();
                
                Ok(Some((
                    StateType::AwaitingInfo,
                    Box::new(next_state)
                )))
            }
        }
    }
    
    fn state_type(&self) -> super::super::StateType {
        super::super::StateType::EMVPayment
    }
    
    fn description(&self) -> String {
        if self.processing {
            format!("Processando pagamento de R$ {:.2}...", self.payment_info.amount)
        } else {
            format!("Pronto para processar pagamento de R$ {:.2}", self.payment_info.amount)
        }
    }
}
