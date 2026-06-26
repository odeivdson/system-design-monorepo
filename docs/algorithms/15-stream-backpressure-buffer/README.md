# Desafio 27: Controle de Fluxo e Backpressure em Processamento de Streams (`algo-stream-backpressure-buffer`)
> **Padrões de Arquitetura de Streaming e Concorrência:** Stream Backpressure (Controle de Fluxo Reativo), Bounded Buffer (Fila Delimitada), Thread Signaling (Sinalização Concorrente).

## 1. Contexto & Cenário
Em sistemas de processamento de fluxos contínuos de dados (Streaming) — como processamento de eventos do Kafka, logs de auditoria em alta escala ou telemetria em tempo real — existe um desacoplamento natural entre o componente que produz as mensagens (**Producer**) e o componente que as processa e persiste (**Consumer**).

Em um cenário ideal, a taxa de processamento do Consumer é maior ou igual à taxa de envio do Producer. No entanto, em picos de tráfego de rede ou momentos em que o banco de dados do Consumer fica lento, a velocidade do Producer supera drasticamente o processamento. Se a fila (Buffer) interna que conecta os dois for ilimitada (unbounded), ela acumulará milhões de mensagens pendentes em memória, levando ao estouro de RAM do servidor e queda definitiva do serviço por **OutOfMemory (OOM) Exception**.

Para evitar a falha catastrófica de falta de memória, a fila deve possuir um limite rígido de capacidade (Bounded Buffer) e a arquitetura deve implementar o padrão de **Backpressure (Controle de Fluxo Reativo)**: a capacidade do buffer sinaliza dinamicamente aos produtores para desacelerarem ou pausarem a ingestão quando limites críticos de armazenamento temporário (Watermarks) forem atingidos, retomando o envio assim que o consumidor esvaziar o buffer de forma segura.

---

## 2. Requisitos Funcionais (RF)
- **Fila Delimitada de Alta Concorrência (Bounded Queue)**: Implementar ou utilizar uma fila concorrente que aceite no máximo $N$ elementos simultâneos.
- **Detecção de Watermarks**:
  - **High Watermark (Limite Crítico Alto, ex: 80% de capacidade)**: Quando a fila atingir este patamar, sinalizar aos produtores para entrarem em estado de pausa/bloqueio temporário.
  - **Low Watermark (Limite Seguro Baixo, ex: 20% de capacidade)**: Quando o consumidor esvaziar a fila até este nível, sinalizar aos produtores suspensos para retomarem a produção de forma imediata.
- **Sinalização Concorrente Não-Bloqueante de CPU**: A suspensão das threads de produção deve suspender o consumo de CPU (evitar Busy Wait / Spin Loops com loops infinitos `while(true)`) utilizando primitivas de notificação eficientes do sistema operacional.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Consumo de Memória Rígido e Previsível**: A quantidade de memória ocupada pelo buffer deve ser limitada de forma absoluta pelo tamanho máximo configurado, garantindo vazão estável sem variações de latência induzidas por ciclos longos de Garbage Collection.
- **Overhead de Sinalização Mínimo (Sub-Microsegundo)**: O custo computacional de checagem do tamanho do buffer e disparo de sinais de suspensão/retomada entre threads concorrentes deve ser sub-microsegundo.
- **Sustentação sob Sobrecarga Extrema**: O sistema não pode colapsar se múltiplos produtores paralelos tentarem forçar escritas com o buffer cheio. As requisições de escrita devem travar com segurança e liberar imediatamente após a sinalização de Low Watermark.

---

## 4. Guia de Implementação & Padrões

### Mecanismo de Backpressure Reativo por Watermarks
```
  [ Produtores (Producers) ] ───────► (Envia Dados) ───────┐
              ▲                                            │
        (Sinal de Pausa / Retomada)                        ▼
┌──────────────────────────────────────────────────────────────┐
│                  Bounded Buffer Queue                        │
│                                                              │
│  - Tamanho Atual > 80% (High Watermark) -> Pausa Produtores  │
│  - Tamanho Atual < 20% (Low Watermark)  -> Retoma Produtores │
└──────────────────────────────┬───────────────────────────────┘
                               │
                       (Consome Dados)
                               ▼
                   [ Consumidores (Consumers) ]
```

### Padrões e Primitivas Recomendadas:
- **Monitoramento de Watermarks com Semáforos e Locks de Sinalização**: Em C#, utilizar estruturas como `Monitor.Wait` / `Monitor.Pulse` ou primitivas reativas como `SemaphoreSlim` e `Channel<T>` delimitados para gerenciar o bloqueio de threads de escrita. No Java, o uso de `ReentrantLock` acoplado com duas variáveis de condição (`notFull`, `notEmpty`) permite implementar de forma clássica a sinalização concorrente precisa.
- **Evitar Busy-Wait (Spinning)**: Jamais escreva loops que queimem CPU esperando que uma variável boleana mude de estado. Sempre suspenda a thread produtora no kernel (ex: usando `AutoResetEvent`, `ManualResetEventSlim` ou locks condicionais).
- **Disruptor Pattern (Ring Buffer)**: Para máxima performance de streaming em tempo real, use um buffer circular pré-alocado (Ring Buffer) de tamanho potência de 2, onde produtores e consumidores movem sequências numéricas (ponteiros de posição) usando operações de bitwise atômicas sem travas exclusivas.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Comprovação de Pausa Concorrente sob Carga**: Teste automatizado simulando 5 threads produtoras enviando dados infinitamente para um buffer com capacidade máxima cravada em 100 itens. A thread consumidora processa 1 item a cada 50ms (lenta). O teste deve provar que:
  - O buffer nunca ultrapassa 100 itens.
  - As threads produtoras passam a maior parte do tempo em estado `WaitSleepJoin` ou suspensas de forma saudável pelo kernel, com uso de CPU da aplicação próximo a zero.
- **Retomada Rápida pós Low Watermark**: Assim que o consumidor esvaziar a fila abaixo da marca crítica baixa (20 itens), as threads produtoras suspensas devem ser imediatamente acordadas para retomar o envio de dados sem perda de mensagens.
- **Tratamento de Cancelamento (Graceful Shutdown)**: O buffer deve suportar sinalização de fechamento (`CompleteAdding`). Se o sistema for desligado, os produtores são impedidos de escrever novas mensagens, mas o consumidor tem a permissão de processar todos os itens que já estavam na fila antes de encerrar o processo de forma limpa.

---

## 6. Trade-offs

### A. Bloquear Produtor (Blocking Backpressure) vs. Descartar Mensagens (Lossy Backpressure)
- **Bloqueio Síncrono (Blocking Backpressure - Recomendado para Integridade)**:
  - *Pró*: Garantia absoluta de entrega de dados. Nenhuma mensagem é perdida na transição.
  - *Contra*: Propaga a lentidão de volta na cadeia de chamada (upstream). Se o consumidor final travar, o gargalo atinge a borda da aplicação (API Gateway / Clientes móveis).
- **Descarte de Mensagens (Lossy Backpressure / Drop Strategies)**:
  - *Pró*: Preserva a velocidade e a latência de ingestão da aplicação na borda; evita que travamentos downstream congelem a aplicação inteira.
  - *Contra*: Perda de dados. Requer decisões difíceis como: descartar o evento mais novo (Drop Newest), o mais antigo da fila (Drop Oldest) ou recusar novas requisições explicitamente.

### B. Watermarks Dinâmicos vs. Watermarks Estáticos
- **Watermarks Estáticos (Ex: 80% / 20% fixos)**:
  - *Pró*: Simplicidade matemática absoluta de codificação e execução livre de bugs.
  - *Contra*: Não se adapta a flutuações sazonais de hardware ou de velocidade de conexões de rede em tempo real.
- **Watermarks Dinâmicos (Monitoramento Adaptativo)**:
  - *Pró*: Ajusta dinamicamente a taxa com base no histórico recente de processamento do consumidor.
  - *Contra*: Complexidade de engenharia massiva; risco de loops de histerese (sinalizar pausa/retomada excessiva muito rapidamente, gerando consumo inútil de processamento do kernel).
