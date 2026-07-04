# Desafios de Complexidade $O(n^2)$ (Tempo Quadrático)

## 1. Contexto & Cenário
A complexidade de tempo quadrática $O(n^2)$ é típica de algoritmos baseados em comparação pareada exaustiva ou força bruta (brute-force). Em sistemas de produção de alta escala, soluções quadráticas geralmente representam gargalos graves: processar $10^5$ elementos em tempo linear leva frações de segundo, enquanto em tempo quadrático exige $10^{10}$ operações, travando threads e exaurindo a CPU. 

No entanto, compreender a mecânica de laços quadráticos é essencial para identificar e refatorar gargalos de código. Além disso, em cenários específicos onde o tamanho da entrada é garantidamente pequeno ($n \le 100$), algoritmos quadráticos simples (como Insertion Sort ou buscas em matrizes pequenas) podem ser preferíveis devido aos coeficientes constantes extremamente baixos e à ausência de sobrecarga de alocação de memória (GC pressure).

---

## 2. Requisitos Funcionais (RF)

### Desafio 1: Busca de Soma de Pares por Força Bruta
- **Input**: Um array de inteiros $A$ de tamanho $n$ e um valor alvo `target`.
- **Output**: Uma lista contendo todos os pares únicos de índices $(i, j)$ tais que $A[i] + A[j] = \text{target}$ com $i \neq j$. A solução deve comparar todos os elementos de forma cruzada sem otimizações de conjuntos/hashes.

### Desafio 2: Análise de Substrings por Força Bruta
- **Input**: Duas strings, $S$ (tamanho $n$) e $T$ (tamanho $m$).
- **Output**: A maior substring comum entre $S$ e $T$, encontrada comparando-se exaustivamente todas as combinações de substrings de $S$ e $T$.

### Desafio 3: Detecção de Ciclos em Matriz de Adjacência
- **Input**: Um grafo de $n$ vértices representado por uma Matriz de Adjacência $M$ de tamanho $n \times n$ (onde $M[i][j] = 1$ indica uma aresta direcionada de $i$ para $j$).
- **Output**: Um booleano indicando se o grafo contém algum ciclo direcionado. O algoritmo deve verificar as relações vasculhando a matriz de adjacência.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Complexidade de Tempo Aceitável**: Os algoritmos devem operar dentro do limite de complexidade quadrática de pior caso $O(n^2)$.
- **Prevenção de Complexidade Pior ($O(n^3)$)**: No Desafio 2, certificar-se de que a comparação de substrings não contenha operações lineares redundantes dentro dos laços aninhados, o que elevaria o algoritmo a complexidades cúbicas.
- **Complexidade de Espaço Adicional**: Deve ser mantida em $O(1)$ nos Desafios 1 e 2, forçando o uso de varredura *in-place* sobre os ponteiros de arrays/strings existentes.

---

## 4. Guia de Implementação & Padrões

A complexidade quadrática é gerada tipicamente por estruturas de laços de repetição aninhados (loops dentro de loops). O gráfico de referência apresenta duas variações comuns:

```
[Padrão 1: Laço Duplo Completo]     [Padrão 2: Laço Duplo Triangular (J < I)]
  for (int i=0; i<n; i++)              for (int i=0; i<n; i++)
    for (int j=0; j<n; j++)              for (int j=0; j<i; j++)
            │                                    │
            ▼                                    ▼
    O(n^2) - Matriz Completa             n(n-1)/2 = O(n^2) - Comparação Cruzada
```

### Código e Padrões de Referência:

#### A. Laço Duplo Triangular (Busca Pareada In-place)
Utilizado no **Desafio 1**. Para comparar todos os pares possíveis evitando auto-comparações ($i = j$) e comparações duplicadas em ordens invertidas (verificar $(A[i], A[j])$ e depois $(A[j], A[i])$), estruturamos o laço interno iniciando de $i + 1$:
```csharp
// Padrão de Laço Triangular O(n^2) com espaço O(1)
List<(int, int)> pairs = new List<(int, int)>();
for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) { // Laço inicia após 'i'
        if (array[i] + array[j] == target) {
            pairs.Add((i, j));
        }
    }
}
```

#### B. Busca em Matriz de Adjacência Completa
Utilizado no **Desafio 3**. A busca por conexões em grafos densos estruturados em matriz de adjacência de tamanho $n \times n$ é naturalmente quadrática. Para a detecção de ciclos, combinamos a varredura das linhas e colunas ao controle de estados de recursão (DFS com coloração de nós):
```csharp
// Padrão de Detecção de Ciclos com Matriz de Adjacência O(n^2)
public bool HasCycle(int[,] adjMatrix, int numVertices) {
    int[] state = new int[numVertices]; // 0: não visitado, 1: visitando, 2: visitado
    for (int i = 0; i < numVertices; i++) {
        if (state[i] == 0) {
            if (DfsCheck(i, adjMatrix, state, numVertices)) return true;
        }
    }
    return false;
}

private bool DfsCheck(int u, int[,] matrix, int[] state, int n) {
    state[u] = 1; // Marca como "visitando" (na pilha atual)
    for (int v = 0; v < n; v++) {
        if (matrix[u, v] == 1) { // Aresta existe
            if (state[v] == 1) return true; // Ciclo detectado!
            if (state[v] == 0 && DfsCheck(v, matrix, state, n)) return true;
        }
    }
    state[u] = 2; // Visitado completamente
    return false;
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Evitar Duplicação de Pares**: Garantir que se a entrada contém valores duplicados, apenas pares de índices únicos sejam retornados.
- **Controle Preciso de Substrings**: No Desafio 2, a extração de substrings não deve alocar novas strings intermediárias para comparação (evitando o garbage collection excessivo). A comparação deve ser baseada em correspondência de caracteres nos índices originais das strings.
- **Tratamento de Grafos Desconexos**: O detector de ciclos deve ser capaz de avaliar corretamente grafos com ilhas (subgrafos desconexos), garantindo que todos os vértices sejam cobertos pela varredura inicial.

---

## 6. Trade-offs

### A. Two-Sum Quadrático $O(n^2)$ vs. Linear $O(n)$ com Set/Hash
- **Solução Quadrática $O(n^2)$**:
  - *Pró*: Complexidade espacial de $O(1)$. Não necessita de alocação de tabelas de símbolos na Heap.
  - *Contra*: Performance degrada severamente com $n$ grande.
- **Solução Linear $O(n)$ usando HashSet**:
  - *Pró*: Roda em $O(n)$ de tempo.
  - *Contra*: Ocupa $O(n)$ de espaço adicional. Em microcontroladores ou loops restritos em hardware de baixa memória, o espaço extra de tabelas hash pode ser inviável.

### B. Matriz de Adjacência $O(v^2)$ vs. Lista de Adjacência $O(v + e)$
- **Matriz de Adjacência**:
  - *Pró*: Verificação de existência de aresta específica em tempo constante $O(1)$. Ideal para grafos densos (onde o número de arestas $e \approx v^2$).
  - *Contra*: Consumo de memória fixo de $O(v^2)$ mesmo que o grafo tenha poucas arestas (grafo esparso).
- **Lista de Adjacência**:
  - *Pró*: Consumo de memória ideal para grafos esparsos.
  - *Contra*: A verificação de arestas requer percorrer a lista de vizinhos do vértice, levando tempo proporcional ao grau do nó.
