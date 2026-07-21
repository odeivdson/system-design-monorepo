# Desafio 21: Propagação de Identidade Zero Trust com BFF e Token Handler (`zero-trust-identity-propagation`)
> **Padrões de Microsserviços Associados:** BFF (Backend for Frontends), Token Handler (Abstração de Sessão/Token), Identity Propagation (Rastreabilidade de Contexto), Distributed Claims Verification, Zero Trust Architecture (RBAC/ABAC descentralizado).

## 1. Contexto & Cenário
Em arquiteturas modernas de microsserviços expostas para aplicações SPA (Single Page Applications) ou Mobile, o gerenciamento de credenciais de autenticação é um dos maiores vetores de falhas de segurança. 

Historicamente, aplicações SPA armazenavam tokens de acesso (JWT) diretamente no `localStorage` ou `sessionStorage` do navegador para realizar chamadas diretas às APIs de microsserviços. No entanto, essa abordagem expõe o token a ataques de **XSS (Cross-Site Scripting)**: se um script malicioso (como uma dependência npm corrompida) for injetado no frontend, ele poderá ler e roubar o JWT completo do usuário, permitindo o sequestro de sessão até que o token expire.

Para mitigar esse risco de segurança e proteger os recursos de nuvem, adota-se o padrão **BFF (Backend for Frontends)** atuando como um **Token Handler**. O frontend não tem acesso aos tokens criptográficos. Em vez disso, ele mantém uma sessão clássica e segura por meio de cookies criptografados, configurados obrigatoriamente com os atributos `HttpOnly`, `Secure` e `SameSite=Strict`.

Quando uma requisição chega, o BFF intercepta o Cookie, localiza ou descriptografa o Token de Acesso correspondente (JWT) e o injeta no cabeçalho `Authorization: Bearer <JWT>` antes de encaminhar a requisição para a rede interna. A partir deste ponto, na rede interna sob premissas de **Zero Trust** (Nunca Confiar, Sempre Verificar), cada microsserviço downstream deve validar o token e propagar de forma segura o contexto de identidade assinado do usuário para os próximos serviços da cadeia.

---

## 2. Requisitos Funcionais (RF)
- **Tradução de Cookie para JWT no BFF**:
  - O BFF deve expor um endpoint reverso que recebe requisições com cookies de sessão de frontend (`session_id`), valida o cookie, extrai o JWT (Access Token e ID Token) correspondente armazenado em cache/memória ou descriptografa-o diretamente (se usado cookie encriptado) e injeta o cabeçalho `Authorization: Bearer <JWT>` na requisição downstream.
- **Validação de Assinatura Descentralizada**:
  - Cada microsserviço receptor do tráfego interno não deve confiar implicitamente na rede física. Cada serviço deve extrair o JWT e validar sua assinatura criptográfica usando um conjunto de chaves públicas (JWKS - JSON Web Key Sets) recuperadas de forma eficiente do Provedor de Identidade (IDP).
- **Propagação de Contexto Seguro (Identity Propagation)**:
  - Ao fazer chamadas internas para outros microsserviços (ex: `Order-Service` chamando `Payment-Service`), o microsserviço de origem deve propagar o JWT do usuário original ou um token de contexto interno assinado contendo as claims mínimas de autorização (Princípio do Menor Privilégio).
- **Mecanismo de Auditoria e Rastreabilidade**:
  - Incluir e verificar o ID de Correlação (`X-Correlation-ID`) e o contexto de autenticação do usuário (ID do usuário, tenant e escopos) em todos os logs gerados na cadeia de execução.
- **Revogação Distribuída de Emergência (Blacklist)**:
  - Implementar um mecanismo ágil onde o microsserviço verifica se o identificador único do token (`jti` - JWT ID) consta em uma lista de revogação de emergência distribuída de baixa latência (ex: cache local sincronizado via Pub/Sub) para bloquear acessos antes do vencimento natural do JWT.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead de Validação Sub-Milissegundo**: A decodificação e validação criptográfica do token JWT não deve adicionar mais de 1ms de latência ao tempo de processamento de requisição no P99 (utilizar algoritmos eficientes de verificação de assinatura e caches locais para o JWKS).
- **Autonomia sob Queda do IDP**: Os microsserviços devem ser capazes de validar a assinatura criptográfica dos tokens de forma offline por até $N$ minutos em caso de indisponibilidade total do Provedor de Identidades (Identity Provider), dependendo estritamente do cache local do JWKS.
- **Isolamento de Vazamento de Memória por Token**: O cache local de tokens validados ou revogados nos microsserviços deve usar estratégias de limpeza automática com tempo de vida curto (TTL curto correspondente à expiração do JWT) para evitar vazamento de memória (Memory Leak) sob alta carga de requisições de usuários distintos.
- **Proteção contra Inflação de Cabeçalhos (Header Bloat)**: Impedir o crescimento descontrolado do tamanho das requisições internas à medida que claims extras são injetadas no contexto, mantendo os cabeçalhos HTTP sob o limite seguro padrão (normalmente 8KB).

---

## 4. Guia de Implementação & Padrões

### Arquitetura de Autenticação Zero Trust (BFF + Downstream Propagation)

```
                       ┌───────────────────────┐
                       │  User Browser (SPA)   │
                       └───────────┬───────────┘
                                   │ (Requisição com Cookie HTTP-Only)
                                   ▼
                       ┌───────────────────────┐
                       │    BFF Gateway /      │
                       │     Token Handler     │◄──────┐ (JWKS Fetch)
                       └───────────┬───────────┘       │
                                   │                   │
  (Substitui Cookie por JWT        │                   │
   no header Authorization)        ▼                   │
                       ┌───────────────────────┐    ┌──┴───────────────┐
                       │    Microservice A     │───►│ Identity Provider│
                       │    (Order-Service)    │    │      (IDP)       │
                       └───────────┬───────────┘    └──────────────────┘
                                   │ (Valida JWT via JWKS local)
                                   │ (Propaga JWT/Contexto Assinado)
                                   ▼
                       ┌───────────────────────┐
                       │    Microservice B     │
                       │   (Payment-Service)   │
                       └───────────────────────┘
```

### Padrões e Primitivas Recomendadas:
1. **BFF / Token Handler Pattern**: O BFF armazena o `access_token`, `refresh_token` e `id_token` em um repositório seguro do lado do servidor (ou em um cookie de sessão altamente encriptado e particionado se for stateless) indexado pelo ID de sessão contido no cookie do navegador do usuário.
2. **JWKS Local Caching com Grace Period**: Os microsserviços devem fazer download das chaves públicas de validação do IDP (`/keys` ou `.well-known/jwks.json`) e mantê-las em cache na memória RAM. Configurar um TTL longo (ex: 24 horas) mas com um mecanismo de recarga background assíncrona se um token contiver uma chave (`kid` - Key ID) desconhecida para suportar rotação de chaves sem downtime.
3. **Decentralized RBAC/ABAC**: Os microsserviços executam as regras de autorização de forma local analisando as claims contidas no JWT (ex: `roles: ["billing-admin"]`, `tenant_id: "company_123"`), evitando chamadas de rede externas para o IDP a cada validação de permissão.
4. **Contexto Interno Assinado (Propagação Segura)**: Opcionalmente, para evitar passar o JWT original pesado e de longa duração entre múltiplos saltos downstream internos, o Gateway ou o primeiro serviço pode traduzir o JWT em um token de contexto interno curto e assinado simetricamente com chave compartilhada (HMAC-SHA256) ou assimétrica rápida contendo apenas as informações estritamente necessárias para os serviços internos.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Zero Vazamento de Tokens**: Provar por meio de fluxo de rede e inspeção de console do navegador que o token de acesso (JWT) nunca é trafegado ou exposto ao frontend (o frontend possui apenas cookies de sessão).
- **Desempenho da Validação Criptográfica**: Demonstração de benchmark onde a validação das assinaturas dos tokens downstream ocorrem em CPU de forma local, mantendo latências quase nulas (microsegundos).
- **Validação de Resiliência de Chaves (Key Rotation)**: Teste automatizado mostrando o que ocorre quando o Provedor de Identidade rotaciona a chave privada de assinatura. O microsserviço downstream deve detectar o novo `kid` no JWT, invalidar o cache local de JWKS, buscar a nova chave pública no IDP de forma segura e prosseguir sem rejeitar requisições legítimas.
- **Mitigação de Token Replay**: Validação de expiração (`exp`), emissor (`iss`) e audiência (`aud`) do token em cada microsserviço independente, garantindo que um token roubado de um escopo/contexto não possa ser reutilizado indevidamente em outro serviço downstream.

---

## 6. Trade-offs

### A. Cookies de Sessão Encriptados (Stateless BFF) vs. Sessão em Cache Servidor (Stateful BFF)
- **Cookie Encriptado no Frontend (Stateless BFF)**:
  - *Pró*: O BFF não precisa manter estado em banco/Redis para traduzir cookies para tokens, o que facilita o escalonamento horizontal simples do BFF.
  - *Contra*: O tamanho dos cookies HTTP cresce consideravelmente (podendo estourar o limite de 4KB do protocolo HTTP se o JWT for muito grande), além do overhead de processamento de CPU no BFF para encriptar e decriptar o cookie a cada requisição.
- **Sessão em Cache Servidor (Stateful BFF)**:
  - *Pró*: Cookies extremamente pequenos (apenas um ID de sessão de 32 bytes). Alta segurança, pois os tokens reais nunca saem da infraestrutura do servidor.
  - *Contra*: Dependência de um datastore distribuído de alto desempenho e baixa latência (como Redis) compartilhado entre as réplicas do BFF para busca de tokens.

### B. Propagação Downstream do JWT Original vs. JWT de Contexto Interno
- **Propagação do JWT Original**:
  - *Pró*: Simplicidade de design. O token que o usuário emitiu trafega intocado até o último microsserviço da cadeia.
  - *Contra*: Viola o princípio do menor privilégio (um serviço interno de envio de e-mails recebe um token com poder total de transação financeira do usuário); expiração do JWT original no meio de um fluxo longo distribuído pode quebrar transações em andamento.
- **JWT de Contexto Interno**:
  - *Pró*: Escopo restrito e dados otimizados para consumo interno. Chaveamento criptográfico interno mais rápido.
  - *Contra*: Complexidade para projetar e manter o serviço de tradução/emissão de tokens internos na borda e sincronizar chaves de validação internas.
