use anyhow::Result;
use std::sync::Arc;
use tokio::sync::{RwLock, mpsc};
use super::{StateType, StateChangeEvent};

/// ===============================================================================
/// STATEMANAGER 100% GENÉRICO - ZERO LÓGICA DE ESTADOS
/// ===============================================================================
/// 
/// Este StateManager é COMPLETAMENTE GENÉRICO:
/// - NÃO conhece estados específicos
/// - NÃO constrói estados (os estados constroem outros estados)
/// - NÃO tem match statements sobre StateType
/// - Pode escalar para 10.000 estados SEM MODIFICAÇÃO
/// 
/// Papel do StateManager:
/// 1. Armazenar o estado atual (type-erased com Box<dyn Any>)
/// 2. Notificar Flutter sobre mudanças
/// 3. Coordenar transições (mas não decidir lógica)
/// ===============================================================================

pub struct StateManager {
    /// Estado atual (type-erased para ser 100% genérico)
    current_state: Arc<RwLock<Box<dyn std::any::Any + Send + Sync>>>,
    
    /// Tipo do estado atual (para notificações)
    current_state_type: Arc<RwLock<StateType>>,
    
    /// Canal para notificar Flutter
    state_sender: mpsc::UnboundedSender<StateChangeEvent>,
}

impl Clone for StateManager {
    fn clone(&self) -> Self {
        Self {
            current_state: Arc::clone(&self.current_state),
            current_state_type: Arc::clone(&self.current_state_type),
            state_sender: self.state_sender.clone(),
        }
    }
}

impl StateManager {
    /// Cria novo StateManager com estado inicial
    pub fn new(
        initial_state: Box<dyn std::any::Any + Send + Sync>,
        initial_type: StateType,
    ) -> (Self, mpsc::UnboundedReceiver<StateChangeEvent>) {
        let (tx, rx) = mpsc::unbounded_channel();
        
        let manager = Self {
            current_state: Arc::new(RwLock::new(initial_state)),
            current_state_type: Arc::new(RwLock::new(initial_type)),
            state_sender: tx,
        };
        
        (manager, rx)
    }
    
    /// API SIMPLIFICADA - Executa ação descobrindo automaticamente o estado atual
    /// 
    /// Uso:
    /// ```
    /// manager.execute(AwaitingInfoAction::SetAmount { amount: 100.0 }).await?;
    /// ```
    /// 
    /// O StateManager descobre qual é o estado atual e tenta executar a ação.
    /// Se a ação não for compatível com o estado atual, retorna erro.
    /// 
    /// TOTALMENTE GENÉRICO - Não conhece nenhum estado específico!
    pub async fn execute<A>(&self, action: A) -> Result<String>
    where
        A: 'static,
    {
        // Descobre qual é o estado atual
        let current_type = *self.current_state_type.read().await;
        
        // Busca a função de dispatch no registry
        let dispatch_fn = super::registry::get_dispatch_fn(current_type)
            .ok_or_else(|| anyhow::anyhow!("Estado não registrado: {:?}", current_type))?;
        
        let mut state_guard = self.current_state.write().await;
        let action_boxed = Box::new(action) as Box<dyn std::any::Any>;
        
        // Executa usando a função registrada
        let transition = dispatch_fn(&mut *state_guard, action_boxed)?;
        
        // Se houver transição, SUBSTITUI estado
        if let Some((new_type, new_state)) = transition {
            // Captura o tipo do estado ANTES de modificar
            let old_type = *self.current_state_type.read().await;
            
            *state_guard = new_state;
            *self.current_state_type.write().await = new_type;
            
            // Notifica Flutter com o estado correto
            self.notify_state_change(old_type, new_type).await?;
            
            Ok(format!("Transicionado para {:?}", new_type))
        } else {
            Ok("Ação executada - permanece no mesmo estado".to_string())
        }
    }
    
    /// Retorna o tipo do estado atual
    pub async fn get_current_state_type(&self) -> StateType {
        *self.current_state_type.read().await
    }
    
    /// Retorna descrição do estado (se implementado)
    pub async fn get_description<S, F>(&self, getter: F) -> Result<String>
    where
        S: 'static + Send + Sync,
        F: FnOnce(&S) -> String,
    {
        let state_guard = self.current_state.read().await;
        let state = state_guard
            .downcast_ref::<S>()
            .ok_or_else(|| anyhow::anyhow!("Estado inválido"))?;
        
        Ok(getter(state))
    }
    
    /// Notifica Flutter sobre mudança de estado
    async fn notify_state_change(&self, from_state: StateType, to_state: StateType) -> Result<()> {
        let event = StateChangeEvent {
            from_state,
            to_state,
            timestamp: chrono::Utc::now().to_rfc3339(),
        };
        
        self.state_sender
            .send(event)
            .map_err(|e| anyhow::anyhow!("Falha ao notificar mudança de estado: {}", e))?;
        
        Ok(())
    }
}
