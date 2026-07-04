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
