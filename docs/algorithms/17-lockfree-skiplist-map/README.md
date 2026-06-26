# Desafio 17: SkipList Concorrente Lock-Free Baseada em CAS (`algo-lockfree-skiplist-map`)

## 1. Contexto & Cenário
Dicionários e mapas que mantêm suas chaves permanentemente ordenadas (Sorted Maps) são estruturas fundamentais para bancos de dados que suportam consultas por intervalo (Range Queries) eficientes. Árvores de busca binária balanceadas clássicas (como Árvores AVL ou Vermelho-Preto) garantem complexidade de tempo de pesquisa em $O(\log N)$. No entanto, adaptar essas estruturas para ambientes concorrentes de alta performance é extremamente complexo. Operações de inserção e remoção exigem **rotações** de nós para manter o balanceamento da árvore. As rotações afetam múltiplos nós em diferentes ramificações da estrutura de dados de forma não-local, tornando quase impossível projetar algoritmos de sincronização de granularidade fina eficientes, levando a gargalos massivos de travamento.

Uma alternativa elegante e probabilística para contornar esse problema é a **SkipList**. Em vez de manter uma árvore balanceada rígida, a SkipList organiza os dados em várias camadas de listas ligadas ordenadas sobrepostas. A camada mais inferior contém todos os nós ordenados, enquanto as camadas superiores atuam como "atalhos" rápidos para saltar grandes trechos da lista, resultando em complexidades médias de $O(\log N)$ para buscas, inserções e deleções.

A principal vantagem da SkipList reside na localidade das suas modificações de ponteiro. Inserir ou remover um nó afeta apenas os nós adjacentes imediatos de cada nível envolvido. Essa característica local permite a implementação de algoritmos **Lock-Free (livres de bloqueio)**, onde múltiplas threads modificam a estrutura simultaneamente sem utilizar exclusão mútua (locks), valendo-se exclusivamente de operações atômicas baseadas em hardware (Compare-And-Swap - CAS). Essa estrutura serve como coração de motores de armazenamento em memória ultra-rápidos, como a MemTable do RocksDB e o Cassandra.

---

## 2. Requisitos Funcionais (RF)
- **Operação Put (`Put`)**: Inserir ou atualizar uma chave e seu valor no mapa ordenado em tempo de complexidade média $O(\log N)$.
- **Operação Get (`Get`)**: Buscar o valor associado a uma chave em tempo de complexidade média $O(\log N)$.
- **Operação Remove (`Remove`)**: Excluir uma chave e seu valor associado do mapa em tempo de complexidade média $O(\log N)$.
- **Consulta por Intervalo (`GetRange`)**: Retornar os itens cujas chaves estejam compreendidas entre um valor inicial e final (`startKey`, `endKey`) de forma ordenada em tempo proporcional ao número de itens retornados.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Concorrência Livre de Bloqueio (Lock-Free)**: Nenhuma thread produtora ou consumidora pode bloquear ou dormir (sleep) aguardando mutexes. Toda a coordenação concorrente deve ser obtida via operações atômicas de CPU (Compare-And-Swap / CAS).
- **Consistência de Travessia Concorrente**: Threads que executam buscas (`Get`) ou varreduras de intervalo (`GetRange`) não devem bloquear nem ler estados corrompidos ou ponteiros órfãos enquanto outras threads inserem ou deletam nós simultaneamente.
- **Marcação de Ponteiros (Pointer Tagging)**: Para evitar condições de corrida em que uma inserção ocorre adjacente a um nó que está sendo deletado concorrentemente, o algoritmo deve usar marcação lógica do ponteiro de próximo nó antes de desvinculá-lo fisicamente.

---

## 4. Guia de Implementação & Padrões

Cada nó possui uma lista (ou array) de ponteiros `Next`, cuja altura (número de níveis) é determinada probabilisticamente no momento da criação por um gerador baseado em lançamentos sucessivos de moedas (ex: probabilidade de 50% de crescer mais um nível, limitado a um nível máximo).

```
 Nível 3: [Head] ───────────────────────► [30] ───────────────────────► [Tail]
 Nível 2: [Head] ──────────► [15] ──────► [30] ──────────► [45] ──────► [Tail]
 Nível 1: [Head] ──► [10] ──► [15] ──► [20] ──► [30] ──► [42] ──► [45] ──► [Tail]
```

### Padrões e Algoritmos Recomendados:
- **Compare-And-Swap (CAS)**: Usar primitivas do sistema operacional (ex: `Interlocked.CompareExchange` em C#, `AtomicReference` em Java, ou `atomic.CompareAndSwapPointer` em Go) para alternar ponteiros de forma atômica e segura.
- **Logical Deletion (Tagging/Marking)**: A remoção de um nó deve ser feita em duas etapas físicas distintas:
  1. **Deleção Lógica**: Marcar o bit menos significativo (LSB) do ponteiro `Next` do nó como deletado. Threads que cruzarem o nó perceberão que ele foi desativado e cooperarão com a remoção física.
  2. **Deleção Física**: Efetuar o desvio dos ponteiros `Next` dos nós antecessores por meio de operações CAS.
- **Nó Sentinela de Cabeça e Cauda (Head & Tail)**: Manter nós sentinelas fixos para simplificar os algoritmos de borda e evitar verificações nulas desnecessárias durante a navegação.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prevenção da Condição de Corrida de Inserção vs. Deleção Adjacente**: Demonstração de que o código previne que uma nova chave seja inserida imediatamente após um nó que acabou de ser excluído, evitando que o novo nó fique permanentemente "perdido" (inacessível) na lista.
- **Cooperação de Limpeza Física (Helping/Cooperative Cleanups)**: Quando uma busca ou inserção encontra um nó marcado logicamente para deleção, a thread em execução deve auxiliar no desvio do ponteiro (limpeza física) em vez de simplesmente falhar ou reiniciar a travessia do zero.
- **Escalabilidade Multicore Linear**: Comprovação de que a vazão agregada do mapa escala linearmente de acordo com a adição de núcleos de processador de CPU ativos, demonstrando ausência total de contenda.

---

## 6. Trade-offs

### A. SkipList Concorrente vs. Árvores B+ Concorrentes (ex: B-Link Tree)
- **SkipList Lock-Free**: Muito mais simples de codificar e implementar de forma correta sem locks. Possui ótimo desempenho para inserções aleatórias.
  - *Contra*: Maior consumo de memória devido à redundância de ponteiros em múltiplos níveis e pior localidade de cache de CPU em comparação com arrays em nós de árvores B.
- **B-Link Tree (Árvore B+ com ponteiros laterais)**: Melhor localidade de cache (dados contíguos em memória) e menor uso geral de ponteiros.
  - *Contra*: Complexidade extrema de desenvolvimento seguro livre de deadlocks sob modificações de nós concorrentes que geram divisões e fusões de blocos físicos de armazenamento.

### B. Logical Tagging vs. Read-Write Locks
- **Logical Tagging (CAS-based)**: Garante progresso global do sistema (Non-blocking Guarantee), com threads de leitura nunca bloqueando sob escrita.
  - *Contra*: Implementação complexa e chance de requisições de gravação falharem em loops de CAS se houver contenção ultra-agressiva na mesma posição, exigindo estratégias de recuo (Backoff).
- **Read-Write Locks por Segmento**: Simples de entender e implementar.
  - *Contra*: Ocorrência inevitável de bloqueios físicos temporários de threads leitoras sob atualizações consecutivas de escrita.
