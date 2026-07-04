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

---

## 🏛️ Seção 8: As 30 Perguntas Frequentes que Mais Reprovam Tech Leads

Esta seção compila as perguntas comportamentais e arquiteturais mais difíceis de entrevistas para Tech Lead em Big Techs, explicando por que os candidatos costumam falhar e qual o mindset correto para aprovação.

---

### Pillar 1: Liderança, Mentoria e Cultura de Engenharia

#### Q8. Como você lida com um desenvolvedor sênior extremamente produtivo, mas que possui atitudes tóxicas ou cria silos de informação no time?
* **Por que reprova?** Candidatos respondem de forma tolerante à toxicidade ("ele entrega muito, então tento não incomodá-lo") ou reagem de forma agressiva/confrontadora de imediato.
* **Abordagem de Sucesso:** Demonstrar que a produtividade individual nunca compensa a destruição da moral coletiva da equipe. Explicar como teria uma conversa privada inicial, baseada em comportamentos observados e dados objetivos, estabelecendo um plano de ação claro de melhoria (ex.: parear com juniores, documentar o código). Se não houver mudança de comportamento, a demissão ou movimentação de área deve ser recomendada em alinhamento com o Engineering Manager.

#### Q9. Como você ajuda um desenvolvedor pleno do seu time a se desenvolver para atingir o nível sênior?
* **Por que reprova?** Foca apenas em conselhos vagos ("digo para ele estudar mais") ou delega toda a responsabilidade ao RH.
* **Abordagem de Sucesso:** Mostrar uma estrutura deliberada de crescimento: mapear as competências exigidas para o nível sênior, identificar lacunas específicas na atuação do pleno e delegar projetos de média complexidade onde ele precise liderar o design e a entrega (com a supervisão e apoio do Tech Lead por trás dos panos).

#### Q10. Como você convence seu time a adotar uma nova prática de engenharia (ex.: testes unitários ricos ou ADRs) quando há resistência ativa?
* **Por que reprova?** Adota uma postura autocrática ("eu mando e eles fazem") ou desiste facilmente diante da resistência.
* **Abordagem de Sucesso:** Demonstrar influência técnica em vez de autoridade: criar uma prova de conceito (PoC) simples mostrando os benefícios rápidos (redução de retrabalho), recrutar um aliado no time para adotar a prática primeiro e liderar workshops práticos de capacitação para diminuir o atrito.

#### Q11. Qual o papel do Tech Lead na diversidade e inclusão dentro do time técnico?
* **Por que reprova?** Respostas genéricas que tratam o assunto como "responsabilidade apenas do RH".
* **Abordagem de Sucesso:** Apresentar ações práticas cotidianas sob controle do TL: garantir que as discussões técnicas no Slack ou reuniões dêem espaço de voz a todos (interrompendo cortes/interrupções), estruturar processos de revisão de Pull Request focados puramente no código de forma objetiva e acolhedora, e criar documentações inclusivas e pedagógicas.

#### Q12. Como você lida com a delegação de tarefas complexas sem cair na armadilha do microgerenciamento?
* **Por que reprova?** Mostra falta de confiança no time ("se eu não fizer ou olhar tudo, dá errado") ou delega totalmente sem qualquer acompanhamento de qualidade (*hand-off* irresponsável).
* **Abordagem de Sucesso:** Definir expectativas de entrega claras no início (o *quê* e *porquê*), mas dar autonomia sobre o *como*. Estabelecer pontos de contato definidos para suporte (ex.: checkpoints na metade do projeto ou pareamento voluntário) e basear o controle em testes e revisões assíncronas de PR.

#### Q13. Como você lida com a desmotivação geral da equipe quando a diretoria cancela um projeto crítico no qual o time trabalhou por 6 meses?
* **Por que reprova?** Concorda com o desânimo criticando a diretoria publicamente ou ignora os sentimentos do time fingindo que nada aconteceu.
* **Abordagem de Sucesso:** Demonstrar inteligência emocional: validar a frustração do time de forma empática, mas redirecionar o foco rapidamente para o aprendizado técnico consolidado (ex.: "a arquitetura de microsserviços que criamos será reutilizada no projeto X") e conectar o time aos novos objetivos estratégicos de negócio da empresa.

---

### Pillar 2: Gestão de Projetos, Prazos e Divisão de Trabalho (Slicing)

#### Q14. O que você faz quando a gerência exige uma estimativa de prazo exata para um projeto de alta complexidade com muitas incertezas técnicas?
* **Por que reprova?** Dá prazos arbitrários para agradar os gerentes ("acho que leva 3 semanas") ou se recusa categoricamente a dar qualquer visibilidade.
* **Abordagem de Sucesso:** Propor a divisão do projeto em etapas. Solicitar um período curto (ex.: 2 a 3 dias) para realizar um estudo técnico e construir pequenas PoCs (Spikes). Fornecer estimativas em faixas de confiança (ex.: 4 a 6 semanas) em vez de uma data única e listar de forma explícita os riscos que podem alterar o cronograma.

#### Q15. Se o time está consistentemente estourando os prazos de entrega acordados nas sprints, como você atua para identificar a causa raiz?
* **Por que reprova?** Culpa o time ("as pessoas são lentas") ou atribui à fatalidade sem propor soluções estruturais.
* **Abordagem de Sucesso:** Realizar uma análise orientada a dados na retrospectiva: verificar se os itens de trabalho estão grandes demais (falta de slicing), medir o tempo em que as tarefas ficam travadas em Code Review ou QA (gargalo de processo), e avaliar se houve sobrecarga de incidentes de produção que interromperam o fluxo de desenvolvimento planejado.

#### Q16. Como você equilibra o tempo entre codificar de forma individual e liderar tecnicamente o time? Qual o percentual ideal?
* **Por que reprova?** Candidatos dizem que passam 100% do tempo codando ou 0% (comportando-se como gerentes de projeto puros).
* **Abordagem de Sucesso:** O percentual ideal varia entre 30% a 50% de codificação individual. Explicar que a escrita de código do TL deve focar em tarefas não-bloqueantes (refatorações, PoCs, ferramentas internas, infraestrutura básica) para evitar que o time dependa dele para entregar features de negócio prioritárias nas sprints. O restante do tempo é investido em reuniões de alinhamento, revisões de PR, design de sistemas e mentoria.

#### Q17. O que você faz se o gerente de produto alterar o escopo de uma funcionalidade crítica no meio de uma sprint ativa?
* **Por que reprova?** Aceita a mudança passivamente gerando sobrecarga e estresse no time, ou reage defensivamente bloqueando o negócio.
* **Abordagem de Sucesso:** Agir como um facilitador de trade-offs. Explicar o impacto técnico ao PM (ex.: "para incluir essa alteração agora, teremos que remover as tarefas X e Y desta sprint para não comprometer a qualidade do código"). Permitir a mudança se houver priorização explícita e substituição de escopo equivalente de forma transparente.

#### Q18. Como você ajuda o time a quebrar uma funcionalidade abstrata e complexa em tarefas pequenas e estimáveis (slicing)?
* **Por que reprova?** Divide as tarefas por camadas técnicas (ex.: Tarefa 1: Criar Banco de Dados; Tarefa 2: Criar API; Tarefa 3: Criar Tela). Esse modelo impede entregas incrementais.
* **Abordagem de Sucesso:** Aplicar o conceito de **Fatiamento Vertical (Vertical Slicing)**: estruturar as tarefas de forma que cada uma represente uma funcionalidade de ponta a ponta utilizável, mesmo que simplificada (ex.: "Cadastrar usuário apenas com dados básicos" em vez de "Criar base inteira de usuários"). Isso permite deploys contínuos e testes integrados rápidos desde o primeiro dia.

#### Q19. O que fazer quando um projeto estratégico importante atrasa por causa de dependências de outros times técnicos da empresa?
* **Por que reprova?** Adota postura passiva ("estou esperando o outro time responder o ticket") ou gera atritos políticos de imediato.
* **Abordagem de Sucesso:** Tomar as rédeas do alinhamento cross-team: marcar reuniões rápidas com o TL do outro time para alinhar contratos de API e prioridades, propor mockar as dependências externas para destravar o time local enquanto o outro conclui a entrega, e escalar a dependência de forma organizada para os managers se o atraso comprometer marcos críticos da empresa.

---

### Pillar 3: Gestão de Débito Técnico e Qualidade de Código

#### Q20. Como você define o limite entre um débito técnico aceitável (que permite acelerar uma entrega comercial) e um débito perigoso?
* **Por que reprova?** Candidatos puristas ("nunca permito débitos técnicos") ou desleixados ("faço qualquer gambiarra para entregar").
* **Abordagem de Sucesso:** Tratar o débito técnico como uma ferramenta financeira. Débito aceitável é aquele temporário, isolado sob testes ricos e feature flags, acordado com produto para testar uma hipótese de mercado rápida. Débito perigoso é aquele que introduz race conditions, afeta a integridade dos dados, reduz drasticamente a velocidade de deploys subsequentes ou compromete a segurança física do sistema.

#### Q21. Um pull request importante contém melhorias de arquitetura excelentes, mas que não estavam no escopo planejado da entrega e aumentam a complexidade do código. Como você avalia e decide sobre a aprovação?
* **Por que reprova?** Aprova sem questionar (criando complexidade acidental) ou rejeita friamente sem dar feedback construtivo.
* **Abordagem de Sucesso:** Avaliar sob a ótica da **Complexidade Acidental vs. Essencial**. Se a melhoria de arquitetura resolve um problema real que o sistema terá na próxima sprint, é aceitável. Se for apenas um padrão abstrato desnecessário no momento (YAGNI - *You Aren't Gonna Need It*), eu conversaria com o engenheiro para remover a complexidade e sugerir criar uma tarefa dedicada no backlog técnico para essa melhoria caso faça sentido no futuro.

#### Q22. Como você argumenta a necessidade de investir tempo em automação de testes e qualidade de código para stakeholders não-técnicos?
* **Por que reprova?** Usa termos técnicos abstratos ("nosso código ficará mais limpo e elegante").
* **Abordagem de Sucesso:** Traduzir qualidade em **velocidade e previsibilidade**: demonstrar estatísticas simples (ex.: "no último trimestre, gastamos 30% do tempo do time corrigindo bugs em produção que foram introduzidos por falta de cobertura de testes. Com testes robustos, teremos deploys mais seguros e entregaremos novas features de produto mais rápido").

#### Q23. Como você conduz o processo de Code Review no time para que ele seja ágil e não se torne um gargalo de entregas?
* **Por que reprova?** Exige que todos os pull requests passem por sua aprovação pessoal de forma centralizada ou permite debates subjetivos intermináveis nos comentários.
* **Abordagem de Sucesso:** Descentralizar o processo: definir regras claras de revisão (ex.: no mínimo 2 aprovações de qualquer sênior/pleno), automatizar code style e linters no CI/CD para que o PR foque apenas na lógica de negócio, e estabelecer a diretriz de que discussões com mais de 3 comentários de ida e volta devem ser resolvidas em uma chamada rápida de 5 minutos, documentando a decisão.

#### Q24. Como o seu time garante que o código entregue atenda aos requisitos de segurança e conformidade (ex.: LGPD/GDPR) antes de ir a produção?
* **Por que reprova?** Trata segurança como tarefa secundária ou "problema do time de segurança global".
* **Abordagem de Sucesso:** Inserir a segurança de forma contínua no fluxo de trabalho (DevSecOps): configurar varreduras estáticas automatizadas de vulnerabilidades (SAST/DAST) no pipeline de CI/CD, realizar modelagem de ameaças básica nos desenhos de System Design e garantir revisões de segurança nos Pull Requests para evitar gravação de dados sensíveis (PII) nos logs da aplicação.

#### Q25. O que fazer se você herdar um microsserviço crítico legado escrito em uma tecnologia legada sem testes e que vive quebrando?
* **Por que reprova?** Propõe imediatamente reescrever o sistema inteiro do zero (uma armadilha clássica que costuma falhar).
* **Abordagem de Sucesso:** Propor refatoração gradual e segura usando o **Padrão Estrangulador (Strangler Fig Pattern)** se for migrar de tecnologia, ou começar cobrindo o sistema legado com **testes de integração caixa-preta** externos (que garantem que a entrada e saída permaneçam inalteradas) antes de mexer em qualquer linha de código interna. Realizar modificações pequenas e incrementais à medida que novas regras de negócio forem solicitadas para aquela base.

---

### Pillar 4: Arquitetura, System Design e Decisões Técnicas Críticas

#### Q26. Como você escolhe entre um banco de dados relacional clássico (Postgres) e um banco NoSQL (DynamoDB/Cassandra) para um novo microsserviço do seu time?
* **Por que reprova?** Responde com base em preferências pessoais ou modismos, sem fundamentar em trade-offs.
* **Abordagem de Sucesso:** Apresentar critérios objetivos de engenharia:
  * **Relacional (SQL):** Escolher quando o sistema exige relacionamentos complexos, consistência transacional estrita (ACID) imediata (ex.: contas e ledgers) e consultas dinâmicas de dados ad-hoc.
  * **NoSQL:** Escolher quando o padrão de acesso aos dados é previsível (busca chave-valor direta), o volume de dados exige escala horizontal elástica ilimitada (ex.: histórico de geolocalização ou logs analíticos de cliques) e a consistência eventual é aceitável para o negócio.

#### Q27. Como você lida com um impasse técnico onde metade do seu time quer ir pelo caminho de arquitetura A (ex.: microsserviços dedicados) e a outra metade pelo caminho B (ex.: modular monolith)?
* **Por que reprova?** Toma a decisão de forma autocrática de imediato, ou adia indefinidamente a decisão com medo de desagradar membros do time.
* **Abordagem de Sucesso:** Estruturar uma decisão guiada por dados. Pedir que cada grupo escreva um documento simplificado detalhando prós, contras, custos operacionais e esforço de entrega (RFC/ADR). Reunir o time, debater os trade-offs de forma respeitosa e, caso o consenso não seja alcançado, o TL toma a decisão final assumindo a responsabilidade (*Disagree and Commit*), explicando claramente os motivos objetivos para todos.

#### Q28. Como seu time projeta APIs públicas para garantir a compatibilidade com versões anteriores e evitar quebrar clientes integrados em produção?
* **Por que reprova?** Sugere fazer alterações destrutivas diretamente na API e esperar que os clientes atualizem rápido.
* **Abordagem de Sucesso:** Aplicar boas práticas de versionamento de API: versionar rotas (ex.: `/v1/payments` vs. `/v2/payments`), garantir que novos campos em payloads sejam sempre opcionais, usar deprecation headers para alertar sobre APIs antigas e manter suporte ativo às rotas legadas até que todos os principais clientes migrem de versão.

#### Q29. O que é "Overengineering" e como você impede que seu time caia nessa armadilha ao projetar novos sistemas?
* **Por que reprova?** Acha que overengineering é apenas escrever código complexo demais, ou defende o uso de padrões complexos desnecessários sob o pretexto de "futura escalabilidade".
* **Abordagem de Sucesso:** Definir overengineering como a introdução de complexidade acidental desnecessária para resolver problemas que o negócio não tem no momento (ex.: configurar clusters multi-regionais complexos para um sistema de 10 requisições por minuto). Evitar isso aplicando o princípio YAGNI, revisando os desenhos de System Design na etapa de RFC e forçando o time a focar em entregar a arquitetura mais simples possível que atenda ao SLA de produto atual e suporte crescimento de curto prazo (ex.: 10x o volume atual, não 1.000x de imediato).

#### Q30. Como você projeta sistemas para lidar com picos sazonais maciços de tráfego de forma resiliente?
* **Por que reprova?** Sugere apenas "aumentar o tamanho das máquinas virtuais" (escala vertical simples, que tem limites físicos e custos astronômicos).
* **Abordagem de Sucesso:** Apresentar estratégias de resiliência e escala horizontal:
  * **Escala Horizontal Automática (HPA):** Configuração de auto-scaling baseada em CPU/Memória ou fila.
  * **Amortecimento de Carga:** Uso de filas de mensageria assíncronas para desacoplar a escrita do processamento.
  * **Degradação de Serviço Graciosa (Graceful Degradation):** Desativar recursos não-essenciais da aplicação sob estresse (ex.: desativar recomendações personalizadas na home de um e-commerce para salvar I/O de banco).
  * **Circuit Breakers & Rate Limiting:** Bloquear tráfego excedente e isolar falhas de serviços externos para evitar efeito cascata (*cascading failures*).

---

### Pillar 5: Gestão de Conflitos e Mediação de Stakeholders

#### Q31. Como você gerencia conflitos de prioridade onde o time de negócios exige o desenvolvimento de uma feature complexa e urgente, mas o time de engenharia está focado em resolver incidentes operacionais recorrentes em produção?
* **Por que reprova?** Fica do lado da engenharia bloqueando o negócio inteiramente, ou cede a negócios sobrecarregando o time técnico.
* **Abordagem de Sucesso:** Agir como tradutor e negociador de riscos. Explicar o impacto real de negócios dos incidentes operacionais (ex.: "a Feature X que vocês pedem perderá conversões de compra porque a plataforma de pagamento cai a cada 2 horas"). Propor um acordo de alocação de esforço equilibrado ou dedicar uma sprint inteira para estabilização operacional em troca de acelerar a entrega da Feature X logo em seguida de forma segura.

#### Q32. Descreva um erro técnico ou arquitetural grave que você cometeu no passado como líder técnico. O que você aprendeu com ele e como corrigiu?
* **Por que reprova?** Diz que nunca errou (sinalizando arrogância ou falta de experiência real) ou relata um erro bobo/irrelevante que não demonstra vulnerabilidade ou aprendizado real.
* **Abordagem de Sucesso:** Compartilhar um cenário real de falha técnica (ex.: "escolhemos uma estratégia de banco de dados NoSQL que parecia ideal para escala, mas conforme as regras de negócio de relatórios cresceram, geramos complexidade extrema para consultas, levando a queries lentas em produção"). Explicar as ações tomadas para mitigar (criar índice composto de urgência, reestruturar fluxo analítico assíncrono) e, principalmente, o aprendizado (ex.: "aprendi a nunca modelar bancos NoSQL sem antes mapear exaustivamente todas as necessidades de consulta do time de produto").

#### Q33. Como você reage quando um desenvolvedor sênior do seu time não concorda com a sua decisão de design de um projeto e expressa isso de forma vocal e contrariada nas reuniões de time?
* **Por que reprova?** Tenta usar a hierarquia para silenciar o sênior ("eu decidi e pronto") ou cede à pressão dele apenas para evitar confrontos.
* **Abordagem de Sucesso:** Demonstrar maturidade profissional e respeito intelectual. Conversar em uma 1-on-1 privada com o sênior para ouvir detalhadamente suas preocupações técnicas sem postura defensiva. Validar os pontos válidos dele. Se os dados objetivos ainda sustentarem minha decisão original, eu explicaria a justificativa de negócios e pediria seu comprometimento técnico com a entrega (*Disagree and Commit*), reforçando que a discordância é saudável, mas o time precisa avançar unido após a decisão tomada.

#### Q34. O que você faz quando a diretoria da empresa impõe o uso de uma tecnologia/parceiro externo que você sabe que é tecnicamente péssimo para a arquitetura atual do sistema?
* **Por que reprova?** Reclama com o time gerando desmotivação geral ou sabota a integração da ferramenta.
* **Abordagem de Sucesso:** Documentar formalmente os riscos de forma profissional (através de uma RFC ou relatório técnico sucinto) cobrindo custos adicionais, aumento de latência e esforço de manutenção. Apresentar alternativas de contorno. Se a decisão executiva for mantida por motivos políticos ou comerciais legítimos da empresa, focar em desenhar uma camada de isolamento (Gateway/Anti-Corruption Layer) para blindar o restante do sistema contra a má qualidade do parceiro externo.

#### Q35. Como você lida com a pressão direta de executivos seniores da empresa que entram em contato direto com você para pedir pequenas features rápidas fora do processo de priorização padrão do time?
* **Por que reprova?** Faz os pedidos escondido de forma informal desorganizando a sprint do time, ou responde de forma rude aos executivos.
* **Abordagem de Sucesso:** Responder de forma diplomática e organizada: "Posso ajudar a analisar a viabilidade técnica disso com prazer! Para garantir que não causemos conflitos com as entregas críticas desta semana, peço que crie uma solicitação rápida com o nosso Product Manager para que possamos priorizar e encaixar essa tarefa no fluxo correto do time de forma transparente".

#### Q36. Como você constrói e mantém uma relação de confiança de longo prazo com o Product Manager do seu time?
* **Por que reprova?** Trata produto como "adversário" que só pede coisas sem entender de tecnologia.
* **Abordagem de Sucesso:** Tratar a parceria com Produto como uma via de mão dupla baseada em **transparência e entrega**. Incluir o PM nos desenhos arquiteturais de alto nível para explicar os desafios técnicos do time de forma simples, dar visibilidade constante sobre o progresso e saúde do repositório, e demonstrar que a engenharia se importa em entregar valor real para o cliente final, e não apenas escrever código bonito por si só.

#### Q37. Como você conduz um Blameless Post-Mortem (Análise de Causa Raiz sem Culpados) com o time após um incidente grave em produção?
* **Por que reprova?** Foca em encontrar o responsável pelo erro (ex.: "quem fez o deploy errado?") e punir/criticar o desenvolvedor.
* **Abordagem de Sucesso:** Reforçar a cultura de que **falhas sistêmicas são causadas por processos fracos, não por pessoas individuais**. O post-mortem deve focar em documentar a linha do tempo exata do incidente, entender quais alertas ou barreiras de segurança falharam em conter o erro (ex.: falta de testes automáticos, monitoramento ineficiente) e definir itens de ação acionáveis claros para evitar que a mesma falha ocorra novamente (ex.: automatizar deploys canary, melhorar logs de erro).

