# Desafio 8: Alocador de Caixas Tridimensional - 3D Bin Packing (`algo-warehouse-packing`)

## 1. Contexto & Cenário
No processo de checkout de grandes plataformas de e-commerce e sistemas integrados de logística, o cálculo do valor do frete e a seleção das embalagens adequadas dependem diretamente do volume físico e da quantidade de caixas necessárias para transportar os itens comprados pelo usuário. Quando um cliente realiza uma compra contendo múltiplos produtos de dimensões variadas (ex: um teclado de computador, um livro e dois carregadores de celular), o sistema precisa determinar instantaneamente o menor número de caixas de envio padrão (e seus respectivos tamanhos) necessárias para acomodar os itens, além de definir a orientação tridimensional exata de cada produto dentro de cada caixa para evitar danos e desperdício de espaço.

Essa operação é descrita matematicamente como o **Problema de Empacotamento de Caixas Tridimensionais (3D Bin Packing)**. Por ser um clássico problema NP-Hard de otimização combinatória, encontrar a solução ótima absoluta por força bruta sob o tempo limite de resposta HTTP (checkout da API) é inviável. Este desafio de estilo HackerRank requer implementar uma heurística de empacotamento 3D eficiente e determinística que maximize a eficiência volumétrica das caixas utilizadas respeitando restrições físicas de rotação e gravidade.

---

## 2. Requisitos Funcionais (RF)
- **Input de Dados**:
  - Lista de itens a serem empacotados, contendo as dimensões de cada um: largura ($w$), altura ($h$), comprimento ($d$) e peso.
  - Lista de tipos de caixas de envio padrão disponíveis (com largura, altura, comprimento, capacidade máxima de peso e custo associado).
- **Criação de Embalagens**: Atribuir cada item a uma caixa específica e calcular as coordenadas tridimensionais $(x, y, z)$ do canto traseiro esquerdo do item dentro da caixa, além da sua orientação de rotação (quais eixos foram rotacionados).
- **Validação de Restrições**:
  - **Sem Sobreposição**: Nenhum par de itens na mesma caixa pode se sobrepor fisicamente no espaço 3D.
  - **Limite de Peso**: O peso somado dos itens colocados em uma caixa não pode exceder a capacidade de carga declarada da caixa.
  - **Suporte Físico (Opcional Avançado)**: Garantir que cada item posicionado tenha pelo menos uma parte de sua base apoiada no fundo da caixa ou no topo de outro item previamente colocado (restrição de gravidade).
- **Minimização de Custos**: O objetivo é encontrar a combinação de caixas que apresente o menor custo total de envio somado.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Desempenho de Tempo Estrito**: O algoritmo de empacotamento deve rodar e retornar a distribuição de caixas em menos de 500 milissegundos para lotes típicos de até 20 itens comerciais.
- **Complexidade Espacial Limitada**: Evitar o uso de representações baseadas em voxel grids tridimensionais de alta resolução na memória RAM (que consome gigabytes de memória), priorizando a abordagem de análise de coordenadas matemáticas de caixas envolventes (Bounding Boxes).
- **Precisão Geométrica Determinística**: A lógica tridimensional não pode apresentar erros de arredondamento de ponto flutuante que levem a sobreposições de frações de milímetros. Usar precisão em milímetros representada por inteiros (`integer` ou `fixed-point`).

---

## 4. Guia de Implementação & Padrões
Dado o limite de tempo de resposta, o algoritmo padrão adotado na indústria é baseado na heurística **First Fit Decreasing (FFD) adaptada para 3D** combinada com o conceito de **Pontos de Inserção Disponíveis (Espaços Vazios Máximos - Maximal Empty Spaces)**.

```
       Caixa de Envio Padrão
      ┌─────────────────────────┐
      │        ┌─────────┐      │
      │        │  Item 2 │      │ (Item 2 empilhado sobre Item 1)
      │        ├─────────┤      │
      │        │  Item 1 │      │ (Item 1 no fundo da caixa)
      └────────┴─────────┴──────┘
      (x,y,z) coords calculadas para evitar overlaps
```

### Abordagem de Resolução Recomendada (Estilo HackerRank):
- **First Fit Decreasing 3D (FFD-3D)**:
  1. Ordenar os itens a serem empacotados por volume decrescente (largura $\times$ altura $\times$ comprimento).
  2. Para cada item, tentar colocá-lo na primeira caixa existente que tenha espaço e capacidade de peso. Se nenhuma comportar o item, abrir uma nova caixa do menor tamanho possível capaz de contê-lo.
- **Algoritmo de Espaços Vazios Máximos (Maximal Empty Spaces - MERs)**:
  - Rastrear o espaço interno não ocupado de uma caixa como uma lista de paralelepípedos vazios disponíveis para inserção.
  - Ao posicionar um item no canto de um MER, dividir o MER restante em até 3 novos sub-MERs menores adjacentes (ao longo dos eixos X, Y e Z).
  - Eliminar ou fundir MERs redundantes ou totalmente contidos dentro de outros espaços vazios maiores.
- **Testes de Rotação de Orientação (6 direções)**: Para cada item e espaço vazio sob análise, testar as 6 rotações de orientação espacial possíveis do item (permutação de largura, altura e comprimento) para achar a que melhor consome o espaço do MER analisado.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Validação Matemática de Colisão Tridimensional (No-Overlap)**: A função que valida se dois blocos tridimensionais se sobrepõem no espaço deve ser correta e performática:
  ```
  overlap = (x1_min < x2_max && x1_max > x2_min) &&
            (y1_min < y2_max && y1_max > y2_min) &&
            (z1_min < z2_max && z1_max > z2_min);
  ```
- **Maximização Volumétrica**: O avaliador checará a eficiência volumétrica obtida pelas heurísticas em casos de teste de estresse (ex: empacotar 10 cubos de tamanhos variados em caixas onde a soma dos volumes dos cubos é 95% do volume da caixa).
- **Detecção de Itens Inviáveis**: O algoritmo deve lançar rapidamente um erro caso um único item da lista de compras possua dimensões maiores que a maior caixa disponível no estoque de embalagens.

---

## 6. Trade-offs

### A. Algoritmo Genético / Backtracking Completo vs. Heurística FFD com MERs
- **Algoritmo Genético / Backtracking**:
  - *Pró*: Altíssima eficiência de empacotamento, minimizando drasticamente o número de caixas finais utilizadas.
  - *Contra*: O tempo de execução é lento e imprevisível ($O(N!)$ para permutações de itens), estourando facilmente o timeout do HackerRank se o cliente comprar mais do que 10 itens variados.
- **Heurística FFD com MERs (Recomendada)**:
  - *Pró*: Latência garantida sub-milissegundo, determinística e de fácil depuração.
  - *Contra*: Pode desperdiçar um pequeno percentual de espaço por não explorar todas as combinações de encaixes geométricos possíveis.

### B. Suporte a Rotações Livres vs. Rotações Limitadas
- **Rotações Livres (6 direções espaciais)**:
  - *Pró*: Melhor aproveitamento volumétrico.
  - *Contra*: Aumenta o custo computacional por fator de $6^N$ nas decisões de alocação de itens. Adicionalmente, alguns produtos não podem sofrer certas rotações (ex: líquidos ou eletrônicos sensíveis devem ficar com a orientação vertical "para cima").
- **Rotações Limitadas (Apenas rotação no plano horizontal X-Y)**:
  - *Pró*: Preserva a integridade de produtos que possuem restrições de orientação e acelera a execução da heurística.
  - *Contra*: Pode exigir caixas maiores em casos onde deitar o item de lado seria a única forma de encaixá-lo.
