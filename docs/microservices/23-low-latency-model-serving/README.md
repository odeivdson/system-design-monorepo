# Desafio 23: Motor de Inferência de Modelos ML de Baixa Latência (`low-latency-model-serving`)
> **Padrões de Microsserviços Associados:** Dynamic Batching (Agrupamento Dinâmico), Resilient Model Serving (Servimento de Modelos), Thread-Pool Segregation (Isolamento de Pools de Execução), Cache de Predições, Fallback & Heuristic Degradation.

## 1. Contexto & Cenário
Em ecossistemas corporativos baseados em inteligência artificial e aprendizado de máquina, servir predições de modelos em tempo real (como detecção de fraudes em pagamentos, motores de recomendação ou precificação dinâmica) é um dos maiores desafios de arquitetura.

Modelos de Machine Learning (ML) e Deep Learning (DL), como modelos baseados em árvores (XGBoost, Random Forest) ou redes neurais (ONNX, PyTorch), são computacionalmente pesados. Há um conflito inerente na forma como sistemas web e hardware de IA trabalham:
- **Sistemas Web**: Recebem requisições transacionais individuais e síncronas de milhares de usuários concorrentes (entradas únicas: `User A -> Predict`).
- **Hardware de ML (CPU/GPU)**: É extremamente eficiente ao computar operações matriciais em lotes grandes (*Batch Processing*), mas muito ineficiente e com alto overhead quando executado para um único registro por vez (*Single-record Inference*).

Se cada requisição HTTP síncrona acionar uma inferência individual na CPU/GPU direta, a fila de concorrência crescerá rapidamente, gerando gargalo de latência, contenção de recursos de hardware e estouro do SLA de tempo de resposta.

Para resolver este trade-off, implementa-se o padrão **Dynamic Batching** no motor de inferência: as requisições individuais dos usuários são retidas em buffers concorrentes de curtíssima duração (ex: 2ms a 5ms). O worker de inferência lê este buffer, agrupa todas as requisições em uma única matriz (lote), executa a inferência de forma massivamente paralela no hardware e distribui os resultados de volta para as respectivas conexões HTTP pendentes dos usuários, viabilizando alto throughput com latência controlada.

---

## 2. Requisitos Funcionais (RF)
- **Agrupador Dinâmico de Lotes (Dynamic Batcher)**:
  - O motor de inferência deve receber requisições individuais concorrentes e acumulá-las em uma fila protegida contra condições de corrida.
  - O lote deve ser despachado para a inferência sob duas condições (a que ocorrer primeiro):
    1. O tamanho do lote atingir o limite máximo pré-definido (ex: `max_batch_size = 32`).
    2. A janela máxima de tempo de espera expirar (ex: `max_delay_ms = 3ms`).
- **Executor de Inferência ONNX / Predictor Engine**:
  - O motor deve carregar e manter um modelo pré-treinado em memória RAM de forma isolada (ex: carregando um arquivo `.onnx` ou usando um preditor simulado com custos computacionais pesados realistas).
  - Executar a predição paralela do lote de dados de entrada na CPU/GPU.
- **Cache de Predições Recorrentes**:
  - Implementar uma camada de cache local de leitura veloz (TTL curto) para consultas cujas chaves de parâmetros de entrada sejam idênticas, poupando CPU/GPU.
- **Mecanismo de Degradação Graciosa com Fallback**:
  - Se a fila de requisições de inferência acumular além de um limite crítico (sobrecarga), ou o tempo de resposta da inferência falhar/estourar, o Circuit Breaker deve disparar.
  - O sistema deve degradar a resposta graciosamente retornando uma predição baseada em um modelo de regressão/heurística estática local muito mais leve e rápido (latência sub-1ms) para manter a disponibilidade sob sobrecarga.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead Interno do Batcher Sub-Milissegundo**: O tempo gasto pelo agregador dinâmico para enfileirar, agrupar, e desenfileirar as requisições (excluindo o tempo de inferência real do modelo) deve ser inferior a 1ms no P99.
- **Isolamento de Thread Pools (Segregação de Recursos)**:
  - As threads que escutam o tráfego de rede HTTP do servidor web não devem ser bloqueadas pelo processamento de inferência.
  - Deve existir uma segregação clara entre o pool de conexões HTTP (I/O non-blocking) e o pool de threads/workers dedicados à inferência intensiva de CPU/GPU.
- **Prevenção contra Estouros de Memória (OOM Prevention)**:
  - O tamanho do lote dinâmico deve ser autolimitado e ajustado sob pressão de memória para impedir estouro de memória da GPU/CPU.
- **Sincronização Não-Bloqueante (Lock-Free Thread Coordination)**:
  - O envio do resultado da inferência da thread do worker de volta para a thread HTTP de resposta do cliente deve ser feito usando primitivas de sincronização assíncronas eficientes (como promessas / *Futures* pendentes), evitando bloqueios globais e contenção de travas (Locks).

---

## 4. Guia de Implementação & Padrões

### Arquitetura do Servidor de Modelos com Dynamic Batching

```
Threads HTTP (Entradas Concorrentes)
   ┌─────────┐
   │ Req A  ─┼────────┐
   └─────────┘        │
   ┌─────────┐        │ (Enfileira assincronamente)
   │ Req B  ─┼────────┼──────► ┌───────────────────────────┐
   └─────────┘        │        │      Lock-Free Queue      │
   ┌─────────┐        │        └─────────────┬─────────────┘
   │ Req C  ─┼────────┘                      │
   └─────────┘                               │
                                             ▼ (Lote aglomerado: A + B + C)
                               ┌───────────────────────────┐
                               │   Dynamic Batcher Worker  │
                               └─────────────┬─────────────┘
                                             │ (Executa chamada de matriz única)
                                             ▼
                               ┌───────────────────────────┐
                               │   Model Predictor (ONNX)  │
                               └─────────────┬─────────────┘
                                             │ (Devolve resultados em paralelo)
                                             ▼
                               ┌───────────────────────────┐
                               │ Future Promise Resolution │
                               └─────────────┬─────────────┘
                                             │
                        ┌────────────────────┼───────────────────┐
                        ▼                    ▼                   ▼
                   [Response A]         [Response B]        [Response C]
```

### Padrões e Primitivas Recomendadas:
1. **Thread Pool Segregation Pattern**: Separar o processamento em duas camadas de execução. A camada HTTP recebe a requisição, gera um identificador único de Future, enfileira a entrada de dados e a promessa na fila e cede o controle para aguardar o resultado de forma não-bloqueante. O worker de inferência puxa a fila de dados, computa o lote e resolve a Future associada a cada requisição.
2. **Channel-based / Lock-free Queues**: Utilizar canais de comunicação com buffers delimitados (Bounded Channels) para enfileirar as predições. Em linguagens como Go ou Rust, usar `channels` ou `crossbeam-channel`. Em Java/C#, usar `LinkedTransferQueue` ou `Disruptor RingBuffer` para evitar contenção de mutexes.
3. **Dynamic Batching Loop Algorithm**: O loop de execução do worker do batcher deve rodar continuamente executando a seguinte lógica simplificada:
   ```python
   # Exemplo conceitual do loop do worker
   while True:
       batch = []
       start_time = now()
       while (now() - start_time < max_delay_ms) and (len(batch) < max_batch_size):
           # Lê da fila com timeout curto remanescente
           request = queue.pop(timeout = max_delay_ms - (now() - start_time))
           if request:
               batch.append(request)
       if batch:
           inputs = format_as_matrix(batch)
           predictions = model.predict(inputs)
           for req, pred in zip(batch, predictions):
               req.promise.resolve(pred)
   ```
4. **Heuristic Fallback Engine**: Manter em cache local um modelo estatístico muito rápido (ex: regressão logística simples ou heurística de árvore com poucas regras). Se o tempo de espera da fila crescer além do limite tolerável do SLA, retirar requisições da fila principal e encaminhá-las para a heurística instantaneamente, mantendo a estabilidade.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Comparação de Throughput / Latência**: Provar por meio de simulações com múltiplos clientes paralelos que o uso de Dynamic Batching aumenta o throughput do sistema (predições por segundo) sem degradar severamente a latência individual percebida por requisição.
- **Eficiência de CPU/GPU**: Métricas comprovando que as chamadas de inferência ao modelo carregado ocorrem majoritariamente com tamanhos de lote maximizados sob alta carga de requisições.
- **Isolamento de Falhas por Sobrecarga**: Demonstrar que o acionamento do Heuristic Fallback impede o colapso por falta de recursos (OOM ou timeouts em cascata) do motor de inferência, mesmo quando o volume de requisições de teste triplica o limite nominal do modelo pesado.
- **Locking Overhead Controlado**: Verificação do perfil de execução do servidor comprovando que o uso de threads sincronizadas via canais/promessas concorrentes consome recursos mínimos de tempo de lock de CPU.

---

## 6. Trade-offs

### A. Latência vs. Throughput no Dynamic Batcher
- **Max Delay Alto (ex: 10ms)**:
  - *Pró*: Maximiza a formação de lotes cheios; ideal para maximizar o throughput e eficiência do hardware (GPU); diminui o custo operacional sob tráfego denso.
  - *Contra*: Adiciona latência artificial de 10ms para os primeiros usuários que entraram na fila antes da formação do lote, o que pode violar SLAs de baixa latência em fluxos síncronos críticos.
- **Max Delay Baixo (ex: 1ms)**:
  - *Pró*: Latência adicional imperceptível para o usuário final; ideal para sistemas de tempo real estrito.
  - *Contra*: O motor executará muitas inferências com lotes pequenos ou unitários, diminuindo a eficiência de hardware e o throughput máximo suportado pelo servidor.

### B. ONNX Runtime vs. Libs Nativas (PyTorch / TensorFlow) para Servimento
- **ONNX Runtime (Recomendado para Servimento)**:
  - *Pró*: Otimizações de grafo de execução em hardware nativo; portabilidade poliglota total; footprint de memória menor e inferência mais veloz de modelos exportados.
  - *Contra*: Requer o passo extra de compilação e exportação do modelo original para o formato `.onnx`.
- **Nativo (PyTorch/TensorFlow)**:
  - *Pró*: Sem necessidade de exportar ou converter formatos de arquivo.
  - *Contra*: Bibliotecas de desenvolvimento pesadas para ambiente produtivo; alto overhead de memória RAM; tempo de inicialização lento.
