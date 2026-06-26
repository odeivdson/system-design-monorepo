# Desafio 4: Padrão Saga Baseado em Eventos (`event-driven-saga-pattern`)
> **Padrões de Microsserviços Associados:** Saga Pattern (Orquestrado/Coreografado), Event Sourcing, CQRS (Segregação de Leitura/Escrita), Database per Service (Autonomia), Async Messaging (Desacoplamento Temporal), Smart Endpoints, Dumb Pipes.

## 1. Contexto & Cenário
Em uma arquitetura monolítica tradicional, manter a consistência de dados em um fluxo de checkout de e-commerce (envolvendo criação de pedido, reserva de estoque e débito de saldo) é simples: basta encapsular todas as operações em uma única transação de banco de dados ACID local. No entanto, em microsserviços rodando sobre o padrão **Database per Service**, cada microsserviço possui seu próprio banco de dados isolado. Não existe a possibilidade de realizar um commit de duas fases (2PC) sem asfixiar a escalabilidade, aumentar a latência e criar dependências temporais rígidas de rede.

Se o serviço de Pagamento falhar após o estoque já ter sido reservado pelo serviço de Inventário, o sistema entrará em estado inconsistente (itens presos no estoque indefinidamente). Para resolver transações distribuídas de longo prazo sem travamento de recursos, utilizamos o **Padrão Saga**. Uma Saga é uma sequência de transações locais, onde cada transação local atualiza o banco de dados e publica um evento. Se uma etapa falhar, a Saga executa uma série de **transações compensatórias** para reverter as alterações anteriores, garantindo consistência eventual.

---

## 2. Requisitos Funcionais (RF)
- **Fluxo Feliz (Happy Path)**:
  1. O cliente cria um pedido (`OrderCreated`).
  2. O Inventário realiza a reserva temporária dos produtos (`InventoryReserved`).
  3. O Pagamento realiza a cobrança (`PaymentProcessed`).
  4. O Pedido é finalizado como aprovado (`OrderApproved`).
- **Fluxo de Compensação (Rollback Path)**:
  - Se o Pagamento falhar (saldo insuficiente, cartão expirado):
    1. O Pagamento publica `PaymentFailed`.
    2. O Inventário escuta a falha e libera os produtos reservados (`InventoryReleased`).
    3. O Pedido marca o status como cancelado (`OrderCancelled`).
- **Idempotência de Mensagens**: O processamento de eventos pelos consumidores deve ser estritamente idempotente (processar o mesmo evento de cobrança duas vezes não pode duplicar o débito).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Desacoplamento Temporal e Buffering**: O fluxo de comunicação deve ser 100% assíncrono apoiado por um Message Broker durável (ex: Kafka ou RabbitMQ). A indisponibilidade de um serviço (ex: Pagamento fora do ar) não pode travar o fluxo de reservas do Inventário.
- **Garantia de Entrega At-Least-Once**: Assegurar que nenhum evento de transição de estado seja perdido na rede.
- **Tratamento de Mensagens Tóxicas (Dead Letter Queue - DLQ)**: Se uma mensagem causar erros de sistema persistentes (ex: falha de desserialização), ela deve ser isolada em uma DLQ para análise manual, liberando a fila principal.
- **Rastreabilidade Distribuída**: Cada Saga iniciada deve carregar um `CorrelationID` único injetado nos headers de mensagens para viabilizar rastreamento fim-a-fim de fluxos em ambientes de logs distribuídos.

---

## 4. Guia de Implementação & Padrões
Existem duas abordagens clássicas para implementar o padrão Saga: **Coreografia** (descentralizada e reativa a eventos) e **Orquestração** (centralizada via um coordenador de estados). A escolha depende da complexidade do domínio.

### Diagrama de Saga Coreografada (Fluxo de Falha e Compensação)
```
[Order Service] ─── (OrderCreated) ───► [Inventory Service]
       │                                        │
 (OrderCancelled)                         (InventoryReserved)
       ▲                                        │
       │                                        ▼
[Order Service] ◄── (PaymentFailed) ◄── [Payment Service]
       │                                        │
       └───────────► [Inventory Service] ◄──────┘
                       (InventoryReleased)
```

### Padrões e Primitivas Recomendadas:
- **Transactional Outbox Pattern**: Evita o problema clássico onde o serviço atualiza seu banco de dados local com sucesso, mas falha ao enviar o evento de notificação para o broker. A escrita do estado no banco de dados e a inserção do evento na tabela `outbox` ocorrem na mesma transação ACID local. Um worker em background lê a tabela `outbox` e publica no Kafka de forma confiável.
- **Saga Orchestrator (Process Manager)**: Para fluxos complexos com mais de 4 etapas, utilize um orquestrador dedicado. O orquestrador centraliza uma máquina de estados persistente que gerencia o progresso, salvando o estado atual e disparando explicitamente as chamadas de compensação.
- **Idempotent Consumer**: Cada consumidor deve manter uma tabela de controle de mensagens processadas (`processed_events`). Antes de processar uma mensagem, verifica se o `EventID` já existe para evitar reprocessamento acidental.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Demonstração do Outbox Pattern**: Garantia de integridade dual (escrita e publicação atômica de eventos).
- **Consistência Eventual Sob Partição de Rede**: Como o sistema se recupera se o broker cair no meio de um rollback. O avaliador buscará rotinas de reconciliação de dados assíncronas periódicas (Outbox Pollers ou scripts de reconciliação automatizados).
- **Isolamento de Transações (Problema de Leitura Suja - Dirty Reads)**: Como a arquitetura lida com o fato de que um cliente pode tentar comprar um item que está reservado temporariamente por uma Saga em andamento que virá a falhar. O avaliador busca estratégias de "reserva pendente" que não bloqueiem o fluxo de navegação, mas garantam que itens não sejam vendidos duas vezes.
- **Design de Mensagens Idempotentes**: Uso adequado de chaves de idempotência lógicas baseadas no ID da entidade (ex: `order_id` + `saga_state_name`).

---

## 6. Trade-offs

### A. Coreografia vs. Orquestração
- **Coreografia (Recomendada para fluxos simples)**:
  - *Pró*: Altamente desacoplada, sem ponto único de gargalo/falha, fácil de adicionar novos consumidores reativos.
  - *Contra*: Difícil de visualizar o fluxo completo do sistema; alto risco de dependências cíclicas em ecossistemas de grande escala.
- **Orquestração (Recomendada para fluxos complexos)**:
  - *Pró*: Fluxo e regras de transição documentados em um único lugar (Process Manager); facilita a depuração e monitoramento.
  - *Contra*: O orquestrador se torna um SPOF complexo e centralizador de lógica de negócios.

### B. Consistência Eventual vs. Lock Síncrono (2PC)
- **Saga (Consistência Eventual)**:
  - *Pró*: Altíssimo throughput, serviços autônomos e tolerantes a partições de rede temporárias.
  - *Contra*: Complexidade de projeto massiva; dados podem ficar inconsistentes por milissegundos/segundos até que as transações locais se propaguem ou se compensem.
- **Commit de Duas Fases (2PC - Consistência Estrita)**:
  - *Pró*: Garantia ACID clássica simples de programar.
  - *Contra*: Péssima escalabilidade. Se um serviço na cadeia travar, todos os bancos envolvidos prendem locks de leitura/escrita, congelando o sistema global.