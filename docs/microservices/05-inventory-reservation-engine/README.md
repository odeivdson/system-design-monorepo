# Desafio 5: Motor de Reserva Temporária de Inventário de Alta Concorrência (`inventory-reservation-engine`)
> **Padrões de Microsserviços Associados:** Polyglot Persistence (Redis de baixa latência + DB relacional durável), Event Sourcing (Log de transações imutável), CQRS (Separação do modelo de reserva em memória e escrita persistente).

## 1. Contexto & Cenário
Em eventos de vendas massivos, lançamentos de produtos limitados (como ingressos para shows internacionais ou ofertas "relâmpago" no Mercado Livre), centenas de milhares de requisições de compra concorrentes atingem o inventário simultaneamente. Em um modelo transacional tradicional, cada tentativa de compra dispara uma transação SQL que bloqueia a linha do produto (`SELECT ... FOR UPDATE`).
Esta abordagem resulta em contenção massiva de travas no banco de dados, pools de conexões esgotados, estouro de latência e, eventualmente, queda total do sistema. 

Para resolver este gargalo, este desafio propõe o design de um **Motor de Reserva Temporária de Inventário** de altíssima performance. O sistema deve desacoplar a garantia imediata de estoque (em memória) do processo lento de escrita persistente no banco de dados, garantindo consistência eventual controlada e zero "overselling" (venda de mais itens do que o disponível).

---

## 2. Requisitos Funcionais (RF)
- **Criação de Reserva Temporária**: Reservar uma quantidade de itens de um produto para um usuário por uma janela de tempo específica (ex: 10 minutos).
- **Confirmação Instantânea**: Confirmar ou rejeitar (com resposta de "sem estoque") a solicitação de reserva em tempo de execução sub-milissegundo.
- **Liberação Automática por Expiração**: Se o pagamento não for confirmado dentro da janela estipulada, os itens reservados devem retornar ao estoque disponível automaticamente.
- **Consolidação em Lote (Durable Persistence)**: Sincronizar de forma cadenciada (eventual) as baixas definitivas de estoque confirmadas no banco de dados relacional oficial.
- **Cancelamento Manual**: Permitir a devolução explícita imediata de itens ao inventário se o usuário cancelar o carrinho voluntariamente.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Throughput Extremo**: Suportar picos de carga de mais de 50.000 RPS para operações de reserva e consulta de inventário.
- **Latência Ultra Baixa**: Tempo de resposta de reserva inferior a 5ms no percentil P99 na borda da aplicação.
- **Consistência Estrita em Memória**: Garantia matemática de zero overselling. Sob concorrência severa (ex: 10 itens disponíveis e 100.000 requisições simultâneas), exatamente 10 reservas válidas devem ser geradas.
- **Consistência Eventual Segura**: O banco de dados relacional durável deve ser sincronizado de forma assíncrona, tolerando atrasos (lag) na fila sem corromper o estado real do inventário.
- **Tolerância a Falhas do Cache (Resiliência)**: Em caso de reboot do cluster Redis, o estado do inventário deve ser reconstruído a partir do banco durável sem gerar inconsistências ou duplicar reservas que já estavam pagas.

---

## 4. Guia de Implementação & Padrões
O motor utiliza uma arquitetura baseada no padrão **Write-Behind (Write-Back) Cache** operando em memória, combinado com mensageria assíncrona para sincronização durável.

```
                  [ Cliente ]
                       │
                       ▼ (POST /reservations)
┌─────────────────────────────────────────────────────────┐
│               Inventory Engine Service                  │
│                                                         │
│  - Executa Script Lua no Redis (Atomic Decr & Check)    │
│  - Se Estoque >= Qtd: decrementa e gera ID de reserva   │
│  - Se Estoque < Qtd: falha imediata (Out of Stock)      │
└──────────────────────────┬──────────────────────────────┘
                           │ (Reserva Concluída em Memória)
                           ├──────────────────────────────┐
                           ▼ (Retorna HTTP 201)           ▼ (Fila de Integração)
                     [ Cliente ]                     [ Kafka Topic: Reservations ]
                                                                  │
                                                                  ▼
                                                     ┌─────────────────────────┐
                                                     │    Sync Consumer        │
                                                     │  (Batch updates to DB)  │
                                                     └────────────┬────────────┘
                                                                  │
                                                                  ▼
                                                     ┌─────────────────────────┐
                                                     │  Relational Database    │
                                                     │   (Durable Inventory)   │
                                                     └─────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Operações Atômicas via Redis Lua Scripts**: Toda a lógica de decréscimo de estoque e criação do registro de reserva pendente deve ser implementada em um único script Lua (`EVALSHA`). O Redis executa o script de forma single-threaded e atômica, evitando race conditions comuns de leitura-e-atualização (Read-Modify-Write).
- **Expiração via Redis TTL (Time-To-Live)**: Utilizar chaves temporárias do Redis para representar as reservas individuais do usuário (ex: `inventory:reserve:{product_id}:{user_id}` com TTL de 600 segundos).
- **Redis Keyspace Notifications (Event Loop)**: Assinar eventos de expiração de chave (`__keyevent@0__:expired`) para disparar workers assíncronos que reincrementam o estoque do produto de forma atômica no banco relacional e no Redis, caso a reserva expire sem ser paga.
- **Outbox Pattern e Kafka / RabbitMQ**: Enviar os eventos de confirmação de pagamento para um barramento de mensageria assíncrona para consolidação de estoque no banco de dados via consumo em lotes (batch ingestion).
- **Idempotência no Consumidor**: Garantir que o processo que consolida a baixa no banco de dados seja idempotente por meio do ID da transação.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Garantia Antiexcesso (Overselling)**: Demonstração analítica e via testes de estresse de que a barreira de limite de estoque nunca é ultrapassada em concorrência extrema.
- **Estratégia de Recuperação pós-Disastre (Reconciliation Loop)**: Como o sistema reconstrói o cache de inventário no Redis após uma queda abrupta sem perder as reservas pendentes em curso. Um validador (reconciliation worker) que sincroniza de tempos em tempos `DB + Mensagens Pendentes -> Cache` é esperado.
- **Minimização de Escritas no Banco de Dados (Batching)**: O mecanismo de consolidação não deve fazer uma escrita por transação. Ele deve agrupar as baixas em queries de atualização em massa (`UPDATE inventory SET stock = stock - X WHERE id = Y`), reduzindo drasticamente o overhead no banco de dados.
- **Tratamento de Redis Cluster Partitioning**: Como lidar com partições do Redis (split-brain) no cluster utilizando algoritmos de quorum ou persistência transacional local como fallback temporário.

---

## 6. Trade-offs

### A. Consistência Imediata vs. Consistência Eventual
- **Consistência Imediata (DB Locks)**: Garante consistência perfeita a qualquer momento, mas limita o throughput do sistema à capacidade IOPS do banco (tipicamente poucas centenas de requisições por segundo por linha de produto).
- **Consistência Eventual (Redis Lua + Queue - Recomendada)**: Destrava escalabilidade ilimitada (50k+ RPS), mas introduz a complexidade de gerenciar a divergência de estados entre o cache e o banco de dados até a sincronização.

### B. Gestão de Expiração: Redis TTL vs. Agendador (Scheduler)
- Utilizar Redis TTL com notificações keyspace é extremamente simples, mas o Redis garante apenas a expiração da chave, não o momento exato de sua remoção em memória, o que pode atrasar a reincorporação de estoque sob alta carga de memória. Um agendador persistente (ex: Quartz, temporal.io) garante confiabilidade regulatória, a custo de complexidade operacional de infraestrutura adicional.

### C. Redução de Consumo de Rede: Script Lua vs. Transações Redis (MULTI/EXEC)
- Transações Redis (`MULTI/EXEC/WATCH`) dependem de optimistic concurrency control (OCC). Se houver colisão extrema na mesma chave (estoque de produto quente), a maioria das transações falhará e exigirá retentativas no cliente, aumentando o tráfego de rede. Scripts Lua executam de forma totalmente determinística e bloqueante rápida dentro do Redis, eliminando retentativas no lado do cliente.