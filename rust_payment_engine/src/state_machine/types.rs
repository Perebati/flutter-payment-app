use serde::{Deserialize, Serialize};

/// Estados possíveis da máquina de estados
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum StateType {
    AwaitingInfo,
    EMVPayment,
    PaymentSuccess,
}

/// Evento de mudança de estado para enviar ao Flutter
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateChangeEvent {
    pub from_state: StateType,
    pub to_state: StateType,
    pub timestamp: String,
}

/// Enum unificado de todas as ações possíveis
/// 
/// Cada estado tem suas ações, mas precisamos de um tipo unificado
/// para o StateManager ser genérico
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum StateAction {
    /// Ações do estado AwaitingInfo
    AwaitingInfo(crate::state_machine::states::AwaitingInfoAction),
    /// Ações do estado EMVPayment
    EmvPayment(crate::state_machine::states::EmvPaymentAction),
    /// Ações do estado PaymentSuccess
    PaymentSuccess(crate::state_machine::states::PaymentSuccessAction),
}
