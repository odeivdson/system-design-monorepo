# Q&A de Elite: Perguntas & Respostas para Entrevistas de Senior Developer

Este documento reúne perguntas clássicas de nível **Senior Developer (L5)** focadas em implementação técnica sólida, algoritmos de concorrência local, modelagem de banco de dados relacional e testes unitários.

---

## 🧭 Seção 1: Concorrência e Thread-Safety local

### Q1: Se você estiver implementando um contador de requisições local na memória da aplicação em uma linguagem que compila para threads nativas (como Java ou Go), quais os problemas de usar apenas inteiros primitivos comuns incrementados em paralelo? Como você corrige isso?
* **Resposta Ideal**:
  * Incrementos simples em variáveis comuns (ex: `count++`) não são operações atômicas no nível da CPU. Um incremento envolve três etapas físicas: ler o valor atual da memória para o registrador, incrementar o valor no registrador, e gravar o valor de volta na memória.
  * Sob concorrência de múltiplas threads paralelas, ocorre uma **Condição de Corrida (Race Condition)**: duas threads podem ler o mesmo valor inicial ao mesmo tempo, incrementar localmente e gravar o mesmo resultado, gerando perda de atualizações (*lost updates*).
  * Para corrigir isso, podemos adotar duas abordagens seguras:
    1. **Bloqueio Síncrono (Locks/Mutex):** Envolver a leitura e escrita com um Mutex (ex: `sync.Mutex` em Go) para garantir exclusão mútua.
    2. **Operações Atômicas (Lock-Free):** Usar primitivas atômicas do processador baseadas na instrução Compare-And-Swap (CAS) (ex: `sync/atomic` em Go ou `AtomicInteger` em Java), que efetuam o incremento de forma atômica direta no hardware, sendo muito mais eficientes que locks síncronos pesados.

---

## 🧭 Seção 2: Banco de Dados Relacional & Locks

### Q2: Qual é a diferença de escopo e comportamento entre o bloqueio otimista (Optimistic Locking) e o bloqueio pessimista (Pessimistic Locking) no controle de concorrência de saldos em bancos de dados SQL?
* **Resposta Ideal**:
  * **Bloqueio Pessimista (`SELECT FOR UPDATE`):**
    * *Funcionamento:* Bloqueia fisicamente a linha correspondente no banco de dados no momento em que ela é lida, impedindo que qualquer outra transação leia com lock ou modifique a linha até que a transação atual dê commit/rollback.
    * *Quando usar:* Alta contenda de dados (muitas requisições atualizando a mesma conta no mesmo instante). Evita falhas de processamento, mas diminui o paralelismo geral do banco.
  * **Bloqueio Otimista (Versionamento / `Version Column`):**
    * *Funcionamento:* Não coloca travas na leitura. Cada linha da tabela possui uma coluna de `version` ou timestamp. Na escrita, a query valida se a versão continua a mesma (ex: `UPDATE accounts SET balance = 100, version = version + 1 WHERE id = 1 AND version = 5`). Se nenhuma linha for atualizada, significa que outra transação alterou os dados antes; o sistema então rejeita a escrita ou tenta novamente.
    * *Quando usar:* Baixa contenda (conflitos raros). Muito mais eficiente e escalável do que travas pessimistas, pois não bloqueia leitores paralelos.

---

## 🧭 Seção 3: Estruturas de Dados e Algoritmos

### Q3: Por que a implementação ideal de um cache LRU (Least Recently Used) usa uma combinação de um Mapa (Hash Map) e uma Lista Duplamente Encadeada (Doubly Linked List)? Qual a complexidade de tempo de obter (`Get`) e inserir (`Put`) itens?
* **Resposta Ideal**:
  * Para atingir complexidade de tempo constante **$O(1)$** tanto em buscas quanto em inserções/atualizações de prioridade de expiração no cache LRU:
    * **Hash Map:** Guarda a associação da chave ao nó físico da lista. Permite consultar a existência de qualquer elemento instantaneamente em tempo constante $O(1)$.
    * **Lista Duplamente Encadeada:** Mantém a ordem de acesso físico dos elementos. O item no topo é o mais recentemente usado, e o item no rodapé da lista é o mais antigo (candidato à remoção). 
    * A lista encadeada permite remover um nó e reinseri-lo no topo da lista em tempo constante $O(1)$ apenas alterando os ponteiros dos vizinhos (seus nós anterior e próximo), sem precisar reorganizar outros elementos na memória, o que seria necessário se usássemos um vetor ($O(N)$).

---

## 🧭 Seção 4: APIs HTTP e Semântica de Erros

### Q4: Se um cliente tenta submeter uma proposta de transação onde o remetente não possui saldo suficiente para a transferência, qual código de status HTTP você retorna no endpoint REST e por quê?
* **Resposta Ideal**:
  * Retornar códigos semânticos corretos (como evitar usar `500 Internal Server Error` para erros de negócio) é crucial porque ferramentas de APM e monitoramento tratam erros 5xx como falhas de infraestrutura/código da aplicação, acionando alertas do suporte desnecessariamente.

---

## 🏛️ Seção 5: As 30 Perguntas Frequentes que Mais Reprovam Devs Seniores

Esta seção compila as 30 perguntas comportamentais, de concorrência, modelagem de banco e design de código local que mais eliminam candidatos a Senior Developer (L5) em processos seletivos de Big Tech.

---

### Pillar 1: Concorrência e Programação Concorrente Local

#### Q5. O que acontece se duas threads tentarem ler e gravar em um HashMap convencional concorrentemente sem sincronização? Como você resolve isso com performance fina?
* **Por que reprova?** Apenas sugere usar locks gigantes globais (`synchronized` ou blocos Mutex inteiros) que paralisam a performance paralela, ou demonstra desconhecimento dos perigos internos (como loops infinitos na reorganização das chaves do mapa).
* **Abordagem de Sucesso:** Explicar que a escrita concorrente sem exclusão mútua corrompe a estrutura de dados interna do mapa (gerando `ConcurrentModificationException` ou corrupção silenciosa). A forma de resolver de forma eficiente é usar um **ConcurrentHashMap** (ou segmentação de locks de escrita), onde os bloqueios são feitos por baldes (*buckets*) individuais de chave em vez do mapa inteiro, permitindo que threads de leitura acessem o mapa sem bloqueios na maioria das vezes.

#### Q6. Como você detecta e previne de forma prática condições de Deadlocks em um código que gerencia múltiplos locks em paralelo?
* **Por que reprova?** Não sabe explicar o conceito matemático de dependência circular de locks ou não propõe uma estratégia clara de prevenção.
* **Abordagem de Sucesso:** Explicar que Deadlocks ocorrem quando a Thread A segura o Lock 1 e quer o Lock 2, enquanto a Thread B segura o Lock 2 e quer o Lock 1. A prevenção reside em **estabelecer uma ordem estrita e global de aquisição de locks** (ex.: ordenar sempre as chaves antes de aplicar os locks, garantindo que ambas as threads sempre tentem obter o Lock 1 antes do Lock 2).

#### Q7. O que é thread-safety e como usar variáveis atômicas (instruções CAS) em vez de Mutexes tradicionais para otimizar a performance?
* **Por que reprova?** Acha que locks Mutex tradicionais são a única forma de garantir segurança concorrente na memória.
* **Abordagem de Sucesso:** Variáveis atômicas usam instruções de hardware (Compare-And-Swap) para atualizar valores na memória de forma lock-free. Mutexes travam a thread na fila do sistema operacional (overhead de troca de contexto de CPU), enquanto o CAS apenas falha a gravação caso o valor inicial mude, tentando novamente em loop rápido de CPU. Indicado para contadores ou atualizações rápidas e isoladas.

#### Q8. Qual a diferença entre processamento CPU-bound e I/O-bound e como você projeta o pool de threads para cada cenário?
* **Por que reprova?** Configura tamanhos de pools fixos e idênticos sem considerar a natureza da computação física, gerando desperdício ou sobrecarga de recursos.
* **Abordagem de Sucesso:** 
  * **CPU-bound (cálculos pesados, criptografia):** O número ideal de threads no pool deve ser igual ao número de núcleos físicos de CPU ($N_{\text{cores}}$ ou $N_{\text{cores}} + 1$). Mais threads geram perda de performance por troca de contexto inútil.
  * **I/O-bound (chamadas HTTP, consultas a bancos de dados):** As threads passam a maior parte do tempo esperando rede/disco. O pool pode ser muito maior, calculado como $N_{\text{cores}} \times (1 + \text{tempo\_espera} / \text{tempo\_computação})$, maximizando o uso de concorrência.

#### Q9. Como funciona o mecanismo de Garbage Collection (GC) e de que forma o design do seu código pode evitar pausas excessivas de GC em produção?
* **Por que reprova?** Desconhece a mecânica de alocação de memória (Stack vs. Heap) ou assume que não precisa se importar com objetos temporários.
* **Abordagem de Sucesso:** O GC vasculha a Heap em busca de objetos sem referências. Pausas longas ocorrem quando há muitos objetos de vida curta alocados na Heap continuamente. Para evitar isso: evitar concatenação de strings dentro de loops (usar StringBuilders), reutilizar buffers e objetos pesados em pools (Object Pools) e dar preferência a alocações na Stack (variáveis locais que não escapam do método).

#### Q10. Como você diagnostica um vazamento de memória (Memory Leak) em sua aplicação rodando em produção?
* **Por que reprova?** Sugere reiniciar o servidor ou apenas olhar logs básicos de texto (que não expõem a estrutura de objetos).
* **Abordagem de Sucesso:** Analisar o comportamento de longo prazo através de métricas de uso da Heap (gráfico em padrão dente-de-serra ascendente). Para isolar a causa raiz, capturar um despejo de memória da aplicação (**Heap Dump**) sob carga e usar ferramentas de análise (como Eclipse Memory Analyzer - MAT, ou o pprof do Go) para identificar quais classes de objetos retêm a maior parte do espaço e quais caminhos de referência impedem que o GC os libere.

---

### Pillar 2: Bancos de Dados e Modelagem de Dados

#### Q11. Como você otimiza uma consulta SQL lenta que está fazendo um Scan completo de tabela (Full Table Scan) na produção?
* **Por que reprova?** Sugere criar índices cegamente em todas as colunas sem analisar o plano de execução real.
* **Abordagem de Sucesso:** Rodar `EXPLAIN ANALYZE` na query lenta para identificar o gargalo exato. Se for um Full Table Scan em campos filtrados no `WHERE` ou usados em `JOIN`, propor a criação de um índice (B-Tree). Explicar que a ordem das colunas em índices compostos é crítica (deve seguir da coluna mais seletiva para a menos seletiva).

#### Q12. Por que usar UUIDs v4 aleatórios como chaves primárias (`PRIMARY KEY`) em bancos de dados relacionais causa sérios problemas de performance de gravação?
* **Por que reprova?** Acha que UUIDs são sempre ideais porque garantem unicidade global, sem conhecer o impacto nos índices físicos em disco.
* **Abordagem de Sucesso:** UUIDs v4 são totalmente aleatórios. Bancos relacionais armazenam chaves primárias em estruturas físicas ordenadas (índices B+ Tree). Como a chave não é sequencial, novos registros são inseridos em posições aleatórias no meio do arquivo, causando constantes quebras e reestruturações físicas das páginas de disco (Page Splits), degradando a performance de escrita. Alternativa sênior: usar UUIDs v7 (que contêm timestamp no início) ou chaves numéricas sequenciais (`BIGSERIAL` / Snowflake IDs).

#### Q13. O que é o problema do "N+1 Queries" em ORMs (como Hibernate, Prisma, Entity Framework) e como você o resolve?
* **Por que reprova?** Apenas define o problema teoricamente sem explicar como corrigir no nível de banco ou código do ORM.
* **Abordagem de Sucesso:** Ocorre quando buscamos uma lista de registros (1 query) e, em seguida, o ORM faz uma consulta separada para cada registro a fim de carregar seus relacionamentos (N queries adicionais). A solução é instruir o ORM a usar **Eager Loading** (efetuando `JOIN` ou subqueries otimizadas) para carregar todos os dados necessários em uma única consulta ao banco de dados.

#### Q14. Quando você escolhe normalizar uma tabela de banco de dados e quando decide desnormalizá-la?
* **Por que reprova?** Defende a normalização estrita até a 3ª Forma Normal a todo custo, ignorando o custo computacional de múltiplos JOINs em sistemas de alto tráfego.
* **Abordagem de Sucesso:** Normalizar para evitar redundâncias e garantir integridade de dados transacionais complexos. Desnormalizar (adicionar colunas redundantes ou agregados pré-calculados) de forma consciente em tabelas de leitura massiva onde o custo computacional de múltiplos `JOIN`s é proibitivo e a latência de leitura precisa ser sub-5ms.

#### Q15. Como você modelaria uma tabela que guarda um histórico de alterações imutável (Audit Trail)?
* **Por que reprova?** Sugere fazer queries de UPDATE ou criar tabelas temporárias que alteram registros antigos.
* **Abordagem de Sucesso:** Utilizar o padrão **Append-Only** (imutabilidade de registros): a tabela aceita apenas inserts (`INSERT`). Cada alteração de estado é gravada como uma nova linha contendo o timestamp, o usuário autor e a cópia dos dados antigos/novos. Não existem comandos de `UPDATE` ou `DELETE` nessa tabela para garantir a rastreabilidade auditável pura.

#### Q16. Qual a diferença prática de comportamento entre os níveis de isolamento "Read Committed" e "Repeatable Read" no PostgreSQL?
* **Por que reprova?** Confunde as definições ou não sabe explicar os problemas de concorrência que persistem em cada nível.
* **Abordagem de Sucesso:** 
  * `Read Committed` (padrão): Cada consulta dentro da transação lê apenas dados commitados antes do início da consulta. Permite **leituras não repetíveis** (se a mesma consulta rodar duas vezes na mesma transação, pode ver dados atualizados por outra transação commitada em paralelo).
  * `Repeatable Read`: A transação lê apenas dados commitados antes de a transação em si iniciar. Evita leituras não repetíveis, mas pode gerar erros de serialização se houver tentativa de atualizar linhas modificadas em paralelo por transações concorrentes.

---

### Pillar 3: Qualidade de Código, Padrões de Projeto (SOLID) e Testes

#### Q17. Qual a diferença prática de uso entre Mocks, Stubs e Fakes em testes unitários?
* **Por que reprova?** Usa todos os termos como sinônimos ou não sabe quando usar cada um de forma produtiva.
* **Abordagem de Sucesso:**
  * **Stub:** Apenas retorna valores estáticos pré-programados para a chamada (não valida interações).
  * **Mock:** Focado na verificação de comportamento (valida se o método X foi chamado exatamente Y vezes com os argumentos Z).
  * **Fake:** Implementação funcional simplificada da dependência real, geralmente sem bater na rede/disco (ex.: um banco de dados em memória para testes de repositório).

#### Q18. Como você testa o consumo de uma fila assíncrona (como RabbitMQ ou SQS) sem adicionar delays estáticos (`Thread.sleep`) que tornam os testes lentos e instáveis?
* **Por que reprova?** Sugere adicionar `sleep(5000)` para esperar o evento chegar, o que torna a suíte de testes frágil (*flaky tests*).
* **Abordagem de Sucesso:** Usar padrões de testes assíncronos baseados em **polling reativo** com timeouts (ex.: biblioteca `Awaitility` no ecossistema Java, ou loops com canais/select em Go). A ferramenta verifica continuamente se a condição esperada ocorreu em intervalos curtíssimos (ex.: a cada 50ms) até atingir um limite máximo (ex.: 2 segundos), liberando a execução do teste imediatamente após o sucesso.

#### Q19. O que é o Princípio de Inversão de Dependência (DIP) do SOLID e como ele difere de Injeção de Dependência (DI)?
* **Por que reprova?** Confunde a técnica (Injeção) com o princípio arquitetural (Inversão).
* **Abordagem de Sucesso:**
  * **Inversão de Dependência (Princípio):** Módulos de alto nível não devem depender de módulos de baixo nível. Ambos devem depender de abstrações.
  * **Injeção de Dependência (Técnica):** Passar as dependências para uma classe (geralmente pelo construtor) em vez de instanciá-las internamente. A injeção é o meio pelo qual viabilizamos o princípio da inversão (passando implementações de abstrações no construtor).

#### Q20. O que você avalia como crítico para manter os tempos de execução da suíte de testes de integração rápidos no CI/CD?
* **Por que reprova?** Apenas diz que "testes rápidos são bons", sem dar ações reais de arquitetura de testes.
* **Abordagem de Sucesso:** Evitar iniciar e destruir contêineres de banco de dados para cada classe de teste (usar Testcontainers compartilhados); usar bancos de dados locais em memória ou sqlite para testes de repositório leves; e rodar testes de integração de forma paralela isolando o estado dos dados por transações ou IDs de escopo exclusivos.

#### Q21. O que é Acoplamento Temporal e como você o evita no design de classes e métodos?
* **Por que reprova?** Desconhece a definição ou não sabe identificar código que exige ordem fixa de execução sem garantias de compilador.
* **Abordagem de Sucesso:** Ocorre quando métodos de uma classe precisam ser chamados em uma ordem estrita oculta para funcionar corretamente (ex.: instanciar classe, chamar `init()`, depois `configure()`, e por fim `execute()`). Se o cliente esquecer um passo, ocorre erro em tempo de execução. Para evitar isso, usar construtores ricos que entregam o objeto 100% pronto para uso de forma atômica ou o padrão Builder.

#### Q22. Como você garante a separação estrita de domínios (DDD) em um projeto que utiliza ORMs onde os modelos de banco de dados possuem anotações de infraestrutura?
* **Por que reprova?** Permite que modelos com anotações ORM vazem pelas camadas de controle e negócio de todo o sistema.
* **Abordagem de Sucesso:** Definir dois modelos de representação: as **Entidades de Domínio** (regras de negócio puras, livres de anotações ORM ou imports de framework) e os **Modelos de Banco/Dados** (usados pelo ORM). Criar mapeadores simples (Mappers) na camada de infraestrutura que convertem de/para o modelo de domínio antes de interagir com o caso de uso.

---

### Pillar 4: APIs Web, Protocolos e Redes

#### Q23. Qual a diferença prática e de comportamento entre os códigos HTTP 301, 302, 307 e 308 em redirecionamentos?
* **Por que reprova?** Confunde as categorias ou acha que 301 e 302 são os únicos que existem e resolvem tudo de forma idêntica.
* **Abordagem de Sucesso:**
  * **301 (Permanent) e 302 (Found/Temporary):** Permitem que o navegador mude o método HTTP da requisição subsequente (ex.: uma requisição original `POST` pode virar `GET` no redirecionamento).
  * **307 (Temporary) e 308 (Permanent):** Garantem de forma estrita que o método HTTP e o corpo da requisição **nunca** sejam alterados durante o redirecionamento (ex.: `POST` continuará obrigatoriamente sendo `POST`).

#### Q24. Como você projeta contratos de API extensíveis para que os clientes integrados não quebrem quando você adicionar novos campos no payload de resposta?
* **Por que reprova?** Apenas versiona a API para qualquer pequena mudança (criando overhead) ou ignora compatibilidade com versões anteriores.
* **Abordagem de Sucesso:** Projetar payloads de resposta flexíveis (JSON objetos, nunca arrays brutos no topo). Adicionar novos campos sempre de forma opcional. Garantir que os serializadores dos clientes estejam configurados para ignorar campos desconhecidos (ex.: `ignoreUnknownProperties` no Jackson ou JSON de cada linguagem) em vez de estourar exceções de desserialização.

#### Q25. Qual a diferença computacional prática no throughput de rede e uso de recursos ao usar gRPC (HTTP/2 + Protobuf) vs. REST (HTTP/1.1 + JSON) na comunicação interna entre serviços?
* **Por que reprova?** Apenas diz que "gRPC é mais rápido" porque é binário, sem explicar os detalhes físicos de rede.
* **Abordagem de Sucesso:**
  * **Throughput de Rede:** Protobuf é um formato binário compacto pré-compilado, consumindo muito menos banda do que JSON (texto legível redundante).
  * **Conexão e Multiplexação:** HTTP/2 permite multiplexação de requisições paralela sob uma única conexão TCP de longa duração (eliminando o overhead de abertura/fechamento contínuo de conexões e handshake TLS e evitando o bloqueio Head-of-Line de requisições HTTP/1.1).

#### Q26. O que é CORS (Cross-Origin Resource Sharing) e como você o configura de forma segura em uma API de produção?
* **Por que reprova?** Recomenda liberar a origem globalmente (`Access-Control-Allow-Origin: *`) para resolver erros de CORS em desenvolvimento, expondo a API a falhas de segurança.
* **Abordagem de Sucesso:** CORS é um mecanismo de segurança do navegador que bloqueia scripts de lerem respostas de domínios diferentes. Para configurar de forma segura em produção: declarar explicitamente a lista de domínios permitidos (*Origin Allowlist*) correspondentes aos domínios web da empresa, restringir métodos HTTP permitidos e nunca expor cabeçalhos sensíveis desnecessariamente.

#### Q27. Como você projeta uma chave de idempotência de forma segura para garantir que o cliente de uma API de pagamento não gere cobranças duplicadas caso ele aperte o botão de pagar duas vezes?
* **Por que reprova?** Salva apenas o token no banco sem tempo de expiração ou trata colisões de forma insegura em memória RAM volátil.
* **Abordagem de Sucesso:** Exigir que o cliente envie um cabeçalho HTTP de idempotência (ex.: `Idempotency-Key` contendo um UUID único gerado no client). No servidor, antes de iniciar o pagamento, salvar no banco de dados distribuído rápido (Redis) o par `chave -> status_pagamento` com um tempo de expiração seguro (TTL de 24h). Se a chave já existir, retornar o status atual imediatamente. Se não, marcar como `PROCESSING` e seguir para a gravação.

#### Q28. O que é Backpressure e como você implementa de forma reativa para proteger a estabilidade de um consumidor local?
* **Por que reprova?** Sugere apenas descartar requisições de forma cega ou adicionar buffers infinitos na memória que geram OOM.
* **Abordagem de Sucesso:** Backpressure é o sinal enviado de um receptor lento para um emissor rápido informando-o para desacelerar a taxa de envio. Em Go, isso é controlado de forma nativa usando canais delimitados (*buffered channels*). Se o canal estiver cheio, o produtor de eventos é bloqueado na escrita até que o consumidor libere espaço na fila, protegendo o uso de RAM física.

---

### Pillar 5: Resolução de Problemas, Diagnóstico e Trabalho em Equipe

#### Q29. O que você faz quando se depara com um bug complexo e intermitente em produção que não consegue reproduzir no seu ambiente local?
* **Por que reprova?** Fica dando chutes ou alterando código aleatoriamente na produção sob esperança técnica (*hope programming*).
* **Abordagem de Sucesso:** Abordagem metódica e científica:
  1. Analisar logs estruturados de produção em busca de padrões (ex.: cruzando com horários, cargas, domínios específicos de clientes ou versões de dependências).
  2. Implementar logs adicionais mais descritivos e rastreabilidade distribuída (Correlation IDs) de forma direcionada.
  3. Criar scripts de teste de carga locais simulando as mesmas condições e concorrência para reproduzir o comportamento anômalo.

#### Q30. Como você onboarding e ajuda a treinar novos engenheiros plenos ou juniores que entram no seu time?
* **Por que reprova?** Fica ocupado com as próprias tarefas e apenas envia links de documentações legadas para o novo contratado ler sozinho.
* **Abordagem de Sucesso:** Estruturar um plano de boas-vindas ativo: garantir que a documentação de setup local esteja saudável, passar uma semana com sessões de pareamento em tarefas de baixo risco (Good First Issues) para ambientação de processos e pipeline de deploy, e se colocar ativamente disponível para responder dúvidas operacionais sem julgamentos, acelerando a autonomia dele.

#### Q31. Como você lida com prazos de entrega apertados definidos pela gerência sem comprometer a qualidade do código entregue?
* **Por que reprova?** Abre mão de testes e boas práticas de design sob o pretexto de "não ter tempo", acumulando débitos técnicos de forma silenciosa.
* **Abordagem de Sucesso:** Propor a redução de escopo funcional do MVP comercial à gerência de produto para entregar a feature de forma robusta e dentro das boas práticas, em vez de entregar um escopo gigante feito de forma instável e perigosa.

#### Q32. Descreva um cenário onde você precisou refatorar uma parte crítica do código que não possuía cobertura de testes. Qual foi sua estratégia de segurança para não quebrar a aplicação?
* **Por que reprova?** Sai alterando a arquitetura do código legado imediatamente, sem rede de proteção de testes.
* **Abordagem de Sucesso:** Estratégia de refatoração segura:
  1. Antes de alterar qualquer linha de código interna do componente, escrever **Testes de Caracterização** (testes de integração caixa-preta) que validem e garantam o comportamento externo atual do componente (entradas e saídas sob diversos cenários).
  2. Com a cobertura externa garantindo que nada mude para o restante da aplicação, realizar refatorações incrementais de forma interna.
  3. Mapear e testar unitariamente os caminhos e lógicas que foram isolados e migrados.

#### Q33. Como você aborda a escrita de documentação técnica (READMEs, diagramas C4) para garantir que seja mantida atualizada pelo time técnico?
* **Por que reprova?** Cria documentações gigantescas em wikis externas separadas (como Confluence) que desatualizam rápido e ninguém lê.
* **Abordagem de Sucesso:** Manter a documentação o mais próxima possível do código (**Documentation as Code**): escrever arquivos Markdown de documentação e diagramas (Mermaid) diretamente no mesmo repositório git. Isso garante que atualizações arquiteturais possam ser exigidas e validadas nos mesmos Pull Requests de alteração de código.

