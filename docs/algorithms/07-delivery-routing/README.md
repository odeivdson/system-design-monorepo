# Desafio 14: Otimizador de Rotas de Entrega com SLAs (`algo-delivery-routing`)

## 1. Contexto & Cenário
Na malha logística de grandes plataformas de e-commerce e transportadoras globais, milhares de pacotes devem ser distribuídos diariamente a partir de Centros de Distribuição (CDs) para múltiplos endereços de clientes. Para operar com custos viáveis, uma frota de vans de entrega deve ser roteada de forma ótima. Cada veículo possui uma capacidade de carga física máxima e cada endereço de entrega possui uma janela de tempo rígida (SLA de entrega garantido, ex: "entrega das 10h às 12h"). 

Esse problema é uma variação do **Problema de Roteamento de Veículos com Janelas de Tempo (VRPTW - Vehicle Routing Problem with Time Windows)**, que pertence à classe de problemas NP-Hard (NP-Difícil). Resolver esse desafio no estilo HackerRank exige projetar um algoritmo que encontre uma solução de menor distância ou custo de transporte total, respeitando todas as restrições logísticas de capacidade e tempo sob restrições estritas de tempo de execução da CPU do avaliador técnico.

---

## 2. Requisitos Funcionais (RF)
- **Input de Dados**:
  - Matriz de adjacência de distâncias/tempos de viagem entre todos os nós (CD e endereços).
  - Lista de demandas de carga e janelas de tempo de entrega `(tempo_inicio, tempo_fim)` para cada endereço de destino.
  - Especificação da frota de veículos (quantidade de veículos disponíveis e capacidade de carga de cada um).
- **Cálculo de Rotas**: Determinar a sequência exata de visitas a endereços para cada veículo, iniciando e terminando obrigatoriamente no Centro de Distribuição (nó 0).
- **Validação de Restrições**:
  - **Capacidade**: A soma das demandas de carga atendidas por uma van na sua rota não pode exceder sua capacidade de carga.
  - **Tempo (SLA)**: A van deve chegar a cada endereço antes do horário final da janela de entrega do cliente. Se chegar antes do horário inicial, ela deve esperar no local sem penalidade.
- **Minimização do Custo**: Minimizar o custo total (soma das distâncias percorridas por todos os veículos operantes).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Desempenho sob Escala**: O algoritmo deve rodar em menos de 2 segundos para instâncias de tamanho médio (ex: 50 a 100 endereços).
- **Complexidade Espacial Otimizada**: Utilizar matrizes esparsas ou listas de adjacência compactadas para representar grafos de grande escala para evitar estouros de cache de CPU e de memória Heap.
- **Tratamento Eficiente de Caminho Mínimo**: A busca por caminhos entre pontos de entrega específicos deve operar em tempo máximo de $O((V + E) \log V)$ usando Dijkstra com heaps binários/Fibonacci heap como componente de cálculo da heurística.
- **Precisão contra Falsos Negativos**: Casos limites, como capacidade de veículos insuficiente para cobrir todas as demandas, devem ser detectados rapidamente, retornando código indicativo de inviabilidade imediata.

---

## 4. Guia de Implementação & Padrões
Dado que o problema é NP-Hard, a solução exata (Programação Inteira / Branch and Bound) só é viável para instâncias minúsculas ($< 15$ nós). Para os limites de tempo do HackerRank, deve-se adotar **Heurísticas de Construção** (como o Método de Economias de Clarke-Wright adaptado para janelas de tempo) seguidas de **Heurísticas de Melhoria Local** (2-opt ou 3-opt), ou meta-heurísticas de Programação Dinâmica aproximada.

```
       [ Centro de Distribuição ] (Nó 0)
             /       ▲        \
            /         \        \  (Roteador divide frota)
           ▼           │        ▼
       [ Cliente 1 ]   │   [ Cliente 3 ]
       (SLA: 9h-11h)   │   (SLA: 12h-14h)
           │           │        │
           ▼           │        ▼
       [ Cliente 2 ] ──┘   [ Cliente 4 ]
       (SLA: 10h-12h)      (SLA: 14h-16h)
      (Capacidade Rota 1) (Capacidade Rota 2)
```

### Abordagem de Resolução Recomendada (Estilo HackerRank):
- **Clarke & Wright Savings Algorithm (Modificado)**:
  1. Calcular as economias (savings) de fundir duas rotas independentes: $S_{ij} = d_{0i} + d_{0j} - d_{ij}$, onde $0$ é o CD.
  2. Ordenar a lista de economias em ordem decrescente.
  3. Fundir as rotas contendo $i$ e $j$ se e somente se as restrições de capacidade física acumulada do veículo e as janelas de tempo de entrega de todos os nós na rota fundida forem válidas.
- **PriorityQueue para Ordenação de Economias**: Usar uma estrutura de dados de Heap (PriorityQueue) para a fase de ordenação das economias, garantindo complexidade $O(N^2 \log N)$ na ordenação inicial de economias de rotas.
- **Verificação Incremental de Viabilidade de Tempo**: Para evitar recalcular linearmente os horários de chegada de toda a rota a cada tentativa de fusão, manter um controle incremental do tempo acumulado mais cedo possível de chegada e o atraso máximo permitido (Slack Time) de cada nó.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Validação Estrita de Janela de Tempo com Espera (Waiting Time)**: O avaliador verificará se o algoritmo calcula corretamente o tempo de viagem acumulado e insere o tempo de espera necessário se o veículo chegar antes do horário mínimo da janela de entrega.
- **Controle de Loop e Ordem**: Garantir que as rotas geradas sejam livres de loops de sub-rotas inválidas que não retornam ao CD.
- **Otimização de Estrutura de Grafos**: Evitar alocações excessivas de objetos do tipo `Node` ou `Edge` durante a execução da heurística, utilizando representações baseadas em arrays primitivos indexados.
- **Tratamento de Edge Cases**:
  - Janelas de tempo sobrepostas de forma estreita.
  - Endereços distantes isolados.
  - Capacidade limite dos veículos exatamente igual à demanda acumulada.

---

## 6. Trade-offs

### A. Algoritmo Exato (Programação Dinâmica / Branch-and-Cut) vs. Heurísticas
- **Algoritmo Exato**:
  - *Pró*: Garante o menor custo de transporte matematicamente possível.
  - *Contra*: O tempo de execução explode exponencialmente ($O(2^N \cdot N^2)$). A solução estoura o timeout do HackerRank em instâncias reais de produção.
- **Algoritmo Heurístico (Recomendado)**:
  - *Pró*: Responde em milissegundos ($O(N^2 \log N)$), ideal para testes técnicos rápidos de tempo limitado.
  - *Contra*: Pode produzir uma rota com custo ligeiramente superior à ótima absoluta (tipicamente entre 2% e 5% de gap).

### B. Heurística Clarke-Wright vs. Busca Tabu (Meta-heurística)
- **Clarke-Wright (Savings)**:
  - *Pró*: Rápida, fácil de codificar e consome pouca memória.
  - *Contra*: Pode cair em mínimos locais ruins se a distribuição das janelas de tempo for muito esparsa.
- **Busca Tabu / Simulated Annealing**:
  - *Pró*: Excelente capacidade de escapar de mínimos locais, produzindo custos menores.
  - *Contra*: Altamente complexa para implementar sob o tempo corrido de um processo seletivo e difícil de parametrizar (tuning de temperatura/tamanho da lista tabu).
