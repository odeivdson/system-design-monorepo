# Desafios de Complexidade $O(\log n)$ (Tempo Logarítmico)

## 1. Contexto & Cenário
A complexidade de tempo logarítmica $O(\log n)$ é a base de sistemas de armazenamento de dados massivos de alto desempenho. Ela é o alicerce de índices de bancos de dados relacionais (B-Trees) e não-relacionais (LSM-Trees/SSTables). Em sistemas reais, a escala de dados pode chegar a bilhões de registros. Um algoritmo que roda em complexidade linear $O(n)$ demoraria bilhões de passos para encontrar um item. Em contrapartida, um algoritmo logarítmico $O(\log n)$ realiza a mesma busca em no máximo 30 passos ($2^{30} \approx 10^9$).

Esses desafios são focados no princípio de "dividir para conquistar", onde o espaço de busca é sucessivamente reduzido pela metade a cada passo do algoritmo, garantindo latências sub-milissegundos mesmo sob cargas extremas de dados.

---

## 2. Requisitos Funcionais (RF)

### Desafio 1: Busca Binária Personalizada (Lower Bound)
- **Input**: Um array de inteiros ordenados $A$ (podendo conter duplicatas) e um valor alvo $x$.
- **Output**: O menor índice $i$ tal que $A[i] \ge x$. Caso nenhum elemento atenda ao critério, retornar `-1`.

### Desafio 2: Índice de Intervalos Ordenados
- **Input**: Uma lista de intervalos fechados e disjuntos ordenados pelo ponto inicial, $[[s_1, e_1], [s_2, e_2], \dots, [s_k, e_k]]$, e um valor numérico query $v$.
- **Output**: O intervalo $[s_i, e_i]$ que contém $v$. Se $v$ não estiver dentro de nenhum intervalo, retornar o próximo intervalo imediatamente à direita (o que inicia com a menor chave maior que $v$). Retornar `-1` se não houver intervalo sucessor.

### Desafio 3: Consulta em Árvore Binária de Busca Balanceada (BST)
- **Input**: Uma estrutura de árvore binária dinâmica.
- **Output**: Operações atômicas de inserção (`Insert`), remoção (`Delete`) e busca de presença (`Contains`) mantendo a árvore estruturalmente balanceada.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Complexidade de Tempo Estrita**: Todas as operações de busca, inserção e remoção devem executar em tempo de pior caso $O(\log n)$.
- **Prevenção de Estouro de Inteiros (Integer Overflow)**: Ao calcular pontos médios em arrays grandes, deve-se evitar a fórmula vulnerável `(low + high) / 2`.
- **Complexidade Espacial Adicional**: 
  - Nos Desafios 1 e 2, o espaço adicional deve ser estritamente $O(1)$ utilizando lógica iterativa.
  - No Desafio 3, o espaço adicional deve ser proporcional à altura da árvore $O(\log n)$ no pior caso (devido à pilha de recursão de rebalanceamento).

---

## 4. Guia de Implementação & Padrões

A complexidade logarítmica é caracterizada por loops de divisão e redução exponencial do espaço de trabalho, como mostrado na imagem de referência:

```
[Padrão 1: Multiplicação de Índice]   [Padrão 2: Divisão de Índice]   [Padrão 3: While de Divisão]
   for (int i=1; i<n; i*=2)              for (int i=n; i>0; i/=2)        while (n > 0) { n /= 2; }
              │                                     │                               │
              ▼                                     ▼                               ▼
       Redução de Espaço                    Busca Inversa                  Busca Binária Iterativa
```

### Código e Padrões de Referência:

#### A. Loop de Divisão Progressiva (Busca Binária Iterativa)
Utilizado nos **Desafios 1 e 2**. Em vez de varrer o array sequencialmente, dividimos a faixa de busca ao meio a cada iteração:
```csharp
// Padrão de Busca Binária Iterativa O(log n)
int low = 0;
int high = array.Length - 1;
int result = -1;

while (low <= high) {
    // Evita integer overflow que ocorreria com (low + high) / 2
    int mid = low + (high - low) / 2; 

    if (array[mid] >= target) {
        result = mid; // Salva o candidato potencial
        high = mid - 1; // Continua buscando na metade esquerda (menor índice)
    } else {
        low = mid + 1; // Busca na metade direita
    }
}
return result;
```

#### B. Redução em Estruturas de Árvores Balanceadas
Utilizado no **Desafio 3**. A busca logarítmica depende da garantia de que a altura $H$ da árvore satisfaça $H \le c \log n$. Para manter essa propriedade durante inserções e remoções dinâmicas, utilizamos rotações de nós (simples e duplas):
```
    Rotação Simples à Esquerda (Balanceamento de Árvores AVL/Red-Black)
         A (Desbalanceado)                    B
          \                                 /   \
           B                               A     C
            \
             C
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Precisão nos Limites (Edge Cases)**:
  - Busca por elementos menores do que todos os itens do array, ou maiores do que todos os itens.
  - Tratamento de arrays vazios e arrays com elementos uniformes/duplicados.
- **Evitar Varredura Linear Oculta**: Em linguagens de alto nível, certifique-se de que operações como fatiamento de arrays (`Slice` ou cópias de sub-arrays) não sejam executadas dentro das etapas recursivas, pois isso transformaria a complexidade espacial e temporal em linear $O(n)$.
- **Exclusão Física na BST**: A operação de remoção em uma árvore binária deve tratar corretamente os três casos clássicos (nó folha, nó com um filho, e nó com dois filhos - onde é necessário encontrar o sucessor em ordem).

---

## 6. Trade-offs

### A. Busca Binária Iterativa vs. Busca Binária Recursiva
- **Iterativa (Recomendada)**: Usa um laço `while`.
  - *Pró*: Executa com complexidade de espaço estrita $O(1)$. Não há custo extra de Stack Frame.
- **Recursiva**:
  - *Contra*: Ocupa espaço na Stack de execução proporcional à profundidade da busca $O(\log n)$. Sob concorrência e restrições extremas de Stack Size, pode haver risco de consumo de memória de sistema desnecessário.

### B. Árvores AVL vs. Árvores Red-Black
- **Árvores AVL**: Apresentam balanceamento estrito (diferença de altura entre subárvores de no máximo 1).
  - *Pró*: Buscas (`Get`) são ligeiramente mais rápidas porque a árvore é mais perfeitamente balanceada.
  - *Contra*: Inserções e remoções podem exigir mais rotações para manter o balanceamento estrito.
- **Árvores Red-Black (Recomendadas para bases dinâmicas)**: Balanceamento mais flexível (altura máxima de no máximo $2 \log(n + 1)$).
  - *Pró*: Menor número de rotações no pior caso nas operações de mutação (inserção/remoção). Excelente para sistemas híbridos de leitura e escrita intensivas.
