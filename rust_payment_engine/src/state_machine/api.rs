use anyhow::Result;
use std::sync::Arc;
use tokio::sync::{Mutex, mpsc};
use super::{StateManager, StateType, StateChangeEvent, initialize_registry};
use super::states::*;
use super::state_trait::PaymentState;

/// API pública para gerenciamento de estados de pagamento
/// 
/// Esta API fornece uma interface simplificada e assíncrona para:
/// - Inicializar o gerenciador de estados
/// - Executar ações de forma type-safe
/// - Receber eventos de mudança de estado
#[derive(Clone)]
pub struct PaymentStateApi {
    manager: StateManager,
    event_receiver: Arc<Mutex<mpsc::UnboundedReceiver<StateChangeEvent>>>,
}

impl PaymentStateApi {
    /// Inicializa a API com o estado inicial AwaitingInfo
    /// 
    /// # Exemplo
    /// ```
    /// let api = PaymentStateApi::new();
    /// ```
    pub fn new() -> Self {
        // Garante que o registry está inicializado
        initialize_registry();
        
        let initial_state = AwaitingInfo {
            amount: None,
            payment_type: None,
        };
        
        let (manager, rx) = StateManager::new(
            Box::new(initial_state),
            StateType::AwaitingInfo,
        );
        
        Self {
            manager,
            event_receiver: Arc::new(Mutex::new(rx)),
        }
    }
    
    /// Executa uma ação assíncrona de forma simplificada
    /// 
    /// # Exemplo
    /// ```
    /// api.execute(AwaitingInfoAction::SetAmount { amount: 100.0 }).await?;
    /// api.execute(AwaitingInfoAction::ConfirmInfo).await?;
    /// ```
    pub async fn execute<A>(&self, action: A) -> Result<String>
    where
        A: 'static,
    {
        self.manager.execute(action).await
    }
    
    /// Retorna o tipo do estado atual
    pub async fn current_state(&self) -> StateType {
        self.manager.get_current_state_type().await
    }
    
    /// Aguarda o próximo evento de mudança de estado
    /// 
    /// Retorna `None` se o canal foi fechado
    pub async fn next_event(&self) -> Option<StateChangeEvent> {
        self.event_receiver.lock().await.recv().await
    }
    
    /// Tenta receber um evento sem bloquear
    /// 
    /// Retorna `Ok(Some(event))` se houver evento disponível,
    /// `Ok(None)` se não houver eventos,
    /// `Err(())` se o canal foi fechado
    pub async fn try_next_event(&self) -> Result<Option<StateChangeEvent>, ()> {
        self.event_receiver.lock().await.try_recv()
            .map(Some)
            .or_else(|e| match e {
                mpsc::error::TryRecvError::Empty => Ok(None),
                mpsc::error::TryRecvError::Disconnected => Err(()),
            })
    }
    
    /// Obtém descrição do estado atual (se disponível)
    pub async fn get_awaiting_info_description(&self) -> Result<String> {
        self.manager.get_description::<AwaitingInfo, _>(|state| state.description()).await
    }
    
    /// Obtém descrição do estado EMVPayment (se disponível)
    pub async fn get_emv_payment_description(&self) -> Result<String> {
        self.manager.get_description::<EMVPayment, _>(|state| state.description()).await
    }
    
    /// Obtém descrição do estado PaymentSuccess (se disponível)
    pub async fn get_payment_success_description(&self) -> Result<String> {
        self.manager.get_description::<PaymentSuccess, _>(|state| state.description()).await
    }
}

impl Default for PaymentStateApi {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod api_tests {
    use super::*;
    use tokio::time::{timeout, Duration};
    
    #[tokio::test]
    async fn test_api_initialization() {
        let api = PaymentStateApi::new();
        assert_eq!(api.current_state().await, StateType::AwaitingInfo);
    }
    
    #[tokio::test]
    async fn test_api_simple_execution() {
        let api = PaymentStateApi::new();
        
        let result = api.execute(AwaitingInfoAction::SetAmount { amount: 100.0 }).await;
        assert!(result.is_ok());
    }
    
    #[tokio::test]
    async fn test_api_full_flow() {
        let api = PaymentStateApi::new();
        
        // Define valor
        api.execute(AwaitingInfoAction::SetAmount { amount: 150.0 }).await.unwrap();
        
        // Define tipo de pagamento
        api.execute(AwaitingInfoAction::SetPaymentType { 
            payment_type: PaymentType::Credit 
        }).await.unwrap();
        
        // Confirma e transiciona
        api.execute(AwaitingInfoAction::ConfirmInfo).await.unwrap();
        
        // Verifica estado após transição
        assert_eq!(api.current_state().await, StateType::EMVPayment);
        
        // Verifica evento
        let event = timeout(Duration::from_millis(100), api.next_event()).await;
        assert!(event.is_ok());
        let event = event.unwrap().unwrap();
        assert_eq!(event.from_state, StateType::AwaitingInfo);
        assert_eq!(event.to_state, StateType::EMVPayment);
    }
    
    #[tokio::test]
    async fn test_api_try_next_event_when_empty() {
        let api = PaymentStateApi::new();
        
        let result = api.try_next_event().await;
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }
    
    #[tokio::test]
    async fn test_api_get_description() {
        let api = PaymentStateApi::new();
        
        let description = api.get_awaiting_info_description().await;
        assert!(description.is_ok());
        assert!(description.unwrap().contains("Aguardando"));
    }
    
    #[tokio::test]
    async fn test_api_clone() {
        let api = PaymentStateApi::new();
        let api_clone = api.clone();
        
        // Executa ação no clone
        api_clone.execute(AwaitingInfoAction::SetAmount { amount: 200.0 }).await.unwrap();
        
        // Estado deve estar sincronizado
        assert_eq!(api.current_state().await, StateType::AwaitingInfo);
    }
    
    #[tokio::test]
    async fn test_api_concurrent_access() {
        let api = PaymentStateApi::new();
        
        let handles: Vec<_> = (0..5).map(|i| {
            let api_clone = api.clone();
            tokio::spawn(async move {
                api_clone.execute(AwaitingInfoAction::SetAmount { 
                    amount: (i * 10 + 100) as f64 
                }).await
            })
        }).collect();
        
        for handle in handles {
            let result = handle.await.unwrap();
            assert!(result.is_ok());
        }
    }
    
    #[tokio::test]
    async fn test_api_error_handling() {
        let api = PaymentStateApi::new();
        
        // Tenta executar ação inválida
        let result = api.execute(AwaitingInfoAction::SetAmount { amount: -50.0 }).await;
        assert!(result.is_err());
    }
    
    #[tokio::test]
    async fn test_api_complete_payment_cycle() {
        let api = PaymentStateApi::new();
        
        // AwaitingInfo -> EMVPayment
        api.execute(AwaitingInfoAction::SetAmount { amount: 300.0 }).await.unwrap();
        api.execute(AwaitingInfoAction::SetPaymentType { 
            payment_type: PaymentType::Debit 
        }).await.unwrap();
        api.execute(AwaitingInfoAction::ConfirmInfo).await.unwrap();
        
        assert_eq!(api.current_state().await, StateType::EMVPayment);
        
        // EMVPayment -> PaymentSuccess
        api.execute(EmvPaymentAction::ProcessPayment).await.unwrap();
        
        let emv_result = EmvResult {
            transaction_id: "TXN999".to_string(),
            authorization_code: "AUTH999".to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
        };
        
        api.execute(EmvPaymentAction::CompletePayment { result: emv_result }).await.unwrap();
        
        assert_eq!(api.current_state().await, StateType::PaymentSuccess);
        
        // Deve ter recebido 2 eventos
        let event1 = api.next_event().await.unwrap();
        assert_eq!(event1.to_state, StateType::EMVPayment);
        
        let event2 = api.next_event().await.unwrap();
        assert_eq!(event2.to_state, StateType::PaymentSuccess);
    }
}
