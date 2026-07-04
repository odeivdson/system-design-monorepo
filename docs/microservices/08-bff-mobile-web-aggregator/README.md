# Desafio 8: Agregador de APIs BFF para Mobile & Web (`bff-mobile-web-aggregator`)
> **Padrões de Microsserviços Associados:** Backends for Frontends (BFF), Stateless Services (Escalabilidade Horizontal), Smart Endpoints, Dumb Pipes (Lógica na borda).

## 1. Contexto & Cenário
Em ecossistemas de microsserviços maduros, o frontend (seja aplicativo móvel ou aplicação web) frequentemente necessita carregar dados de múltiplas origens para construir uma única tela do usuário. Por exemplo, a página inicial do usuário (Dashboard) precisa exibir: dados cadastrais (User Service), últimos pedidos (Order Service) e sugestões personalizadas (Recommendation Service).

Se o aplicativo cliente realizar chamadas diretas HTTP sequenciais a cada um desses microsserviços downstream, a latência percebida será desastrosa. Dispositivos móveis sofrem com conexões de rede oscilantes e latência de rádio móvel (3G/4G/5G). Além disso, o payload retornado pelo microsserviço de pedidos pode conter dados internos de faturamento irrelevantes para o app mobile, consumindo banda desnecessária do plano de dados do usuário.

Para otimizar o consumo de recursos e acelerar a experiência do usuário, utilizamos o padrão **BFF (Backends for Frontends)**. Projetamos uma camada intermediária stateless que atua como agregador inteligente. O BFF expõe um único endpoint otimizado por tipo de cliente, busca os dados downstream de forma assíncrona concorrente, funde as respostas, filtra chaves desnecessárias e retorna um payload enxuto sob medida.

---

## 2. Requisitos Funcionais (RF)
- **Endpoints Customizados**: Expor rotas distintas para canais diferentes:
  - `GET /api/v1/mobile/dashboard`: Retorna apenas campos essenciais para telas pequenas (nome, ID do pedido, status do pedido, IDs recomendados).
  - `GET /api/v1/web/dashboard`: Retorna o payload completo enriquecido (detalhes dos itens do pedido, tracking de entrega, histórico completo de recomendações).
- **Agregação Assíncrona**: O agregador deve disparar requisições em paralelo para os três serviços downstream:
  - `GET /users/{id}`
  - `GET /orders?user_id={id}`
  - `GET /recommendations?user_id={id}`
- **Filtragem Lógica de Payload (Dynamic Pruning)**: Implementar uma rotina de limpeza de chaves (JSON mapping) para expurgar dados que o cliente mobile não consome (ex: logs, metadados internos de auditoria).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Task Parallelism Sem Bloqueio**: A execução das consultas downstream deve ser realizada de forma não-bloqueante concorrente (usando primitivas como `Task.WhenAll` em C# ou `CompletableFuture.allOf` em Java). A latência total do BFF deve ser ditada pelo serviço mais lento, não pela soma deles:
  $$\text{Latência}_{BFF} \approx \max(\text{Lat}_{User}, \text{Lat}_{Order}, \text{Lat}_{Rec}) + \text{Overhead}_{Aggregation}$$
- **Timeouts Agressivos e Degradabilidade Graceful**:
  - Timeout máximo estrito para chamadas downstream: 200ms.
  - Se o serviço de recomendações falhar ou exceder o timeout, o BFF deve degradar de forma elegante (Graceful Degradation): omitir a seção de recomendações ou injetar uma lista pré-compilada em cache estático local, permitindo que a resposta de dados cadastrais e pedidos seja entregue normalmente (`HTTP 200 OK` com dados parciais).
- **Stateless absoluto**: Nenhuma sessão ou estado de requisição deve ser salvo localmente no BFF. O BFF delega tokens JWT diretamente aos serviços downstream para validação stateless.

---

## 4. Guia de Implementação & Padrões

### Arquitetura de Agregação de Fluxo Concorrente
```
                   [ App Mobile ]
                         │
                         ▼ (GET /mobile/dashboard)
┌────────────────────────────────────────────────────────┐
│                      BFF Gateway                       │
│                                                        │
│  Dispara 3 Tarefas Assíncronas em Paralelo (Timeout 200ms) │
└──────┬───────────────────┬───────────────────┬─────────┘
       │                   │                   │
       ▼ (Task 1)          ▼ (Task 2)          ▼ (Task 3)
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│ User Service │    │Order Service │    │ Recom. Service   │
│ (HTTP 200)   │    │ (HTTP 200)   │    │ (Timeout/503)    │
└──────┬───────┘    └──────┬───────┘    └──────┬───────────┘
       │                   │                   │
       │           (Funde respostas)           │ (Fallback Ativado)
       └───────────────────┼───────────────────┘
                           ▼
              Omitir Recomendações do JSON
                           │
                           ▼
                  [ Retorna HTTP 200 ]
```

### Padrões e Primitivas Recomendadas:
- **Client Fallback (Circuit Breaker local)**: Acoplar um Circuit Breaker ou lógica de retry local para as APIs downstream. Se o serviço de ordens falhar seguidamente, o BFF abre o circuito para evitar atolar conexões TCP em chamadas perdidas.
- **Task Cancellation Tokens**: Passar `CancellationToken` nas tarefas de chamada HTTP downstream. Se uma das tarefas estourar o timeout ou se o cliente cancelar a requisição HTTP original, todas as outras chamadas em andamento devem ser abortadas imediatamente para economizar recursos e conexões de rede do servidor.
- **HttpClient Factory e Connection Pooling**: Evitar criar instâncias de `HttpClient` por requisição (risco de esgotamento de portas efêmeras - Socket Exhaustion). Usar pools reutilizáveis configurados para reaproveitar conexões TCP ativas (Keep-Alive).

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Evitar sequential-blocking**: Código estrutural limpo de paralelização (comprovação de que não há nenhum `await` ou `.Result` sequencial bloqueando a thread principal antes do disparo das demais chamadas).
- **Tratamento de Exceções Robustas**: Se o serviço A retornar erro HTTP `400 Bad Request` (erro de validação do cliente), o BFF deve repassar o erro adequadamente. Se o serviço C retornar `500 Internal Server Error`, o BFF deve absorver a falha e prosseguir de forma degradada, sem colapsar a tela inteira.
- **Segurança Stateless**: Como os tokens de autenticação (JWT) são repassados e sanitizados (Propagation of Context/Security Headers).
- **Eficiência na Serialização**: Evitar sobrecargas de serialização e desserialização repetidas. Desserializar apenas os campos necessários downstream e serializar o payload mobile final de forma eficiente.

---

## 6. Trade-offs

### A. BFF Dedicado vs. API Gateway Genérico
- **BFF Dedicado por Cliente (Recomendado)**:
  - *Pró*: Alta flexibilidade para o time de frontend modificar contratos e payloads de forma autônoma sem impactar outros sistemas.
  - *Contra*: Duplicação de código básico de infraestrutura (autenticação, rate limiting) em múltiplos BFFs.
- **API Gateway Genérico (Ex: Kong, Ocelot)**:
  - *Pró*: Ponto único consolidado de auditoria e segurança.
  - *Contra*: O Gateway se torna um gargalo organizacional e de código, pois qualquer alteração de payload mobile/web exige manutenção centralizada.

### B. BFF Customizado vs. GraphQL Downstream
- **BFF com endpoints REST Customizados**:
  - *Pró*: Altíssima performance, implementação direta, facilidade de caching tradicional em HTTP gateways e monitoramento de logs de rotas específicas.
  - *Contra*: Exige escrita de novas rotas no código a cada nova tela ou campo necessário.
- **GraphQL**:
  - *Pró*: O cliente escolhe exatamente quais campos quer; reduz overhead de novas rotas.
  - *Contra*: Complexidade extrema de segurança e prevenção de queries abusivas que sobrecarreguem e derrubem os bancos downstream (N+1 queries).
