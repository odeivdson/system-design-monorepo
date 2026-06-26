# Desafio 21: Carteira Digital Baseada em Event Sourcing & CQRS (`event-sourced-wallet`)
> **Padrões de Microsserviços Associados:** Event Sourcing (Auditoria e Reconstrução), CQRS (Segregação de Leitura e Escrita), Polyglot Persistence (Event Store + Cache de Projeção), Database per Service (Autonomia de Dados).

## 1. Contexto & Cenário
Em sistemas financeiros, carteiras digitais e processadores de pagamento (como PayPal, Stripe ou carteiras de e-commerce), a integridade dos saldos das contas é sagrada. Atualizar saldos executando simples comandos SQL destrutivos do tipo `UPDATE wallets SET balance = balance - 100 WHERE id = 1` é altamente arriscado. Esta abordagem destrói o histórico de como o saldo foi alcançado, inviabiliza auditorias regulatórias confiáveis e é propensa a fraudes e corrupção silenciosa de dados.

Para resolver este problema de conformidade e integridade, utilizamos o padrão **Event Sourcing**. Em vez de armazenar o estado atual da carteira, armazenamos todos os **eventos de mudança de estado** que ocorreram em ordem cronológica imutável (ex: `WalletCreated`, `MoneyDeposited`, `MoneyWithdrawn`, `WithdrawalFailed`). O saldo atual é computado agregando e reproduzindo (replaying) a história de eventos sobre a carteira.

Em paralelo, para evitar lentidão ao computar o saldo reproduzindo milhões de eventos históricos em tempo real a cada leitura, aplicamos o padrão **CQRS (Command Query Responsibility Segregation)**. O modelo de escrita (Command) valida as transações estritamente contra o log imutável de eventos, enquanto o modelo de leitura (Query) lê um banco de dados de leitura altamente otimizado (Projeção) atualizado de forma assíncrona orientada a eventos.

---

## 2. Requisitos Funcionais (RF)
- **Depósitos e Retiradas (Commands)**:
  - `DepositMoney(WalletID, Amount)`: Valida e registra o evento `MoneyDeposited`.
  - `WithdrawMoney(WalletID, Amount)`: Verifica se o saldo atualizado é suficiente. Se sim, gera `MoneyWithdrawn`. Se não, rejeita a transação e grava `WithdrawalFailed` para histórico.
- **Consulta de Carteira (Query)**:
  - `GetWalletState(WalletID)`: Retorna o saldo consolidado atualizado e a lista resumida de transações executadas.
- **Snapshot Automatizado**: O sistema deve gerar um instantâneo do estado (`Snapshot`) a cada 1.000 eventos no stream. Na próxima inicialização, o motor reconstrói o estado a partir do último Snapshot mais os eventos excedentes subsequentes, reduzindo o tempo de lookup para $O(\text{Eventos restantes})$ em vez de $O(N)$.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Consistência Estrita no Modelo de Escrita**: Evitar overdraft (saldo negativo). Em chamadas concorrentes paralelas de débito do mesmo milissegundo, o sistema deve impedir saques duplicados. Deve-se implementar **Controle de Concorrência Otimista (OCC)** baseado na versão do stream (ex: lançar erro se a versão atualizada no evento for diferente da versão esperada no banco de dados).
- **Projeção com Consistência Eventual Controlada**: O pipeline de sincronização que lê o Event Store e atualiza o banco de leitura (ex: Redis ou tabela de leitura SQL) deve rodar em background. A latência de replicação das projeções de leitura deve ser sub-50ms sob carga.
- **Append-Only Performance**: O Event Store deve ser otimizado para gravações extremamente rápidas baseadas apenas em inserções (sem Updates ou Deletes).

---

## 4. Guia de Implementação & Padrões

### Arquitetura CQRS & Event Sourcing Fim-a-Fim
```
 [ Cliente: Gravação ]                   [ Cliente: Leitura ]
         │                                       │
         ▼ (Deposit / Withdraw Command)          ▼ (Get Balance Query)
┌────────────────────────────────┐       ┌──────────────────────────────┐
│        Command Handler         │       │        Query Handler         │
│                                │       │                              │
│ 1. Lê Snapshot + Eventos       │       │ Retorna imediatamente da     │
│ 2. Valida Regras de Saldo      │       │ Base de Projeção (Latência   │
│ 3. Salva Evento no Event Store │       │ Sub-milissegundo)            │
└────────────────┬───────────────┘       └──────────────▲───────────────┘
                 │                                      │
        (Appends event to log)               (Read Replica / Cache)
                 ▼                                      │
┌────────────────────────────────┐                      │
│     Event Store (Append-Only)  │                      │
└────────────────┬───────────────┘                      │
                 │                                      │
           (Publish Event)                              │
                 ▼                                      │
┌────────────────────────────────┐                      │
│     Projector / Event Denom    │                      │
│ (Lê o log de eventos e atualiza│──────────────────────┘
│  assincronamente a projeção)   │
└────────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Optimistic Concurrency Control (OCC)**: O esquema da tabela `events` no banco de dados deve possuir uma restrição de chave única composta por `(stream_id, version)`. Ao tentar persistir um novo evento de débito, a aplicação incrementa `version = version + 1`. Se duas threads tentarem gravar a mesma versão simultaneamente, o banco relacional rejeitará a transação por violação de índice exclusivo, forçando a thread perdedora a retentar todo o fluxo de validação (Reload + Re-evaluate).
- **Event Store Schema**:
  - `id`: UUID (Chave primária).
  - `stream_id`: UUID (ID da carteira).
  - `version`: Integer (Versão sequencial incremental do stream).
  - `event_type`: String (Ex: `MoneyWithdrawn`).
  - `payload`: Text/JSON (Dados do evento contendo valores, moedas e timestamps).
  - `created_at`: Timestamp.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prevenção Concorrente de Saldo Negativo (Zero Race Condition)**: Teste prático rodando 50 threads paralelas disparando debitos simultâneos de R$ 10,00 em uma carteira com saldo inicial de R$ 30,00. Exatamente 3 transações devem ter sucesso; as outras 47 devem gerar falhas controladas e o saldo final da projeção deve ser cravado em R$ 0,00.
- **Reconstrução com Snapshot**: O código deve demonstrar a capacidade de ler o snapshot mais recente como ponto de partida e aplicar apenas os eventos gerados após o snapshot.
- **Resiliência do Projetor**: Como o projetor de leitura se recupera se cair durante o processamento. O avaliador buscará checkpoints do projetor (armazenamento do `LastProcessedEventID` no banco de leitura) para garantir processamento idempotente exato de uma vez (exactly-once processing das projeções).
- **Tratamento de Mudanças de Contrato (Event Schema Evolution)**: Design de manipulação de evolução de esquema de eventos antigos no payload do JSON (Upcasting de eventos).

---

## 6. Trade-offs

### A. Consistência Eventual de Leitura vs. Bloqueio Síncrono
- **Leitura em Projeção CQRS (Consistência Eventual - Recomendado)**:
  - *Pró*: Leituras escaláveis a bilhões de queries com latência sub-milissegundo acessando caches distribuídos.
  - *Contra*: O cliente pode fazer um depósito e, se atualizar a tela imediatamente, o saldo exibido pode demorar milissegundos para refletir o depósito (janela de inconsistência).
- **Leitura com Replay em Tempo Real (Consistência Imediata)**:
  - *Pró*: O saldo exibido é sempre 100% garantido e atualizado matematicamente no ato.
  - *Contra*: O banco sofre degradação geométrica de performance conforme o volume de transações da carteira cresce (lookup pesado e repetitivo).

### B. Tamanho do Snapshot
- **Snapshots Frequentes (Ex: a cada 100 eventos)**:
  - *Pró*: Recuperação de agregados em tempo recorde (tempo de replay irrisório).
  - *Contra*: Alto custo de processamento e armazenamento duplicado de snapshots no banco de dados.
- **Snapshots Espaçados (Ex: a cada 5.000 eventos)**:
  - *Pró*: Poupa armazenamento e processamento de instantâneos.
  - *Contra*: Latência na inicialização de carteiras com alto giro de transações devido ao longo replay necessário.
