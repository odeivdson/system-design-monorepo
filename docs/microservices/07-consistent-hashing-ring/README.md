# Desafio 10: Anel de Hash Consistente com Nós Virtuais (`algo-consistent-hashing-ring`)

## 1. Contexto & Cenário
Em sistemas distribuídos que gerenciam grandes volumes de cache ou armazenamento fragmentado (sharding) (ex: clusters de Memcached/Redis na Netflix ou particionamento de banco de dados no Mercado Livre), a distribuição uniforme de chaves entre nós servidores é crítica. Uma abordagem ingênua baseada em módulo aritmético ($node = Hash(key) \pmod N$, onde $N$ é o número de nós servidores) funciona até que ocorra uma alteração na topologia. Se um nó cair ou um novo nó for adicionado, quase todas as chaves existentes serão mapeadas para nós diferentes, gerando perda massiva de cache (*cache stampede*) e sobrecarregando instantaneamente o banco de dados durável.

O padrão **Consistent Hashing (Hash Consistente)** resolve este problema mapeando chaves e nós para uma mesma estrutura lógica circular (Anel de Hash). Ao alterar a topologia do cluster, apenas uma fração de $1/N$ das chaves precisa ser migrada. Para evitar o problema de desequilíbrio na distribuição (onde alguns servidores recebem muito mais carga que outros devido a agrupamentos aleatórios de hash), implementamos **Nós Virtuais (Virtual Nodes ou Vnodes)**, multiplicando a presença lógica de cada nó físico no anel e equilibrando o tráfego de forma uniforme.

---

## 2. Requisitos Funcionais (RF)
- **Mapeamento de Chaves (Lookup)**: Encontrar o nó físico responsável por uma determinada chave (string) no anel de forma eficiente.
- **Adição Dinâmica de Nós**: Permitir a inclusão dinâmica de novos nós físicos ao anel com a criação automática de seus respectivos Nós Virtuais (Vnodes).
- **Remoção Dinâmica de Nós**: Permitir a remoção de nós físicos do anel (e de seus Vnodes), liberando a estrutura lógica correspondente.
- **Equilíbrio Estatístico**: Distribuir as chaves entre os nós com desvio estatístico de carga inferior a 5% sob grandes volumes de chaves.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Latência de Lookup Otimizada**: A operação de mapeamento de chave para nó deve rodar em tempo sub-milissegundo, operando no máximo em complexidade $O(\log(\text{Nós Físicos} \times \text{Vnodes}))$.
- **Thread-Safety Não Bloqueante**: O anel de hash deve permitir buscas simultâneas em regime concorrente (leituras), enquanto alterações de topologia (inserções/remoções de nós) ocorrem em paralelo sem corromper o anel de dados.
- **Função de Espalhamento Uniforme (MurmurHash3 / Ketama)**: Não usar a função `hashCode()` padrão de linguagens de alto nível, mas sim funções criptograficamente estáveis e de excelente espalhamento (como MurmurHash3 ou SHA-1/Ketama).
- **Minimização de Garbage Collection (GC)**: Evitar a criação e destruição excessiva de objetos de busca ou iteradores temporários a cada pesquisa no anel.

---

## 4. Guia de Implementação & Padrões
A estrutura canônica do anel é representada por uma lista circular ou um array plano mantido estritamente ordenado para permitir pesquisas rápidas usando algoritmos de busca binária.

```
                   Anel de Hash Consistente
                          [Vnode A-1] (Hash: 12000)
                         /           \
     [Vnode C-2] (89000)               [Vnode B-1] (34000)
            │                                 │
     [Vnode B-2] (72000)               [Vnode A-2] (48000)
                         \           /
                          [Vnode C-1] (61000)

   * Busca da chave "user_982":
     1. Hash("user_982") = 42000
     2. Busca no anel pelo primeiro Vnode com Hash >= 42000
     3. Encontra [Vnode A-2] (48000)
     4. Retorna nó físico: "Servidor A"
```

### Padrões e Primitivas Recomendadas:
- **Busca Binária (Binary Search / Upper Bound)**: Usar busca binária sobre uma coleção ordenada de hashes de Vnodes para encontrar o primeiro hash $\ge$ hash da chave buscada. Se não houver nenhum maior, o anel dá a volta (wrap around) e a chave é mapeada para o primeiro Vnode do anel (o menor hash).
- **Vnodes Multipliers**: Mapear cada nó físico a $V$ hashes virtuais (ex: hash da concatenação `ip_servidor + "#" + index_vnode`). Um valor típico de $V$ situa-se entre 100 e 300 para garantir espalhamento.
- **Concorrência Copy-On-Write**: Como as alterações na topologia de um cluster de cache são raras comparadas às buscas de chaves, manter a estrutura do anel como um array de structs imutável e substituí-lo totalmente por uma cópia atualizada (`Copy-On-Write`) no momento das escritas. Isso permite que as leituras ocorram de forma totalmente livre de locks (`lock-free`), sem overhead de sincronização.
- **MurmurHash3 (32 ou 128 bits)**: Excelente taxa de throughput em CPU e propriedades matemáticas superiores de espalhamento em relação a funções criptográficas pesadas como MD5 ou SHA-256.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Entendimento de "Hotspots" e Skew**: Demonstração matemática de como a quantidade de Vnodes afeta a homogeneidade da distribuição física.
- **Operação de Lookup Sem Alocações de Heap**: A busca binária deve rodar sobre estruturas nativas ordenadas (como arrays ou listas planas do tipo `uint[]` ou structs compactas) sem instanciar novos objetos na pilha a cada busca.
- **Tratamento de Volta do Anel (Wrap Around)**: Implementação correta e resiliente do caso limite em que o hash da chave supera o maior hash no anel, retornando o primeiro elemento de forma linear.
- **Consistência Dinâmica sob Concorrência**: Proteger a consistência da busca concorrente enquanto novos nós estão sendo adicionados, garantindo que o array de busca nunca seja exposto em estado parcialmente atualizado ou inconsistente (por exemplo, hashes de Vnodes inseridos sem os correspondentes mapeamentos físicos prontos).

---

## 6. Trade-offs

### A. Copy-On-Write Array vs. Dicionário Ordenado com Locks (SortedDictionary)
- **Copy-On-Write (Recomendada)**:
  - *Pró*: Leituras lock-free brutas. Ideal para workloads de cache onde a leitura representa 99,99% do tráfego.
  - *Contra*: A adição/remoção de nós exige a alocação e ordenação de um novo array com todos os Vnodes, sendo uma operação lenta e custosa em memória se o cluster possuir milhares de servidores.
- **SortedDictionary com Lock Mutex**:
  - *Pró*: Adição/remoção de nós extremamente rápidas ($O(\log N)$).
  - *Contra*: Leituras concorrentes sofrem com a contenção do lock de leitura/escrita, limitando o throughput sob múltiplos núcleos.

### B. Número de Vnodes: Alto vs. Baixo
- **Alto (ex: 500 Vnodes por nó físico)**:
  - *Pró*: Distribuição de carga quase perfeita. Menor risco de sobrecarregar um único servidor (Hotspot).
  - *Contra*: Maior consumo de memória RAM e degradação proporcional no tempo de busca binária ($O(\log(\text{Nós} \times 500))$).
- **Baixo (ex: 10 Vnodes por nó físico)**:
  - *Pró*: Busca binária ultraveloz, pegada de memória mínima.
  - *Contra*: Alto risco de desequilíbrio estatístico de carga, gerando disparidades de uso de RAM e CPU no cluster físico.
