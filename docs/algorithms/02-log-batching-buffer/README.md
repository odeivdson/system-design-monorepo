# Desafio 8: Agrupador de Logs por Janela de Tempo e Tamanho (`algo-log-batching-buffer`)

## 1. Contexto & Cenário
Em arquiteturas de microsserviços e sistemas distribuídos em escala de produção (ex: telemetria na Netflix ou ingestão de eventos de clickstream no Mercado Livre), a geração de logs e métricas alcança facilmente dezenas de milhões de eventos por minuto. Se cada linha de log ou métrica for enviada individualmente ao provedor externo de monitoramento (ex: Datadog, Splunk ou Elasticsearch) por meio de uma requisição de rede HTTP direta, a aplicação sofrerá uma degradação de performance drástica. 

O overhead de handshakes TCP/TLS frequentes, alocação de cabeçalhos HTTP e latência física de rede esgotará os recursos de thread e CPU do hospedeiro. Para otimizar esse fluxo de forma viável, agentes coletores de logs utilizam buffers em memória. A hot path da aplicação escreve logs instantaneamente no buffer local e uma thread em background consome as mensagens agrupando-as em lotes (batching) sob uma regra de duplo gatilho: ou o lote atinge um tamanho ideal em bytes/itens, ou um tempo máximo de espera expira.

---

## 2. Requisitos Funcionais (RF)
- **Ingestão Concorrente**: Expor um método thread-safe para que qualquer parte da aplicação enfileire logs no buffer instantaneamente.
- **Duplo Gatilho de Despacho (Flush Trigger)**: Agrupar logs e despachá-los para um método de envio (sink) fictício quando:
  - **Gatilho de Tamanho**: O lote acumular um número pré-definido de logs (ex: 1.000 logs).
  - **Gatilho de Tempo (Time Window)**: Uma janela de tempo máxima expirar (ex: 500ms desde o primeiro log inserido no lote atual), mesmo que o lote esteja incompleto.
- **Tratamento de Controlo de Fluxo (Backpressure)**: O buffer deve impor um limite de capacidade máxima. Se o sink downstream estiver lento e o buffer encher, o buffer deve aplicar uma política de backpressure configurável para evitar estourar a memória.
- **Graceful Shutdown**: Em caso de encerramento da aplicação, o buffer deve garantir o flush imediato de todos os logs remanescentes na memória antes de permitir a finalização do processo.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Ingestão de Baixa Latência (Zero Contention)**: O tempo para enfileirar um log na aplicação deve ser inferior a 1 microsegundo, não bloqueando a thread geradora do log com chamadas de rede ou sincronizações pesadas.
- **Alocação de Memória Otimizada (GC-Friendly)**: O design deve evitar a alocação recorrente de arrays ou listas de tamanho fixo a cada lote despachado. O reuso de buffers (Buffer Pooling) deve ser priorizado para evitar fragmentação de memória e overhead do Garbage Collector (GC).
- **Precisão Temporal e Threads Dedicadas**: A expiração do timer de tempo de espera não pode gerar race conditions que resultem no mesmo lote de logs sendo disparado mais de uma vez ou logs sendo perdidos em trânsito.
- **Bounded In-Memory Size**: O consumo de RAM pelo buffer deve ser estritamente delimitado para evitar crashes por estouro de memória (OOM).

---

## 4. Guia de Implementação & Padrões
O design do agrupador baseia-se no padrão **Producer-Consumer** utilizando canais concorrentes assíncronos ou buffers circulares em anel (Ring Buffers).

```
         [ Threads Produtoras da Aplicação ]
                       │ (Ingestão Instantânea)
                       ▼
┌───────────────────────────────────────────────┐
│     Lock-free Queue / Ring Buffer             │
│   (Ingestão Concorrente Segura e Limitada)    │
└──────────────────────┬────────────────────────┘
                       │
                       ▼ (Consumido pelo Worker Thread)
┌───────────────────────────────────────────────┐
│            Batch Aggregator                   │
│                                               │
│  - Monitora Tamanho do Lote (Counter == K)     │
│                     E                          │
│  - Monitora Timer (Window == T ms)             │
└──────────────────────┬────────────────────────┘
                       │
             (Qualquer gatilho dispara)
                       │
                       ▼
┌───────────────────────────────────────────────┐
│              Flush Task / Sink                │
│     (Envio em lote unificado por rede)        │
└───────────────────────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Lock-Free Queue (ConcurrentQueue / Java Disruptor / Go Channels)**: Primitivas não bloqueantes baseadas em CAS (Compare-And-Swap) para enfileirar as mensagens sem custos de locks de mutexes do SO.
- **System.Threading.Channels (no .NET) ou BlockingQueue**: Facilita a construção do pipeline produtor-consumidor de forma assíncrona pura.
- **Timer de Alta Precision (ex: System.Threading.Timer ou PeriodicTimer)**: Para garantir que o gatilho de tempo atue de forma consistente no tempo exato configurado, mesmo sob estresse de CPU.
- **Primitivas de Coordenação Assíncrona (SemaphoreSlim / AutoResetEvent)**: Para sincronizar de forma limpa o sinalizador de flush entre a thread do timer e a thread de ingestão de logs.
- **Políticas de Backpressure**:
  - `BlockProducer`: A thread produtora é temporariamente bloqueada até que o consumidor abra espaço no buffer (preserva logs a custo de latência na aplicação).
  - `DropNewest` / `DropOldest`: O buffer descarta logs excedentes para proteger a performance (comportamento lossy tolerável para alguns logs não críticos).

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Eliminação de Condições de Corrida Temporais**: Como a solução garante que, se o gatilho de tamanho de lote (ex: log de número 1.000) e o timer de tempo (500ms) dispararem no exato milissegundo correspondente, o lote seja enviado apenas uma vez e os contadores/timers internos sejam reiniciados atomicamente.
- **Redução de Alocação de Memória**: Uso de estruturas reutilizáveis como pooling de listas (`ArrayPool` ou buffers circulares reaproveitados) em vez de alocar uma nova coleção a cada batch flush.
- **Estratégia de Encerramento (Graceful Shutdown)**: Demonstração clara de uso de tokens de cancelamento (`CancellationToken`) ou flags atômicos que bloqueiam novas entradas no buffer e realizam o dreno das mensagens remanescentes no encerramento da aplicação.
- **Isolamento de Erros no Sink**: Se o serviço de logs de destino falhar (HTTP 500), demonstrar que a falha não derruba a aplicação geradora de logs (isolamento de exceções e retentativas locais com limite).

---

## 6. Trade-offs

### A. Buffer em Memória Puro vs. Buffer Híbrido em Disco (WAL)
- **Buffer em Memória Puro (Recomendado para este desafio)**: Performance máxima, latência insignificante na ingestão.
  - *Contra*: Se o contêiner ou VM sofrer um crash elétrico ou reinicialização brusca, todas as mensagens de log atualmente no buffer local que ainda não foram enviadas serão permanentemente perdidas.
- **Buffer Híbrido (Write-Ahead Logging / WAL)**: Salva os logs localmente em disco antes de subir na memória.
  - *Pró*: Durabilidade extrema dos logs.
  - *Contra*: O throughput é severamente limitado pela escrita em disco, exigindo I/O considerável.

### B. Ingestão Lossless (Blocking) vs. Lossy (Dropping)
- **Ingestão Lossless (Blocking)**: Bloqueia a thread geradora do log quando o buffer está cheio.
  - *Pró*: Garantia absoluta de zero perda de métricas/logs.
  - *Contra*: Sob sobrecarga do sink de destino, a aplicação de negócios inteira pode congelar, afetando a experiência do cliente final por conta de um log secundário.
- **Ingestão Lossy (Dropping)**: Descarta mensagens excedentes de forma silenciosa ou emitindo alertas.
  - *Pró*: A performance da jornada principal de negócios nunca é prejudicada por telemetria.
  - *Contra*: Perda de rastros que podem ser vitais para investigar a própria falha do sistema.