# Desafio 20: Estrutura Union-Find Concorrente Lock-Free (`algo-concurrent-union-find`)
> **Padrões de Algoritmos e Concorrência:** Disjoint Set Union (DSU), Lock-Free CAS (Compare-And-Swap), Dynamic Connectivity, Concorrência de Granularidade Fina.

## 1. Contexto & Cenário
Em sistemas distribuídos e paralelos de alto desempenho, a estrutura de dados **Union-Find** (ou *Disjoint Set Union - DSU*) é vital para resolver o problema de conectividade dinâmica em tempo real (como agrupar nós ativos em topologias de rede mutáveis ou detectar ciclos em grafos massivos de forma concorrente).

Uma implementação sequencial padrão usa compressão de caminhos (path compression) e união por rank para atingir complexidade de tempo quase constante $O(\alpha(n))$ por operação. No entanto, o DSU padrão é inerentemente **stateful** e mutável: as operações de busca (`Find`) modificam os ponteiros de parentesco para otimizar buscas futuras. 

Se múltiplas threads tentarem ler e escrever no DSU simultaneamente, ocorrerão condições de corrida gravíssimas:
- Ciclos infinitos causados por ponteiros de parentesco apontando uns para os outros em loops circulares.
- Inconsistência nos contadores de rank/tamanho, levando a árvores desbalanceadas com altura degenerada de $O(n)$.
- Travamentos causados por locks globais síncronos que eliminam a paralelização da CPU.

Este desafio exige projetar uma estrutura DSU **totalmente thread-safe e livre de travas (lock-free)**, utilizando primitivas de hardware atômicas como **Compare-And-Swap (CAS)** para coordenar atualizações simultâneas de ponteiros e manter a consistência da estrutura sob carga massiva de múltiplas threads de CPU.

---

## 2. Requisitos Funcionais (RF)
- **Operação Find**: Localizar e retornar o representante (raiz) do conjunto que contém o elemento $x$ de forma concorrente.
- **Operação Union**: Unir dinamicamente os conjuntos contendo os elementos $x$ e $y$. Se já pertencerem ao mesmo conjunto, a operação deve reportar e encerrar de forma segura.
- **Operação Connected**: Retornar um booleano indicando se os elementos $x$ e $y$ pertencem atualmente ao mesmo subconjunto.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Garantia de Progresso Lock-Free**: Nenhuma thread deve ser suspensa por locks síncronos (como `lock`, `Mutex` ou `Semaphore`). As colisões concorrentes nas atualizações de ponteiros devem ser resolvidas via loops de retentativa CAS (`Interlocked.CompareExchange` ou `AtomicReference.compareAndSet`).
- **Otimização de Travessia Concorrente (Path Halving)**: Implementar compressão de caminho de passagem única através de *Path Halving* ou *Path Splitting* atômicos, reduzindo a altura da árvore de forma passiva nas operações de busca.
- **Prevenção de Ciclos**: Garantir que as atualizações simultâneas de ponteiros por threads distintas nunca gerem ciclos auto-referenciados (nós que apontam para si mesmos ou laços circulares de parentesco).
- **Complexidade de Espaço Estrita**: Uso de memória limitado a arrays indexados primitivos de tamanho fixo $n$, evitando a alocação dinâmica de objetos na Heap durante as operações.

---

## 4. Guia de Implementação & Padrões

### Compressão de Caminho via Path Halving Concorrente (Lock-Free)
A compressão de caminho tradicional por recursão (`Find(parent[x])`) requer duas passagens e é difícil de tornar lock-free. Em vez disso, usamos o **Path Halving** em uma única passagem: para cada nó visitado durante a busca, apontamos o nó atual para o seu avô usando um CAS atômico.

```
                      Path Halving Concorrente (CAS)
                       
                 [Node X]                                [Node X]
                    │                                    ┌───┴───┐
                    ▼ (parent)                           │       ▼
                [Node Y]              === CAS ===>       │   [Node Y]
                    │                                    │       │ (parent)
                    ▼ (parent)                           │       ▼
                [Node Z (Root)]                          └──►[Node Z (Root)]
```

### Código de Referência Lock-Free (C#):
O segredo de um Union-Find concorrente lock-free seguro reside em ordenar as uniões por valor numérico de identificador da raiz para prevenir deadlocks lógicos e loops recursivos infinitos.

```csharp
public class ConcurrentUnionFind
{
    private readonly int[] _parent;
    private readonly int[] _rank;

    public ConcurrentUnionFind(int size)
    {
        _parent = new int[size];
        _rank = new int[size];
        for (int i = 0; i < size; i++)
        {
            _parent[i] = i; // Cada nó aponta para si mesmo inicialmente
            _rank[i] = 0;
        }
    }

    // Operação Find Lock-Free com Path Halving
    public int Find(int x)
    {
        while (true)
        {
            int p = Volatile.Read(ref _parent[x]);
            int gp = Volatile.Read(ref _parent[p]);

            if (p == gp) return p; // Atingiu a raiz

            // CAS: Tenta apontar 'x' diretamente para o seu avô 'gp' (Path Halving)
            Interlocked.CompareExchange(ref _parent[x], gp, p);
            x = gp; // Avança na travessia
        }
    }

    // Operação Connected
    public bool Connected(int x, int y)
    {
        return Find(x) == Find(y);
    }

    // Operação Union Lock-Free usando loops CAS
    public bool Union(int x, int y)
    {
        while (true)
        {
            int rootX = Find(x);
            int rootY = Find(y);

            if (rootX == rootY) return false; // Já estão no mesmo conjunto

            // Prevenção de ciclos: Força a união direcionada baseada em menor rank
            // Se empatar, usamos o valor do índice como desempate determinístico
            if (_rank[rootX] < _rank[rootY] || (_rank[rootX] == _rank[rootY] && rootX < rootY))
            {
                // Tenta apontar rootX para rootY de forma atômica
                if (Interlocked.CompareExchange(ref _parent[rootX], rootY, rootX) == rootX)
                {
                    return true;
                }
            }
            else
            {
                // Tenta apontar rootY para rootX de forma atômica
                if (Interlocked.CompareExchange(ref _parent[rootY], rootX, rootY) == rootY)
                {
                    // Se os ranks eram iguais e unimos rootY a rootX, incrementamos o rank de rootX
                    if (_rank[rootX] == _rank[rootY])
                    {
                        Interlocked.Increment(ref _rank[rootX]);
                    }
                    return true;
                }
            }
            // Se o CAS falhou devido a uma mutação concorrente por outra thread, o loop while retenta
        }
    }
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prevenção Concorrente de Ciclos**: O candidato deve provar matematicamente como as regras de desempate por índice (`rootX < rootY`) ou Rank impedem que duas threads unam simultaneamente `A` a `B` e `B` a `A`, o que geraria um loop infinito no `Find`.
- **Estratégia de Path Halving Unipessoal**: Demonstração de que o `CompareExchange` na atualização do avô (`parent[x] = gp`) não corrompe o estado caso a raiz já tenha mudado, pois o CAS apenas falhará silenciosamente e continuará a busca.
- **Ausência de Locks**: Verificação de que não existem sessões críticas síncronas (`lock`, `synchronized`) sob nenhum pretexto.

---

## 6. Trade-offs

### A. Path Compression (2 passagens) vs. Path Halving (1 passagem)
- **Path Compression (2 passagens)**:
  - *Pró*: Otimização máxima do balanceamento, encurtando todos os nós visitados diretamente até a raiz absoluta.
  - *Contra*: Muito complexo de implementar de forma lock-free, pois exige atualizar múltiplos ponteiros mutáveis em momentos distintos de pilha, gerando condições de corrida severas de inconsistência.
- **Path Halving / Splitting (1 passagem - Recomendado)**:
  - *Pró*: Altamente amigável a operações lock-free. Faz atualizações atômicas imediatas locais a cada passo da travessia.
  - *Contra*: O balanceamento resultante é ligeiramente menos perfeito do que na compressão completa, porém compensado pela enorme vazão concorrente.

### B. Union por Rank vs. Union Sem Balanceamento
- **Union por Rank/Tamanho (Recomendado)**:
  - *Pró*: Garante limites logarítmicos estritos na altura máxima das árvores ($O(\log n)$), assegurando buscas rápidas.
  - *Contra*: Exige controle atômico e espaço adicional para gerenciar o array de ranks concorrentemente.
- **Union Sem Balanceamento (União aleatória ou simples)**:
  - *Pró*: Implementação mais simples, poupando espaço de memória auxiliar.
  - *Contra*: Em cenários específicos de inserções ordenadas, a árvore pode degenerar em uma lista linear, transformando o tempo de busca em $O(n)$ e arruinando o desempenho da estrutura.
