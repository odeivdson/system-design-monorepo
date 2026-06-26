# Desafio 6: Despachante Resiliente de Webhooks (`webhook-dispatcher`)
> **Padrões de Microsserviços Associados:** Circuit Breaker (Isolamento de Falhas), Bulkhead (Isolamento de Filas por Cliente), Retry (Backoff com Jitter), Async Messaging (Comunicação Assíncrona).

## 1. Contexto & Cenário
Em ecossistemas SaaS integrados e plataformas financeiras (como Stripe, GitHub ou Pagar.me), a notificação assíncrona de eventos via Webhooks é o padrão de mercado para integração entre sistemas. No entanto, enviar requisições HTTP para servidores de terceiros é inerentemente caótico. As APIs dos parceiros podem estar instáveis, sofrer com timeouts severos, retornar erros `5xx` ou mesmo estar totalmente fora do ar por longos períodos.

Se o seu despachante de webhooks processar envios em uma única fila global sequencial, um único cliente parceiro lento ou inativo causará um efeito cascata de lentidão que atolará a fila inteira. Isso é conhecido como **Head-of-Line Blocking (HoL)**, impedindo que notificações de clientes saudáveis sejam entregues a tempo. O objetivo deste desafio é construir um motor de entrega de webhooks resiliente, isolado, de alta taxa de transferência, que implemente retentativas inteligentes com backoff e disjuntores de circuito (Circuit Breakers) customizados por assinante.

---

## 2. Requisitos Funcionais (RF)
- **Despacho Assíncrono de Eventos**: Ler mensagens de eventos internos de negócios e colocá-las em uma fila persistente para entrega externa via HTTP POST.
- **Políticas de Retentativa com Backoff e Jitter**: Em caso de falhas de rede ou HTTP `429/5xx`, retentar o envio respeitando um tempo de espera que cresce exponencialmente, acrescido de uma variação aleatória (jitter) para evitar o "efeito manada" nos servidores de destino.
- **Circuit Breaker por Assinante**: Monitorar taxas de erros por URL de destino (ou assinante). Se um destino falhar repetidamente além de um limiar tolerável, o circuito correspondente a este assinante deve ser aberto.
- **Roteamento para Dead Letter Queue (DLQ)**: Mensagens destinadas a assinantes com circuito aberto ou que atingiram o limite máximo de retentativas devem ser desviadas para uma fila de DLQ para análise manual ou expiração.
- **Assinatura de Segurança**: Cada webhook disparado deve incluir uma assinatura digital criptográfica (ex: HMAC-SHA256 no cabeçalho `X-Hub-Signature-256`) baseada em uma chave secreta compartilhada com o parceiro para garantir a autenticidade e integridade da mensagem.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Isolamento de Falhas Dinâmico**: O atraso ou queda completa de uma URL de parceiro X não pode atrasar em mais de 100ms a entrega de notificações para o parceiro saudável Y.
- **Throughput e Escala**: Ser capaz de disparar mais de 20.000 webhooks por segundo.
- **Garantia de Entrega (At-Least-Once)**: Garantia absoluta de que nenhuma notificação legítima de webhook seja perdida antes de expirar o limite máximo de retentativas.
- **Controle de Concorrência de Saída**: O dispatcher deve limitar a concorrência de requisições de saída por assinante para evitar atuar como um ataque de negação de serviço distribuído (DDoS) involuntário contra os servidores dos próprios parceiros.
- **Monitoramento e Observabilidade**: Latência de rede externa monitorada em tempo real, fornecendo métricas de taxa de sucesso/falha por tenant para abertura proativa de circuitos.

---

## 4. Guia de Implementação & Padrões
O design proposto se baseia no padrão **Transactional Outbox** para captura confiável de eventos da base de dados, associado a um processador baseado em **Worker Pools com Filas Virtuais (Rate Limiter por Tenant)**.

```
┌─────────────────────────────────┐
│        Banco de Dados           │
│  (Tabela Outbox: Eventos Salvos)│
└────────────────┬────────────────┘
                 │
                 ▼ (Outbox Poller / Debezium CDC)
┌─────────────────────────────────┐
│     Queue / Broker (Kafka/RMQ)  │
└────────────────┬────────────────┘
                 │
                 ▼ (Webhook Dispatcher Worker Pool)
 ┌────────────────────────────────────────────────────────┐
 │   Isolamento e Controle de Fluxo por Assinante         │
 │                                                        │
 │ 1. Verifica estado do Circuit Breaker no Redis         │
 │    - Fechado: segue processamento                      │
 │    - Aberto: desvia direto para DLQ                    │
 │ 2. Limita taxa de saída (Token Bucket / Rate Limiter)  │
 └───────────────┬────────────────────────────────────────┘
                 │
                 ▼ (Async HTTP Client Exec)
       ┌───────────────────┐
       │   Parceiro API    │ (HTTP POST com Assinatura HMAC)
       └───────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Transactional Outbox Pattern**: Evita problemas de escrita em duas fases. A gravação do evento no banco é feita na mesma transação de negócios da aplicação. Um processo secundário lê e despacha para a fila de webhooks.
- **Circuit Breaker Distribuído via Redis**: Manter o contador de sucessos/falhas e o estado do circuito (CLOSED, OPEN, HALF-OPEN) no Redis para garantir consistência em ambientes horizontais (múltiplas instâncias do despachante).
- **Algoritmo Full Jitter para Backoff**:
  ```
  t_sleep = random(0, min(cap, base * 2^attempt))
  ```
  Isso espalha perfeitamente a carga de retentativas de forma uniforme no tempo.
- **Queue Partitioning (Sharding de Filas)**: Usar tópicos do Kafka com chaves de partição baseadas no `tenant_id` ou `subscriber_id`. Isso garante ordem de eventos para o mesmo cliente e permite que partições não afetadas continuem operando a taxas máximas de throughput.
- **Client HTTP Não Bloqueante (Async I/O)**: Evitar alocação de threads físicas por conexão HTTP de saída. Utilizar I/O assíncrono puro (ex: `HttpClient` com `Task` em C#, `CompletableFuture` em Java ou `libuv` no Node.js/Go) para manter o consumo de memória estável sob milhares de requisições de saída simultâneas.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Mitigação Prática de HoL (Head-of-Line) Blocking**: Demonstração de como filas entupidas por um cliente instável são isoladas rapidamente sem degradar a vazão geral.
- **Segurança Criptográfica**: Implementação robusta de cálculo de assinaturas digitais na borda para mitigar ataques de spoofing/replay nos clientes.
- **Gestão Eficiente de Pooling de Conexões**: Reuso apropriado de conexões HTTP (Connection Pooling) para evitar esgotamento de portas efêmeras (socket exhaustion) na infraestrutura local do despachante.
- **Processo de Transição do Circuit Breaker (Half-Open)**: Como o sistema testa de forma controlada (canary probing) a reativação de um assinante outrora doente antes de fechar o circuito novamente.

---

## 6. Trade-offs

### A. Filas Dedicadas por Cliente vs. Fila Compartilhada com Sharding
- **Filas Dedicadas (Uma fila por parceiro)**:
  - *Pró*: Isolamento perfeito. Se um parceiro quebrar, apenas sua fila cresce.
  - *Contra*: Complexidade operacional de gerenciar dinamicamente milhares de filas no broker.
- **Fila Única com Partiçoes Dinâmicas (Kafka / Recomendada)**:
  - *Pró*: Simplicidade de infraestrutura.
  - *Contra*: Particionamento estático pode gerar desequilíbrio de carga se um único parceiro enviar um volume desproporcional de eventos.

### B. At-Least-Once vs. At-Most-Once
- **At-Least-Once (Recomendada)**: Garante que toda notificação seja recebida, mas exige que a API cliente seja idempotente devido à possibilidade de envios repetidos por falha na recepção do ACK.
- **At-Most-Once**: Envia a notificação apenas uma vez e ignora falhas.
  - *Pró*: Latência mínima, sem necessidade de filas de retentativa ou estado.
  - *Contra*: Perda inaceitável de dados para sistemas de pagamento ou integridade de dados comerciais.

### C. Circuit Breaker Centralizado (Redis) vs. Local (In-Memory do Worker)
- **Centralizado**: Garante que o circuito abra uniformemente para todas as instâncias do dispatcher imediatamente. Aumenta a latência em rede por conta das chamadas constantes ao Redis.
- **Local (In-Memory)**: Extremamente rápido e sem dependência de rede, mas pode fazer com que algumas instâncias continuem martelando a API parceira enquanto outras já abriram o circuito localmente.