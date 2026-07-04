# Desafios de Complexidade $O(n \log n)$ (Tempo Linear-Logarítmico)

## 1. Contexto & Cenário
A complexidade de tempo linear-logarítmica $O(n \log n)$ é o limite inferior matemático para qualquer algoritmo de ordenação baseado em comparações. Ela representa a eficiência ideal para agrupar e organizar grandes volumes de dados desordenados. Em infraestruturas de dados modernas, o padrão $O(n \log n)$ é amplamente aplicado na consolidação de logs distribuídos (Write-Ahead Logs em bancos LSM), na ordenação de resultados de motores de busca, e na reconciliação de logs de auditoria financeira.

O comportamento linear-logarítmico surge da estratégia de Dividir para Conquistar, onde dividimos repetidamente o conjunto de dados ao meio (gerando uma árvore de chamadas de altura $\log n$) e realizamos uma operação linear de processamento ou intercalação de tamanho $n$ em cada nível da árvore.

---

## 2. Requisitos Funcionais (RF)

### Desafio 1: Ordenação de Objetos por Prioridade Composta
- **Input**: Uma coleção de $n$ objetos complexos (ex: Tarefas de Sistema com ID, Urgência, Tempo de Espera e Peso do Usuário).
- **Output**: A coleção ordenada em ordem decrescente de acordo com um critério de prioridade composta (ex: ordenar por Urgência primeiro; em caso de empate, pelo maior Tempo de Espera; em caso de novo empate, pelo menor ID).

### Desafio 2: Mesclagem K-way de Registros Ordenados
- **Input**: Um conjunto de $k$ listas de registros, onde cada lista individual já está ordenada de forma crescente. A soma total de elementos em todas as listas é $n$.
- **Output**: Uma única lista unificada contendo todos os $n$ elementos perfeitamente ordenados.

### Desafio 3: Reorganização e Fusão de Intervalos
- **Input**: Um array desordenado de intervalos de tempo ou faixas numéricas $[[s_1, e_1], [s_2, e_2], \dots, [s_n, e_n]]$.
- **Output**: Um array consolidado contendo apenas intervalos disjuntos, onde todos os intervalos sobrepostos foram fundidos em um único intervalo contíguo de cobertura.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Complexidade de Tempo Estrita**:
  - Os Desafios 1 e 3 devem ser resolvidos com complexidade de tempo estrita $O(n \log n)$.
  - O Desafio 2 deve ser resolvido com complexidade de tempo $O(n \log k)$, que representa $O(n \log n)$ no pior caso quando $k \approx n$, garantindo desempenho muito superior a um algoritmo linear simples $O(n \times k)$.
- **Complexidade Espacial Otimizada**:
  - No Desafio 2, a memória auxiliar de trabalho deve ser no máximo $O(k)$ para manter a estrutura de Heap ativa.
  - No Desafio 3, a fusão deve ocorrer in-place ou utilizando no máximo $O(n)$ de memória adicional para a saída final, evitando alocações temporárias na hot path de ordenação.

---

## 4. Guia de Implementação & Padrões

Esta classe de complexidade baseia-se fortemente na equação clássica de recorrência descrita no teorema mestre de divisão de tarefas, conforme ilustrado no gráfico de referência:

```
                  Equação de Recorrência Dividir e Conquistar
                             T(n) = 2T(n/2) + O(n)
                                       │
                      ┌────────────────┴────────────────┐
                      ▼                                 ▼
         Divisão de Subproblemas (log n)       Intercalação Linear O(n)
             [n] -> [n/2], [n/2]                   [Mesclagem / Merge]
```

### Código e Padrões de Referência:

#### A. Divisão e Intercalação Concorrente / Heap de Prioridades
Utilizado no **Desafio 2**. A intercalação eficiente de $k$ listas ordenadas é implementada por meio de uma Min-Heap (Fila de Prioridades) de tamanho $k$. A cada passo, retiramos o menor elemento da Heap (complexidade $O(\log k)$) e inserimos o próximo elemento da mesma lista de onde o item foi removido:
```csharp
// Padrão de Mesclagem K-way O(n log k) usando Min-Heap
public List<int> MergeKLists(List<List<int>> lists) {
    var minHeap = new PriorityQueue<HeapNode, int>();
    
    // Inicia a Heap com o primeiro elemento de cada lista
    for (int i = 0; i < lists.Count; i++) {
        if (lists[i] != null && lists[i].Count > 0) {
            minHeap.Enqueue(new HeapNode(lists[i][0], i, 0), lists[i][0]);
        }
    }
    
    var result = new List<int>();
    while (minHeap.Count > 0) {
        var node = minHeap.Dequeue(); // O(log k)
        result.Add(node.Value);
        
        // Se a lista de origem do elemento ainda tem itens, insere o próximo
        if (node.ElementIndex + 1 < lists[node.ListIndex].Count) {
            int nextVal = lists[node.ListIndex][node.ElementIndex + 1];
            minHeap.Enqueue(new HeapNode(nextVal, node.ListIndex, node.ElementIndex + 1), nextVal);
        }
    }
    return result;
}
```

#### B. Ordenação Prévia para Processamento Linear
Utilizado no **Desafio 3**. A fusão de intervalos desordenados requer ordenação prévia para garantir que intervalos sobrepostos fiquem adjacentes. Após ordenar em $O(n \log n)$, realizamos uma única varredura linear de $O(n)$ para consolidar os intervalos:
```csharp
// Padrão: Ordenar por ponto de partida e mesclar linearmente
intervals.Sort((a, b) => a.Start.CompareTo(b.Start)); // O(n log n)

var merged = new List<Interval>();
foreach (var interval in intervals) {
    if (merged.Count == 0 || merged[^1].End < interval.Start) {
        merged.Add(interval);
    } else {
        merged[^1].End = Math.Max(merged[^1].End, interval.End); // Fusão em O(1)
    }
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Comparadores Eficientes e Estáveis**: No Desafio 1, demonstrar o uso de comparadores nativos altamente otimizados que evitem *boxing/unboxing* de tipos primitivos.
- **Tratamento de Listas Vazias e Nulas**: No Desafio 2, certificar-se de que listas vazias dentro do conjunto de $k$ listas de entrada não causem exceções de referência nula ou travamentos.
- **Não Recorrer a Soluções Quadráticas**: No Desafio 3, evitar comparar todos os intervalos contra todos os outros em laços aninhados ($O(n^2)$). A ordenação prévia é obrigatória para atingir a meta de $O(n \log n)$.

---

## 6. Trade-offs

### A. Algoritmos de Ordenação: Quick Sort vs. Merge Sort vs. Heap Sort
- **Quick Sort**:
  - *Pró*: Excelente localidade de cache de CPU (Cache-Friendly). É extremamente rápido na prática (in-place).
  - *Contra*: Complexidade no pior caso de $O(n^2)$ se o pivô for mal escolhido (ex: array já ordenado). Não é estável.
- **Merge Sort**:
  - *Pró*: Garante complexidade estrita $O(n \log n)$ no pior caso e é uma ordenação estável (preserva ordem original em empates).
  - *Contra*: Requer memória auxiliar adicional de $O(n)$, o que causa alocações massivas na Heap.
- **Heap Sort**:
  - *Pró*: Garante complexidade $O(n \log n)$ no pior caso e opera in-place com espaço adicional $O(1)$.
  - *Contra*: Má localidade de cache (salta muito na memória), sendo mais lento que Quick/Merge na prática. Não é estável.

### B. Min-Heap vs. Ordenação do Array Consolidado no K-way Merge
- **Usar Min-Heap (Recomendado)**: Complexidade total $O(n \log k)$. Muito eficiente se $k$ (número de listas) for pequeno em relação a $n$.
- **Concatenar todas as listas e ordenar o array final**:
  - *Contra*: Complexidade $O(n \log n)$. Se $k$ for pequeno (ex: mesclar 4 arquivos de log contendo 1 milhão de linhas cada), concatenar e reordenar tudo ignora o fato de que os arquivos já estão individualmente ordenados, gerando desperdício severo de processamento.
