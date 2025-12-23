#[cfg(test)]
mod state_manager_tests {
    use crate::state_machine::state_manager::StateManager;
    use crate::state_machine::{StateType, StateChangeEvent, initialize_registry};
    use crate::state_machine::{
        AwaitingInfo, AwaitingInfoAction, PaymentType, PaymentInfo,
        EMVPayment, EmvPaymentAction, EmvResult,
    };
    use crate::state_machine::state_trait::PaymentState;
    use tokio::time::{timeout, Duration};
    
    // Inicializa o registry uma vez para todos os testes
    fn setup() {
        static INIT: std::sync::Once = std::sync::Once::new();
        INIT.call_once(|| {
            initialize_registry();
        });
    }

    // ==================== HELPER FUNCTIONS ====================
    
    /// Cria um StateManager com estado inicial AwaitingInfo
    fn create_awaiting_info_manager() -> (StateManager, tokio::sync::mpsc::UnboundedReceiver<StateChangeEvent>) {
        setup();
        let initial_state = AwaitingInfo {
            amount: None,
            payment_type: None,
        };
        
        StateManager::new(
            Box::new(initial_state),
            StateType::AwaitingInfo,
        )
    }
    
    /// Cria um StateManager com estado EMVPayment
    fn create_emv_payment_manager(amount: f64, payment_type: PaymentType) -> (StateManager, tokio::sync::mpsc::UnboundedReceiver<StateChangeEvent>) {
        setup();
        let payment_info = PaymentInfo {
            amount,
            payment_type,
        };
        
        let emv_state = EMVPayment {
            payment_info,
            processing: false,
            emv_result: None,
        };
        
        StateManager::new(
            Box::new(emv_state),
            StateType::EMVPayment,
        )
    }

    // ==================== TESTES DE INICIALIZAÇÃO ====================

    #[tokio::test]
    async fn test_new_state_manager_has_correct_initial_state() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        let current_type = manager.get_current_state_type().await;
        assert_eq!(current_type, StateType::AwaitingInfo);
    }

    #[tokio::test]
    async fn test_new_state_manager_returns_receiver() {
        let (_manager, mut rx) = create_awaiting_info_manager();
        
        // Receiver deve estar vazio no início
        assert!(rx.try_recv().is_err());
    }

    // ==================== TESTES DE AÇÕES SEM TRANSIÇÃO ====================

    #[tokio::test]
    async fn test_set_amount_action_stays_in_same_state() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        let action = AwaitingInfoAction::SetAmount { amount: 100.0 };
        
        let result = manager.execute(action).await;
        
        assert!(result.is_ok());
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
        
        // Não deve emitir evento de mudança de estado
        assert!(rx.try_recv().is_err());
    }

    #[tokio::test]
    async fn test_set_payment_type_action_stays_in_same_state() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        let action = AwaitingInfoAction::SetPaymentType { 
            payment_type: PaymentType::Credit 
        };
        
        let result = manager.execute(action).await;
        
        assert!(result.is_ok());
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
        
        // Não deve emitir evento de mudança de estado
        assert!(rx.try_recv().is_err());
    }

    #[tokio::test]
    async fn test_multiple_actions_without_transition() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        // Define valor
        let result1 = manager.execute(
            AwaitingInfoAction::SetAmount { amount: 50.0 }
        ).await;
        assert!(result1.is_ok());
        
        // Define tipo de pagamento
        let result2 = manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Debit }
        ).await;
        assert!(result2.is_ok());
        
        // Deve permanecer no mesmo estado
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
        
        // Não deve emitir eventos
        assert!(rx.try_recv().is_err());
    }

    // ==================== TESTES DE VALIDAÇÃO ====================

    #[tokio::test]
    async fn test_invalid_amount_returns_error() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        let action = AwaitingInfoAction::SetAmount { amount: -10.0 };
        
        let result = manager.execute(action).await;
        
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("maior que zero"));
    }

    #[tokio::test]
    async fn test_confirm_without_amount_returns_error() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Apenas define o tipo de pagamento
        let _ = manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Credit }
        ).await;
        
        // Tenta confirmar sem valor
        let result = manager.execute(
            AwaitingInfoAction::ConfirmInfo
        ).await;
        
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("não definido"));
    }

    #[tokio::test]
    async fn test_confirm_without_payment_type_returns_error() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Apenas define o valor
        let _ = manager.execute(
            AwaitingInfoAction::SetAmount { amount: 75.0 }
        ).await;
        
        // Tenta confirmar sem tipo de pagamento
        let result = manager.execute(
            AwaitingInfoAction::ConfirmInfo
        ).await;
        
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("Tipo de pagamento não definido"));
    }

    // ==================== TESTES DE TRANSIÇÃO DE ESTADO ====================

    #[tokio::test]
    async fn test_confirm_info_transitions_to_emv_payment() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        // Configura informações
        let _ = manager.execute(
            AwaitingInfoAction::SetAmount { amount: 100.0 }
        ).await;
        
        let _ = manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Credit }
        ).await;
        
        // Confirma e transiciona
        let result = manager.execute(
            AwaitingInfoAction::ConfirmInfo
        ).await;
        
        assert!(result.is_ok());
        
        // Deve receber evento de mudança de estado
        let event = timeout(Duration::from_secs(1), rx.recv()).await;
        assert!(event.is_ok());
        
        let event = event.unwrap().unwrap();
        assert_eq!(event.from_state, StateType::AwaitingInfo);
        assert_eq!(event.to_state, StateType::EMVPayment);
        
        // Verifica estado após todas as operações
        assert_eq!(manager.get_current_state_type().await, StateType::EMVPayment);
    }

    #[tokio::test]
    async fn test_complete_payment_transitions_to_success() {
        let (manager, mut rx) = create_emv_payment_manager(100.0, PaymentType::Credit);
        
        // Inicia processamento
        let _ = manager.execute(
            EmvPaymentAction::ProcessPayment
        ).await;
        
        // Completa pagamento
        let emv_result = EmvResult {
            transaction_id: "TXN123".to_string(),
            authorization_code: "AUTH456".to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
        };
        
        let result = manager.execute(
            EmvPaymentAction::CompletePayment { result: emv_result }
        ).await;
        
        assert!(result.is_ok());
        
        // Deve receber evento de mudança de estado
        let event = timeout(Duration::from_secs(1), rx.recv()).await;
        assert!(event.is_ok());
        
        let event = event.unwrap().unwrap();
        assert_eq!(event.from_state, StateType::EMVPayment);
        assert_eq!(event.to_state, StateType::PaymentSuccess);
        
        // Verifica estado após todas as operações
        assert_eq!(manager.get_current_state_type().await, StateType::PaymentSuccess);
    }

    #[tokio::test]
    async fn test_cancel_payment_returns_to_awaiting_info() {
        let (manager, mut rx) = create_emv_payment_manager(100.0, PaymentType::Debit);
        
        let result = manager.execute(
            EmvPaymentAction::CancelPayment
        ).await;
        
        assert!(result.is_ok());
        
        // Deve receber evento de mudança de estado
        let event = timeout(Duration::from_secs(1), rx.recv()).await;
        assert!(event.is_ok());
        
        let event = event.unwrap().unwrap();
        assert_eq!(event.from_state, StateType::EMVPayment);
        assert_eq!(event.to_state, StateType::AwaitingInfo);
        
        // Verifica estado após todas as operações
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
    }

    // ==================== TESTES DE FLUXO COMPLETO ====================

    #[tokio::test]
    async fn test_full_payment_flow() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        // Passo 1: Define valor
        manager.execute(
            AwaitingInfoAction::SetAmount { amount: 250.0 }
        ).await.unwrap();
        
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
        
        // Passo 2: Define tipo de pagamento
        manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Credit }
        ).await.unwrap();
        
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
        
        // Passo 3: Confirma informações -> transiciona para EMVPayment
        manager.execute(
            AwaitingInfoAction::ConfirmInfo
        ).await.unwrap();
        
        assert_eq!(manager.get_current_state_type().await, StateType::EMVPayment);
        
        // Verifica evento
        let event1 = rx.recv().await.unwrap();
        assert_eq!(event1.to_state, StateType::EMVPayment);
        
        // Passo 4: Inicia processamento
        manager.execute(
            EmvPaymentAction::ProcessPayment
        ).await.unwrap();
        
        assert_eq!(manager.get_current_state_type().await, StateType::EMVPayment);
        
        // Passo 5: Completa pagamento -> transiciona para PaymentSuccess
        let emv_result = EmvResult {
            transaction_id: "TXN789".to_string(),
            authorization_code: "AUTH012".to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
        };
        
        manager.execute(
            EmvPaymentAction::CompletePayment { result: emv_result }
        ).await.unwrap();
        
        assert_eq!(manager.get_current_state_type().await, StateType::PaymentSuccess);
        
        // Verifica evento
        let event2 = rx.recv().await.unwrap();
        assert_eq!(event2.to_state, StateType::PaymentSuccess);
    }

    // ==================== TESTES DE GET_DESCRIPTION ====================

    #[tokio::test]
    async fn test_get_description_for_awaiting_info() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        let description = manager.get_description::<AwaitingInfo, _>(
            |state| state.description()
        ).await;
        
        assert!(description.is_ok());
        assert!(description.unwrap().contains("Aguardando informações"));
    }

    #[tokio::test]
    async fn test_get_description_after_setting_values() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Define valores
        manager.execute(
            AwaitingInfoAction::SetAmount { amount: 99.99 }
        ).await.unwrap();
        
        manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Debit }
        ).await.unwrap();
        
        let description = manager.get_description::<AwaitingInfo, _>(
            |state| state.description()
        ).await.unwrap();
        
        assert!(description.contains("99.99"));
        assert!(description.contains("Debit"));
    }

    #[tokio::test]
    async fn test_get_description_for_emv_payment() {
        let (manager, _rx) = create_emv_payment_manager(150.0, PaymentType::Credit);
        
        let description = manager.get_description::<EMVPayment, _>(
            |state| state.description()
        ).await.unwrap();
        
        assert!(description.contains("150.00"));
    }

    // ==================== TESTES DE ERRO DE TIPO ====================

    #[tokio::test]
    async fn test_wrong_state_type_returns_error() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Tenta executar ação de EMVPayment no estado AwaitingInfo
        let result = manager.execute(
            EmvPaymentAction::ProcessPayment
        ).await;
        
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("incompatível"));
    }

    #[tokio::test]
    async fn test_wrong_description_type_returns_error() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Tenta obter descrição como se fosse EMVPayment
        let result = manager.get_description::<EMVPayment, _>(
            |state| state.description()
        ).await;
        
        assert!(result.is_err());
    }

    // ==================== TESTES DE CONCORRÊNCIA ====================

    #[tokio::test]
    async fn test_concurrent_state_reads() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Cria múltiplas tarefas lendo o estado
        let handles: Vec<_> = (0..10).map(|_| {
            let manager_clone = manager.clone();
            tokio::spawn(async move {
                manager_clone.get_current_state_type().await
            })
        }).collect();
        
        // Todas devem retornar o mesmo estado
        for handle in handles {
            let state_type = handle.await.unwrap();
            assert_eq!(state_type, StateType::AwaitingInfo);
        }
    }

    #[tokio::test]
    async fn test_sequential_actions_maintain_consistency() {
        let (manager, _rx) = create_awaiting_info_manager();
        
        // Sequência de ações
        for i in 1..=5 {
            let result = manager.execute(
                AwaitingInfoAction::SetAmount { amount: (i * 10) as f64 }
            ).await;
            
            assert!(result.is_ok());
        }
        
        assert_eq!(manager.get_current_state_type().await, StateType::AwaitingInfo);
    }

    // ==================== TESTES DE EVENTOS ====================

    #[tokio::test]
    async fn test_event_contains_timestamp() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        // Configura e confirma para gerar transição
        manager.execute(
            AwaitingInfoAction::SetAmount { amount: 100.0 }
        ).await.unwrap();
        
        manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Credit }
        ).await.unwrap();
        
        manager.execute(
            AwaitingInfoAction::ConfirmInfo
        ).await.unwrap();
        
        let event = rx.recv().await.unwrap();
        assert!(!event.timestamp.is_empty());
        
        // Verifica se o timestamp é válido (formato RFC3339)
        assert!(chrono::DateTime::parse_from_rfc3339(&event.timestamp).is_ok());
    }

    #[tokio::test]
    async fn test_multiple_transitions_generate_multiple_events() {
        let (manager, mut rx) = create_awaiting_info_manager();
        
        // Transição 1: AwaitingInfo -> EMVPayment
        manager.execute(
            AwaitingInfoAction::SetAmount { amount: 100.0 }
        ).await.unwrap();
        
        manager.execute(
            AwaitingInfoAction::SetPaymentType { payment_type: PaymentType::Credit }
        ).await.unwrap();
        
        manager.execute(
            AwaitingInfoAction::ConfirmInfo
        ).await.unwrap();
        
        let event1 = rx.recv().await.unwrap();
        assert_eq!(event1.from_state, StateType::AwaitingInfo);
        assert_eq!(event1.to_state, StateType::EMVPayment);
        
        // Transição 2: EMVPayment -> AwaitingInfo (cancelamento)
        manager.execute(
            EmvPaymentAction::CancelPayment
        ).await.unwrap();
        
        let event2 = rx.recv().await.unwrap();
        assert_eq!(event2.from_state, StateType::EMVPayment);
        assert_eq!(event2.to_state, StateType::AwaitingInfo);
    }
}
