# Desafio 9: Mecanismo de Busca por Prefixo Otimizado para Memória (`algo-high-performance-trie`)

## 1. Contexto & Cenário
Em plataformas de grande escala (como o campo de pesquisa principal do Mercado Livre ou sugestões de buscas no Netflix), a velocidade do recurso de autocompletar (autocomplete) dita a experiência de conversão do usuário. À medida que o usuário digita cada caractere (ex: "g", "ge", "gel"), o sistema precisa retornar instantaneamente as sugestões mais populares (ex: "geladeira", "geladeira frost free", "gelo"). Consultar bancos de dados relacionais usando `LIKE '%gel%'` a cada pressionamento de tecla sob uma carga massiva de usuários é inviável, levando ao colapso imediato dos servidores de banco.

Para atingir latências de sub-milissegundo, a estrutura de dados clássica de árvore de prefixos (Trie) é ideal, pois permite buscar palavras correspondentes a um prefixo com complexidade de tempo proporcional apenas ao comprimento do termo buscado ($O(L)$), e não ao tamanho total da base de dados ($O(N)$). 
No entanto, a implementação padrão de uma Trie (onde cada nó contém um dicionário ou array de ponteiros para os seus 26 filhos) é um ralo de memória. Armazenar milhões de palavras no Heap de execução de linguagens gerenciadas (como C# ou Java) gera centenas de milhões de pequenos objetos na memória RAM, resultando em sobrecarga e pausas intoleráveis do Garbage Collector (GC) (Stop-The-World). O objetivo deste desafio é projetar uma Trie de alta performance otimizada para baixo consumo de memória e latência mínima.

---

## 2. Requisitos Funcionais (RF)
- **Inserção Dinâmica**: Permitir a inserção de termos associados a um peso de popularidade (frequência de busca).
- **Busca por Prefixo com Ranking (Top-K)**: Retornar rapidamente as $K$ sugestões mais populares que começam com o prefixo digitado.
- **Atualização Incremental**: Permitir atualizar a popularidade de termos existentes de forma eficiente.
- **Deleção Limpa**: Permitir a remoção de termos, liberando os nós órfãos da memória associada.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Latência de Busca Sub-Milissegundo**: A operação de busca por prefixo deve responder em menos de 1ms no percentil P99.
- **Eficiência Extrema de RAM**: Minimizar drasticamente a quantidade de ponteiros vazios por nó. O consumo total de memória deve ser reduzido em pelo menos 60% comparado a uma Trie tradicional (26 pointers por nó).
- **Zero GC Overhead no Hot Path**: A busca por prefixo (operação mais frequente) não deve alocar objetos temporários no Heap (Heap Allocations) para não sobrecarregar o Garbage Collector.
- **Thread-Safety Não Bloqueante**: Suportar leituras simultâneas ilimitadas (Search) enquanto atualizações de escrita em background (Insert) ocorrem em paralelo sem corromper a estrutura.

---

## 4. Guia de Implementação & Padrões
O design deve ir além da estrutura teórica básica, implementando padrões de **Radix Trees (Tries Comprimidas)** e estruturas sucintas na memória RAM.

```
       [ Prefix Tree Clássica ]                     [ Radix Tree (Comprimida) ]
                (g)                                            (gel)
                 │                                            ┌──┴──┐
                (e)                                        (adeira) (o)
                 │                                            │
                (l)                                      ( frost free)
             ┌───┴───┐
         (adeira)   (o)
```

### Padrões e Primitivas Recomendadas:
- **Radix Tree (Trie Comprimida)**: Fundir nós consecutivos que possuem apenas um filho único (ex: "g" -> "e" -> "l" vira um único nó "gel"). Isso reduz o número de nós totais na árvore em até 80% para bases de dados reais de termos de busca.
- **Representação Esparsa de Filhos (Sparse Nodes)**: Em vez de alocar um array estático de tamanho fixo para todo o alfabeto em cada nó, usar coleções dinâmicas que crescem sob demanda:
  - Nós com poucos filhos: Usar um array de caracteres de tamanho dinâmico (mantido ordenado para busca binária em $O(\log C)$).
  - Nós com muitos filhos (ex: raiz e nós principais): Usar uma tabela hash ou array completo para busca instantânea em $O(1)$.
- **Cache Local de Top-K no Nó**: Armazenar nos nós internos os ponteiros diretos para as $K$ palavras mais populares de sua subárvore. Isso evita a necessidade de percorrer recursivamente todos os descendentes do nó de prefixo durante a busca em tempo de digitação, transformando a busca em tempo de consulta puramente constante ($O(L)$ para achar o prefixo, $O(1)$ para pegar o cache do nó).
- **Arena Allocation ou Flat Array Layout**: Em linguagens como C# ou C++, representar a árvore como um grande array plano (flat array de estruturas `struct`) no lugar de uma teia de objetos referenciados por ponteiros. Isso coloca os dados adjacentes próximos fisicamente na memória (Cache Locality) e elimina a existência de pequenos objetos gerenciados no Heap.
- **Copy-On-Write ou Lock-Free Reads**: Garantir que as threads de busca acessem nós imutáveis. As atualizações criam novas versões dos nós alterados e alteram o ponteiro pai atomicamente, permitindo leituras sem locks (`lock-free`).

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Localidade de Cache da CPU**: O design deve levar em consideração a arquitetura física de computadores (L1/L2 Cache Hits). Arrays contíguos de nós são preferidos a ponteiros esparsos espalhados pela memória RAM.
- **Estruturas de Dados Compactas (Bitmaps)**: Demonstração de uso de bitmasks ou bitmaps de presença para rastrear quais caracteres filhos estão ativos em um nó sem alocar ponteiros para eles.
- **Algoritmo de Ordenação e Ranking Otimizado**: Para o ranking das Top-K sugestões, uso eficiente de Heap (Min-Heap / Priority Queue) na fase de inserção, garantindo que o cache do nó esteja pré-calculado.
- **Zero Allocations na Busca**: Utilização de tipos de valor (`structs`, `ReadOnlySpan<char>` em C#) para representar a string digitada e navegar na árvore sem alocar novos objetos do tipo `String`.

---

## 6. Trade-offs

### A. Radix Tree (Comprimida) vs. Trie Padrão
- **Radix Tree (Recomendada)**:
  - *Pró*: Economia colossal de memória e redução drástica no número de nós.
  - *Contra*: O algoritmo de inserção e deleção torna-se imensamente complexo, exigindo quebras dinâmicas (splits) e fusões (merges) de strings nos nós intermediários em tempo de execução.

### B. Cache de Top-K nos Nós vs. Travessia Dinâmica (DFS/BFS)
- **Cache de Top-K nos Nós (Recomendado)**:
  - *Pró*: Latência de busca nula ($O(1)$ após encontrar o nó do prefixo).
  - *Contra*: Maior consumo de memória RAM por nó (cada nó armazena uma lista de ponteiros para as melhores sugestões) e custo extra de tempo de escrita no `Insert` para atualizar os caches de todos os nós ancestrais do termo inserido.
- **Travessia Dinâmica**:
  - *Pró*: Memória RAM mínima para representação da árvore pura.
  - *Contra*: Latência instável no P99 se o prefixo buscado tiver milhões de ramificações abaixo dele (ex: o usuário digita "a").

### C. Estrutura Mutável Lock-free vs. Trie Congelada (Immutable Read-Only)
- **Trie Mutável**: Permite atualizações em tempo real com alta performance. Exige algoritmos de concorrência avançados e pode consumir mais memória devido a metadados de sincronização.
- **Trie Congelada (Frozen Trie)**: A árvore é construída de forma sequencial na inicialização e convertida em uma estrutura de bytes linear de leitura imutável.
  - *Pró*: Memória e velocidade de leitura máximas absolutas e GC-free.
  - *Contra*: Não suporta atualizações dinâmicas sem rebuild total da árvore em lote (adequado se a base de sugestões só for atualizada diariamente via jobs de batch).