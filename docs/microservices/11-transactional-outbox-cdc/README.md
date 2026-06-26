# Desafio 23: Transactional Outbox com CDC (`algo-transactional-outbox-cdc`)
> **Padrões de Arquitetura Distribuída:** Transactional Outbox (Consistência Dual), Change Data Capture - CDC (Tailing de Logs), At-Least-Once Delivery (Garantia de Entrega).

## 1. Contexto & Cenário
Em arquiteturas de microsserviços orientadas a eventos (Event-Driven), um dos maiores desafios é garantir a consistência entre o banco de dados interno de um serviço e as mensagens publicadas para outros serviços através de um message broker (ex: Kafka ou RabbitMQ).

Considere um fluxo de faturamento. Quando o `Payment Service` processa um pagamento com sucesso, ele precisa realizar duas ações:
1. Atualizar o saldo da carteira no banco de dados local.
2. Publicar o evento `PaymentApproved` no Kafka para liberar a entrega do produto.

Realizar uma escrita direta ("dual-write") na aplicação é uma receita para inconsistência:
```csharp
// Exemplo de bug clássico:
await db.SavePaymentAsync(payment); // Sucesso
await kafka.PublishAsync("PaymentApproved", eventPayload); // Se a rede cair aqui, o pagamento foi feito mas o produto nunca é entregue!
```
Tentar inverter a ordem ou encapsular a chamada de rede em uma transação de banco de dados bloqueia conexões do pool do banco durante tempos de resposta da rede, degradando a performance drasticamente.

Para resolver este problema de consistência sem transações distribuídas lentas (como 2-Phase Commit), adotamos o padrão **Transactional Outbox** em conjunto com **CDC (Change Data Capture)**. A aplicação atualiza o estado local e insere um registro em uma tabela temporária de `outbox` na mesma transação atômica local. Uma ferramenta de CDC lê o log de transações do banco de dados (WAL) em background e publica o evento no Kafka de forma assíncrona, garantindo entrega at-least-once com impacto zero na latência do banco.

---

## 2. Requisitos Funcionais (RF)
- **Escrita Atômica na Transação**: Expor uma API de gravação que execute na mesma transação local:
  - Inserção de dados do pagamento na tabela `payments`.
  - Inserção do evento bruto na tabela `outbox`.
- **Change Data Capture (CDC)**: Implementar ou desenhar o motor de leitura que monitore a tabela `outbox` sem realizar consultas destrutivas do tipo `SELECT ... DELETE`. O motor deve tailar o log de transações física (WAL/binlog).
- **Envio Confiável (Delivery)**: Publicar a mensagem no Kafka e marcar o registro outbox correspondente como processado.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Garantia de Entrega At-Least-Once**: Assegurar que nenhum evento seja perdido, mesmo que o pod da aplicação, o banco de dados ou o broker de mensageria sofram crashes no meio do processo.
- **Overhead da Transação Sub-Milissegundo**: A inserção na tabela `outbox` deve ser ultraveloz (um insert simples indexado), adicionando menos de 1ms ao tempo total da transação de banco de dados do checkout.
- **Latência de Propagação do Evento**: O atraso entre o COMMIT da transação local no banco e a chegada da mensagem no Kafka deve ser inferior a 50ms no P99.
- **Deduplicação e Ordem**: Garantir que as mensagens de um mesmo stream (ex: mesmo usuário) sejam enviadas ao Kafka na ordem exata em que foram gravadas no banco de dados.

---

## 4. Guia de Implementação & Padrões

### Fluxo de Escrita Atômica e Captura Assíncrona
```
┌────────────────────────────────────────────────────────┐
│                   Payment Service                      │
│                                                        │
│  1. Inicia Transação Local (PostgreSQL)                │
│  2. INSERT INTO paymentsState (...)                    │
│  3. INSERT INTO outboxEvents (eventPayload)            │
│  4. COMMIT TRANSACTION                                 │
└──────────────────────────┬─────────────────────────────┘
                           │
             (Persiste Dados + Tabela Outbox)
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│           Write-Ahead Log (WAL) do Postgres            │
└──────────────────────────┬─────────────────────────────┘
                           │
                 (CDC monitora o WAL)
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│                CDC Connector (Debezium)                │
│ (Lê o WAL em background, extrai os inserts da outbox)  │
└──────────────────────────┬─────────────────────────────┘
                           │
                (Publica assincronamente)
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│                     Kafka Broker                       │
└────────────────────────────────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Tabela Outbox Dedicada**:
  - `event_id`: UUID (Chave primária).
  - `aggregate_type`: String (Ex: `Payment`).
  - `aggregate_id`: String (Ex: `payment_123`).
  - `event_type`: String (Ex: `PaymentApproved`).
  - `payload`: JSONB (Dados do evento).
  - `created_at`: Timestamp.
- **Leitura baseada em Log (Log-based CDC - Recomendada)**: Evitar fazer polling na tabela usando timers com query `SELECT * FROM outbox`. Em vez disso, utilizar ferramentas como **Debezium** ou tailers nativos (ex: replicação lógica do PostgreSQL/PgOutput) que decodificam o WAL em tempo real. Isso evita locks de leitura, índices fragmentados e consumo inútil de IOPS do banco de dados.
- **At-Least-Once Sem Duplicidade na Borda**: O CDC garante at-least-once (em caso de crash do Debezium, a última mensagem pode ser reenviada). Os consumidores downstream devem usar chaves de idempotência lógicas baseadas no `event_id` recebido no envelope para garantir processamento idempotente.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Eliminação Absoluta de Dual-Writes na Camada de Aplicação**: Zero código chamando biblioteca de mensageria dentro das rotinas HTTP de checkout.
- **Tratamento de Indisponibilidade do Broker**: Prova de resiliência caso o Kafka caia no momento em que o Debezium tenta entregar. O fluxo de commits no PostgreSQL principal não deve ser bloqueado nem sofrer timeouts; os eventos simplesmente se acumulam no log binário até a mensageria se restabelecer.
- **Escrita Otimizada**: Uso adequado de tipos de dados eficientes (ex: JSONB compactado) para evitar sobrecarregar o tráfego de gravação de logs de transação físicos do disco (Write Amplification).
- **Limpeza do Outbox**: Estratégia de purga física automática da tabela `outbox` se não for utilizado log tailing puro (se a engine for baseada em query fallback).

---

## 6. Trade-offs

### A. CDC baseada em Log (Tailing) vs. CDC baseada em Polling (Query)
- **CDC baseada em Log (Recomendado)**:
  - *Pró*: Performance máxima; não consome IOPS com selects repetitivos; captura alterações mesmo se feitas por scripts diretos no banco de dados.
  - *Contra*: Alta complexidade operacional de configuração de infraestrutura (requer drivers de replicação lógica, configurações especiais do WAL e infraestrutura Debezium/Kafka Connect).
- **CDC baseada em Polling (SELECT em loop na tabela com thread local)**:
  - *Pró*: Simples de implementar em código puro de aplicação usando uma tarefa Scheduler em background.
  - *Contra*: Causa grande overhead de escrita/leitura e locks concorrentes na tabela; pode perder estados intermediários rápidos caso a linha seja atualizada múltiplas vezes antes do polling ler.

### B. Serialização do Evento no Transaction Path vs. Out-of-band Serialization
- **Serializar na Aplicação (Inserir JSON montado na outbox - Recomendado)**:
  - *Pró*: Garante que as mensagens de eventos estejam perfeitamente alinhadas com as regras de negócio em execução no código daquela versão.
  - *Contra*: O processo de serialização de JSON grande na thread HTTP principal gasta alguns microssegundos a mais de CPU.
- **Serializar no CDC (Decodificar linhas de tabelas de negócio diretamente no WAL)**:
  - *Pró*: Sem tabela outbox; menor consumo de espaço em disco no banco.
  - *Contra*: Acopla o esquema físico interno do banco com a API pública de eventos que terceiros consomem. Se você renomear uma coluna do banco local, quebra silenciosamente os consumidores externos.
