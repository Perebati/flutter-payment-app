use anyhow::Result;
use super::StateType;

/// Trait comum para TODOS os estados
/// 
/// **ESTADOS CONSTROEM PRÓXIMOS ESTADOS**
/// 
/// Quando há transição, o estado atual constrói o próximo estado.
/// StateManager NUNCA constrói estados - apenas armazena e notifica.
/// 
#[allow(dead_code)]
pub trait PaymentState<Action>: Send + Sync {
    /// Executa ação e CONSTRÓI próximo estado se houver transição
    /// 
    /// Retorna:
    /// - Ok(None) - Permanece no mesmo estado
    /// - Ok(Some((StateType, Box<NextState>))) - Transiciona, retornando estado JÁ construído
    /// - Err(_) - Erro na operação
    fn execute_action_with_transition(
        &mut self, 
        action: Action
    ) -> Result<Option<(StateType, Box<dyn std::any::Any + Send + Sync>)>>;
    
    /// Retorna o tipo do estado atual
    fn state_type(&self) -> StateType;
    
    /// Retorna uma descrição do estado
    fn description(&self) -> String;
}
