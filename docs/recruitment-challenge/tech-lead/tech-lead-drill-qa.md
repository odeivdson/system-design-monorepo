# Q&A de Elite: Perguntas & Respostas para Entrevistas de Tech Lead

Este documento reúne perguntas clássicas de nível **Tech Lead (L5/L6)** focadas na liderança técnica da equipe, tomadas de decisão de arquitetura local e de integração, divisão de tarefas (*slicing*) e mediação com produto.

---

## 🧭 Seção 1: Clean Architecture & SOLID

### Q1: Como Tech Lead, como você argumenta com um desenvolvedor sênior que prefere injetar diretamente dependências concretas (como um cliente HTTP do Stripe) nos casos de uso em vez de criar interfaces e aplicar a inversão de dependências (DIP)?
* **Resposta Ideal**:
  * O foco da injeção de dependências e de interfaces não é "escrever mais código", mas sim o **desacoplamento** e a **testabilidade** do sistema.
  * Injetar diretamente clientes HTTP concretos torna o caso de uso acoplado à assinatura daquela biblioteca específica. Se precisarmos mudar de provedor de pagamento ou atualizar a biblioteca HTTP, teremos que alterar a classe de regras de negócio.
  * Além disso, testar a lógica de negócio de forma isolada (sem fazer chamadas reais de rede ao Stripe) fica impossível sem interfaces.
  * Eu explicaria esses trade-offs técnicos ao desenvolvedor sênior em uma sessão de pareamento ou revisão de código, demonstrando na prática como a escrita de testes de unidade fica simplificada ao mockar uma interface limpa.

---

## 🧭 Seção 2: Arquitetura Event-Driven & Consistência

### Q2: Em um sistema orientado a eventos onde um consumidor do Kafka processa pagamentos e atualiza saldos de carteiras, como garantir a idempotência no consumidor sabendo que o Kafka garante entrega do tipo "at-least-once" (pelo menos uma vez)?
* **Resposta Ideal**:
  * Como a rede ou brokers podem falhar após o processamento, mas antes do commit do offset no Kafka, mensagens duplicadas são normais.
  * Para garantir processamento de pagamento único (*exactly-once* do ponto de vista do negócio), o consumidor deve aplicar o padrão de **Idempotência no Consumidor**:
    1. Cada evento de pagamento deve conter um identificador único de transação (`transaction_id` ou `event_id`).
    2. No início do processamento do consumidor, iniciamos uma transação no banco de dados.
    3. Tentamos inserir esse ID em uma tabela de controle de idempotência (ex: `processed_events`) que possui uma `PRIMARY KEY` ou restrição única no campo do ID.
    4. Se a inserção falhar por chave duplicada (`UniqueConstraintViolation`), o banco sofre rollback imediato e o consumidor rejeita a mensagem sem reprocessar (commitando o offset).
    5. Se a inserção suceder, atualizamos o saldo e registramos o lançamento na mesma transação atômica do banco de dados, completando a escrita de forma segura.

---

## 🧭 Seção 3: Divisão de Projetos (Slicing) & Produto

### Q3: O time de produto quer lançar um sistema de cashback e estima que a integração total com o motor de crédito e contabilidade levará 3 meses. Como você faz o fatiamento técnico (*slicing*) do projeto para que a equipe comece a entregar valor em produção a cada duas semanas?
* **Resposta Ideal**:
  * Em vez de planejar um "Big Bang deploy" no final de 3 meses, eu aplico **Slicing Vertical** guiado por fatias menores de negócio:
    * **Sprint 1 (MVP de Leitura/Cálculo):** Implementar o cálculo conceitual de cashback no carrinho de compras e expor para um grupo fechado de testes via *Feature Flags*, sem gravar saldo ainda.
    * **Sprint 2 (Lançamento Simplificado):** Gravar o cashback em um banco de dados local simples e processar o resgate manual via painel do suporte (atendendo os primeiros clientes).
    * **Sprint 3 (Integração de Escrita):** Integrar com o motor de crédito centralizado de forma automática assíncrona.
    * **Sprint 4 (Otimizações & Analytics):** Adicionar relatórios de uso e conciliação financeira automatizada.
  * Isso permite que o código seja implantado de forma contínua em produção sob Feature Flags, reduzindo o risco de integração no fim do projeto e gerando feedback real de uso logo no início.

---

## 🧭 Seção 4: Gestão de Débito Técnico
 
### Q4: Como convencer o Product Manager (PM) do seu time a priorizar uma refatoração crítica de uma biblioteca HTTP de integração de pagamentos que está vazando conexões e gerando lentidões esporádicas, mas cuja alteração não traz nenhuma nova funcionalidade visual para o usuário final?
* **Resposta Ideal**:
  * Para dialogar com produto de forma eficaz, o Tech Lead deve traduzir problemas de arquitetura técnica em **métricas comerciais de negócio e custos**:
    * Apresentar o impacto financeiro das falhas: "As lentidões geradas pelo vazamento de sockets estão gerando 2% de falhas na conversão de compras, o que equivale a R$ X mil perdidos por semana".
    * Apresentar o impacto no tempo de desenvolvimento da equipe: "Nossos engenheiros sênior perdem hoje 10 horas semanais reiniciando servidores e corrigindo falhas de suporte manual causadas por esse bug. Resolvendo isso, ganharemos velocidade para entregar a feature Y mais rápido".
    * Propor uma solução focada (ex: configurar um Connection Pool correto na biblioteca atual) em vez de reescrever tudo do zero, reduzindo o esforço de 2 semanas para apenas 1 dia de trabalho.

---

## 🧭 Seção 5: Padrão Outbox e Consistência Transacional (FinTech)

### Q5: No Ledger do nosso time, após salvar o lançamento financeiro no banco de dados local com sucesso, a aplicação precisa publicar um evento `TransactionCreated` no Kafka para que outros times (como Fraude e Contabilidade) reajam. Se publicarmos o evento diretamente após o commit do banco, o que acontece se a aplicação cair (crash) exatamente no milissegundo após o commit, mas antes do envio para o Kafka? Como você desenha esse fluxo de forma atômica?
* **Resposta Ideal**:
  * Se tentarmos fazer o commit do banco e a publicação no Kafka em duas etapas consecutivas sem uma barreira atômica, o sistema sofrerá de **inconsistência eventual irreversível** em caso de crash (a transação é gravada, mas o evento nunca é disparado).
  * Para resolver isso no nível do time de forma resiliente, empregamos o **Padrão Outbox (Transactional Outbox)**:
    1. Na mesma transação ACID que grava o saldo e o lançamento (tabelas `accounts` e `ledger_entries`), inserimos uma nova linha em uma tabela local chamada `outbox` contendo o payload do evento (JSON) e o status `PENDING`.
    2. Como a gravação do Outbox está na mesma transação de banco de dados, ela tem garantia ACID: ou ambos salvam, ou ambos falham.
    3. Um processo separado de background worker (ou um agente de CDC como o Debezium lendo o WAL do banco) varre periodicamente a tabela `outbox`, lê os eventos pendentes, publica no Kafka e, após a confirmação de recebimento (Ack), atualiza a linha para `PROCESSED` ou a deleta.
    4. Isso garante entrega *at-least-once* de forma 100% tolerante a falhas do servidor da aplicação.

---

## 🧭 Seção 6: Observabilidade e Telemetria no Worker Pool (Ride-Sharing Dispatcher)

### Q6: O motor de despacho de motoristas (`MatchJobProcessor`) possui um pool de workers concorrentes consumindo a fila geoespacial. Durante um pico de demanda (chuva), a latência para os passageiros explodiu, e o sistema começou a falhar por time-out. Quais métricas operacionais e ferramentas de observabilidade você exige que o time implemente para diagnosticar se a lentidão é decorrente de concorrência/bloqueios (Thread Starvation) ou sobrecarga externa do banco?
* **Resposta Ideal**:
  * Para diagnosticar o gargalo sem fazer suposições, precisamos cruzar métricas de runtime com telemetria de dependências:
    1. **Métricas de Fila e Workers:** Rastrear a taxa de ocupação dos workers (ex.: quantas threads do pool estão ativas simultaneamente), a latência da fila em memória (tempo que a requisição passa na fila antes de ser consumida) e taxa de processamento por segundo (throughput).
    2. **Métricas de Runtime (Thread Starvation/GC Pause):** Coletar o número de threads bloqueadas (Thread State: Blocked/Waiting), o tempo gasto com Garbage Collection (GC Pause Time) e o uso de CPU. Se a CPU estiver baixa mas a latência alta e workers 100% ocupados, indica Thread Starvation (threads presas aguardando locks).
    3. **Rastreamento de Banco de Dados:** Medir o tempo de execução e a contenda de conexão do pool do PostgreSQL (Connections in Use, Waiting Connections, Query Latency).
    4. **Distributed Tracing (OpenTelemetry):** Criar spans específicos no processador de match para separar o tempo gasto na fila do tempo de busca geoespacial no Redis e gravação no Postgres. Isso aponta com precisão cirúrgica onde a latência reside.

---

## 🧭 Seção 7: Cache Stampede & Cache Penetration sob Alto Tráfego (URL Shortener)

### Q7: O encurtador de URLs do time está sob tráfego agressivo (10.000 QPS de leitura). O que acontece se uma URL encurtada extremamente popular expirar no Redis (Cache Miss simultâneo de milhares de requisições) ou se um invasor fizer varredura de chaves aleatórias inexistentes? Como você protege o banco NoSQL contra sobrecarga sem criar soluções complexas demais para o time manter?
* **Resposta Ideal**:
  * Esses dois problemas de escala exigem proteções distintas e complementares:
    1. **Cache Stampede (Key Expiration sob Carga):** Quando uma chave popular expira, milhares de requisições paralelas sofrerão cache miss ao mesmo tempo e baterão no DynamoDB para buscar o valor. Para evitar isso, o time deve implementar **Singleflight** (ou coalescência de requisições locais). O Singleflight garante que para uma mesma chave em cache miss, apenas a primeira thread consulte o banco, enquanto todas as outras threads em paralelo aguardam a resposta daquela única consulta antes de repovoar o cache, reduzindo 10.000 chamadas para 1 única query.
    2. **Cache Penetration (Chaves Inexistentes):** Se chaves inexistentes forem consultadas, elas sempre gerarão cache miss e baterão no banco de dados. A solução é armazenar no Redis a indicação de que a chave é inexistente com um TTL curto (ex.: salvar o token com valor vazio/nulo por 5 minutos). Para volumes maiores, podemos configurar um **Filtro de Bloom (Bloom Filter)** no API Gateway, que valida rapidamente se o token existe antes mesmo de tocar na infraestrutura de cache ou banco de dados.
