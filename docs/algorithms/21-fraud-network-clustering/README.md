# Desafio 21: Agrupamento de Redes de Fraude com Union-Find (`algo-fraud-network-clustering`)
> **Padrões de Algoritmos e Microsserviços:** Disjoint Set Union (DSU), Fraude Bancária (Exactly-Once Tracking), Grafos de Conectividade Dinâmica, Detecção de Anomalias em Tempo Real.

## 1. Contexto & Cenário
Em sistemas de processamento de pagamentos instantâneos (como o PIX ou transações de cartão de crédito de adquirentes), a detecção precoce de fraudes organizadas (fraud rings) é um dos maiores desafios de segurança. Fraudadores operam redes complexas de "contas laranjas" (money mules) interligadas por transações dinâmicas ou pelo compartilhamento de dados cadastrais/telemetria (como o mesmo endereço IP, mesmo número de telefone, o mesmo identificador de dispositivo físico - Device ID, ou mesmo cartão de crédito).

Se o sistema de segurança analisar apenas transações isoladas, o comportamento parecerá legítimo. No entanto, se consolidarmos as contas ligadas em um único grafo dinâmico, conseguiremos identificar instantaneamente grandes aglomerados suspeitos. Se um nó (conta) de um grupo for categorizado como fraude confirmada, toda a rede associada deve ser suspensa imediatamente para conter as perdas de capital.

Uma solução ingênua baseada em buscas completas de grafos (como BFS ou DFS periódicos em bancos de dados de grafos como Neo4j ou Cosmos DB) tem complexidade $O(V + E)$. Sob uma taxa de fluxo contínuo de milhares de transações por segundo, rodar buscas completas causaria timeouts e asfixia de infraestrutura. 

O **Union-Find (DSU)** com otimizações de **Compressão de Caminho** e **União por Tamanho (Size)** é a estrutura ideal para este cenário. Ela permite processar e mesclar a rede de relacionamentos de forma **incremental** e em tempo de execução quase constante $O(\alpha(n))$, informando instantaneamente o tamanho total do anel de fraude associado a qualquer conta que tente realizar uma transação.

---

## 2. Requisitos Funcionais (RF)
- **Registrar Transação**: Conectar duas contas dinamicamente (`LinkAccounts(accountA, accountB)`) devido a um fluxo financeiro entre elas.
- **Vincular Atributo Cadastral**: Associar uma conta a um identificador de atributo comum (`LinkAttribute(account, attributeType, attributeValue)`), agrupando automaticamente contas que compartilham o mesmo IP/dispositivo.
- **Consulta de Tamanho do Cluster**: Retornar imediatamente o tamanho atual da rede de relacionamento (`GetClusterSize(account)`) à qual a conta pertence.
- **Avaliação de Risco**: Indicar se o tamanho da rede de relacionamento da conta ultrapassa um limite de segurança de tamanho de cluster (`IsHighRisk(account, threshold)`).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Processamento Incremental Sub-Milissegundo**: A vinculação e consulta de anéis de fraude devem rodar em complexidade de tempo quase constante $O(\alpha(n))$ por transação na hot path, garantindo resposta imediata na validação pré-aprovação de pagamento.
- **Indexação Dinâmica Bifuncional**: O serviço deve traduzir chaves string de contas e atributos (ex: `"ACC-99831"` ou `"IP-192.168.1.1"`) para IDs inteiros sequenciais internos em $O(1)$ de forma thread-safe antes de operar no DSU físico, otimizando o cache de CPU.
- **Rastreamento Dinâmico de Peso (Size Tracking)**: O Union-Find deve manter atualizado de forma precisa o tamanho de cada conjunto disjoint. Ao realizar o `Union`, o tamanho do conjunto pai deve absorver o tamanho do conjunto filho atomaticamente.

---

## 4. Guia de Implementação & Padrões

### Agrupamento Dinâmico de Contas e Atributos Compartilhados
Ao usar o Union-Find, tratamos contas e atributos (como IPs ou Device IDs) como nós de um mesmo conjunto disjunto. Quando a `Conta 1` e a `Conta 2` usam o mesmo IP, fazemos `Union(Conta 1, IP)` e `Union(Conta 2, IP)`. Ambas as contas passam a compartilhar a mesma raiz, criando um cluster de tamanho 3 (2 contas + 1 IP).

```
                       Agrupamento de Contas e Atributos (DSU)
                       
         [Conta 1] ──── (IP: 192.168.1.1) ──── [Conta 2] (Union)
              │                                   │
         (Device A)                           (Device A)  <-- Mesmo Device ID!
              │                                   │
         [Conta 3] ───────────────────────────────┘
         
         ===> Todas as 3 contas e os 2 atributos consolidados em uma única raiz!
```

### Código de Referência (C#):
Abaixo está o gerenciador de clusters de fraude estruturado em cima de um DSU robusto indexado por strings:

```csharp
public class FraudClusterManager
{
    private readonly ConcurrentDictionary<string, int> _idMapping = new();
    private int _nodeCounter = 0;

    private int[] _parent;
    private int[] _size;
    private readonly object _lock = new();

    public FraudClusterManager(int maxExpectedElements)
    {
        _parent = new int[maxExpectedElements];
        _size = new int[maxExpectedElements];
        for (int i = 0; i < maxExpectedElements; i++)
        {
            _parent[i] = i;
            _size[i] = 1; // Cada nó inicia com tamanho 1 (si mesmo)
        }
    }

    // Obtém ou cria um ID numérico sequencial para a entidade string
    private int GetOrAddEntity(string entity)
    {
        return _idMapping.GetOrAdd(entity, _ =>
        {
            int id = Interlocked.Increment(ref _nodeCounter);
            if (id >= _parent.Length)
            {
                throw new InvalidOperationException("Capacidade máxima do DSU excedida.");
            }
            return id;
        });
    }

    // Find clássico com Compressão de Caminho (Path Compression) recursiva
    private int Find(int i)
    {
        if (_parent[i] == i) return i;
        // Salva diretamente no array de parents, achatando a árvore de busca
        return _parent[i] = Find(_parent[i]);
    }

    // Union por Tamanho (Size-based Union)
    private bool Union(int i, int j)
    {
        int rootI = Find(i);
        int rootY = Find(j);

        if (rootI == rootY) return false;

        // Anexa a menor árvore sob a raiz da maior árvore
        if (_size[rootI] < _size[rootY])
        {
            _parent[rootI] = rootY;
            _size[rootY] += _size[rootI]; // Acumula o tamanho no novo pai
        }
        else
        {
            _parent[rootY] = rootI;
            _size[rootI] += _size[rootY]; // Acumula o tamanho no novo pai
        }
        return true;
    }

    public void LinkAccounts(string accountA, string accountB)
    {
        int idA = GetOrAddEntity(accountA);
        int idB = GetOrAddEntity(accountB);

        lock (_lock)
        {
            Union(idA, idB);
        }
    }

    public void LinkAttribute(string account, string attributeType, string attributeValue)
    {
        string attrKey = $"{attributeType}:{attributeValue}";
        int accId = GetOrAddEntity(account);
        int attrId = GetOrAddEntity(attrKey);

        lock (_lock)
        {
            Union(accId, attrId);
        }
    }

    public int GetClusterSize(string account)
    {
        if (!_idMapping.TryGetValue(account, out int accId))
        {
            return 0; // Conta não registrada ainda pertence a um cluster de tamanho 0
        }

        lock (_lock)
        {
            int root = Find(accId);
            return _size[root];
        }
    }

    public bool IsHighRisk(string account, int threshold)
    {
        return GetClusterSize(account) >= threshold;
    }
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Correcção do Acúmulo de Tamanho (Size Summation)**: O avaliador checará se a contagem de elementos do cluster é acumulada com precisão absoluta nas uniões (evitar erros onde o tamanho é duplicado ou não atualizado).
- **Tradução Eficiente de Strings**: Uso de dicionários concorrentes que evitem travas no mapeamento de strings para inteiros sequenciais na hot path.
- **Tratamento de Entidades Inexistentes**: Consultar o tamanho de redes de fraude para contas que nunca transacionaram deve retornar `0` ou `1` (consistente) sem quebrar o sistema com exceções.

---

## 6. Trade-offs

### A. Union-Find Incremental vs. Busca em Grafo Tradicional (DFS/BFS)
- **Union-Find (Incremental)**:
  - *Pró*: Altíssima performance. Processa conexões e consultas de forma imediata em quase $O(1)$. Perfeito para gateways de pagamento em tempo real.
  - *Contra*: Não armazena as arestas físicas de conexão. O DSU responde *se* as contas estão conectadas e qual o tamanho da rede, mas não consegue rastrear e mostrar o caminho de transferência (ex: "Conta A enviou para B, que enviou para C").
- **Busca em Grafo (DFS/BFS)**:
  - *Pró*: Permite extrair o caminho exato da fraude e todas as arestas de relacionamento para visualização em dashboards de investigação criminal.
  - *Contra*: Complexidade temporal de $O(V + E)$ inviável para processamento síncrono inline de transações sob alta vazão.

### B. Locks por Operação vs. DSU Concorrente Lock-Free
- **Lock por Operação (Monitor Sync - Recomendado para Casos Simples)**:
  - *Pró*: Simples de garantir corretude ao atualizar o parentesco e os tamanhos dos dois nós simultaneamente.
  - *Contra*: Sob concorrência agressiva de muitas threads unindo elementos de clusters distintos, pode haver gargalos de contenção.
- **DSU Concorrente Lock-Free**:
  - *Pró*: Throughput de CPU máximo sem suspensão de threads.
  - *Contra*: Implementar a atualização simultânea do parentesco e do array de tamanhos (`size`) de forma atômica e lock-free é matematicamente desafiador (exige técnicas complexas de transações de memória de software - STM ou relaxação temporal de consistência do tamanho).
