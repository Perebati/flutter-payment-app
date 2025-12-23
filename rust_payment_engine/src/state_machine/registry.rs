use std::collections::HashMap;
use std::sync::OnceLock;
use anyhow::Result;
use super::StateType;
use super::state_trait::PaymentState;

/// Função que pode executar uma ação em um estado
type DispatchFn = fn(
    state: &mut Box<dyn std::any::Any + Send + Sync>,
    action: Box<dyn std::any::Any>,
) -> Result<Option<(StateType, Box<dyn std::any::Any + Send + Sync>)>>;

/// Registry global de estados
static STATE_REGISTRY: OnceLock<HashMap<StateType, DispatchFn>> = OnceLock::new();

/// Registra um estado no registry
#[allow(dead_code)]
pub fn register_state(state_type: StateType, dispatch_fn: DispatchFn) {
    STATE_REGISTRY.get_or_init(|| {
        let mut map = HashMap::new();
        map.insert(state_type, dispatch_fn);
        map
    });
}

/// Obtém a função de dispatch para um estado
pub fn get_dispatch_fn(state_type: StateType) -> Option<DispatchFn> {
    STATE_REGISTRY.get().and_then(|registry| registry.get(&state_type).copied())
}

/// Inicializa o registry com todos os estados
#[allow(dead_code)]
pub fn initialize_registry() {
    use super::states::*;
    
    let mut registry = HashMap::new();
    
    // AwaitingInfo
    registry.insert(StateType::AwaitingInfo, (|state: &mut Box<dyn std::any::Any + Send + Sync>, action: Box<dyn std::any::Any>| {
        let state = state.downcast_mut::<AwaitingInfo>()
            .ok_or_else(|| anyhow::anyhow!("Estado inválido"))?;
        let action = action.downcast::<AwaitingInfoAction>()
            .map_err(|_| anyhow::anyhow!("Ação incompatível"))?;
        state.execute_action_with_transition(*action)
    }) as DispatchFn);
    
    // EMVPayment
    registry.insert(StateType::EMVPayment, (|state: &mut Box<dyn std::any::Any + Send + Sync>, action: Box<dyn std::any::Any>| {
        let state = state.downcast_mut::<EMVPayment>()
            .ok_or_else(|| anyhow::anyhow!("Estado inválido"))?;
        let action = action.downcast::<EmvPaymentAction>()
            .map_err(|_| anyhow::anyhow!("Ação incompatível"))?;
        state.execute_action_with_transition(*action)
    }) as DispatchFn);
    
    // PaymentSuccess
    registry.insert(StateType::PaymentSuccess, (|state: &mut Box<dyn std::any::Any + Send + Sync>, action: Box<dyn std::any::Any>| {
        let state = state.downcast_mut::<PaymentSuccess>()
            .ok_or_else(|| anyhow::anyhow!("Estado inválido"))?;
        let action = action.downcast::<PaymentSuccessAction>()
            .map_err(|_| anyhow::anyhow!("Ação incompatível"))?;
        state.execute_action_with_transition(*action)
    }) as DispatchFn);
    
    // Inicializa o OnceLock
    let _ = STATE_REGISTRY.set(registry);
}
