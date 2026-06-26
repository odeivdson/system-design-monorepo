# Desafio 17: Resolutor de Dependências com Grafo Acíclico Direcionado - DAG (`algo-dependency-resolver`)

## 1. Contexto & Cenário
Em grandes sistemas baseados em microsserviços, gerenciadores de pacotes (como npm, NuGet ou Maven) ou motores de compilação de código e orquestração de tarefas, o controle de ordem de execução e dependências entre componentes é uma funcionalidade essencial. Por exemplo, ao iniciar uma aplicação composta por múltiplos serviços, o banco de dados de autenticação deve subir antes do microsserviço de usuários, que por sua vez deve estar pronto antes do microsserviço de checkout.

Esse relacionamento é modelado como um **Grafo Direcionado Acíclico (DAG - Directed Acyclic Graph)**, onde os vértices representam tarefas ou serviços e as arestas direcionadas representam dependências obrigatórias de execução. Resolver esse problema em estilo de testes de Big Tech exige projetar um algoritmo que determine uma ordem linear de execução válida para todas as tarefas (resolução topológica) e detecte instantaneamente falhas catastróficas, como dependências circulares (loops, ex: A depende de B, que depende de C, que depende de A), retornando uma indicação de erro clara.

---

## 2. Requisitos Funcionais (RF)
- **Input de Dados**:
  - Lista de tarefas/serviços (strings ou identificadores numéricos).
  - Lista de dependências direcionadas expressas na forma de pares `(A, B)` (significando que a tarefa A depende da conclusão prévia da tarefa B).
- **Ordenação Linear de Execução**: Produzir uma sequência de tarefas que respeite todas as restrições de precedência (uma tarefa só aparece na lista de saída após todas as suas dependências estarem resolvidas).
- **Detecção de Ciclos**: Validar se o grafo fornecido possui ciclos (Loops) e, em caso positivo, apontar quais nós fazem parte do ciclo para fins de diagnóstico e depuração.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Complexidade de Tempo Linear $O(V + E)$**: A ordenação topológica e a detecção de ciclos devem rodar em tempo linear em relação ao número de vértices (V) e arestas (E) do grafo, evitando algoritmos de busca ineficientes de $O(V^2)$ ou pior.
- **Thread-Safety e Imutabilidade**: O resolvedor de dependências deve processar buscas simultâneas para diferentes grafos em threads paralelas sem compartilhar estado global.
- **Gerenciamento de Stack Overflow**: Para grafos extremamente profundos (ex: cadeias de dependências com profundidade $> 10.000$ nós), o uso de DFS recursivo padrão pode estourar a pilha do sistema. O algoritmo deve utilizar implementações iterativas ou controle estrito de recursão profunda.

---

## 4. Guia de Implementação & Padrões
A resolução do grafo baseia-se na travessia e ordenação topológica do DAG, que pode ser implementada utilizando o **Algoritmo de Kahn (Baseado em BFS)** ou uma variação do **Algoritmo de Tarjan (Baseado em DFS)** com detecção de ciclo por coloração de nós.

```
       Grafo de Dependências (DAG)
            [ Servidor Web ]
             /            \  (depende de)
            ▼              ▼
     [ Auth Service ]    [ Billing Service ]
            \              /
             ▼            ▼
             [ Database DB ]

   * Ordenação Topológica Válida:
     Database DB -> Auth Service -> Billing Service -> Servidor Web
```

### Algoritmos Recomendados:
- **Algoritmo de Kahn (Baseado em Grau de Entrada - In-degree)**:
  1. Calcular o grau de entrada (in-degree) para cada vértice (número de arestas direcionadas chegando a ele).
  2. Enfileirar (Queue) todos os vértices que possuem grau de entrada igual a 0 (nós independentes).
  3. Enquanto a fila não estiver vazia, remover um vértice $U$, adicioná-lo à ordem final de execução e diminuir o grau de entrada de todos os seus nós vizinhos. Se um vizinho chegar a grau de entrada 0, inseri-lo na fila.
  4. Se o número de nós na ordem final for menor que o número total de nós do grafo, há pelo menos um ciclo.
- **DFS com Coloração de Nós (Tarjan / Kahn adaptado)**:
  - Rastrear o estado de visita dos nós usando 3 cores/estados:
    - *Branco (Não visitado)*: Nó ainda não processado.
    - *Cinza (Visitando)*: Nó em processamento na pilha de recursão atual. Se encontrarmos um nó cinza durante a travessia, **um ciclo foi detectado**.
    - *Preto (Concluído)*: Nó e todos os seus descendentes totalmente processados.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Detecção Precisa de Ciclos**: O algoritmo não pode entrar em loop infinito ao receber um grafo cíclico. Ele deve falhar de forma elegante lançando uma exceção informativa (ex: `CyclicDependencyException` contendo o caminho do loop).
- **Resiliência a Nós Isolados**: O algoritmo deve lidar corretamente com nós que não possuem nenhuma conexão ou dependência, ordenando-os de forma válida.
- **Implementação Sem Alocação Excessiva**: Evitar instanciar listas e arrays temporários de tamanho dinâmico a cada passo de travessia. Usar arrays indexados primitivos para representar o In-degree e as visitas.

---

## 6. Trade-offs

### A. Algoritmo de Kahn (BFS-based) vs. DFS com Coloração
- **Algoritmo de Kahn (BFS)**:
  - *Pró*: Detecta ciclos de forma muito simples e natural (basta checar se a quantidade de nós processados é igual ao total de nós). Não corre risco de Stack Overflow pois utiliza uma fila (`Queue`) alocada no Heap em vez da pilha de chamada de métodos.
  - *Contra*: Requer o cálculo e manutenção inicial do grau de entrada de todos os nós em memória.
- **DFS com Coloração**:
  - *Pró*: Permite identificar o caminho exato do ciclo facilmente olhando os nós atualmente cinzas na pilha.
  - *Contra*: Vulnerabilidade a estouro de pilha (Stack Overflow) em grafos muito profundos e estreitos se implementado de forma recursiva ingênua.

### B. Representação do Grafo: Lista de Adjacência vs. Matriz de Adjacência
- **Lista de Adjacência (Recomendada)**:
  - *Pró*: Economia colossal de memória para grafos esparsos (que possuem poucas conexões entre nós). A travessia de vizinhos de um nó roda em $O(\text{grau de saída})$, que é muito rápido.
  - *Contra*: Verificar se existe uma aresta específica de A para B roda em $O(V)$ no pior caso.
- **Matriz de Adjacência**:
  - *Pró*: Verificar conexões diretas entre A e B em tempo constante $O(1)$.
  - *Contra*: Consumo inaceitável de memória de $O(V^2)$, inviável para grafos com milhares de nós. A travessia dos vizinhos é lenta, pois sempre exige avaliar linearmente uma linha inteira de tamanho $V$.
