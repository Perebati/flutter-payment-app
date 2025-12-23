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
    
    /// Executa ação em estado ESPECÍFICO
    /// 
    /// Este método é 100% genérico:
    /// - S = tipo do estado (AwaitingInfo, EMVPayment, etc.)
    /// - A = tipo da ação (AwaitingInfoAction, EmvPaymentAction, etc.)
    /// - executor = closure que sabe como executar a ação
    /// 
    /// O ESTADO decide se transiciona e CONSTRÓI o próximo estado!
    pub async fn execute_action<S, A, F>(
        &self,
        action: A,
        executor: F,
    ) -> Result<String>
    where
        S: 'static + Send + Sync,
        F: FnOnce(&mut S, A) -> Result<Option<(StateType, Box<dyn std::any::Any + Send + Sync>)>>,
    {
        let mut state_guard = self.current_state.write().await;
        
        // Downcasta para o tipo específico
        let state = state_guard
            .downcast_mut::<S>()
            .ok_or_else(|| anyhow::anyhow!("Estado inválido para esta ação"))?;
        
        // Executa ação - O ESTADO decide tudo!
        let transition = executor(state, action)?;
        
        // Se houver transição, SUBSTITUI estado
        if let Some((new_type, new_state)) = transition {
            *state_guard = new_state;
            *self.current_state_type.write().await = new_type;
            
            // Notifica Flutter
            self.notify_state_change(new_type).await?;
            
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
    async fn notify_state_change(&self, new_state: StateType) -> Result<()> {
        let event = StateChangeEvent {
            from_state: *self.current_state_type.read().await,
            to_state: new_state,
            timestamp: chrono::Utc::now().to_rfc3339(),
        };
        
        self.state_sender
            .send(event)
            .map_err(|e| anyhow::anyhow!("Falha ao notificar mudança de estado: {}", e))?;
        
        Ok(())
    }
}
