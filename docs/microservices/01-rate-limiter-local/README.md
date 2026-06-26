# Desafio 1: Limitador de Taxa em Memória (`rate-limiter-local`)
> **Padrões de Microsserviços Associados:** API Gateway (Borda), Rate Limiting (Local/Defesa de Borda).

## 1. Contexto & Cenário
Em arquiteturas modernas de microsserviços, cada instância é responsável por proteger a si mesma de abusos de uso ou sobrecarga de recursos. Embora existam limitadores de taxa distribuídos globais (como gateways de API), a proteção local (in-memory) é vital como uma linha de defesa secundária de baixo custo. Ela impede que um vazamento de conexões, um loop infinito em um cliente, ou um pico súbito de tráfego de um único usuário sature a CPU, esgote o pool de conexões com o banco de dados local ou cause estouro de memória na máquina hospedeira.

O problema acadêmico básico é comumente resolvido usando estruturas de dados simples. Entretanto, sob a perspectiva de um Engenheiro Staff, a implementação prática exige thread-safety absoluto sob concorrência extrema de leituras e escritas sem a dependência de bloqueios globais que causam degradação severa da latência e degradação de CPU. Além disso, o limitador deve ter baixo consumo de memória e evitar alocações constantes de objetos no Heap para manter as coletas de lixo (GC) no mínimo absoluto.

---

## 2. Requisitos Funcionais (RF)
- **Consumo de Tokens**: Permitir que a aplicação cheque se uma requisição com base em um identificador (ex: ID do cliente ou IP) pode prosseguir. Se permitido, consome 1 token.
- **Replenish de Tokens (Recarga)**: Os tokens para cada cliente devem ser recarregados de forma contínua a uma taxa pré-estabelecida (ex: 10 tokens por segundo) até atingirem a capacidade máxima do bucket.
- **Isolamento de Clientes**: A limitação aplicada a um cliente não pode interferir no estoque de tokens de outros clientes.
- **Exclusão de Buckets Inativos**: Remover automaticamente do mapa em memória os clientes que não realizam requisições há um determinado período para evitar vazamento de memória.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead Sub-Microsegundo**: A validação de limites deve rodar em tempo inferior a 1 microsegundo por requisição na hot path.
- **Throughput Concorrente Elevado**: Suportar milhões de validações simultâneas por segundo em ambientes multicore sem gargalos de sincronização.
- **Eficiência de GC (Otimização de Alocação)**: A recarga dos tokens não pode depender de timers em background ativos por cliente. Em vez disso, a recarga deve ser calculada de forma passiva (lazy evaluation) no momento de cada requisição.
- **Gerenciamento Seguro de Memória**: O cache em memória contendo os buckets dos usuários ativos deve ser delimitado (bounded) ou passar por limpezas agressivas periódicas.

---

## 4. Guia de Implementação & Padrões
A estrutura central utiliza um mapa concorrente para associar chaves de identificação (IP/Client ID) a um objeto ou estrutura de dados representando seu respectivo Bucket de Tokens.

```
       [ Chamada de API Downstream ]
                     │
                     ▼ (Checar Limite por Client ID)
┌───────────────────────────────────────────────┐
│        ConcurrentDictionary<Key, Bucket>      │
└────────────────────┬──────────────────────────┘
                     │ (Recupera / Cria Bucket)
                     ▼
┌───────────────────────────────────────────────┐
│             Token Bucket Local                │
│                                               │
│  - Checa Timestamp Atual (Time.Now)           │
│  - Calcula Delta = Time.Now - Time.Last       │
│  - Replenish Passivo (Lazy Evaluation):        │
│    Tokens = min(Cap, Tokens + Delta * Rate)   │
│  - Se Tokens >= 1:                            │
│      Decrementa e Retorna true (Consumido)    │
│    Se não:                                    │
│      Retorna false                            │
└───────────────────────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Replenish Passivo (Lazy replenishment)**: O cálculo do saldo atualizado de tokens é feito sob demanda na requisição usando a fórmula:
  $$Tokens_{atual} = \min\left(Capacidade, Tokens_{anterior} + Taxa \times (Tempo_{atual} - Tempo_{anterior})\right)$$
  Isso elimina a necessidade de inicializar `System.Threading.Timer` ou threads de background dedicadas por cliente, poupando CPU e memória RAM.
- **Operações Atômicas e CAS (Compare-And-Swap)**: Em C#, utilizar estruturas de valores imutáveis para o estado do bucket e atualizá-las usando `Interlocked.CompareExchange` ou no Java usando `AtomicReference` com loops CAS. Isso garante que a atualização do timestamp e do saldo de tokens seja atômica e lock-free para o mesmo usuário.
- **ConcurrentDictionary com Sharded Cleanup**: Limpar buckets inativos usando uma tarefa em background em lote de menor prioridade ou por meio de varreduras concorrentes de baixo impacto nos períodos de ociosidade do sistema.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Eliminação de Locks Globais**: Uso correto de `ConcurrentDictionary` sem travas síncronas que bloqueiem todo o mapa de clientes.
- **Atualização Atômica Lock-Free por Usuário**: Como tratar requisições simultâneas ultravelozes vindas do mesmo cliente. Um lock tradicional no nível de bucket limita o desempenho; o avaliador buscará implementações lock-free (CAS) no estado interno de cada bucket.
- **Tratamento de Overflow e Arredondamentos**: Precisão no tratamento de frações de tokens gerados em intervalos de nanossegundos/milissegundos, evitando bugs de arredondamento matemático de ponto flutuante que possam inflar artificialmente ou deprimir o estoque de tokens.
- **Remoção Segura de Itens Inativos**: Estratégia resiliente para evitar condições de corrida em que um bucket é removido por ociosidade exatamente no mesmo nanossegundo em que uma nova requisição para aquele mesmo cliente é recebida e tenta utilizá-lo.

---

## 6. Trade-offs

### A. Token Bucket vs. Leaky Bucket vs. Sliding Window Log
- **Token Bucket (Recomendada)**:
  - *Pró*: Altíssima vazão, implementação simples baseada em lazy evaluation, aceita rajadas controladas de tráfego.
  - *Contra*: Pode permitir picos de carga súbitos no limite máximo de capacidade se o bucket estiver cheio.
- **Leaky Bucket**:
  - *Pró*: Suaviza o tráfego de saída perfeitamente em uma taxa constante.
  - *Contra*: Aumenta a latência das requisições, pois as força a esperar em fila para sair.
- **Sliding Window Log**:
  - *Pró*: Precisão absoluta nos limites temporais.
  - *Contra*: Consumo massivo de memória, pois armazena o timestamp de cada requisição individual na janela de tempo.

### B. Locks Finos vs. Lock-Free CAS
- **Locks Finos (ex: lock(bucket))**:
  - *Pró*: Código de fácil leitura e manutenção simples.
  - *Contra*: Threads suspensas pelo SO geram overhead de troca de contexto (context switch) sob concorrência agressiva de requisições de um único cliente.
- **CAS (Compare-And-Swap)**:
  - *Pró*: Performance máxima sem suspensão de threads no kernel.
  - *Contra*: Maior complexidade de depuração e risco de loops excessivos de spin (CPU burn) se o cliente realizar chamadas infinitamente paralelas.