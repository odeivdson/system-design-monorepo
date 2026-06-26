# Desafio 17: Integrador de APIs Governamentais Resiliente (Dataprev Gateway) (`external-api-throttler-outbox`)

## 1. Contexto & Cenário
Em ecossistemas bancários e fintechs de crédito no Brasil, a concessão de empréstimos consignados ou a antecipação de benefícios exige a consulta obrigatória a bases governamentais (como Dataprev, INSS ou Receita Federal). A API do parceiro externo (Dataprev) é de missão crítica, mas sofre com latências imprevisíveis (de 500 ms até picos de 10 segundos) e impõe limites de vazão extremamente rígidos (ex: máximo de 50 requisições por segundo por instituição parceira).

Se a aplicação de empréstimo fizer chamadas HTTP síncronas diretamente da thread da requisição do cliente, a latência da Dataprev causará um gargalo de **esgotamento de thread pool** no servidor da fintech. Sob alto volume de acessos, as conexões de banco de dados e os recursos de rede serão totalmente consumidos aguardando a API externa, derrubando a API principal da instituição financeira para todos os outros usuários.

A solução clássica de arquitetura distribuída para este problema é isolar a integração externa por meio do padrão **Transactional Outbox (Caixa de Saída Transacional)** combinado com um **Gateway Limitador de Vazão (Throttling)**. Em vez de chamar a API externa no fluxo crítico de checkout, a aplicação grava a solicitação na tabela de Outbox do mesmo banco de dados sob a mesma transação ACID do empréstimo. Um trabalhador em background (Worker) consome essa tabela e enfileira as tarefas em um agendador com controle estrito de vazão (*Leaky Bucket*), garantindo que as chamadas HTTP à Dataprev nunca ultrapassem a cota permitida. Se o órgão público falhar de forma consecutiva, um disjuntor (**Circuit Breaker**) abre na borda do gateway para desviar novas propostas para fluxos de processamento offline demorados, protegendo a integridade da fila do sistema.

---

## 2. Requisitos Funcionais (RF)
- **Registrar Solicitação (`SubmitVerification`)**: Gravar uma solicitação de consulta Dataprev na tabela de Outbox de forma transacional atômica e retornar um identificador único de rastreamento (`verificationId`).
- **Processar Lote com Throttling (`ProcessBatch`)**: Um worker em segundo plano lê as tarefas pendentes do Outbox e dispara as chamadas HTTP de verificação externa respeitando estritamente a taxa máxima de requisições por segundo (RPS) configurada.
- **Consultar Estado de Verificação (`GetStatus`)**: Consultar o estado atual do processamento da solicitação (ex: `PENDENTE`, `PROCESSANDO`, `SUCESSO`, `FALHA` ou `DEGRADADO`).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Limite de Vazão Garantido (Strict Throttling)**: O gateway deve garantir matematicamente que as chamadas à Dataprev nunca superem o limite máximo de RPS parametrizado, mesmo se houver um pico repentino de 100.000 requisições de empréstimo em lote de uma só vez (uso do algoritmo *Leaky Bucket* na fila de despacho).
- **Circuit Breaker com Degradação Ativa**: Se a taxa de erro ou de timeouts da Dataprev superar 50% em uma janela deslizante, o Circuit Breaker deve abrir (`OPEN`). Novas propostas que entrarem no sistema devem cair instantaneamente em um fluxo de análise offline temporário (degradação amigável), evitando entupir as filas de memória com tarefas fadadas ao fracasso.
- **Retentativas Resilientes com Exponential Backoff e Jitter**: Quando chamadas individuais sofrerem timeouts esporádicos, o sistema deve retentar a execução aplicando tempos de espera crescentes multiplicativos adicionados de ruído aleatório (Jitter), impedindo que o gateway execute ataques de negação de serviço (DDoS) involuntários à Dataprev quando o órgão público reestabelecer seus servidores pós-instabilidade.

---

## 4. Guia de Implementação & Padrões

O fluxo transacional e a coordenação de vazão concorrente do integrador são estruturados conforme ilustrado abaixo:

```
    [ Nova Proposta Empréstimo ]
                 │
                 ▼ (Transação ACID Local)
    ┌─────────────────────────┐
    │ Banco de Dados Legacy   ├────────┐
    │ (Grava Empréstimo +     │        ▼
    │  Outbox de Consulta)    │  ┌───────────┐
    └────────────┬────────────┘  │  WAL Log  │
                 │               └───────────┘
                 ▼ (Processo Polling / CDC)
    ┌─────────────────────────┐
    │  Worker de Integração   │
    └────────────┬────────────┘
                 │
                 ▼ [ Fila de Vazão Leaky Bucket (Max 50 RPS) ]
    ┌─────────────────────────┐
    │  Circuit Breaker        │ ◄─────┐ (Se taxa falha > 50%, abre)
    └────────────┬────────────┘       │
                 │ (Closed)           │
                 ▼                    │
    ┌─────────────────────────┐ ──────┘
    │ API Externa Dataprev    │
    └─────────────────────────┘
```

### Padrões e Componentes Recomendados:
- **Algoritmo Leaky Bucket (Fila com Vazão Constante)**: Utilizar um semáforo temporizado ou temporizadores atômicos periódicos para despachar chamadas em lotes fixos (ex: a cada 20 ms, liberar exatamente 1 tarefa da fila de envio, resultando em 50 chamadas por segundo constantes).
- **Máquina de Estados de Resiliência (Circuit Breaker)**: Implementar uma máquina de estados robusta (`CLOSED`, `OPEN`, `HALF-OPEN`) que monitore a saúde das conexões. Em estado `HALF-OPEN`, o gateway permite a passagem de apenas algumas requisições de teste para reavaliar a estabilidade da Dataprev de forma controlada.
- **Lock-Free Polling do Outbox**: Para ler e atualizar a tabela de Outbox concorrentemente de forma rápida sem travar linhas de processamento da aplicação, utilizar queries SQL otimizadas (ex: no PostgreSQL, `SELECT ... FOR UPDATE SKIP LOCKED` limita a seleção de registros sem causar contenção ou bloqueios com as threads que gravam novas transações de empréstimo).

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Zero Vazamento de Mutexes / Conexões sob Timeout**: Comprovada resiliência lógica no tratamento de cancelamento HTTP (uso estrito de `CancellationToken` ou timeouts de timeout de conexão). O gateway deve abortar conexões lentas de forma agressiva para evitar manter sockets de rede órfãos abertos indefinidamente.
- **Políticas de Retentativa sem Starvation**: Garantir que tarefas antigas que falharam e estão sofrendo retries com *backoff* não fiquem "furando a fila" ou impedindo que novas propostas mais recentes progridam na esteira do gateway.
- **Estratégia de Auto-Reparo do Reconciliador**: Como o sistema detecta propostas que ficaram presas em estado `PROCESSANDO` devido a quedas abruptas do pod do próprio worker. O gateway deve rodar uma rotina de checagem de "checkpoints" expirados para redefinir o estado e forçar o reprocessamento de tarefas órfãs.

---

## 6. Trade-offs

### A. Tabela Outbox no DB vs. Mensageria em Memória (Redis / RabbitMQ)
- **Tabela Outbox no DB (Recomendado para consistência financeira)**: Consistência transacional absoluta. A proposta de empréstimo só é criada se o registro de outbox também for gravado no mesmo commit atômico do banco. Perda zero de dados em caso de queda de energia física.
  - *Contra*: Alta contenda e escrita no banco de dados principal de produção, exigindo manutenção periódica de limpeza de registros processados da tabela de outbox.
- **Mensageria em Memória (RabbitMQ/Redis)**: Velocidade ultra-rápida e desacoplamento de I/O do banco de dados.
  - *Contra*: Ocorrência eventual de problemas de consistência (ex: transação de empréstimo sofre rollback no banco, mas a mensagem já foi disparada para a fila RabbitMQ, executando uma chamada Dataprev fantasma).

### B. Fail Fast Imediato vs. Agendamento com Fila de Espera Infinita
- **Fail Fast Imediato sob Sobrecarga**: Se o gateway ultrapassar o limite de capacidade e a fila de throttling encher, rejeitar novas propostas na hora.
  - *Pró*: Garante proteção total de recursos e previne estouros de memória.
  - *Contra*: Experiência do usuário prejudicada devido a erros intermitentes de serviço indisponível.
- **Fila Infinita com Agendamento Tardio**: Aceitar todas as requisições e processá-las aos poucos.
  - *Pró*: O cliente nunca recebe erros de barramento de tráfego.
  - *Contra*: Risco iminente de falta de memória (OOM) no servidor caso a carga de entrada persista superior à taxa de vazão da Dataprev por muitas horas, além de gerar latências de processamento gigantescas de várias horas que frustram o cliente final.
