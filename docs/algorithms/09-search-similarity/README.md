# Desafio 9: Motor de Busca com Tolerância a Erros - Edit Distance (`algo-search-similarity`)

## 1. Contexto & Cenário
No comércio eletrônico moderno e em grandes ferramentas de busca, a barra de pesquisa é a principal porta de entrada para a navegação do usuário. É comum que usuários digitem termos de busca com erros de digitação, omissões ou trocas de letras (ex: digitar "jelfadeira" em vez de "geladeira", ou "smaftv" em vez de "smart tv"). Se o motor de busca realizar apenas buscas exatas (substring matching), ele retornará zero resultados, frustrando o cliente e causando abandono de sessões e perda direta de conversão. 

Para resolver isso, implementamos algoritmos de **Tolerância a Erros (Fuzzy Search)** que buscam mapear palavras incorretas para termos corretos do catálogo de produtos. A métrica padrão para medir a semelhança entre duas palavras é a **Distância de Edição (Levenshtein Distance)**, que calcula o número mínimo de operações (inserções, deleções ou substituições de caracteres) necessárias para transformar uma string em outra. Em escala extrema, realizar esse cálculo de programação dinâmica contra milhões de termos cadastrados a cada caractere digitado causaria timeout imediato. Este desafio estilo HackerRank exige otimizar o algoritmo de distância de edição para que a busca tolerante a falhas rode em tempo sub-milissegundo.

---

## 2. Requisitos Funcionais (RF)
- **Input de Dados**:
  - Termo de busca digitado pelo usuário (string $S$).
  - Catálogo de termos legítimos conhecidos do marketplace (dicionário contendo $N$ palavras).
  - Distância máxima de edição permitida ($K$, ex: $K=2$).
- **Busca Tolerante a Falhas**: Retornar todas as palavras do catálogo cuja distância de edição em relação a $S$ seja menor ou igual a $K$.
- **Cálculo de Distância de Edição (Levenshtein)**: Implementar a função de cálculo de distância entre duas strings usando Programação Dinâmica.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Tempo de Resposta Rápido (Autocomplete)**: Retornar os candidatos em menos de 10 milissegundos para um catálogo de até 100.000 termos.
- **Complexidade de Espaço Linear $O(\min(|S|, |T|))$**: O cálculo da distância de edição por programação dinâmica clássica usa uma matriz de tamanho $|S| \times |T|$. Para evitar alocação excessiva de memória RAM no Heap, deve-se otimizar a representação espacial de forma linear, mantendo apenas as duas últimas linhas da matriz na memória (ou usando o Algoritmo de Hirschberg).
- **Zero Allocations na Hot Path**: Evitar criar arrays temporários adicionais por termo avaliado. Usar buffers de memória compartilhada reaproveitados pelas threads de busca.
- **Busca Poda (Trie-based Pruning)**: Não varrer linearmente todo o dicionário de $N$ palavras. A travessia deve ser otimizada combinando uma árvore Trie ao cálculo da distância de edição para podar subárvores inteiras cujo erro acumulado supere o limite $K$.

---

## 4. Guia de Implementação & Padrões
A união de uma árvore de prefixos (Trie) à Programação Dinâmica de Distância de Edição permite realizar buscas tolerantes a falhas de forma extremamente otimizada através de busca por backtracking com poda de ramificações inviáveis.

```
                   Trie + Levenshtein Backtracking
                                (g)  [1, 2, 3...] <- Row 0 (Levenshtein Vector)
                                 │
                                (e)  [2, 1, 2...] <- Row 1
                                 │
                                (l)  [3, 2, 1...] <- Row 2
                             ┌───┴───┐
         (adeira) [Row 9]  (a)      (o) [Row 3: "gelo" vs "jelfadeira" distance > K -> PRUNED]
```

### Abordagem de Resolução Recomendada (Estilo HackerRank):
- **Levenshtein com Vetor Unidimensional**: Reduzir a complexidade espacial da programação dinâmica. Em vez de uma tabela bidimensional, manter apenas duas linhas da matriz: a linha anterior e a linha atual.
  $$Row_{new}[j] = \min\left(Row_{old}[j] + 1, Row_{new}[j-1] + 1, Row_{old}[j-1] + (S[i] \neq T[j])\right)$$
- **Trie Search com Backtracking Recursivo**:
  1. O método recursivo de busca na Trie aceita o nó atual, a letra do nó e o vetor de distâncias da linha anterior correspondente.
  2. Para o nó atual da Trie, calcular a nova linha do vetor Levenshtein contra a string buscada.
  3. Se o menor valor contido na nova linha de distâncias for maior que a distância de erro máxima permitida $K$, a recursão para essa ramificação é interrompida imediatamente (Poda / Pruning).
  4. Se o menor valor for $\le K$ e o nó atual representar o fim de uma palavra válida do catálogo, calcular a distância final e, se for $\le K$, adicionar a palavra aos resultados.
- **Reuso de Arrays (Pooling)**: Criar e reusar um pool de arrays para os vetores de distância Levenshtein temporários usados na travessia recursiva para evitar alocações sob concorrência.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Implementação Correta da Poda (Pruning) na Trie**: Garantia de que subárvores inteiras são descartadas precocemente. Se o usuário digitar "jelf", nós abaixo de "gelo" (como "geladeira") são avaliados apenas se a distância acumulada de prefixo ainda estiver dentro do limite $K$.
- **Complexidade Espacial Estrita**: Não alocar matrizes de tamanho $|S| \times |T|$ para o cálculo individual de Levenshtein. O avaliador testará o consumo de memória sob estresse.
- **Tratamento de Strings Grandes (Edge Cases)**:
  - Casos em que o termo de busca é menor que $K$.
  - Comparação de strings vazias.
  - Caracteres Unicode ou acentuações (normalização de strings antes da busca).
- **Eficiência de Travessia**: Evitar recursões profundas desnecessárias que possam levar a estouro de pilha (*StackOverflowException*).

---

## 6. Trade-offs

### A. Busca Linear com Levenshtein Otimizado vs. Busca baseada em Trie + DP
- **Busca Linear com Levenshtein**:
  - *Pró*: Fácil implementação, sem necessidade de construir ou carregar uma árvore Trie complexa em memória RAM.
  - *Contra*: O tempo de execução escala linearmente com o tamanho do catálogo ($O(N \cdot |S| \cdot |T|)$). Sob catálogos reais de milhões de produtos, o timeout é estourado.
- **Trie + DP (Recomendada)**:
  - *Pró*: Latência de busca ultraveloz, escalando de forma quase independente do tamanho do catálogo devido à eliminação de ramificações inteiras.
  - *Contra*: Alta complexidade de codificação da recursão com backtracking e maior consumo inicial de memória RAM para representação física dos nós da Trie.

### B. Algoritmo de Hirschberg (Espaço Linear) vs. Matriz DP Padrão
- **Hirschberg (Espaço Linear)**:
  - *Pró*: Otimização espacial teórica perfeita.
  - *Contra*: Complexidade algorítmica e tempo de CPU ligeiramente maior devido à abordagem de dividir e conquistar (divide and conquer) recursivo.
- **Vetor de Duas Linhas (Recomendada)**:
  - *Pró*: Simples de codificar, extremamente performática em CPU (boa localidade de cache L1/L2) e atende ao requisito de espaço linear para checagem simples de distância sem reconstruir o caminho de edição (alinhamento).
