# Desafios de Complexidade de Tempo (Time Complexity Challenges)

Este diretório reúne um conjunto de desafios conceituais e práticos de algoritmos, organizados estritamente por suas classes de complexidade de tempo do pior caso (Big-O). O objetivo deste treinamento é capacitar engenheiros a reconhecer padrões estruturais em blocos de código e equações de recorrência matemática, sabendo mapeá-los para cenários reais de engenharia de software de alta escala.

---

## 1. Matriz de Padrões de Complexidade de Tempo
Abaixo está o mapeamento dos padrões de código e equações de recorrência (baseados na imagem de referência **Time Complexity Patterns**) integrados aos desafios deste diretório:

| Complexidade | Padrão de Código / Equação | Descrição Conceitual | Pasta de Desafios |
| :--- | :--- | :--- | :--- |
| **$O(n)$** | `for (int i = 0; i < n; i++)` | Iteração simples e completa de passagem única. | [O(n)](./o_n/README.md) |
| **$O(n)$** | `for (int i = 0; i < n/2; i++)` | Iteração convergente de duas pontas (Two Pointers). | [O(n)](./o_n/README.md) |
| **$O(n)$** | `for (int i = 0; i < n; i++) {}`<br>`for (int i = 0; i < n; i++) {}` | Dois laços sequenciais independentes ($O(n+n) = O(n)$). | [O(n)](./o_n/README.md) |
| **$O(n)$** | $T(n) = T(n-1) + O(1)$ | Relação de recorrência para funções recursivas lineares. | [O(n)](./o_n/README.md) |
| **$O(\log n)$** | `for (int i = 1; i < n; i *= 2)` | Divisão progressiva (multiplicação de índice). | [O(log n)](./o_log_n/README.md) |
| **$O(\log n)$** | `for (int i = n; i > 0; i /= 2)` | Busca inversa ou redução de limite de dados. | [O(log n)](./o_log_n/README.md) |
| **$O(\log n)$** | `while (n > 0) { n /= 2; }` | Busca binária clássica reduzindo o espaço de busca. | [O(log n)](./o_log_n/README.md) |
| **$O(n \log n)$** | $T(n) = 2T(n/2) + O(n)$ | Recorrência de Divisão e Conquista (ex: Merge Sort). | [O(n log n)](./o_n_log_n/README.md) |
| **$O(n^2)$** | `for (int i = 0; i < n; i++)`<br>`  for (int j = 0; j < n; j++)` | Laço duplo aninhado completo sobre grid bidimensional. | [O(n_squared)](./o_n_squared/README.md) |
| **$O(n^2)$** | `for (int i = 0; i < n; i++)`<br>`  for (int j = 0; j < i; j++)` | Laço duplo aninhado triangular ($n(n-1)/2$). | [O(n_squared)](./o_n_squared/README.md) |
| **$O(\varphi^n)$** | $T(n) = T(n-1) + T(n-2)$ | Recorrência exponencial de Fibonacci ($\approx 1.618^n$). | [O(phi_n)](./o_phi_n/README.md) |

---

## 2. Estrutura dos Desafios

Cada subdiretório contém três desafios práticos detalhados seguindo as diretrizes de nível de sistema (Senior/Staff):

1. **[Desafios $O(n)$ (Tempo Linear)](./o_n/README.md)**
   - **Desafio 1**: Soma de Segmento Móvel (Janela Deslizante)
   - **Desafio 2**: Consulta de Frequência de Elementos em Fluxo
   - **Desafio 3**: Validação de Palíndromo com Duas Pontas

2. **[Desafios $O(\log n)$ (Tempo Logarítmico)](./o_log_n/README.md)**
   - **Desafio 1**: Busca Binária Personalizada (Lower Bound)
   - **Desafio 2**: Índice de Intervalos Ordenados
   - **Desafio 3**: Consulta em Árvore Binária de Busca Balanceada (BST)

3. **[Desafios $O(n \log n)$ (Tempo Linear-Logarítmico)](./o_n_log_n/README.md)**
   - **Desafio 1**: Ordenação de Objetos por Prioridade Composta
   - **Desafio 2**: Mesclagem K-way de Registros Ordenados
   - **Desafio 3**: Reorganização e Fusão de Intervalos

4. **[Desafios $O(n^2)$ (Tempo Quadrático)](./o_n_squared/README.md)**
   - **Desafio 1**: Busca de Soma de Pares por Força Bruta
   - **Desafio 2**: Análise de Substrings por Força Bruta
   - **Desafio 3**: Detecção de Ciclos em Matriz de Adjacência

5. **[Desafios $O(\varphi^n)$ (Tempo Exponencial)](./o_phi_n/README.md)**
   - **Desafio 1**: Fibonacci Recursivo Ineficiente
   - **Desafio 2**: Geração de Subconjuntos (Power Set) por Força Bruta
   - **Desafio 3**: Caminhos Hamiltonianos por Busca Exaustiva

---

## 3. Diretrizes de Resolução e Avaliação (Foco Staff)
Ao implementar ou projetar soluções para estes desafios, preste especial atenção a:
* **GC Pressure e Alocação na Hot Path**: Evite instanciar objetos adicionais desnecessariamente dentro de laços repetitivos. Dê preferência ao reuso de buffers (pooling).
* **Stack Overflow**: Em soluções de complexidade exponencial ou logarítmica baseadas em recursão, certifique-se de que a profundidade da pilha seja restrita a $O(n)$ ou $O(\log n)$, ou utilize abordagens iterativas equivalentes.
* **Complexidade Espacial Estrita**: Respeite os limites de espaço propostos (ex: $O(1)$ adicional). Não crie cópias de coleções grandes se as operações puderem ser feitas in-place.
