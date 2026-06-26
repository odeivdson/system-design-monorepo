# Desafio 16: Índice Espacial Quadtree Concorrente (`algo-spatial-quadtree-matching`)

## 1. Contexto & Cenário
Em plataformas de geolocalização e serviços de transporte em tempo real (como Uber, Lyft, Grab ou Yelp), rastrear e consultar a localização geográfica de milhares de agentes ativos (motoristas, entregadores ou usuários) em tempo real é uma necessidade crítica de infraestrutura. Um cliente que abre o aplicativo precisa receber quase instantaneamente a lista dos motoristas livres mais próximos dentro de um raio de 3 km.

Uma varredura linear simples ($O(N)$) sobre todas as coordenadas de motoristas ativos na cidade falhará sob alta carga de requisições. Para realizar buscas espaciais eficientes, estruturamos os dados em índices espaciais bidimensionais. O **Quadtree** é uma estrutura de árvore na qual cada nó interno possui exatamente quatro filhos, dividindo recursivamente o espaço bidimensional em quatro quadrantes: Noroeste (NW), Nordeste (NE), Sudoeste (SW) e Sudeste (SE).

O principal desafio em um cenário de produção em escala de Big Tech reside na **concorrência**. Motoristas atualizam suas coordenadas GPS a cada poucos segundos (carga extrema de escrita) enquanto milhares de passageiros buscam motoristas ao mesmo tempo (carga extrema de leitura). Se a árvore Quadtree for protegida por um único lock de sincronização global, o sistema sofrerá com contenção severa, degradando a latência de ponta a ponta. O objetivo deste desafio é projetar uma Quadtree concorrente de alta performance e thread-safe.

---

## 2. Requisitos Funcionais (RF)
- **Atualização de Posição (`UpdatePosition`)**: Atualizar ou inserir a localização de um motorista (`driverId`, `latitude`, `longitude`) no índice.
- **Busca de Proximidade (`FindNearby`)**: Consultar os motoristas mais próximos em relação a um ponto central (`latitude`, `longitude`) dentro de um raio máximo em metros (`radius`), limitando o retorno a `limit` elementos.
- **Remoção de Agente (`Remove`)**: Excluir a localização do motorista quando ele se desconectar da plataforma.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Sincronização de Granularidade Fina (Fine-grained Locking)**: Evitar locks globais na árvore. Cada nó da árvore deve gerenciar concorrentemente seu estado de forma independente (ex: usando locks de leitura/escrita individuais por nó ou travas segmentadas por região).
- **Tratamento de Travessia de Fronteiras**: Quando um motorista atualiza sua posição de forma que ele mude de quadrante, a remoção da posição antiga e a inserção no novo quadrante devem ser realizadas com concorrência segura, evitando race conditions em que o motorista fique temporariamente invisível em ambas as regiões.
- **Minimização de Alocações na Heap**: Reusar estruturas de dados e mapeamentos rápidos para evitar pressão sobre o Garbage Collector sob dezenas de milhares de atualizações de GPS por segundo.

---

## 4. Guia de Implementação & Padrões

A Quadtree armazena pontos espaciais em folhas. Quando um nó folha atinge um limite crítico (`MaxCapacity`), ele deve sofrer uma operação de **Split** (divisão), transformando-se em um nó interno e criando quatro nós filhos.

```
       [Espaço Global]                [Divisão em Quadtree]
┌───────────────────────────┐                 [Root]
│             │             │             ┌───┬───┬───┐
│     NW      │     NE      │            NW  NE  SW  SE
│             │             │            ▼   ▼   ▼   ▼
├─────────────┼─────────────┤          [Leaf]  ...
│             │             │           (x,y)
│     SW      │     SE      │
│             │             │
└───────────────────────────┘
```

### Padrões e Estruturas Recomendadas:
- **Dicionário de Localização Rápido (Index Bypass)**: Manter um mapa auxiliar `ConcurrentDictionary<DriverId, QuadtreeNode>` para encontrar instantaneamente em qual nó da árvore o motorista está atualmente alocado. Isso permite que a remoção do motorista ocorra em $O(1)$ sem a necessidade de buscar recursivamente o nó a partir da raiz da árvore.
- **Locks de Leitura/Escrita por Nó (`ReaderWriterLockSlim`)**: Cada nó possui seu próprio lock. As leituras espaciais (`FindNearby`) adquirem lock de leitura nos nós cruzados pela busca. As atualizações de posição (`UpdatePosition`) adquirem lock de escrita no nó específico de inserção/remoção.
- **Split Seguro (Copy-On-Write ou Lock Handshaking)**: Quando um nó precisa fazer o split, ele deve adquirir temporariamente lock exclusivo de escrita no nó pai e no nó folha que será dividido para evitar leituras cruzadas inconsistentes durante a criação e redistribuição dos elementos para as folhas filhas.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Ordem de Aquisição de Locks Livre de Deadlocks**: Se uma atualização exigir remoção de um quadrante e inserção em outro, o motor do índice deve demonstrar uma ordenação estrita de aquisição de locks (ex: travar por ID de nó crescente) para evitar deadlocks de movimento cruzado.
- **Algoritmo de Interseção de Círculo e Retângulo**: Implementação eficiente para checar se o círculo de busca de proximidade intersecta a caixa delimitadora (Bounding Box) do quadrante atual antes de descer recursivamente a busca, otimizando o número de nós visitados.
- **Gerenciamento de Nós Vazios**: Como o sistema lida com a redução de motoristas em uma região. Nós filhos que ficam permanentemente vazios após remoções consecutivas devem ser "mesclados" de volta ao nó pai de forma segura concorrentemente para economizar memória e profundidade de travessia.

---

## 6. Trade-offs

### A. Quadtree vs. Geohash vs. Uber H3 (Grid Hexagonal)
- **Quadtree (Recomendado para este desafio)**: Adapta-se dinamicamente à densidade dos pontos de dados. Regiões muito povoadas (centros urbanos) sofrem divisões sucessivas gerando nós de alta resolução geográfica, enquanto desertos geográficos não consomem profundidade da árvore.
  - *Contra*: Dificuldade de sincronização multi-thread devido a splits dinâmicos.
- **Geohash (Baseado em strings de base32)**: Divide a Terra em quadrantes fixos identificados por strings. Fácil de indexar no Redis ou bancos de dados relacionais padrão.
  - *Contra*: Ocorre "efeito de borda" onde pontos muito próximos fisicamente podem possuir hashes iniciais totalmente diferentes.
- **Uber H3 (Sistema de Indexação Hexagonal)**: Excelente para cobrir áreas geográficas com o mesmo raio e calcular distâncias com menos distorção.
  - *Contra*: Consumo computacional elevado para conversões matemáticas de coordenadas.

### B. Locks de Nós Individuais vs. Travamento Globais por Nível da Árvore
- **Locks por Nó**: Máxima concorrência paralela e independência total entre quadrantes.
  - *Contra*: Elevado consumo de memória para manter instâncias de locks por nó e maior chance de deadlocks se a ordem de aquisição não for monitorada.
- **Locks por Nível ou Faixa Temporal**: Travas em macro-blocos da árvore.
  - *Pró*: Simplifica o código de sincronização de dados.
  - *Contra*: Cria "hotspots" de contenção em regiões movimentadas do mapa da cidade.
