# Desafio 12: Roteamento Dinâmico para Consistência Read-After-Write (`algo-read-after-write-routing`)
> **Padrões de Arquitetura Distribuída:** Read-After-Write Consistency (Consistência de Sessão), Replication Lag Mitigation (Mitigação de Atraso), Dynamic Data Source Routing (Roteamento de Conexão).

## 1. Contexto & Cenário
Para suportar milhões de leituras simultâneas, arquiteturas de alto rendimento utilizam replicação de banco de dados com topologia de **Nó Primário (Master/Writer)** e **Nós de Réplica (Replicas/Readers)**. Todas as operações de modificação (escritas, updates, deletes) são processadas exclusivamente pelo nó Primário, que replica as atualizações de forma assíncrona para as Réplicas.

Como a replicação física de rede leva tempo (variando de milissegundos a segundos sob alta carga - Replication Lag), as réplicas estão constantemente em um estado ligeiramente desatualizado. Isso cria uma experiência de usuário terrível conhecida como **falta de consistência de leitura-após-escrita (Read-After-Write)**:
1. O usuário edita a descrição do seu perfil (escrita enviada ao nó Primário).
2. O aplicativo redireciona o usuário para a página de perfil.
3. A requisição de leitura da página de perfil bate em uma réplica com lag de 500ms.
4. O perfil é renderizado com a descrição antiga. O usuário assume que o sistema falhou e tenta editar novamente, gerando cliques duplicados e frustração.

O objetivo deste desafio é projetar e implementar um middleware de **Roteamento Dinâmico de Conexão** na camada de aplicação que garanta a consistência de leitura-após-escrita (o usuário sempre vê suas próprias modificações instantaneamente), enquanto continua direcionando com segurança o tráfego de leitura frio de outros usuários para as réplicas, otimizando o uso do hardware.

---

## 2. Requisitos Funcionais (RF)
- **Rastreamento de Modificações (Write Tracking)**: Interceptar operações mutativas (POST/PUT/DELETE) e injetar um token temporário contextualmente associado à sessão do usuário (ex: Cookie HTTP seguro ou metadados de cabeçalho JWT contendo o timestamp da última gravação ou o LSN - Log Sequence Number).
- **Avaliação de Janela de Consistência**:
  - Nas requisições de leitura (GET), verificar a presença e o valor do token de última escrita.
  - Se a diferença temporária entre o timestamp atual e o timestamp da última escrita for menor que a janela crítica máxima (ex: 5 segundos), forçar o roteamento da query de leitura para o **banco de dados Primário**.
  - Caso a janela crítica tenha expirado, rotear a query para a **Réplica de Leitura**.
- **Independência de Usuários**: A garantia de ler do Primário deve ser restrita apenas ao usuário que realizou a escrita. Outros usuários lendo o mesmo recurso devem continuar consultando a réplica com consistência eventual.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead de Decisão Sub-Milissegundo**: A lógica de interceptação, decodificação do token de sessão e chaveamento de strings de conexão de banco de dados deve ocorrer em tempo inferior a 1ms na camada de aplicação.
- **Prevenção de Sobrecarga do Primário (Write-Forced Avalanche)**: 
  - Se o sistema passar por um pico de escritas agressivo, o Primário não pode ser sufocado pelo volume de leituras forçadas subsequentes. Implementar limites ou travas de segurança (ex: desativar bypass de réplica se o banco Primário atingir limites críticos de conexões ou CPU).
- **Compatibilidade com Pool de Conexões**: Chavear dinamicamente o banco sem reiniciar os pools de conexões TCP físicas (reutilizar `ConnectionPools` distintos de leitura e escrita).

---

## 4. Guia de Implementação & Padrões

### Fluxo de Roteamento Dinâmico de Banco de Dados
```
 [ Usuário Realiza Escrita ]                 [ Usuário Realiza Leitura ]
            │                                            │
            ▼ (POST /profile)                            ▼ (GET /profile)
┌───────────────────────────────┐            ┌───────────────────────────────┐
│        Primary Database       │            │  Middleware de Roteamento     │
│ (Grava dados da modificação)  │            │                               │
└──────────────┬────────────────┘            │ 1. Lê Cookie: LastWriteTime   │
               │                             │ 2. Delta = Atual - LastWrite   │
       (Replicando... Lag 2s)                └──────────────┬────────────────┘
               ▼                                            │
┌───────────────────────────────┐                   (Delta < 5s?)
│        Replica Database       │             ┌─────────────┴─────────────┐
└───────────────────────────────┘             ▼ (Sim)                     ▼ (Não)
                                     ┌─────────────────┐         ┌─────────────────┐
                                     │ Roteia p/ Nó    │         │ Roteia p/ Réplica│
                                     │ Primário (Master)│         │ de Leitura      │
                                     └─────────────────┘         └─────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **`IDbConnection` Dynamic Routing Interceptor**: Em linguagens corporativas, estender as classes de conexão ou usar interceptores ORM (ex: DbContext Interceptors em Entity Framework Core ou RoutingDataSource no Spring Boot). O interceptor lê o contexto de execução de threads local (`ThreadLocal` / `AsyncLocal` carregados pelo middleware HTTP) para decidir qual string de conexão injetar ativamente antes de abrir a transação.
- **Rastreamento baseado em LSN (Log Sequence Number)**: Para sistemas financeiros ultra-consistentes, em vez de usar timestamps temporais simples (que podem falhar por dessincronização de relógios NTP), o banco de dados retorna o LSN gerado no Commit da escrita. A réplica expõe sua versão atual de LSN replicado. O middleware compara: se `LSN_Replicado >= LSN_Escrita`, a réplica está atualizada o suficiente e pode receber a leitura de forma segura, caso contrário, bate no Primário.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Roteamento Inteligente Comprovado**: Teste de integração automatizado simulando:
  - Requisição de escrita seguida de leitura em menos de 100ms $\rightarrow$ Conexão deve apontar para o pool de escrita (Primary).
  - Requisição de leitura após 6 segundos da escrita $\rightarrow$ Conexão deve apontar para o pool de leitura (Replica).
- **Evitar Vazamento de Threads**: Prova de que a primitiva de contexto concorrente (`AsyncLocal` ou `RequestContext`) é limpa de forma confiável ao final de cada ciclo de vida HTTP request/response para evitar vazamentos lógicos de estado de conexão entre diferentes requisições concorrentes.
- **Tratamento de Indisponibilidade de Réplicas**: Se todas as réplicas caírem, o roteador dinâmico deve chavear automaticamente todo o tráfego de volta ao Primário (High Availability Fallback) e disparar alarmes.

---

## 6. Trade-offs

### A. Rastreamento baseados em Sessão (Cookies/JWT) vs. Rastreamento Centralizado (Redis)
- **Cookies locais ou Claims JWT (Recomendado)**:
  - *Pró*: 100% descentralizado e sem chamadas de rede extras; o próprio cliente carrega seu histórico de última escrita; escalabilidade infinita.
  - *Contra*: O cliente pode forçar a leitura do Primário alterando o cookie local (risco de abuso de segurança de infraestrutura se os dados não forem assinados digitalmente).
- **Rastreamento via cache distribuído (Gravar `user_id_last_write` no Redis)**:
  - *Pró*: Seguro e inviolável pelo cliente; controle de infraestrutura absoluto.
  - *Contra*: Adiciona um salto de rede extra (Redis Get) em **todas** as requisições GET da API de entrada, inserindo overhead de rede.

### B. Tempo de Janela Estático vs. Monitoramento Dinâmico de Lag
- **Janela Estática (Ex: Janela rígida de 5s)**:
  - *Pró*: Extremamente simples de codificar e sem custos de CPU medindo latências do banco.
  - *Contra*: Se o lag real da réplica for de 10 segundos devido a uma migração ou índice pesado em background, o usuário continuará vendo inconsistências durante a janela de 5s a 10s.
