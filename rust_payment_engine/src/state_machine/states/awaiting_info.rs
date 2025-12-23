use anyhow::Result;
use serde::{Deserialize, Serialize};

// ==================== TYPES DESTE ESTADO ====================

/// Tipo de pagamento selecionado pelo usuário
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum PaymentType {
    Debit,
    Credit,
}

/// Informações necessárias para iniciar um pagamento
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentInfo {
    pub amount: f64,
    pub payment_type: PaymentType,
}

/// Ações válidas no estado AwaitingInfo
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AwaitingInfoAction {
    SetAmount { amount: f64 },
    SetPaymentType { payment_type: PaymentType },
    ConfirmInfo,
}

// ==================== ESTADO ====================

/// Estado inicial - aguardando informações do pagamento
#[derive(Debug, Clone)]
pub struct AwaitingInfo {
    pub amount: Option<f64>,
    pub payment_type: Option<PaymentType>,
}

// ==================== IMPLEMENTAÇÃO DO TRAIT ====================

use super::super::state_trait::PaymentState;
use super::emv_payment::EMVPayment;

impl PaymentState<AwaitingInfoAction> for AwaitingInfo {
    /// Executa ação - CONSTRÓI próximo estado se houver transição
    fn execute_action_with_transition(
        &mut self, 
        action: AwaitingInfoAction
    ) -> Result<Option<(super::super::StateType, Box<dyn std::any::Any + Send + Sync>)>> {
        use super::super::StateType;
        
        match action {
            AwaitingInfoAction::SetAmount { amount } => {
                if amount <= 0.0 {
                    return Err(anyhow::anyhow!("Valor deve ser maior que zero"));
                }
                self.amount = Some(amount);
                Ok(None)
            }
            
            AwaitingInfoAction::SetPaymentType { payment_type } => {
                self.payment_type = Some(payment_type);
                Ok(None)
            }
            
            AwaitingInfoAction::ConfirmInfo => {
                let amount = self.amount.ok_or_else(|| anyhow::anyhow!("Valor não definido"))?;
                let payment_type = self.payment_type.clone()
                    .ok_or_else(|| anyhow::anyhow!("Tipo de pagamento não definido"))?;
                
                // CONSTRÓI o próximo estado AQUI
                let payment_info = PaymentInfo { amount, payment_type };
                let next_state = EMVPayment {
                    payment_info,
                    processing: false,
                    emv_result: None,
                };
                
                Ok(Some((
                    StateType::EMVPayment,
                    Box::new(next_state)
                )))
            }
        }
    }
    
    fn state_type(&self) -> super::super::StateType {
        super::super::StateType::AwaitingInfo
    }
    
    fn description(&self) -> String {
        match (&self.amount, &self.payment_type) {
            (Some(amt), Some(typ)) => format!(
                "Aguardando confirmação: R$ {:.2} ({:?})",
                amt, typ
            ),
            _ => "Aguardando informações do pagamento".to_string(),
        }
    }
}

impl AwaitingInfo {
    /// Construtor para estado inicial
    pub fn initial() -> Self {
        Self {
            amount: None,
            payment_type: None,
        }
    }
}
