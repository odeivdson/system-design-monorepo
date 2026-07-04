# Desafios de Complexidade $O(\varphi^n)$ (Tempo Exponencial)

## 1. Contexto & Cenário
A complexidade de tempo exponencial, modelada por classes como $O(2^n)$, $O(\varphi^n)$ (onde $\varphi \approx 1.618$ é a proporção áurea) ou pior ($O(n!)$), representa o limite computacional prático. Problemas dessa natureza (geralmente classificados como NP-difíceis ou NP-completos) surgem em otimização de rotas logísticas (Problema do Caixeiro Viajante), empacotamento de contêineres em armazéns (3D Bin Packing) ou geração exaustiva de combinações de chaves criptográficas.

Em sistemas reais, a escala de entrada admissível para esses algoritmos é minúscula: se $n=50$, uma solução exponencial realizaria $2^{50} \approx 1.12 \times 10^{15}$ operações, o que exigiria semanas de execução contínua. Compreender o comportamento exponencial e as árvores de decisão recursivas é fundamental para projetar técnicas de poda de backtracking (Branch-and-Bound) ou converter problemas combinatórios sobrepostos em soluções polinomiais via Programação Dinâmica.

---

## 2. Requisitos Funcionais (RF)

### Desafio 1: Fibonacci Recursivo Ineficiente
- **Input**: Um número inteiro $n$ ($0 \le n \le 30$).
- **Output**: O $n$-ésimo número da sequência de Fibonacci utilizando recursão dupla pura sem armazenamento de estados (memoização) para demonstrar a árvore de recorrência redundante.

### Desafio 2: Geração de Subconjuntos (Power Set) por Força Bruta
- **Input**: Um conjunto contendo $n$ elementos distintos.
- **Output**: Uma lista contendo todos os $2^n$ subconjuntos possíveis (conjunto das partes). O algoritmo deve gerar os resultados através de backtracking combinatório ou máscaras de bits (bitmasks).

### Desafio 3: Caminhos Hamiltonianos por Busca Exaustiva
- **Input**: Um grafo de $n$ vértices e um conjunto de arestas.
- **Output**: Um caminho simples que visita cada vértice exatamente uma vez. Caso não exista tal caminho, retornar uma indicação de falha. A busca deve varrer todas as permutações de caminhos possíveis recursivamente.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Complexidade de Tempo Estrita**: Os algoritmos devem ter complexidade exponencial nativa ($O(\varphi^n)$ para o Fibonacci recursivo duplo e $O(2^n)$ para os subconjuntos).
- **Consumo Controlado de Pilha (Stack Size)**: A profundidade máxima da pilha de recursão não deve exceder $O(n)$ para evitar estouro de pilha (`StackOverflowException`).
- **Poda Antecipada (Pruning)**: No Desafio 3, o algoritmo de busca não deve continuar explorando caminhos parciais que violam as regras do grafo (ex: tentar saltar para um nó sem aresta de conexão direta), implementando backtracking eficiente com backtracking pruning.

---

## 4. Guia de Implementação & Padrões

A complexidade exponencial de Fibonacci recursivo baseia-se na equação matemática de recorrência clássica de bifurcação, como ilustrado no gráfico de referência:

```
                      Equação de Recorrência Exponencial
                             T(n) = T(n-1) + T(n-2)
                                       │
                      ┌────────────────┴────────────────┐
                      ▼                                 ▼
               Subproblema Esquerdo             Subproblema Direito
                     T(n-1)                            T(n-2)
```

### Código e Padrões de Referência:

#### A. Bifurcação Recursiva Pura (Árvore de Recorrência Exponencial)
Utilizado no **Desafio 1**. A execução recursiva dupla sem cache recalcula os mesmos valores repetidamente. A árvore de chamadas expande a uma taxa de crescimento baseada na proporção áurea ($\approx 1.618^n$), resultando em $O(\varphi^n)$:
```csharp
// Padrão de Recorrência Exponencial O(φ^n)
public int FibonacciRecursivo(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    // Bifurcação sem cache: gera árvore de chamadas redundantes
    return FibonacciRecursivo(n - 1) + FibonacciRecursivo(n - 2);
}
```

#### B. Backtracking Combinatório para Subconjuntos
Utilizado no **Desafio 2**. Para gerar todas as $2^n$ combinações, construímos uma árvore de decisão de inclusão/exclusão recursiva para cada elemento:
```csharp
// Padrão de Backtracking O(2^n)
public List<List<int>> GenerateSubsets(int[] nums) {
    var result = new List<List<int>>();
    var currentSubset = new List<int>();
    Backtrack(0, nums, currentSubset, result);
    return result;
}

private void Backtrack(int index, int[] nums, List<int> current, List<List<int>> result) {
    result.Add(new List<int>(current)); // Clona e salva o estado atual
    
    for (int i = index; i < nums.Length; i++) {
        current.Add(nums[i]); // Decisão: incluir elemento
        Backtrack(i + 1, nums, current, result); // Recorre
        current.RemoveAt(current.Count - 1); // Decisão: remover (backtrack)
    }
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prova de Explosão Combinatória**: No Desafio 1, demonstrar analiticamente como o tempo de execução escala exponencialmente para pequenos incrementos de $n$ (ex: comparar latência de $n=15$ vs $n=30$).
- **Garantia de Não Repetição**: No Desafio 2, certificar-se de que os subconjuntos gerados não contenham duplicatas e que o tamanho final da coleção seja exatamente $2^n$.
- **Pilha de Recursão Limpa**: No Desafio 3, garantir que as variáveis locais criadas em cada frame de recursão sejam limpas ou reaproveitadas para não causar esgotamento de memória Heap sob testes intensivos de permutação.

---

## 6. Trade-offs

### A. Fibonacci Recursivo $O(\varphi^n)$ vs. DP Iterativo $O(n)$ vs. Exponenciação de Matriz $O(\log n)$
- **Recursão Dupla $O(\varphi^n)$**:
  - *Contra*: Inviável para uso prático. Serve apenas como modelo acadêmico de ineficiência e representação exponencial.
- **Programação Dinâmica Iterativa $O(n)$**:
  - *Pró*: Otimiza o tempo para linear guardando estados anteriores em memória (ou apenas duas variáveis), reduzindo drasticamente a carga do processador.
- **Exponenciação de Matrizes $O(\log n)$**:
  - *Pró*: Aceleração matemática usando propriedades de matrizes e divisão logarítmica. Ideal para valores gigantescos de $n$ ($n > 10^9$).

### B. Algoritmo Combinatório Exato (Exponencial) vs. Heurísticas Aproximadas (Polinomial)
- **Algoritmo Combinatório Exato**:
  - *Pró*: Garante encontrar a solução ótima absoluta ou todas as combinações reais possíveis (indispensável para criptografia ou subconjuntos matemáticos).
  - *Contra*: Limitação severa de escala ($n$ não pode passar de algumas poucas dezenas).
- **Heurísticas Aproximadas (ex: Algoritmos Gulosos, Simulated Annealing)**:
  - *Pró*: Encontra soluções de altíssima qualidade em tempo polinomial ($O(n \log n)$ ou $O(n^2)$) para entradas gigantescas (ex: roteamento de frotas com milhares de destinos).
  - *Contra*: Não garante encontrar a melhor solução ótima teórica, apenas uma resposta "boa o suficiente".
