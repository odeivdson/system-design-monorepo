# 🏛️ Dev Senior - Trilha 3 - Etapa 3: System Design - URL Shortener Caching

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração:** 60 minutos
* **Foco:** Caching distribuído (Redis), consistência eventual, armazenamento NoSQL e dimensionamento de banco.

---

## 🎯 O Enunciado do Desafio

Projete o sistema de **Encurtamento e Redirecionamento de Links** para o site da empresa. O sistema deve receber URLs longas e gerar um link encurtado exclusivo. Quando alguém clicar no link, deve ser redirecionado instantaneamente para a URL original.

* **Escala:** ~1.000 requisições de redirecionamento por segundo (leitura).
* **Foco do Sênior:** Modelar o fluxo de cache para evitar ler o banco de dados principal a cada clique e planejar o particionamento básico do banco de dados (ex.: MongoDB/DynamoDB).

```mermaid
graph TD
    A[Navegador Cliente] -->|GET /t/{token}| B[Shortener Server]
    B -->|Check Cache| C[(Redis Cache)]
    C -->|Miss| D[(DynamoDB/Key-Value)]
    B -->|Grava Cache se Miss| C
    B -->|Redirect HTTP 302| A
```

---

## 🗺️ Guia de Expectativas para Avaliação (Nível Dev Senior)

### 1. Modelagem do Banco NoSQL
* **Foco Dev Senior:** Escolher um banco de dados NoSQL Chave-Valor (como DynamoDB ou MongoDB) ideal para buscas por chave rápida (`token -> long_url`). Propor o schema com campos básicos: `token` (Partition Key), `long_url`, `created_at`, `expiration_at`.

### 2. Estratégia de Cache e Expiração (Cache Eviction)
* **Desafio:** Como gerenciar a memória do cache para não estourar os custos com milhões de links antigos e raramente clicados?
* **Solução Dev Senior:**
  * Uso de política de expiração automática no Redis (TTL de 30 dias para links novos/acessados).
  * Configuração de política de limpeza de cache nativa no Redis (como LRU - Least Recently Used) para liberar memória automaticamente quando o cache estiver cheio.

### 3. Validação de Idempotência na Criação
* **Foco Dev Senior:** Explicar como evitar criar tokens duplicados para a mesma URL longa caso o usuário clique duas vezes no botão de "Encurtar" (ex.: fazer um hash MD5 da URL longa e salvá-lo como índice secundário exclusivo no banco).

---

## ⚖️ Rubrica de Avaliação (Dev Senior)
* **Sinal Verde (Green Flag):** Sabe modelar tabelas chave-valor eficientes; entende o funcionamento de cache e expirações de TTL; trata colisões de token de forma elegante.
* **Sinal Vermelho (Red Flag):** Propõe salvar todas as URLs no Redis sem TTL (estouro de memória); desconhece o conceito de cache miss.

---

[Ir para a Etapa 4: Coding Onsite ➡️](./04-coding-onsite.md)
