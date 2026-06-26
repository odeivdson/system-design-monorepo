# Desafio 7: Cache LRU (Least Recently Used) Thread-Safe de Alta Performance (`algo-threadsafe-lru-cache`)

## 1. Contexto & Cenário
Em microsserviços de alto tráfego (como gateways de API de borda, proxies de roteamento ou resolvedores de DNS), o acesso repetido a repositórios de dados externos causa degradação severa da latência geral. Para evitar consultas excessivas a bancos de dados ou chamadas de rede, implementamos cache local em memória. No entanto, a memória física de uma instância é finita e deve ser estritamente controlada para evitar estouro de memória (Out-Of-Memory - OOM). A política LRU (Least Recently Used) é ideal para isso, pois expulsa os elementos menos utilizados recentemente quando a capacidade máxima é atingida.

O problema acadêmico padrão é resolvido facilmente com uma tabela hash e uma lista duplamente ligada executadas de forma sequencial. No entanto, em um ambiente de produção moderno altamente concorrente, dezenas de threads lerão e escreverão no cache simultaneamente. Se utilizarmos uma trava global ingênua (`lock(this)` ou `synchronized`), causaremos **thread contention (contenção de threads)** severa, resultando em gargalos de sincronização de CPU e destruindo os benefícios de latência do cache sob carga concorrente. O objetivo deste desafio é projetar e codificar um cache LRU thread-safe com baixíssima contenção de trava.

---

## 2. Requisitos Funcionais (RF)
- **Operação de Obtenção (Get)**: Recuperar o valor associado a uma chave em tempo de complexidade constante $O(1)$. Se a chave for encontrada, promovê-la a elemento mais recentemente usado da lista.
- **Operação de Inserção/Atualização (Put)**: Inserir ou atualizar um par chave-valor em $O(1)$. Se a chave foi nova e o cache atingiu seu limite de capacidade máxima, remover o item menos recentemente usado (evicção automatizada).
- **Evicção Eficiente**: A remoção do item LRU e a inserção de novos nós na lista devem ocorrer estritamente em complexidade de tempo constante $O(1)$.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Minimização da Contenção (Lock Contention)**: O cache deve ser projetado para que múltiplas leituras concorrentes ocorram sem bloqueio mútuo e que as escritas impactem o menor escopo possível de dados.
- **Thread-Safety Absoluto**: Sob condições de corrida agressivas de escrita e leitura simultâneas, os ponteiros da lista duplamente ligada e os buckets do dicionário interno nunca devem ficar corrompidos (evitar ponteiros órfãos ou vazamentos de nós).
- **Overhead de Garbage Collector (GC) Reduzido**: A estrutura deve evitar a alocação excessiva de objetos temporários nas operações frequentes de promoção (`Get`) para prevenir surtos de coletas de lixo que causam pausas do tipo Stop-The-World (STW).
- **Bounded Capacity**: Capacidade máxima de armazenamento estrita em número de itens.

---

## 4. Guia de Implementação & Padrões
A estrutura canônica combina um Dicionário concorrente rápido para busca $O(1)$ a uma lista duplamente ligada customizada para recorrência física dos elementos.

```
                  [ Operações Concorrentes ]
                              │
             ┌────────────────┴────────────────┐
             ▼ (Get - Leitura)                 ▼ (Put - Escrita)
 ┌───────────────────────┐         ┌───────────────────────┐
 │ Dicionário Concorrente│         │  Lock Striping /      │
 │ (ConcurrentDictionary)│         │  Mutex Segmentados    │
 └───────────┬───────────┘         └───────────┬───────────┘
             │                                 │
             ▼                                 ▼
   (Move nó para o Head)              (Insere / Evita Cauda)
 ┌─────────────────────────────────────────────────────────┐
 │               Lista Duplamente Ligada                   │
 │       [Head (Recente)] <-> [Node] <-> [Tail (LRU)]      │
 └─────────────────────────────────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **ConcurrentDictionary / ConcurrentHashMap**: Usado para o mapeamento de chaves para nós da lista duplamente ligada sem a necessidade de locks globais na fase de leitura.
- **Lock Striping (Travamento Segmentado)**: Em vez de bloquear toda a estrutura do cache com um único lock de gravação, segmentar o cache em $N$ shards independentes (ex: 16 ou 64 shards baseados no hash da chave), cada um contendo sua própria lista LRU e dicionário de menor escala. Isso reduz a probabilidade de colisão de travas drasticamente.
- **ReaderWriterLockSlim**: Para caches onde o volume de leituras supera massivamente as escritas. Permite leituras concorrentes ilimitadas, exigindo lock exclusivo apenas no momento da mutação física da lista (escrita).
- **Deferred List Updates (Fila de Promoção)**: Para evitar lock de escrita na lista duplamente ligada a cada operação de leitura (`Get` que requer mover o nó ao `Head`), podemos utilizar uma fila concorrente lock-free (ex: `ConcurrentQueue`) para armazenar os IDs das chaves acessadas de forma assíncrona. Um worker único em background consome essa fila e reordena a lista fisicamente de forma sequencial e sem contenção.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Estratégia Anti-Contenção no Get**: Demonstração clara de que a leitura (`Get`) não causa contenção síncrona generalizada. O candidato deve responder: *"Como atualizar os ponteiros da lista de recência no Get sem bloquear outros leitores?"*
- **Sincronização Atômica de Ponteiros**: Cuidados especiais ao remover nós da lista duplamente ligada. A ordem de alteração de ponteiros (`next`, `prev`) deve estar protegida contra condições de corrida que levariam a loops infinitos na navegação da lista.
- **Prevenção de Memory Leaks**: Garantir que as referências a objetos removidos da tabela Hash e da lista física sejam completamente eliminadas, permitindo a coleta imediata pelo Garbage Collector.
- **Prevenção de Deadlocks**: Se for utilizado travamento segmentado ou múltiplos locks aninhados (ex: lock no dicionário e depois na lista), demonstrar que a aquisição de travas segue sempre uma ordem estrita e determinística.

---

## 6. Trade-offs

### A. Strict LRU vs. Approximated LRU (LFU / Clock-Sweep / W-TinyLFU)
- **Strict LRU (Recomendado para este desafio)**: Garante precisão matemática na evicção do menor usado recente.
  - *Contra*: O ato de promover o nó em cada leitura exige manipulação física de ponteiros e trava na lista, gerando contenção mesmo sob leitura massiva.
- **Approximated LRU (ex: Clock / Second-Chance / W-TinyLFU)**: Não reordena fisicamente uma lista em cada leitura; usa apenas flags ou contadores atômicos (como um bit de referência).
  - *Pró*: Altíssima vazão de leitura com lock-free absoluto.
  - *Contra*: Perda de precisão na evicção, podendo descartar itens que deveriam ser mantidos.

### B. ReaderWriterLockSlim vs. Sharding (Lock Striping)
- **ReaderWriterLockSlim**: É simples e unificado, mas o próprio lock de leitura tem um pequeno overhead de contenção interna nas primitivas do SO para contabilizar os leitores ativos.
- **Lock Striping (Sharding - Recomendado)**: Reduz a contenção física para próximo de zero à medida que o número de shards aumenta.
  - *Contra*: Aumenta o consumo de memória (múltiplas instâncias de listas/dicionários) e o cálculo da capacidade global de itens torna-se impreciso (cada shard tem um limite local que pode não representar o estado global perfeitamente).

### C. Promoção Síncrona vs. Promoção Assíncrona (Read Buffer)
- **Síncrona**: O nó da lista é atualizado no mesmo momento do `Get`. Garante consistência imediata do LRU.
- **Assíncrona (Deferred Update - Recomendada)**: O `Get` apenas joga o evento de acesso em um buffer de anotações (Concurrent Queue) e retorna o dado instantaneamente. A performance de leitura escala ao máximo, mas a ordem LRU pode ficar levemente dessincronizada por breves períodos.