# Guia de Treinamento: Padrões de Arquitetura de Microsserviços e Big Techs

Este guia serve como a matriz de referência definitiva para treinar e compreender os padrões arquiteturais de microsserviços e sistemas distribuídos em escala de elite (Big Techs). Ele conecta cada conceito abstrato a desafios práticos de código e especificações arquiteturais presentes neste monorepo.

---

## 1. O Princípio de Treinamento de Elite
Na engenharia de software de alto nível (Staff/Principal), padrões não são apenas definições teóricas. Eles são avaliados a partir de:
* **Garantia de Consistência e Concorrência**: Como o padrão evita race conditions, double-writes e dados corrompidos.
* **Sobrevivência sob Falhas (Fault Tolerance)**: Como o padrão isola falhas para impedir que uma pane local paralise todo o sistema.
* **Trade-offs Reais de Infraestrutura**: Latência de rede extra vs. consistência de dados vs. complexidade operacional.

---

## 2. Matriz de Cobertura e Mapeamento: 19 Padrões Essenciais de Microsserviços

### 1. Service Registry
* **O Padrão no Artigo**: Banco de dados central contendo os endereços de rede das instâncias ativas dos microsserviços para viabilizar Service Discovery dinâmico.
* **Onde treinar no Monorepo**: [22-service-mesh-sidecar-proxy](../microservices/10-service-mesh-sidecar-proxy/README.md) e [10-algo-consistent-hashing-ring](../microservices/07-consistent-hashing-ring/README.md).
* **Foco Staff**: O proxy Sidecar descobre endpoints dinamicamente consultando o Service Registry central, realizando balanceamento de carga local (client-side load balancing) para distribuir requisições uniformemente.

### 2. API Gateway
* **O Padrão no Artigo**: Ponto de entrada único que filtra e distribui as requisições para o ecossistema de microsserviços interno.
* **Onde treinar no Monorepo**: [2-rate-limiter-distributed](../microservices/02-rate-limiter-distributed/README.md), [3-idempotent-billing](../microservices/03-idempotent-billing/README.md) e [20-bff-mobile-web-aggregator](../microservices/08-bff-mobile-web-aggregator/README.md).
* **Foco Staff**: O Gateway gerencia segurança, rate limiting distribuído e injeção de cabeçalhos de idempotência antes de repassar chamadas para serviços downstream.

### 3. Circuit Breaker
* **O Padrão no Artigo**: Interrupção temporária de chamadas a um serviço downstream instável para evitar esgotamento de recursos locais.
* **Onde treinar no Monorepo**: [6-webhook-dispatcher](../microservices/06-webhook-dispatcher/README.md).
* **Foco Staff**: Máquina de estados (`CLOSED`, `OPEN`, `HALF-OPEN`) para reavaliar a integridade de endpoints remotos sem sobrecarregá-los.

### 4. Bulkhead
* **O Padrão no Artigo**: Isolamento de recursos (pools de threads, conexões ou memória) para conter a propagação de falhas.
* **Onde treinar no Monorepo**: [6-webhook-dispatcher](../microservices/06-webhook-dispatcher/README.md) e [7-algo-threadsafe-lru-cache](../algorithms/01-threadsafe-lru-cache/README.md).
* **Foco Staff**: Alocação de filas/workers isolados por parceiro no Webhook Dispatcher e Lock Striping no LRU Cache.

### 5. Saga Pattern
* **O Padrão no Artigo**: Transações distribuídas de longo prazo com fluxos de compensação para reverter falhas.
* **Onde treinar no Monorepo**: [4-event-driven-saga-pattern](../microservices/04-event-driven-saga-pattern/README.md).
* **Foco Staff**: Orquestração vs. Coreografia, Outbox Pattern para atomicidade de banco/fila e manuseio de mensagens de rollback.

### 6. Event Sourcing
* **O Padrão no Artigo**: Persistência baseada em um log imutável de eventos de alteração em vez do estado atual.
* **Onde treinar no Monorepo**: [21-event-sourced-wallet](../microservices/09-event-sourced-wallet/README.md) e [5-inventory-reservation-engine](../microservices/05-inventory-reservation-engine/README.md).
* **Foco Staff**: Gravação append-only ultraveloz no Event Store, recuperação por replay e invalidação por Snapshots periódicos para manter tempos de lookup eficientes.

### 7. CQRS (Command Query Responsibility Segregation)
* **O Padrão no Artigo**: Segregação de canais, modelos e instâncias de banco de leitura e escrita.
* **Onde treinar no Monorepo**: [21-event-sourced-wallet](../microservices/09-event-sourced-wallet/README.md) e [5-inventory-reservation-engine](../microservices/05-inventory-reservation-engine/README.md).
* **Foco Staff**: Sincronização assíncrona entre o banco de escrita imutável e a projeção de leitura rápida (Redis/Read Replicas), tratando consistência eventual.

### 8. Data Sharding
* **O Padrão no Artigo**: Particionamento horizontal de bases de dados.
* **Onde treinar no Monorepo**: [10-algo-consistent-hashing-ring](../microservices/07-consistent-hashing-ring/README.md).
* **Foco Staff**: Uso de nós virtuais no anel de consistência para balancear de forma elástica a carga de dados nos servidores de partição.

### 9. Polyglot Persistence
* **O Padrão no Artigo**: Uso do banco de dados especializado ideal para cada serviço (relacional, texto, cache chave-valor).
* **Onde treinar no Monorepo**: [21-event-sourced-wallet](../microservices/09-event-sourced-wallet/README.md) e [3-idempotent-billing](../microservices/03-idempotent-billing/README.md).
* **Foco Staff**: Resolver o fluxo relacional transacional combinado com o cache lock Redis e tabelas de checkpoints de eventos.

### 10. Retry
* **O Padrão no Artigo**: Reprocessamento de chamadas instáveis transientes.
* **Onde treinar no Monorepo**: [6-webhook-dispatcher](../microservices/06-webhook-dispatcher/README.md).
* **Foco Staff**: Uso obrigatório de Exponential Backoff com Full Jitter para não asfixiar os servidores remotos.

### 12. Sidecar (Nota: Padrão 11 pulado na fonte original)
* **O Padrão no Artigo**: Co-alocação de processos auxiliares de infraestrutura (Envoy, filtros) no mesmo container/rede do app.
* **Onde treinar no Monorepo**: [22-service-mesh-sidecar-proxy](../microservices/10-service-mesh-sidecar-proxy/README.md).
* **Foco Staff**: Interceptação local de rede usando iptables e otimização de latência via IPC com Unix Domain Sockets (UDS).

### 13. BFF (Backends for Frontends)
* **O Padrão no Artigo**: Camada agregadora enxuta otimizada por tipo de canal cliente (Mobile vs Web).
* **Onde treinar no Monorepo**: [20-bff-mobile-web-aggregator](../microservices/08-bff-mobile-web-aggregator/README.md).
* **Foco Staff**: Paralelização assíncrona não-bloqueante de chamadas downstream e degradação suave com dados padrão em caso de timeout.

### 14. Shadow Deployment
* **O Padrão no Artigo**: Espelhamento e duplicação assíncrona de tráfego de produção para validar novas versões sem impacto.
* **Onde treinar no Monorepo**: [22-service-mesh-sidecar-proxy](../microservices/10-service-mesh-sidecar-proxy/README.md).
* **Foco Staff**: Envio assíncrono isolado de requisições de escrita clonadas, descartando respostas imediatamente e impedindo reflexos na requisição do usuário real.

### 15. Consumer-Driven Contracts
* **O Padrão no Artigo**: Testagem de contratos de integração a partir da ótica de consumo do serviço cliente.
* **Onde treinar no Monorepo**: [22-service-mesh-sidecar-proxy](../microservices/10-service-mesh-sidecar-proxy/README.md).
* **Foco Staff**: Validação rigorosa na borda via JSON Schema ou pactos (Pact) integrados ao ciclo de integração contínua (CI/CD).

### 16. Smart Endpoints, Dumb Pipes
* **O Padrão no Artigo**: Inteligência nos microsserviços locais e transporte puro pelos barramentos de rede (Kafka/RabbitMQ).
* **Onde treinar no Monorepo**: [4-event-driven-saga-pattern](../microservices/04-event-driven-saga-pattern/README.md) e [6-webhook-dispatcher](../microservices/06-webhook-dispatcher/README.md).
* **Foco Staff**: Evitar triggers lógicos pesados ou processamentos nos message brokers, garantindo consumo puro e assíncrono.

### 17. Database per Service
* **O Padrão no Artigo**: Autonomia estrita de banco de dados por serviço para garantir acoplamento zero.
* **Onde treinar no Monorepo**: [4-event-driven-saga-pattern](../microservices/04-event-driven-saga-pattern/README.md).
* **Foco Staff**: Lidar com JOINs de bases distintas via agregações sob demanda ou replicação de eventos.

### 18. Async Messaging
* **O Padrão no Artigo**: Comunicação assíncrona por mensagens, amortecendo picos de carga.
* **Onde treinar no Monorepo**: [6-webhook-dispatcher](../microservices/06-webhook-dispatcher/README.md) e [8-algo-log-batching-buffer](../algorithms/02-log-batching-buffer/README.md).
* **Foco Staff**: Controle de vazão concorrente (Backpressure) local nos consumidores para evitar asfixia do servidor.

### 19. Stateless Services
* **O Padrão no Artigo**: Design de aplicação desacoplado de estados locais em memória.
* **Onde treinar no Monorepo**: [2-rate-limiter-distributed](../microservices/02-rate-limiter-distributed/README.md) e [20-bff-mobile-web-aggregator](../microservices/08-bff-mobile-web-aggregator/README.md).
* **Foco Staff**: Facilidade de replicação e auto-scaling horizontal elástico, relegando o estado mutável a datastores distribuídos.

---

## 3. Matriz de Mapeamento: Padrões Avançados de Big Techs (ID 23 ao 27)

### 23. Transactional Outbox com CDC (Change Data Capture)
* **O Padrão**: Gravação atômica da mudança de estado e do evento associado sob a mesma transação ACID local, decodificado assincronamente através do log de transações físico do banco (WAL/binlog).
* **Onde treinar no Monorepo**: [23-algo-transactional-outbox-cdc](../microservices/11-transactional-outbox-cdc/README.md).
* **Foco Staff**: Eliminar "dual-writes" na camada de aplicação e lidar com publicação garantida *at-least-once* sob crashes parciais de rede ou de pods.

### 24. Single-Flight (Request Collapsing)
* **O Padrão**: Interceptação e colapso de requisições de leitura idênticas simultâneas em trânsito para resolver a expiração de caches massivos (mitigação de Cache Stampede / Thundering Herd).
* **Onde treinar no Monorepo**: [24-algo-singleflight-collapsing](../algorithms/13-singleflight-collapsing/README.md).
* **Foco Staff**: Sincronização concorrente livre de locks globais exclusivas no dicionário de promessas in-flight e gestão segura de erros transientes downstream.

### 25. Read-After-Write Consistency (Roteamento Dinâmico)
* **O Padrão**: Bypass temporário das réplicas de leitura direcionando consultas críticas para o nó primário (Master) após operações de gravação do próprio usuário da sessão.
* **Onde treinar no Monorepo**: [25-algo-read-after-write-routing](../microservices/12-read-after-write-routing/README.md).
* **Foco Staff**: Chaveamento dinâmico e thread-safe de pools de conexões e rastreamento de escrita via metadados de sessão HTTP (Cookies/LSN) sem sobrecarregar o nó primário.

### 26. Lock Distribuído com Fencing Tokens e Leases
* **O Padrão**: Aquisição de exclusão mútua através de prazos de expiração (Leases) e verificação de concorrência com tokens numéricos crescentes (Fencing Tokens) diretamente na persistência final do recurso.
* **Onde treinar no Monorepo**: [26-algo-fencing-token-locks](../algorithms/14-fencing-token-locks/README.md).
* **Foco Staff**: Evitar corrupção de dados por escritas cruzadas de workers retardados causados por pausas de Garbage Collection (Stop-The-World).

### 27. Controle de Fluxo e Backpressure em Streams
* **O Padrão**: Sinalização concorrente reativa entre threads produtoras e consumidoras para regular o fluxo de dados em buffers delimitados (Bounded Buffers), prevenindo falhas de falta de memória (OOM).
* **Onde treinar no Monorepo**: [27-algo-stream-backpressure-buffer](../algorithms/15-stream-backpressure-buffer/README.md).
* **Foco Staff**: Bloqueio e retomada eficiente de CPU com sincronizadores nativos de kernel (Watermarks lógicas) e trade-offs de descarte.

### 28. Migração de Dados Live Sem Downtime
* **O Padrão**: Migração gradativa e estruturada de banco de dados crítico ativo em 4 fases (Dual-Write, Backfill Histórico, Reconciliação Contínua e Cutover) sem indisponibilidade.
* **Onde treinar no Monorepo**: [13-live-data-migration](./13-live-data-migration/README.md).
* **Foco Staff**: Prevenção de sobrescritas fora de ordem via verificação de versões e timestamps, além do isolamento estrito de indisponibilidade da nova base na escrita da aplicação.

### 29. Isolamento Multi-Tenant (Fair-Share Scheduling)
* **O Padrão**: Bufferização e escalonamento justo de requisições de entrada por Tenant para proteger o sistema e mitigar o efeito "Noisy Neighbor".
* **Onde treinar no Monorepo**: [14-multitenant-fairshare-scheduler](./14-multitenant-fairshare-scheduler/README.md).
* **Foco Staff**: Algoritmos de agendamento de deficit circular (ex: Deficit Round Robin) em complexidade $O(1)$ amortizado e Fail Fast por estouro de fila limite local por tenant.

### 30. Consistência de Cache Híbrido (L1/L2 com Pub/Sub)
* **O Padrão**: Notificação e invalidação ativa de caches L1 locais na memória RAM das réplicas via eventos disparados por canais Pub/Sub centralizados (L2/Redis).
* **Onde treinar no Monorepo**: [15-hybrid-cache-sync](./15-hybrid-cache-sync/README.md).
* **Foco Staff**: Neutralização de condições de corrida em que leituras antigas lentas de banco de dados sobrescrevem invalidações de cache recentes, e estratégias de failover sob queda do Pub/Sub.

### 31. Transações Distribuídas com Try-Confirm-Cancel (TCC)
* **O Padrão**: Consistência lógica em duas fases na camada de negócio, realizando reservas temporárias de recursos (Try) que são consolidadas (Confirm) ou estornadas (Cancel) sem locks físicos na persistência.
* **Onde treinar no Monorepo**: [16-distributed-tcc-transaction](./16-distributed-tcc-transaction/README.md).
* **Foco Staff**: Resolução de inversão de chamadas de cancelamento (Cancel-Before-Try), idempotência total das ações de participantes e gerenciamento de expiração de leases de reserva.

### 32. Gateway de Integração com Throttling e Outbox (APIs Governamentais/Dataprev)
* **O Padrão**: Isolamento de integrações externas críticas lentas e limitadas por meio de tabelas de Outbox transacionais locais e despacho com limitação de taxa constante (*Leaky Bucket*).
* **Onde treinar no Monorepo**: [17-external-api-throttler-outbox](./17-external-api-throttler-outbox/README.md).
* **Foco Staff**: Evitar esgotamento de thread pools locais e saturação de banco de dados, com ativação ágil de Circuit Breakers e retentativas controladas (Backoff com Jitter).

### 33. Proteção Concorrente de Pagamentos (Pix Idempotency Engine)
* **O Padrão**: Garantia de processamento Exactly-once em transferências financeiras instantâneas sob falha de rede e retentativas concorrentes simultâneas.
* **Onde treinar no Monorepo**: [18-pix-double-payment-prevention](./18-pix-double-payment-prevention/README.md).
* **Foco Staff**: Empregar travas distribuídas (Redlock) para evitar duplo pagamento sob concorrência síncrona na mesma chave, com tratamentos para chaves pendentes (`PROCESSING`) e locks órfãos.

### 34. Coordenação de Workflows Distribuídos e Limites de Transação (BPMN Engine)
* **O Padrão**: Orquestração resiliente de processos de negócio sequenciais com salvamentos atômicos em banco de dados (`asyncBefore`) para restabelecimento pós-crash de máquina de estados.
* **Onde treinar no Monorepo**: [19-distributed-workflow-coordinator](./19-distributed-workflow-coordinator/README.md).
* **Foco Staff**: Uso do padrão *External Tasks* para delegar execução a workers desacoplados diminuindo a carga e contenda do banco do Camunda, com tratamento de leases expiradas por falhas físicas dos workers.


