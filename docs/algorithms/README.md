# Guia de Treinamento: Algoritmos de Alta Performance e Padrões de Código

Este guia serve como a matriz de referência definitiva para treinar e compreender padrões algorítmicos e estruturas de dados de alta performance em escala de sistemas distribuídos e concorrência crítica de Big Techs. Ele conecta padrões clássicos de codificação (como Sliding Window, Two Heaps e Topological Sort) a desafios práticos de engenharia presentes neste monorepo.

---

## 1. O Princípio de Treinamento de Elite: Algoritmos Reais vs. LeetCode Acadêmico
Na engenharia de software de alto nível (Senior Staff/Principal), algoritmos não são apenas quebra-cabeças lógicos abstratos resolvidos em uma única thread ou classe simples. Eles são avaliados a partir de:
* **Concorrência Segura (Thread-safety) e Baixa Contenda**: Como a estrutura de dados gerencia concorrência (ex: Lock-Free CAS, Lock Striping, RWLocks) sem estrangular a CPU sob alta concorrência de múltiplos leitores e escritores.
* **Eficiência de Memória e GC Pressure**: Evitar alocações excessivas na heap (alocadores customizados, reutilização de arrays, bitsets compactos) para impedir pausas severas de Garbage Collection (Stop-The-World) em sistemas de baixa latência.
* **Localidade de Cache e Hardware**: Desenvolver layouts de memória eficientes que respeitem as linhas de cache de CPU (Cache Line Friendly), otimizando a latência de acesso aos dados.

---

## 2. Treinamento de Fundamentos: Complexidade de Tempo (Big-O)
Antes de avançar para os padrões algorítmicos complexos de concorrência e de nível de infraestrutura, é indispensável dominar a análise de complexidade de tempo de pior caso ($Big-O$) e a identificação de padrões estruturais de código.
* **Módulo de Fundamentos**: [Desafios de Complexidade de Tempo](./00-time-complexity-challenges/README.md)
* **Objetivo**: Estudar e reconhecer de forma imediata laços lineares ($O(n)$), divisões logarítmicas ($O(\log n)$), ordenação e divisões ($O(n \log n)$), laços aninhados ($O(n^2)$) e recorrências exponenciais ($O(\varphi^n)$) através de 15 desafios focados.

---

## 3. Matriz de Cobertura e Mapeamento: 15 Padrões Essenciais de Código (JavaRevisited)

Aqui, mapeamos os 15 padrões de código essenciais consagrados na preparação técnica, readequados para cenários práticos e escaláveis no monorepo:

### 1. Two Pointers
* **Descrição Teórica**: Uso de dois índices para iterar sobre uma estrutura linear de forma convergente, reduzindo a complexidade de tempo de $O(N^2)$ para $O(N)$.
* **Onde treinar no Monorepo**: [09-search-similarity](./09-search-similarity/README.md).
* **Foco Staff**: Otimização de busca e cálculo dinâmico de distância/similaridade entre sequências de caracteres de forma linear com varredura bidirecional compacta para limitar uso de CPU.

### 2. Fast and Slow Pointers (Ciclos)
* **Descrição Teórica**: Algoritmo de Tortoise and Hare para detectar ciclos e loops em estruturas ligadas em tempo $O(N)$ e espaço $O(1)$.
* **Onde treinar no Monorepo**: [10-dependency-resolver](./10-dependency-resolver/README.md).
* **Foco Staff**: Detecção de ciclos em grafos direcionados complexos (DAG) em tempo de carregamento ou inicialização de microsserviços. Implementado via algoritmo DFS com coloração de nós (Branco, Cinza, Preto) para evitar loops infinitos de dependências cruzadas.

### 3. Sliding Window
* **Descrição Teórica**: Subconjunto dinâmico deslizante sobre um array/fluxo para rastrear sub-valores contíguos de forma contínua.
* **Onde treinar no Monorepo**: [11-sliding-window-extremes](./11-sliding-window-extremes/README.md) e [01-rate-limiter-local](../microservices/01-rate-limiter-local/README.md).
* **Foco Staff**: Uso de fila monotônica (Deque) para obter extremos de janela em $O(1)$ constante sob fluxo contínuo de milhões de requisições de métricas e limites temporais.

### 4. Merge Intervals
* **Descrição Teórica**: Fusão e consolidação de intervalos numéricos ou temporais sobrepostos.
* **Onde treinar no Monorepo**: [12-ip-range-lookup](./12-ip-range-lookup/README.md).
* **Foco Staff**: Fusão e busca hiper-rápida de blocos de faixas CIDR de IPs sobrepostos no Gateway de WAF, garantindo tempos de lookup de $O(\log N)$ em árvores de intervalos ou árvores de segmentos compactas.

### 5. Cyclic Sort
* **Descrição Teórica**: Ordenação in-place em tempo linear aproveitando que os elementos pertencem a uma faixa numérica conhecida (1 a N).
* **Foco Staff**: Justificativa e Alternativas: O padrão acadêmico é frágil para sistemas de concorrência distribuída. Em produção real, para deduplicação e checagem de presença sem memória extra, usamos estruturas baseadas em hashes probabilísticos, como no [05-concurrent-bloom-filter](./05-concurrent-bloom-filter/README.md).

### 6. In-place Reversal of a Linked List
* **Descrição Teórica**: Reversão ou manipulação direta de ponteiros em listas ligadas sem alocação extra de memória.
* **Onde treinar no Monorepo**: [01-threadsafe-lru-cache](./01-threadsafe-lru-cache/README.md) e [04-hierarchical-timer-wheel](./04-hierarchical-timer-wheel/README.md).
* **Foco Staff**: Manipulação atômica de ponteiros de listas duplamente ligadas em sistemas de cache de evicção concorrente e listas de tarefas agendadas na Timer Wheel sob concorrência rigorosa de threads e locks refinados.

### 7. Tree Breadth-First Search (BFS)
* **Descrição Teórica**: Travessia por níveis utilizando filas (Queue) para encontrar o caminho mais curto ou elementos no mesmo nível de profundidade.
* **Onde treinar no Monorepo**: [10-dependency-resolver](./10-dependency-resolver/README.md).
* **Foco Staff**: Execução paralela e ordenada de tarefas independentes usando o algoritmo de Ordenação Topológica de Kahn estruturado em BFS reativa com filas de tarefas com In-Degree zero.

### 8. Tree Depth-First Search (DFS)
* **Descrição Teórica**: Exploração recursiva até as folhas de uma ramificação antes do backtracking.
* **Onde treinar no Monorepo**: [10-dependency-resolver](./10-dependency-resolver/README.md) e [09-search-similarity](./09-search-similarity/README.md).
* **Foco Staff**: Pesquisa recursiva de padrões ou ordenação topológica reversa (Tarjan) com prevenção estruturada de estouro de pilha (StackOverflow) através de pilhas explícitas ou recursões controladas.

### 9. Two Heaps
* **Descrição Teórica**: Manutenção coordenada de dois Heaps (Min-Heap e Max-Heap) para monitoramento dinâmico de elementos medianos ou de alta prioridade.
* **Onde treinar no Monorepo**: [03-high-performance-trie](./03-high-performance-trie/README.md) e [07-delivery-routing](./07-delivery-routing/README.md).
* **Foco Staff**: Min-Heap local atômica e coordenada em buckets concorrentes para rastrear dinamicamente os termos de autocomplete mais frequentes (Top-K) e Priority Queues para algoritmos de roteamento de entregas.

### 10. Subsets
* **Descrição Teórica**: Geração exaustiva de todas as combinações ou subconjuntos possíveis através de backtracking.
* **Onde treinar no Monorepo**: [08-warehouse-packing](./08-warehouse-packing/README.md).
* **Foco Staff**: Resolução ótima de problemas NP-Hard de distribuição e empacotamento tridimensional (3D Bin Packing) usando técnicas combinatórias com podas rápidas e heurísticas de limite superior (Branch-and-Bound).

### 11. Modified Binary Search
* **Descrição Teórica**: Variações da busca binária clássica sobre conjuntos de dados especiais (arrays rotacionados, intervalos contínuos ou anéis virtuais).
* **Onde treinar no Monorepo**: [07-consistent-hashing-ring](../microservices/07-consistent-hashing-ring/README.md).
* **Foco Staff**: Busca binária customizada (`binarySearch` / `bisect`) no anel circular de nós virtuais de Consistent Hashing para associar chaves de requisição a nós de destino eficientemente em $O(\log N)$.

### 12. Top 'K' Elements
* **Descrição Teórica**: Localização dos K maiores ou menores elementos em um conjunto de dados maciço de forma contínua.
* **Onde treinar no Monorepo**: [03-high-performance-trie](./03-high-performance-trie/README.md).
* **Foco Staff**: Manutenção de sugestões ordenadas diretamente nos nós da árvore Trie atualizadas concorrentemente sem a necessidade de reordenar o dataset completo a cada escrita.

### 13. K-way Merge
* **Descrição Teórica**: Intercalação e fusão ordenada de K fluxos ou arrays já individualmente ordenados.
* **Onde treinar no Monorepo**: [02-log-batching-buffer](./02-log-batching-buffer/README.md).
* **Foco Staff**: Agrupamento concorrente ordenado de múltiplos buffers circulares Thread-Local produtores em uma única esteira de gravação sequencial ordenada no disco (Write-Ahead Log), mitigando contenda de I/O de rede ou disco.

### 14. Topological Sort
* **Descrição Teórica**: Ordenação linear de vértices de um grafo direcionado acíclico (DAG) onde cada vértice precede seus dependentes.
* **Onde treinar no Monorepo**: [10-dependency-resolver](./10-dependency-resolver/README.md).
* **Foco Staff**: Motor de resolução de dependências assíncrona concorrente multi-thread para orquestração de microsserviços do monorepo, isolando tarefas em threads paralelas tão logo suas dependências sejam satisfeitas.

### 15. Dynamic Programming (DP)
* **Descrição Teórica**: Otimização de problemas complexos de decisão que podem ser decompostos em subproblemas sobrepostos com memoização ou tabulação de estados.
* **Onde treinar no Monorepo**: [09-search-similarity](./09-search-similarity/README.md) e [08-warehouse-packing](./08-warehouse-packing/README.md).
* **Foco Staff**: Cálculo de similaridade fuzzy e distância de edição de Levenshtein otimizando o espaço da matriz de estados bidimensional para apenas duas linhas lineares, reduzindo uso de memória de $O(M \times N)$ para $O(\min(M, N))$.

---

## 4. Matriz de Mapeamento: Algoritmos e Estruturas de Dados Avançadas de Big Techs

Aqui estão os algoritmos distribuídos e padrões de controle de fluxo de infraestrutura de alto nível presentes nas pastas de algoritmos:

### 16. Snowflake Distributed ID Generator
* **O Padrão**: Geração de chaves primárias numéricas exclusivas de 64 bits em escala global e distribuída de forma independente por máquina sem coordenação centralizada (ex: ZooKeeper/Redis).
* **Onde treinar no Monorepo**: [06-distributed-id-generator](./06-distributed-id-generator/README.md).
* **Foco Staff**: Coordenação e alocação atômica de bits (Timestamp, Machine ID, Sequence) com tratamento robusto de recuo de relógio de hardware (Clock Drift) e concorrência Thread-Safe em altíssima vazão de requisições.

### 17. Single-Flight (Request Collapsing)
* **O Padrão**: Mitigação de Cache Stampede e Thundering Herd via colapso dinâmico de múltiplas requisições de leitura idênticas simultâneas em trânsito em uma única chamada física ao banco de dados downstream.
* **Onde treinar no Monorepo**: [13-singleflight-collapsing](./13-singleflight-collapsing/README.md).
* **Foco Staff**: Estrutura de dados concorrente (Concurrent Dictionary de promessas e canais de resposta) livre de travas pesadas para gerenciar acessos e replicação segura de erros.

### 18. Fencing Tokens e Leases
* **O Padrão**: Proteção contra escritas corrompidas na base de dados final por parte de workers lentos ou atrasados por pausas de Garbage Collection (STW) através da inclusão de tokens monotônicos sequenciais nas transações.
* **Onde treinar no Monorepo**: [14-fencing-token-locks](./14-fencing-token-locks/README.md).
* **Foco Staff**: Garantia técnica de exclusão mútua distribuída confiável que detecta tokens defasados diretamente no armazenamento físico (Optimistic Locks) de forma robusta e livre de race conditions.

### 19. Controle de Fluxo e Backpressure reativo (Bounded Buffers)
* **O Padrão**: Regulagem e sinalização de taxa de vazão de dados entre threads produtoras rápidas e threads consumidoras lentas para prevenir vazamento de memória por buffers sem limites (OOM).
* **Onde treinar no Monorepo**: [15-stream-backpressure-buffer](./15-stream-backpressure-buffer/README.md).
* **Foco Staff**: Semáforos e travas de sincronização de baixo nível baseados em limites máximos (High Watermark) e mínimos (Low Watermark) para bloqueio inteligente de CPU de produtores e estratégias de descarte ou desaceleração sob carga extrema.

### 20. Índice Espacial Quadtree Concorrente
* **O Padrão**: Particionamento recursivo do espaço 2D em quatro quadrantes para busca e indexação eficiente de proximidade geológica em tempo real (problema do Uber/Yelp).
* **Onde treinar no Monorepo**: [16-spatial-quadtree-matching](./16-spatial-quadtree-matching/README.md).
* **Foco Staff**: Sincronização concorrente de granularidade fina por nó (`ReaderWriterLockSlim`) para atualizações intensas de GPS e prevenção de deadlocks no movimento de motoristas entre divisas de quadrantes.

### 21. SkipList Concorrente Lock-Free (CAS)
* **O Padrão**: Lista encadeada ordenada probabilística de múltiplos níveis para busca $O(\log N)$ concorrente escalável sem contenção de locks de exclusão mútua.
* **Onde treinar no Monorepo**: [17-lockfree-skiplist-map](./17-lockfree-skiplist-map/README.md).
* **Foco Staff**: Manipulação de ponteiros concorrentes com operações atômicas baseadas em hardware (Compare-And-Swap) e marcação lógica de ponteiros deletados (Pointer Tagging) para segurança concorrente.

### 22. Motor de Armazenamento LSM-Tree Minimal
* **O Padrão**: Otimização de I/O de escrita sequencial unificando inserções em buffers de memória (MemTables) ordenados, persistência durável em logs (WAL) e flush para arquivos ordenados imutáveis (SSTables) consolidados via Merge-Sort em background (Compaction).
* **Onde treinar no Monorepo**: [18-lsm-storage-engine](./18-lsm-storage-engine/README.md).
* **Foco Staff**: Coordenação não-bloqueante na troca de tabelas de escrita ativas e imutáveis, controle de concorrência contra threads paralelas de flush/compactação e filtros Bloom de alto acerto.

### 23. Estimador de Cardinalidade HyperLogLog
* **O Padrão**: Estimativa probabilística rápida de elementos únicos em streams massivos de alta vazão com consumo constante $O(1)$ de memória RAM em escala de poucos kilobytes.
* **Onde treinar no Monorepo**: [19-hyperloglog-cardinality](./19-hyperloglog-cardinality/README.md).
* **Foco Staff**: Otimizações bitwise de baixo nível (instrução CLZ de CPU para contagem de zeros à esquerda), computação de médias harmônicas imunes a ruídos e correções matemáticas de pequeno/médio range de contagem.

### 24. Union-Find Concorrente Lock-Free (CAS)
* **O Padrão**: Agrupamento dinâmico de elementos (Disjoint Set Union) com operações de união e busca concorrentes livre de locks, garantindo consistência por meio de Compare-And-Swap (CAS) e Path Halving de passagem única.
* **Onde treinar no Monorepo**: [20-concurrent-union-find](./20-concurrent-union-find/README.md).
* **Foco Staff**: Empregar união concorrente ordenada e compressão de caminho atômica por desempate numérico para prevenir loops infinitos e deadlocks lógicos sob threads concorrentes agressivas.

### 25. Agrupamento de Redes de Fraude (DSU Aplicado)
* **O Padrão**: Consolidação e rastreamento dinâmico e incremental de redes de fraudadores baseadas em transações ativas e atributos cadastrais compartilhados (IP, dispositivo), operando em tempo quase constante.
* **Onde treinar no Monorepo**: [21-fraud-network-clustering](./21-fraud-network-clustering/README.md).
* **Foco Staff**: Lidar com processamento incremental de fluxo de alta vazão com acúmulo exato de tamanhos de conjunto nas uniões, evitando re-processar caminhos inteiros por buscas de grafos tradicionais lineares ($O(V+E)$).

### 26. Motor de Ordenação de Baixa Latência (HFT & Bancos de Dados)
* **O Padrão**: Ordenação física otimizada em memória contígua contornando o limite matemático de comparações via Radix Sort Bitwise $O(n)$ ou Merge Sort estável com buffer pooling pré-alocado.
* **Onde treinar no Monorepo**: [22-sorting-algorithms](./22-sorting-algorithms/README.md).
* **Foco Staff**: Empregar micro-otimizações como zero alocação de Heap, substituição de comparadores virtuais por inline primitivos e acoplamento híbrido com Insertion Sort para subarrays curtos.



