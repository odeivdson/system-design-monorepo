# Desafio 11: Roda de Temporização Hierárquica (`algo-hierarchical-timer-wheel`)

## 1. Contexto & Cenário
Em servidores de rede de alto tráfego (como proxies reversos, API Gateways ou brokers de mensageria como Apache Kafka) e despachantes assíncronos (como motores de envio de webhooks), o gerenciamento de milhões de timers de curto prazo é um desafio clássico. Por exemplo, monitorar timeouts de conexões TCP, agendar retentativas de webhooks com segundos de atraso ou impor quotas de uso. 

A abordagem tradicional de armazenar os timers em uma Fila de Prioridades (Min-Heap) exige complexidade de tempo de $O(\log N)$ para inserção e remoção. Quando escalada para milhões de timers simultâneos, a manutenção do Heap consome recursos massivos de CPU, gerando picos de latência intoleráveis. A estrutura de dados **Hierarchical Timing Wheel (Roda de Temporização Hierárquica)** resolve esse problema ao permitir que inserções, cancelamentos e a execução de tarefas ocorram em complexidade de tempo constante $O(1)$ amortizado, organizando as tarefas em rodas que representam diferentes grandezas de tempo (ex: segundos, minutos, horas) e movendo-as de nível (cascateamento) conforme o tempo passa.

---

## 2. Requisitos Funcionais (RF)
- **Agendamento de Tarefas (Schedule)**: Adicionar um callback de execução futura com um atraso de tempo relativo configurável.
- **Execução em Tempo Real (Tick)**: A roda deve avançar em ticks de tamanho definido (ex: 10ms ou 1s) e disparar automaticamente todos os callbacks das tarefas que expiraram naquele intervalo de tempo.
- **Cancelamento Eficiente (Cancel)**: Permitir cancelar uma tarefa agendada previamente antes que ela expire, removendo-a da estrutura física em $O(1)$.
- **Cascateamento de Tarefas (Cascading)**: Mover tarefas automaticamente de rodas mais lentas (ex: roda de minutos) para rodas mais rápidas (ex: roda de segundos) conforme o relógio avança e o tempo restante para execução diminui.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Operação Estrita em $O(1)$**: Inserir, cancelar e despachar tarefas do bucket ativo devem ser executados em tempo constante ($O(1)$).
- **Suporte a Milhões de Timers**: O consumo de memória RAM deve ser linear e otimizado, sem a necessidade de criar instâncias de Thread do sistema operacional por temporizador.
- **Precisão Temporal e Jitter Mínimo**: Minimizar atrasos ou antecipações na execução das tarefas (jitter) sob condições de oscilação de uso de CPU do hospedeiro.
- **GC-Friendly Design**: Reaproveitar instâncias de nós de temporizador (Timer Nodes) por meio de pooling para mitigar alocações frequentes de Heap.

---

## 4. Guia de Implementação & Padrões
A estrutura implementa múltiplas rodas concêntricas, onde cada roda é um array circular de buckets (listas ligadas de tarefas pendentes).

```
         [ Roda de Minutos ] (60 slots de 1 min)
                 │
                 ▼ (Cascateamento de tarefas quando resta < 1 min)
         [ Roda de Segundos ] (60 slots de 1s) ◄─── Tick do Relógio
                 │
                 ▼ (Disparo da tarefa)
         [ Executor Worker Pool ]
```

### Padrões e Primitivas Recomendadas:
- **Hierarquia de Rodas**: Criar rodas aninhadas, por exemplo:
  - *Roda de Milissegundos*: 512 slots de 1ms (tempo de ciclo total = 512ms).
  - *Roda de Segundos*: 64 slots de 512ms (tempo de ciclo total = ~32s).
  - *Roda de Minutos*: 64 slots de ~32s (e assim por diante).
- **Lista Duplamente Ligada para Buckets**: Cada slot (bucket) do array circular deve ser a cabeça de uma lista duplamente ligada de nós de tarefas. Isso permite que qualquer tarefa seja removida (cancelada) em $O(1)$ se tivermos a referência direta do nó.
- **Hashing Circular de Slots**: O slot index de inserção de uma tarefa com delay $D$ é calculado atomicamente como:
  $$Index = \left(Tick_{atual} + \frac{Delay}{Intervalo}\right) \pmod{Tamanho\_da\_Roda}$$
- **Delay Queue Integrada (Kafka Style)**: Para evitar que a thread de ticking gaste CPU vasculhando buckets vazios da roda de forma estéril, pode-se acoplar uma fila de atraso baseada em prioridades (`DelayQueue` com tempo de bloqueio) contendo apenas os buckets que possuem pelo menos uma tarefa agendada.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Mecanismo de Cascateamento Correto**: Como o sistema transfere as tarefas pendentes da roda de granularidade maior para a roda menor. O avaliador checará se há falha de limite (off-by-one errors) no momento da transição do ponteiro de tick da roda.
- **Implementação do Cancelamento em Tempo Constante**: A capacidade de realizar o cancelamento síncrono ou lógico sem percorrer linearmente as listas.
- **Coordenação Concorrente sem Bloqueio de Thread de Tick**: A thread responsável por rodar o `tick` deve fazer apenas tarefas rápidas. Tarefas pesadas demoradas executadas nos callbacks devem ser delegadas a um pool de threads externo (`ThreadPool`), impedindo que uma tarefa demorada atrase o andamento do relógio do sistema.
- **Precisão contra Desvio de Relógio (Clock Drift)**: Sincronizar a roda a um relógio real externo (ex: `System.nanoTime()` ou contadores de CPU) em vez de confiar apenas em `Thread.sleep()`, que sofre distorções severas de scheduler do SO.

---

## 6. Trade-offs

### A. Roda Hierárquica vs. Roda Simples com Multi-Voltas (Round Counter)
- **Roda Simples com Multi-Voltas**: Cada nó de temporizador armazena uma variável `Rounds`. A cada volta completa no anel, o contador é decrementado. O callback é acionado apenas quando `Rounds == 0`.
  - *Pró*: Simplicidade de código, não requer cascateamento.
  - *Contra*: Perda do princípio $O(1)$. Se um slot tiver milhares de tarefas com atrasos longos diferentes, o tick precisará varrer linearmente toda a lista desse slot para decrementar seus contadores de volta, consumindo muita CPU.
- **Roda Hierárquica (Recomendada)**:
  - *Pró*: Eficiência garantida de $O(1)$ sob qualquer volume e distribuição de tempo de tarefas.
  - *Contra*: Código significativamente mais complexo devido à sincronização entre rodas e ao algoritmo de cascateamento.

### B. Tick com Thread Dedicada vs. Tick sob Demanda (On-Access)
- **Thread Dedicada (Loop Ativo)**: Uma thread de background monitora o tempo e realiza ticks contínuos.
  - *Pró*: Execução determinística e próxima do tempo real.
  - *Contra*: Consumo contínuo de CPU mesmo que não existam tarefas cadastradas na aplicação.
- **Tick sob Demanda**: O relógio só avança quando novas tarefas são inseridas ou consultadas.
  - *Pró*: Recursos de CPU otimizados.
  - *Contra*: Timers podem sofrer atrasos severos na execução se a aplicação passar por um período sem interações ou requisições de clientes.
