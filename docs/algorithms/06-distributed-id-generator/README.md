# Desafio 6: Gerador de IDs Distribuídos Únicos (`algo-distributed-id-generator`)

## 1. Contexto & Cenário
Em arquiteturas de microsserviços altamente distribuídas e com particionamento de dados (sharding) massivo, a geração de IDs únicos para entidades de negócios (como transações, ordens de compra ou usuários) é um requisito fundamental. Em bancos de dados monolíticos tradicionais, confiamos na numeração auto-incremental fornecida pela própria engine do banco. No entanto, em um ambiente fragmentado onde as escritas são enviadas para múltiplos servidores PostgreSQL ou MySQL independentes, IDs incrementais locais colidirão inevitavelmente.

Uma solução trivial seria utilizar UUIDs (Universally Unique Identifiers). Entretanto, UUIDs convencionais de 128 bits são aleatórios e geram indexação ineficiente no banco de dados. Eles quebram a localidade física de dados em índices baseados em B-Trees (como o índice clusterizado InnoDB do MySQL), resultando em fragmentação severa de páginas de disco, auto-page-splits constantes e degradação severa na latência de escritas e leituras. O objetivo deste desafio é implementar um gerador de IDs descentralizado de alta performance, compacto (64 bits) e ordenável cronologicamente (time-sortable), similar ao conceito **Twitter Snowflake**.

---

## 2. Requisitos Funcionais (RF)
- **Geração Descentralizada**: Permitir a geração de identificadores numéricos de 64 bits de forma totalmente offline em cada nó gerador, sem realizar chamadas de rede ou consultar bancos de dados centrais.
- **Unicidade Global**: Garantir que nenhum ID gerado em qualquer nó do cluster colida com IDs gerados em outros nós do cluster.
- **Ordenação Temporal Relativa (Time-Sortable)**: IDs gerados sequencialmente no tempo devem ser naturalmente crescentes na ordenação numérica aproximada.
- **Tratamento de Desvio de Relógio (Clock Skew)**: Se o relógio do sistema operacional sofrer um desvio para trás (ajuste NTP ou sincronia de horário), o gerador deve detectar a mudança e recusar a geração de IDs ou pausar até que o relógio real alcance o timestamp da última geração para prevenir colisões.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Performance Sub-Microsegundo**: A geração de um ID deve demorar menos de 1 microsegundo, operando puramente em memória e lógica bitwise sem bloqueios pesados na hot path.
- **Throughput Massivo por Nó**: Ser capaz de gerar mais de 4 milhões de IDs únicos por segundo por nó gerador.
- **Compactação e Eficiência**: Os IDs gerados devem caber estritamente em um inteiro de 64 bits (`long` / `int64_t`), simplificando a transmissão de dados por rede e otimizando o consumo de armazenamento de chaves primárias.
- **Thread-Safety Exclusivo**: Garantir unicidade sob concorrência extrema de múltiplas threads solicitando IDs no mesmo milissegundo no mesmo nó.

---

## 4. Guia de Implementação & Padrões
A estrutura canônica do ID de 64 bits do Snowflake é baseada em segmentação binária através de operações de bit-shifting.

```
 ┌───────────────────┬─────────────────────┬───────────────────┐
 │ Timestamp (41b)   │ Machine ID (10b)    │ Sequence (12b)    │
 └───────────────────┴─────────────────────┴───────────────────┘
  ◄─── Bit 63-22 ────►◄──── Bit 21-12 ─────►◄──── Bit 11-0 ────►
```

### Divisão Binária Recomendada (64 bits):
- **1 bit de sinal**: Sempre `0` para garantir que o número gerado seja positivo.
- **41 bits de timestamp**: Representa a diferença em milissegundos em relação a uma época (epoch) customizada (ex: `1577836800000` para 1 de Janeiro de 2020). Essa quantidade de bits permite uma vida útil de mais de 69 anos antes do estouro dos bits de tempo.
- **10 bits de identificador do trabalhador (Worker/Machine ID)**: Permite o suporte a até 1024 nós geradores simultâneos na infraestrutura de servidores da empresa.
- **12 bits de sequência**: Permite a geração de até 4096 IDs diferentes dentro do exato mesmo milissegundo por nó físico. Se a sequência estourar 4095 dentro daquele milissegundo, a execução deve travar (sleep) e aguardar o próximo milissegundo.

### Padrões e Primitivas Recomendadas:
- **Bitwise Shifts e Bitwise OR**: Montagem do ID por deslocamento de bits:
  ```
  id = (currentTimestamp << 22) | (workerId << 12) | sequence;
  ```
- **Sincronização de Concorrência**: Utilizar um lock mutex leve (ex: `Monitor` em C# ou `synchronized` em Java) para proteger o estado interno do gerador (`lastTimestamp` e `sequence`) no momento em que threads concorrentes tentam gerar um ID no mesmo milissegundo. Alternativamente, utilizar estruturas lock-free baseadas em CAS no estado empacotado em um único `long` (timestamp + sequence).
- **Proteção NTP (Network Time Protocol)**: Em caso de recuo do relógio, se `currentTimestamp < lastTimestamp`, o gerador deve lançar uma exceção explícita indicando anomalia no relógio do sistema (*clock moved backwards*) ou realizar um spin loop rápido de espera até que o tempo do sistema se restabeleça.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Cálculo Correto dos Deslocamentos (Bit Shifts)**: Demonstração de domínio sobre aritmética binária e prevenção de estouros de bits que possam alterar o sinal ou apagar dados de máquina.
- **Prevenção de Colisão por Concorrência**: Garantia de que a sequência é incrementada e resetada atomicamente sem risco de que duas threads concorrentes recebam o mesmo par `(timestamp, sequence)`.
- **Estratégia de Atribuição de Machine IDs**: Como os 1024 identificadores de máquina são distribuídos na infraestrutura (ex: usando variáveis de ambiente do Kubernetes, registro dinâmico no Consul/ZooKeeper ou hashes de IP da máquina).
- **Mitigação Prática de Clock Skew**: Resiliência contra variações horárias introduzidas por sincronizadores de tempo de rede (NTP).

---

## 6. Trade-offs

### A. Alocação Estática vs. Dinâmica de Machine IDs
- **Alocação Estática (IDs hardcoded via config)**:
  - *Pró*: Simplicidade operacional absoluta, sem dependências externas.
  - *Contra*: Alta propensão a erros humanos (ex: duplicar o machine ID em dois containers diferentes leva a colisões de IDs indetectáveis silenciosas).
- **Alocação Dinâmica (Consul / ZooKeeper / Redis)**:
  - *Pró*: Automação segura. O container se registra em um coordenador distribuído na inicialização, adquire um ID livre e o libera no shutdown.
  - *Contra*: Introduz dependência de rede e infraestrutura crítica para a inicialização da aplicação.

### B. Bloqueio por Limite de Sequência vs. Falha Rápida (Fail-Fast)
- **Bloqueio (Espera ativa / Sleep até o próximo milissegundo - Recomendada)**:
  - *Pró*: Transparente para o chamador. Garante a entrega do ID assim que o tempo avança 1ms.
  - *Contra*: Introduz latências esporádicas no percentil P99 se a taxa de geração momentânea superar 4096 req/ms no nó.
- **Fail-Fast (Lançar exceção imediatamente)**:
  - *Pró*: Latência previsível, sem bloqueios de thread na aplicação.
  - *Contra*: Exige tratamento complexo de retentativas no cliente gerador de requisições.
