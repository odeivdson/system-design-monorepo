# Desafio 19: Coordenador de Workflows BPMN e Limites de Transação (`distributed-workflow-coordinator`)

## 1. Contexto & Cenário
Motores de execução de fluxos e orquestração de processos (como Camunda BPMN, Temporal.io, Netflix Conductor ou AWS Step Functions) são componentes indispensáveis em instituições financeiras. Eles controlam a esteira de liberação de crédito, gerenciando ações de longo prazo que dependem de etapas manuais e de integrações com parceiros instáveis. Uma esteira de empréstimo típica inicia com a solicitação do cliente, realiza consultas cadastrais na Dataprev, faz verificações em bureaus de crédito e antifraude, aguarda a assinatura eletrônica do contrato e finaliza com o Pix de liquidação.

O principal gargalo operacional de motores de workflow tradicionais como o Camunda reside na **persistência e contenda de banco de dados**. Cada passo do fluxo BPMN tradicionalmente altera o estado de execução no banco relacional. Se o banco de dados saturar sob alto volume de empréstimos simultâneos, toda a esteira da instituição financeira ficará lenta ou indisponível.

Para projetar soluções de escala Staff/Principal, é preciso dominar o conceito de **Fronteiras Transacionais (Transaction Boundaries)**. O orquestrador não pode persistir a cada mínima micro-operação; ele deve consolidar o progresso em banco apenas em pontos de salvamento estratégicos (padrão `asyncBefore`/`asyncAfter` do Camunda). Além disso, em vez de executar códigos síncronos pesados acoplados à máquina de estados principal, o orquestrador deve adotar o padrão **External Tasks (Trabalhadores Externos)**, onde workers distribuídos dão *pull* em tarefas de tópicos específicos de forma isolada, processam-nas fora do escopo principal e reportam de volta o sucesso ou falha.

O objetivo deste desafio é projetar o núcleo e as fronteiras transacionais de um coordenador de workflows distribuídos leve e de alta vazão.

---

## 2. Requisitos Funcionais (RF)
- **Iniciar Instância de Processo (`StartProcess`)**: Criar e inicializar uma nova execução de fluxo a partir de uma definição de tarefas sequenciais/paralelas BPMN.
- **Consultar Tarefas Externas (`PollTasks`)**: Permitir que microsserviços trabalhadores (Workers) façam varredura e adquiram (lock) tarefas pendentes de um tópico específico (`topicName`, `workerId`, `leaseDuration`).
- **Completar Tarefa (`CompleteTask`)**: Reportar a finalização de uma tarefa pelo worker, salvando as variáveis de saída e destravando a transição do processo para o próximo nó do fluxo.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Consolidação Atômica em Fronteiras (Commit Points)**: O coordenador só deve gravar e persistir o progresso no banco de dados físico ao atingir nós marcados como assíncronos (`asyncBefore` habilitado). Passos lógicos puramente em memória devem rodar na mesma transação de CPU sem escritas consecutivas no disco. Se o servidor cair, o fluxo deve retomar exatamente do último ponto de salvamento atômico, garantindo reexecução segura *at-least-once*.
- **Isolamento de Workers via Travas de Lease**: Ao realizar o *pull* de uma tarefa externa, o coordenador deve marcar a tarefa como bloqueada para aquele `workerId` específico por um tempo determinado (`leaseDuration`, ex: 30 segundos). Nenhuma outra thread de worker pode capturar a mesma tarefa concorrentemente enquanto a trava estiver ativa.
- **Tratamento de Workers Mortos (Dead Worker Recovery)**: Se um worker capturar uma tarefa e sofrer um crash silencioso sem reportar sucesso ou falha, a tarefa ficará presa. O coordenador deve possuir uma rotina background que detecte travas de lease expiradas e as retorne automaticamente para a fila (`QUEUED`), permitindo que outros workers assumam a execução.

---

## 4. Guia de Implementação & Padrões

A arquitetura e os limites de transição do orquestrador com suporte a external tasks e commit points operam conforme detalhado abaixo:

```
    [ Inicia Processo ]
            │
            ▼ (Em Memória)
    ┌──────────────────────┐
    │  Tarefa 1 (Síncrona) │
    └───────┬──────────────┘
            │ (Passa Direto)
            ▼
    ┌──────────────────────┐
    │  Tarefa 2 (asyncBefore) ◄────────┐ (Ponto de Retomada pós-crash)
    └───────┬──────────────┘           │
            │ (Grava Estado no DB)     │
            ▼                          │
    ┌──────────────────────┐           │
    │  Fila de Tarefas     │           │
    │  Externas (Outbox)   │           │
    └───────┬──────────────┘           │
            │                          │
            ▼ [ Worker Poll Loop ] ────┼ (Se falha/timeout, reverte)
    ┌──────────────────────┐           │
    │  Worker HTTP/gRPC    │ ──────────┘
    │  (Consulta Dataprev) │
    └──────────────────────┘
```

### Padrões e Primitivas Recomendados:
- **Tabela de Jobs com Estados Finitos**: Projetar as tabelas de banco de dados do coordenador separando o estado do workflow:
  - `ProcessInstance`: Armazena a definição ativa, variáveis globais e o ID do nó atual de progresso.
  - `ExternalTask`: Armazena a fila de tarefas ativas com estados `QUEUED`, `LOCKED`, `COMPLETED` e os metadados de controle (`worker_id`, `lock_expiration`).
- **Atomic Lock com SKIP LOCKED**: Ao consultar tarefas pendentes para o worker, usar SQL otimizado para concorrência de forma a evitar que duas threads de polling selecionem a mesma tarefa:
  ```sql
  UPDATE external_task 
  SET status = 'LOCKED', worker_id = :workerId, lock_expiration = :expirationTime
  WHERE id = (
      SELECT id FROM external_task 
      WHERE status = 'QUEUED' AND topic_name = :topicName
      ORDER BY created_at ASC 
      FOR UPDATE SKIP LOCKED 
      LIMIT 1
  )
  RETURNING *;
  ```
- **State Machine de Execução (Engine Loop)**: Implementar um processador de grafo direcionado acíclico (DAG) que navegue pelos nós. Ao encontrar um nó sem a flag `asyncBefore`, execute-o na mesma thread de CPU. Ao encontrar um nó com a flag, persista o estado no banco de dados e encerre a thread síncrona atual.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Recuperabilidade Pós-Crash**: Demonstrar via testes de simulação que, se a aplicação for abortada abruptamente no meio de um passo assíncrono, ao reiniciar o coordenador é capaz de carregar e retomar o estado correto a partir da tabela de checkpoints salvos, sem pular ou refazer passos indevidamente.
- **Prevenção de Condições de Corrida de Polling**: Garantir que sob alta carga concorrente de centenas de workers paralelos fazendo requisições de *pull* no mesmo tópico, cada tarefa seja distribuída estritamente para um único worker por vez.
- **Isolamento de Variáveis por Escopo**: Como as variáveis locais e globais do processo são isoladas e mescladas. A conclusão de uma tarefa com dados de saída (`outputVariables`) deve fundir esses dados no contexto do processo de forma atômica, lidando de forma consistente com dados modificados em paralelo.

---

## 6. Trade-offs

### A. Persistência de Estado em Banco de Dados vs. Event Sourcing (ex: Temporal.io)
- **Persistência de Estado (Camunda clássico / Recomendado para este desafio)**: Muito simples de compreender e interagir via consultas SQL em tabelas relacionais padrão.
  - *Contra*: Alta contenda de escrita no banco de dados principal de produção à medida que o volume de instâncias cresce.
- **Event Sourcing (Temporal.io / Zeebe Camunda 8)**: O estado não é salvo atualizando linhas de tabelas; em vez disso, grava-se um log contínuo e imutável de eventos (Process Started, Task Locked, Task Completed). O estado é reconstruído via replay rápido de eventos.
  - *Pró*: Throughput de gravação gigantesco e lock-free absoluto na base de dados.
  - *Contra*: Complexidade extrema de infraestrutura (necessita de um event store robusto e indexador paralelo para buscas) e curva de aprendizado íngreme para os desenvolvedores.

### B. Polling Baseado em Pull vs. Notificação HTTP baseada em Push (Webhooks)
- **Polling Baseado em Pull (External Tasks - Recomendado)**: O worker determina quando quer tarefas com base no seu próprio tempo ocioso.
  - *Pró*: Controle perfeito de Backpressure. O microsserviço nunca é inundado com mais requisições do que aguenta processar.
- **Notificação HTTP baseada em Push**: O coordenador faz chamadas POST automáticas para os microsserviços trabalhadores assim que a tarefa fica pronta.
  - *Pró*: Menor latência interna (não há tempo morto esperando o ciclo de polling).
  - *Contra*: O coordenador pode sufocar os microsserviços se houver um pico repentino de processos, exigindo que cada microsserviço implemente mecanismos pesados de rejeição de tráfego.
