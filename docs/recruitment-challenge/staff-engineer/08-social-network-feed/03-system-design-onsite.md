# 🏛️ Etapa 3: System Design Onsite - Motor de Timeline e Grafo Social

* **Responsável:** Alex (Staff Engineer) & Principal Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Arquitetura de sistemas sociais de alta escala, modelos de fan-out híbridos, consistência eventual de cache e gestão de hotspots de escrita.

---

## 🎯 O Enunciado do Desafio

O candidato deve projetar a infraestrutura e os fluxos de dados de uma **Rede Social Global** focada em consumo de mensagens em texto (similar ao Twitter ou Threads). 

O sistema deve suportar **150 milhões de usuários ativos diários (DAU)**, lidando com picos massivos de publicação em tempo real.

### 📊 Requisitos e Escala de Big Tech

#### Requisitos Funcionais:
1. **Publicar Post**: Usuários podem postar textos curtos (até 280 caracteres).
2. **Seguir Usuários**: Estabelecer relacionamentos direcionados (Seguidores / Seguindo).
3. **News Feed (Home Timeline)**: Visualizar um feed consolidado contendo os posts mais recentes de todos os usuários seguidos, ordenado cronologicamente de forma reversa.

#### Requisitos Não-Funcionais (Escala e Latência):
* **Escala de Escrita**: Média de **15.000 posts publicados por segundo**.
* **Escala de Leitura**: Média de **300.000 leituras de timeline por segundo**.
* **Latência de News Feed**: Retornar o News Feed consolidado do usuário em menos de 100ms na leitura.
* **Consistência Eventual**: Um post feito deve aparecer na timeline de seguidores ativos em no máximo 5 segundos (consistência eventual tolerável).

---

## 🗺️ Guia de Expectativas para Avaliação (Nível Staff L6+)

O design de alta performance deve ser baseado em um **modelo híbrido de Fan-out** controlado dinamicamente pela contagem de seguidores dos usuários.

```mermaid
graph TD
    User[Autor do Post] -->|Publica post| PostService[Post Service]
    PostService -->|Gravação física| Db[(Post Store - Document Db)]
    PostService -->|Evento de Post| Kafka[Kafka Message Broker]
    
    Kafka -->|Consumo assíncrono| FanoutWorker[Fan-Out Workers]
    FanoutWorker -->|Verifica seguidores| GraphService[Social Graph Service]
    
    GraphService -->|Seguidores < 25k (Push)| PushCache[(Cache Redis de Timelines)]
    GraphService -->|Seguidores >= 25k (Pull)| CelebrityDb[(Celebrity Metadata Db)]
    
    Reader[Leitor do Feed] -->|Carrega Home Feed| FeedService[Feed Aggregator]
    FeedService -->|Leitura rápida| PushCache
    FeedService -->|Identifica celebridades seguidas| CelebrityDb
    FeedService -->|Busca posts de celebridades e faz merge| MergeWorker[K-Way Merge Engine]
    MergeWorker --> Reader
```

### 1. Motor Híbrido de Fan-Out
* **Expectativa Staff**: O candidato **não** deve propor um modelo puramente de *Push* (que falha catastróficamente ao lidar com celebridades) nem um modelo puramente de *Pull* (que estrangula a leitura devido a JOINs/consultas gigantes em bancos para 300k QPS).
* **Solução Esperada**:
  * **Push para Comuns (Seguidores < $N$, ex.: 25.000)**: Quando o autor publica, o worker assíncrono espalha o ID do post diretamente no cache Redis (lista/zset) das timelines de seus seguidores ativamente logados nos últimos 30 dias.
  * **Pull para Celebridades (Seguidores $\ge N$)**: O post de celebridades é gravado apenas no seu store particular. Quando o seguidor carrega o feed, o agregador intercepta a lista de celebridades seguidas pelo leitor, busca as publicações recentes delas no banco/cache de posts e faz a **mesclagem ordenada** local de forma concorrente antes de entregar o payload.

### 2. Gestão de Caching de Timelines na RAM
* **Expectativa Staff**: Como a memória RAM de clusters Redis é cara e limitada, manter a timeline de todos os 150M de usuários ativos diários (e inativos) na RAM gerará desperdício.
* **Solução**:
  * Política de **evicção baseada em atividade**. Manter timelines ativas no cache na RAM. Se um usuário não faz login há mais de 3 dias, sua timeline de cache é destruída.
  * Ao fazer login novamente, um worker consome o grafo social e realiza o processo de re-hidratação (*cold startup*) da timeline a partir de bancos frios históricos em segundo plano.

### 3. Read-After-Write Consistency Local
* **Desafio**: Se o usuário publica um post e atualiza a página imediatamente, seu post deve aparecer na sua própria timeline, mesmo sob replicação assíncrona lenta.
* **Solução**:
  * A própria aplicação (cliente) ou o API Gateway pode fazer um bypass de cache injetando o post recém-criado na resposta da timeline local de forma imediata (otimismo de UI), ou buscar o feed pessoal diretamente no banco primário de escrita (User Timeline) em vez de ler da Home Timeline compartilhada no cache de consistência eventual.

---

## ⚖️ Rubrica de Avaliação (Sinais de Senioridade)

### 🟥 Sinais Vermelhos (Red Flags)
* Sugere resolver buscas de feeds complexos no tempo de leitura usando queries SQL com Joins recursivos em tabelas gigantes de banco relacional central único.
* Não diferencia a arquitetura de *User Timeline* (posts criados pelo usuário) de *Home Timeline* (feed consolidado que o usuário assiste).
* Propõe modelo puramente de Push e falha ao modelar o tráfego gerado por contas com mais de 10 milhões de seguidores.

### 🟨 Senior Engineer (L5)
* Entende e desenha fluxos de Push e Pull e propõe uso de mensageria (Kafka/RabbitMQ) para desacoplamento de escrita.
* Desenha tabelas de banco adequadas e caches baseados em Redis (Sorted Sets) utilizando chaves cronológicas.
* Lida com replicação simples e separação de leitura/escrita.

### 🟩 Staff Engineer (L6+)
* Formula e justifica com precisão os limites matemáticos do threshold híbrido (ex.: calcular o throughput de escrita no Redis com base em limites de CPU sob fan-out).
* Descreve detalhadamente o algoritmo de mesclagem e hidratação de timelines inativas.
* Identifica e propõe soluções de contingência para falhas parciais em sistemas de cache, garantindo que o feed do usuário sofra degradação suave (mostrar posts antigos cached) em vez de uma tela de erro 500.
