# Desafio 18: Motor de Armazenamento LSM-Tree Minimal (`algo-lsm-storage-engine`)

## 1. Contexto & Cenário
Bancos de dados e sistemas de persistência tradicionais construídos sobre árvores B+ (B-Trees) organizam as informações gravando dados diretamente em páginas físicas do disco. Sob cargas agressivas de escrita, as árvores B+ realizam atualizações in-place dispersas, resultando em acessos aleatórios de gravação ao disco (Random I/O). O acesso aleatório degrada drasticamente a performance, além de aumentar o desgaste físico de unidades SSD devido à amplificação de escrita.

Para resolver este gargalo de gravação, os bancos de dados modernos de alta performance (como Apache Cassandra, RocksDB, LevelDB, InfluxDB e ClickHouse) utilizam motores baseados em **LSM-Tree (Log-Structured Merge-Tree)**.

A LSM-Tree otimiza o fluxo convertendo acessos aleatórios de disco em escritas puramente sequenciais. Em vez de gravar dados diretamente na estrutura final persistida, as novas atualizações de dados seguem dois passos atômicos rápidos:
1. Gravação sequencial em um arquivo de log físico (Write-Ahead Log - WAL) apenas para garantir durabilidade caso a máquina caia.
2. Atualização de uma estrutura ordenada na memória rápida chamada **MemTable** (geralmente implementada com uma SkipList concorrente).

Quando a MemTable atinge seu limite de capacidade física, ela é congelada (transformada em MemTable Imutável) e um processo em segundo plano (background thread) efetua o **Flush**, descarregando os dados ordenadamente em arquivos imutáveis no disco chamados **SSTables (Sorted String Tables)**. Devido a essa imutabilidade e divisão temporária, a leitura precisa buscar as chaves em ordem cronológica inversa (da mais nova para a mais antiga). Para evitar que a leitura sofra com consultas consecutivas a múltiplos arquivos em disco (Read Amplification), implementamos **Bloom Filters** na memória e uma rotina recorrente de **Compactação** (Compaction) em segundo plano que mescla SSTables redundantes eliminando chaves duplicadas ou deletadas (Tombstones).

---

## 2. Requisitos Funcionais (RF)
- **Inserir Registro (`Put`)**: Gravar uma chave e seu valor no motor de armazenamento.
- **Recuperar Registro (`Get`)**: Buscar e retornar o valor correspondente a uma chave.
- **Remover Registro (`Delete`)**: Marcar uma chave como deletada escrevendo um marcador especial de exclusão (Tombstone). A remoção física deve ocorrer apenas durante a compactação de dados.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Flush Assíncrono Não-Bloqueante**: Quando a MemTable ativa atinge a capacidade máxima, o motor deve chavear atomicamente para uma nova MemTable ativa e despachar a MemTable antiga para gravação assíncrona em disco em uma thread em segundo plano, sem bloquear as requisições de gravação dos clientes.
- **Leitura Coerente Concorrente (Read Path)**: A busca de chaves deve respeitar estritamente a ordem cronológica de atualização: `Active MemTable` -> `Immutable MemTable (aguardando flush)` -> `SSTables mais novas` -> `SSTables mais antigas`.
- **Motor de Compactação em Background**: Um worker em segundo plano deve identificar SSTables elegíveis e realizar a mesclagem e ordenação (Merge-Sort) sequencial de arquivos em novos blocos maiores, limpando registros inválidos e liberando espaço físico no disco.
- **Recuperabilidade (Crash Recovery)**: Ao inicializar, o motor deve detectar a presença do arquivo WAL e efetuar o replay de logs para reconstruir o estado em memória caso o sistema tenha caído abruptamente.

---

## 4. Guia de Implementação & Padrões

O fluxo de dados e os processos concorrentes do motor de armazenamento são orquestrados conforme ilustrado abaixo:

```
                  [ Operações Put / Delete ]
                              │
               ┌──────────────┴──────────────┐
               ▼ (Gravação WAL)              ▼ (Escrita MemTable)
          ┌─────────┐                  ┌──────────┐
          │ WAL.log │                  │ MemTable │ (Active)
          └─────────┘                  └────┬─────┘
                                            │ (Atinge Capacidade Máxima)
                                            ▼
                                       ┌──────────┐ (Chaveia Atômico)
                                       │ MemTable │ (Immutable)
                                       └────┬─────┘
                                            │
                                            ▼ [ Thread de Flush ]
                                       ┌──────────┐
                                       │ SSTable  │ (Disco - Nível 0)
                                       └────┬─────┘
                                            │
                                            ▼ [ Thread de Compactação ]
                                       ┌──────────┐
                                       │ SSTables │ (Disco - Nível 1)
                                       └──────────┘
```

### Padrões e Componentes Recomendados:
- **Indexador SSTable de Nível Único**: Salvar um índice esparso (Sparse Index) no final de cada arquivo SSTable contendo chaves amostrais de blocos físicos e seus offsets correspondentes. Isso permite buscar itens via busca binária rápida sem precisar ler toda a SSTable para a memória.
- **Bloom Filters**: Criar e carregar em memória um Bloom Filter local associado a cada arquivo SSTable criado no disco. Leituras a chaves inexistentes devem ser rejeitadas no filtro para evitar acessos inúteis I/O de leitura ao disco.
- **Mesclagem Ordenada de K Vias (K-Way Merge)**: O processo de compactação de SSTables (que são arquivos ordenados internamente) deve ser implementado via algoritmo de Merge-Sort utilizando uma Priority Queue (Min-Heap) para ordenar e unificar os arquivos lidos sequencialmente, garantindo complexidade de tempo eficiente em $O(N \log K)$ e baixíssimo consumo de memória RAM.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Atomicidade no Chaveamento de MemTable**: Comprovação de que a troca entre as referências da MemTable ativa e imutável e a criação do novo arquivo WAL de transações ocorre de forma thread-safe e atômica, evitando perda de chaves concorrentes durante a transição.
- **Prevenção de I/O Blocking no Read Path**: Garantir que consultas (`Get`) a dados em memória (MemTables) nunca sofram bloqueios de leitura concorrentes originados pelo processo de compactação ou flush de disco em segundo plano.
- **Gestão de Tombstones na Compactação**: Garantir que as chaves marcadas com exclusão (Tombstones) sejam propagadas e removidas definitivamente das SSTables finais consolidando o espaço em disco. O candidato deve responder: *"Quando é seguro remover definitivamente um Tombstone durante o ciclo de vida de compactação?"*

---

## 6. Trade-offs

### A. Leveled Compaction vs. Size-Tiered Compaction
- **Leveled Compaction (ex: RocksDB)**: Divide os arquivos do disco em níveis numerados (L1, L2, L3...). Cada nível possui limite máximo de tamanho físico e garante que as SSTables do mesmo nível não tenham chaves sobrepostas.
  - *Pró*: Reduz a amplificação de leitura (Read Amplification) ao limite de uma SSTable por nível.
  - *Contra*: Alta amplificação de escrita (Write Amplification) devido à constante mesclagem de arquivos entre níveis adjacentes.
- **Size-Tiered Compaction (ex: Cassandra)**: Mescla SSTables que atingem tamanhos semelhantes de forma direta em novos arquivos.
  - *Pró*: Baixa amplificação de escrita (escreve muito rápido).
  - *Contra*: Alta amplificação de espaço (consome muito disco temporário para compactar) e de leitura (pode precisar pesquisar em múltiplos arquivos simultaneamente).

### B. WAL Fsync: Sync vs. Async (Buffered Writes)
- **Fsync Síncrono (Always Sync)**: Grava e força a gravação física no hardware a cada transação (`Put`).
  - *Pró*: Perda zero de dados garantida em caso de queda de energia física.
  - *Contra*: Latência severamente limitada pelo tempo de rotação do disco / acesso físico ao SSD.
- **Fsync Assíncrono (Periodic / Buffered)**: Escreve no buffer do SO e executa fsync de tempos em tempos (ex: a cada 1 segundo).
  - *Pró*: Alta vazão de escritas simultâneas.
  - *Contra*: Risco de perder os últimos segundos de dados inseridos se houver perda abrupta de energia na máquina de processamento.
