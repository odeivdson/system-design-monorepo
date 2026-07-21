# Desafio 24: Matriz de Decisão Arquitetural de Mensageria (`messaging-architectural-decision-matrix`)
> **Padrões de Microsserviços Associados:** Message-Driven Communication, Event Streaming, Fan-out Pattern, Competing Consumers, Message Replay, Offsets and Partitioning.

## 1. Contexto & Cenário
Em sistemas distribuídos modernos e microsserviços, a comunicação assíncrona orientada a mensagens é o principal mecanismo para garantir desacoplamento, resiliência e escalabilidade. No entanto, decidir a tecnologia de mensageria correta é uma das decisões arquiteturais mais críticas, pois as ferramentas disponíveis operam sob paradigmas fundamentalmente diferentes.

Uma escolha equivocada pode introduzir complexidade operacional desnecessária, custos elevados ou, pior, falhas na consistência de dados e ordenação de transações. Os três principais expoentes do mercado representam trade-offs distintos:
- **RabbitMQ**: Um message broker clássico focado em filas de mensagens flexíveis e roteamento complexo.
- **Apache Kafka**: Uma plataforma de processamento de fluxo de eventos baseada em log de commits imutável e distribuído.
- **AWS SNS + SQS**: Uma solução nativa na nuvem que combina notificação push (Pub/Sub) e filas de mensagens pull gerenciadas de forma serverless.

Este guia atua como a matriz de referência técnica definitiva para escolher a tecnologia ideal baseando-se em trade-offs de infraestrutura, consistência de dados, throughput de rede e esforço operacional.

---

## 2. Modelos Fundamentais de Mensageria

```
MODELO BASEADO EM FILAS (QUEUE-CENTRIC - ex: RabbitMQ, SQS):
[Produtor] ──► [Exchange/Broker] ──► [Fila A] ──► [Consumidor 1] (Mensagem consumida é deletada)
                                 └──► [Fila B] ──► [Consumidor 2]

MODELO BASEADO EM LOG (LOG-CENTRIC - ex: Apache Kafka):
[Produtor] ──► [Commit Log (Append-Only)] (Mensagens ficam salvas sequencialmente por TTL)
               ├─ Partição 0: [E0][E1][E2][E3] ◄── [Consumidor A - Offset: 3]
               └─ Partição 1: [E0][E1][E2]      ◄── [Consumidor B - Offset: 2]
```

### A. Queue-Centric (RabbitMQ / AWS SQS)
- **Filosofia**: "Smart Broker, Dumb Consumer". O broker é responsável pelo roteamento das mensagens para as filas corretas, por rastrear se a mensagem foi lida/confirmada (`ACK`) e por removê-la da fila imediatamente após a confirmação para liberar memória.
- **Ciclo de Vida da Mensagem**: Transiente. As mensagens existem na fila apenas até serem processadas com sucesso.

### B. Log-Centric (Apache Kafka)
- **Filosofia**: "Dumb Broker, Smart Consumer". O broker apenas grava mensagens sequencialmente em arquivos de log em disco de forma append-only. O consumidor gerencia qual índice do log ele está lendo atualmente (Offset).
- **Ciclo de Vida da Mensagem**: Persistente. As mensagens não são deletadas após a leitura. Elas são mantidas em disco baseado em políticas de retenção (por tempo ou tamanho acumulado), permitindo que consumidores releiam dados históricos (*Replay*).

---

## 3. Deep-Dive Tecnológico

### A. RabbitMQ (AMQP 0-9-1)
- **Arquitetura de Roteamento**: Utiliza exchanges para receber mensagens e associá-las a filas através de chaves de roteamento (*routing keys*):
  - **Direct**: Envia para a fila que possui a chave de roteamento exata.
  - **Fanout**: Envia para todas as filas conectadas (Pub/Sub simples).
  - **Topic**: Roteamento por curingas (ex: `payment.brazil.*` envia para filas ouvindo compras no Brasil).
  - **Headers**: Filtro baseado nos cabeçalhos HTTP da mensagem.
- **Distribuição de Carga**: Suporta o padrão **Competing Consumers** nativo. Se você tiver 5 instâncias ouvindo uma única fila, o RabbitMQ distribui as mensagens de forma equilibrada (Round-Robin ou via prefetch limit).
- **Garantias de Entrega**: At-least-once (nativamente) e At-most-once.

### B. Apache Kafka
- **Mecânica de Alta Performance**:
  - **Escrita Sequencial em Disco**: Gravar sequencialmente no final do arquivo é quase tão rápido quanto escrever na memória RAM, evitando a busca aleatória física do disco (*disk seek*).
  - **Page Cache & Zero-Copy**: O Kafka delega o cache para o sistema operacional (PageCache) e usa a chamada de sistema `sendfile` para mover os dados diretamente do cache de disco para o soquete de rede (NIC) sem passar pelo espaço de memória da aplicação JVM, eliminando overhead de CPU.
- **Ordenação e Particionamento**: Garante ordenação estrita das mensagens **apenas dentro de uma partição**. O produtor deve calcular uma chave de partição (ex: `hash(user_id)`) para garantir que todos os eventos do mesmo usuário caiam na mesma partição do tópico.
- **Consumer Groups**: Permite que múltiplos consumidores trabalhem em paralelo em um grupo de consumo. Cada partição é designada a apenas um consumidor dentro do grupo por vez.

### C. AWS SNS + SQS (Fan-out Serverless)
- **AWS SNS (Pub/Sub Push)**: O produtor envia para um Tópico SNS. O SNS replica a mensagem e empurra imediatamente para todas as assinaturas registradas (Push-to-HTTP, Push-to-Lambda ou empurra para múltiplas filas SQS).
- **AWS SQS (Message Queue Pull)**: Fila com retenção de até 14 dias. Os consumidores realizam chamadas de busca (*Polling*) para extrair mensagens. Possui recurso de *Visibility Timeout* (tempo em que uma mensagem lida fica oculta para outros consumidores até que o primeiro dê `delete` ou o tempo expire).
- **SQS FIFO**: Garante ordenação de entrega estrita de ponta a ponta e processamento único (Exactly-once deduplication), limitado a 300 mensagens/segundo padrão (ou até 3.000 mensagens/segundo com lotes de alta taxa).

---

## 4. Matriz Comparativa de Trade-offs

| Critério de Escolha | RabbitMQ | Apache Kafka | AWS SNS + SQS |
| :--- | :--- | :--- | :--- |
| **Throughput (Vazão)** | Média (~Dezenas de milhares/s por nó) | Ultra Alta (Milhões/s por cluster) | Alta (Escala automática baseada em APIs) |
| **Latência de Mensagem** | Ultra Baixa (Sub-milissegundo) | Baixa (Poucos milissegundos) | Baixa (Dezenas de milissegundos) |
| **Persistência do Histórico** | Não (Deleta após leitura) | Sim (Retém baseado em TTL/Size) | Não (Deleta após o processamento) |
| **Recuperação de Dados (Replay)**| Impossível | Nativo (Rewind Offset) | Impossível |
| **Complexidade de Roteamento** | Altíssima (Exchanges, Bindings) | Baixa (Apenas por Tópico) | Média (Filtros simples em JSON no SNS) |
| **Competing Consumers** | Nativo (Múltiplos workers por fila) | Limitado ao número de Partições | Nativo (Múltiplos workers por fila SQS) |
| **Esforço Operacional (Ops)** | Alto (Patches, clustering, Erlang) | Altíssimo (Particionamento, KRaft/ZK) | Nulo (Totalmente gerenciado) |
| **Modelo de Custo** | Custo de Máquinas/Infraestrutura | Custo de Máquinas/Infraestrutura | Custo por requisições e volume de dados |

---

## 5. Árvore de Decisão: Onde Usar Cada Um?

```
                                 [Qual é a sua necessidade primária?]
                                                  │
         ┌────────────────────────────────────────┼────────────────────────────────────────┐
         ▼                                        ▼                                        ▼
[Throughput massivo de logs/eventos]      [Roteamento complexo e dinâmico]         [Zero administração e rodando na AWS]
         │                                        │                                        │
         ▼                                        ▼                                        ▼
   [Apache Kafka]                           [RabbitMQ]                              [AWS SNS + SQS]
```

### Escolha o Apache Kafka se:
1. Você está construindo uma arquitetura baseada em **Event Sourcing** ou **CQRS** onde precisa reprocessar eventos do passado para reconstruir base de dados.
2. O sistema processa streams contínuos de alta telemetria (ex: cliques de navegação de milhões de usuários, dados de sensores IoT em tempo real, auditoria global de ações).
3. Você precisa de integração nativa com ecossistemas de processamento de streaming em tempo real (como Spark Streaming, Apache Flink ou Kafka Streams).
4. O ecossistema exige garantia estrita de ordem de eventos agrupados por entidade (particionamento por chave).

### Escolha o RabbitMQ se:
1. Suas aplicações precisam de um roteamento dinâmico e flexível (ex: rotear a mesma mensagem para filas diferentes dependendo de regras baseadas em padrões nas chaves de roteamento).
2. O ciclo de vida da mensagem é puramente transiente: a mensagem chega, é processada de forma concorrente e deve ser apagada da fila para não consumir disco.
3. Você tem um ecossistema poliglota complexo que depende de protocolos legados (como AMQP 0-9-1 clássico, MQTT ou STOMP) além do HTTP.
4. É necessário garantir distribuição balanceada exata de tarefas longas para múltiplos consumidores de forma concorrente (Competing Consumers com prefetch).

### Escolha AWS SNS + SQS se:
1. Sua infraestrutura é hospedada inteiramente na AWS e o time de desenvolvimento busca foco total no produto, preferindo delegar 100% da gerência de servidores de fila (Serverless).
2. Você precisa implementar o padrão **Fan-out** (um evento único publicado no SNS dispara processamentos assíncronos paralelos e isolados em múltiplas filas SQS para microsserviços distintos).
3. O volume de tráfego é altamente volátil (sazonal) e o sistema precisa escalar horizontalmente de forma elástica automática sem intervenção manual.

---

## 6. Estudos de Caso Reais

### Caso A: Ingestão de Telemetria de CLI (Clicks & Visualizações)
- **Problema**: Milhões de dispositivos reportando cliques de usuários a cada segundo. O sistema precisa persistir essas informações em um Data Lake e gerar estatísticas em tempo real.
- **Decisão**: **Apache Kafka**. O volume massivo estouraria a memória do RabbitMQ rapidamente. Com o Kafka, gravamos o fluxo sequencialmente nas partições. Múltiplos consumidores leem de forma paralela sem remover os dados do log, e o time de dados pode reprocessar os dados do zero a qualquer momento relendo o log desde o offset zero.

### Caso B: Gateway de Webhooks de E-Commerce (Faturamento)
- **Problema**: Integrar eventos de pagamento com gateways externos. As requisições de pagamento falham frequentemente por instabilidade do parceiro, exigindo retentativas com Exponential Backoff e filas de erros (DLQs) isoladas por parceiro.
- **Decisão**: **RabbitMQ**. O broker gerencia nativamente o enfileiramento das retentativas com TTL e redirecionamento de mensagens para Dead Letter Exchanges (DLX) caso o limite de tentativas estoure, mantendo o código da aplicação isolado dessa lógica de infraestrutura.

### Caso C: Plataforma SaaS Multi-Tenant (Notificações)
- **Problema**: Quando uma fatura vence no sistema SaaS, múltiplos serviços independentes (faturamento, envio de e-mails, push notifications e auditoria financeira) precisam ser notificados assíncronamente sem acoplamento direto.
- **Decisão**: **AWS SNS + SQS (Fan-out)**. O serviço de faturamento publica um único evento `InvoiceExpired` no SNS. O SNS faz o fan-out para quatro filas SQS assinadas de forma isolada por cada um dos microsserviços interessados. O ecossistema escala de forma automática e serverless na AWS.
