use anyhow::Result;
use serde::{Deserialize, Serialize};
use super::awaiting_info::{PaymentInfo, AwaitingInfo};
use super::emv_payment::EmvResult;

// ==================== TYPES DESTE ESTADO ====================

/// Ações válidas no estado PaymentSuccess
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PaymentSuccessAction {
    Reset,
}

/// Estado final - pagamento concluído com sucesso
#[derive(Debug, Clone)]
pub struct PaymentSuccess {
    pub payment_info: PaymentInfo,
    pub result: EmvResult,
}

// ==================== IMPLEMENTAÇÃO DO TRAIT ====================

use super::super::state_trait::PaymentState;

impl PaymentState<PaymentSuccessAction> for PaymentSuccess {
    /// Executa ação - CONSTRÓI próximo estado se houver transição
    fn execute_action_with_transition(
        &mut self, 
        action: PaymentSuccessAction
    ) -> Result<Option<(super::super::StateType, Box<dyn std::any::Any + Send + Sync>)>> {
        use super::super::StateType;
        
        match action {
            PaymentSuccessAction::Reset => {
                // CONSTRÓI o estado inicial AQUI
                let next_state = AwaitingInfo::initial();
                
                Ok(Some((
                    StateType::AwaitingInfo,
                    Box::new(next_state)
                )))
            }
        }
    }
    
    fn state_type(&self) -> super::super::StateType {
        super::super::StateType::PaymentSuccess
    }
    
    fn description(&self) -> String {
        format!(
            "Pagamento concluído com sucesso - ID: {}, Código: {}, Valor: R$ {:.2}",
            self.result.transaction_id,
            self.result.authorization_code,
            self.payment_info.amount
        )
    }
}
