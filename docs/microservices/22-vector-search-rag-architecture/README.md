# Desafio 22: Arquitetura de Busca Vetorial e RAG (Retrieval-Augmented Generation) (`vector-search-rag-architecture`)
> **Padrões de Microsserviços Associados:** Pipeline de Ingestão de Dados (Batch/Streaming), Ingestion Outbox Pattern, Semantic Caching (Cache por Similaridade), Resilient External API Integration, Fallback/Graceful Degradation.

## 1. Contexto & Cenário
Com a ascensão de Modelos de Linguagem de Grande Porte (LLMs), surgiu a necessidade de conectar a inteligência conceitual das IAs aos dados privados, dinâmicos e proprietários das empresas. Como o treinamento e ajuste fino (*Fine-Tuning*) de modelos são processos lentos, caros e complexos, o padrão **RAG (Retrieval-Augmented Generation)** estabeleceu-se como a arquitetura padrão para resolver esse desafio.

O RAG funciona enriquecendo o prompt enviado à LLM com trechos de informações relevantes extraídos de uma base de conhecimento privada no momento da requisição, mitigando significativamente o problema das **alucinações** (respostas factualmente incorretas do modelo).

No entanto, projetar um sistema de RAG para produção em nível empresarial impõe severos desafios de engenharia e arquitetura de software:
- **Processamento Ineficiente de Documentos**: Arquivos grandes e não estruturados (PDFs, relatórios) precisam ser divididos (*chunking*) de maneira inteligente para não estourar o limite de tokens da LLM nem diluir o contexto semântico.
- **Latência de Geração de Embeddings e LLM**: Chamadas externas a provedores de modelos (ex: OpenAI, Anthropic, Google Gemini) são lentas, caras e sujeitas a falhas de rede e limites de taxa severos (*Rate Limits*).
- **Consistência de Dados**: Se a base de documentos interna é atualizada, o banco de dados vetorial deve ser atualizado de forma sincronizada e eventual consistente, sem bloquear o sistema produtivo.

Para solucionar esses gargalos, implementa-se um pipeline duplo desacoplado: um **Pipeline de Ingestão Assíncrono** (que processa documentos e gera embeddings em background utilizando filas de mensagens) e um **Pipeline de Consulta Síncrono de Baixa Latência** (que orquestra a busca de similaridade e a chamada para a LLM, otimizados por um **Semantic Cache**).

---

## 2. Requisitos Funcionais (RF)
- **Pipeline de Ingestão Vetorial (Indexing)**:
  - O sistema deve expor um endpoint para receber novos documentos. A ingestão deve ser dividida em tarefas assíncronas:
    1. *Chunking*: Dividir o texto usando estratégias estruturadas (ex: chunks de 500 caracteres com overlap de 10%).
    2. *Embedding Generation*: Submeter os chunks a um modelo de embedding de forma assíncrona com controle de concorrência.
    3. *Vector Storage*: Armazenar os vetores gerados e seus metadados associados (texto original, ID do documento) em um Vector Database.
- **Pipeline de Consulta Semântica (Retrieval)**:
  - O orquestrador síncrono deve:
    1. Traduzir a pergunta do usuário em um vetor de consulta (Query Embedding).
    2. Realizar uma busca de similaridade (ex: Cosseno) no banco vetorial e extrair os $K$ chunks mais relevantes.
    3. Construir o Prompt final injetando o contexto retornado e a pergunta do usuário.
    4. Enviar o prompt consolidado para a LLM e retornar a resposta textual.
- **Semantic Cache (Cache Semântico)**:
  - Antes de realizar a chamada para gerar a embedding da pergunta e consultar o banco vetorial, verificar se a mesma pergunta ou uma **semanticamente equivalente** (similaridade de cosseno $> 0.95$) já foi feita anteriormente, retornando a resposta diretamente do cache (ex: Redis) e economizando chamadas para a LLM e banco vetorial.
- **Gestão de Cotas e Rate Limiting de LLM**:
  - Limitar a taxa de requisições de saída para as APIs de LLM externas para evitar bloqueios de cota por estouro de RPM (Requests Per Minute) ou TPM (Tokens Per Minute).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Latência de Busca Semântica P99 < 50ms**: O tempo de pesquisa no índice de vetores deve ser extremamente baixo, requerendo algoritmos de busca por aproximação de vizinhos mais próximos (ANN - *Approximate Nearest Neighbor*), como HNSW (Hierarchical Navigable Small World) ou indexação baseada em partições (IVF).
- **Backpressure na Geração de Embeddings**: O worker assíncrono de geração de embeddings deve ter um controle de vazão rígido (Backpressure) para respeitar os limites de taxa da API de embeddings, evitando descartar mensagens sob picos de ingestão em lote de documentos.
- **Graceful Degradation sob Queda da LLM**: Se a API da LLM cair ou retornar timeout repetidamente, o sistema deve degradar graciosamente (ex: ativar um modelo de linguagem local menor rodando localmente na infraestrutura ou retornar respostas pré-computadas de um cache estático de fallback).
- **Isolamento de Tenant no Espaço Vetorial (Multi-Tenancy)**: Garantir que buscas de um Tenant $A$ nunca acessem ou retornem vetores de um Tenant $B$. O Vector Database deve suportar particionamento lógico rígido (filtros de metadados aplicados em nível de busca vetorial).

---

## 4. Guia de Implementação & Padrões

### Fluxo Arquitetural do Pipeline RAG e Ingestão

```
PIPELINE DE INGESTÃO (ASSÍNCRONO):
[Documento] ──► [Chunker Engine] ──► [Outbox Table/Queue] ──► [Embedding Worker] ──► [Vector DB Index]

PIPELINE DE CONSULTA (SÍNCRONO):
                     ┌──────────────────┐
                     │   User Request   │
                     └────────┬─────────┘
                              │ (Pergunta: "Como cancelo meu Pix?")
                              ▼
                     ┌──────────────────┐    (Hit)      ┌────────────────┐
                     │  Semantic Cache  ├──────────────►│ Return Cached  │
                     └────────┬─────────┘               │    Response    │
                              │ (Miss)                  └────────────────┘
                              ▼
                     ┌──────────────────┐
                     │ Query Embedding  │
                     └────────┬─────────┘
                              │
                              ▼
                     ┌──────────────────┐
                     │ Vector Search    ├──────► [Filtra Tenant ID]
                     │ (HNSW Index DB)  │
                     └────────┬─────────┘
                              │ (Retorna K chunks relevantes)
                              ▼
                     ┌──────────────────┐
                     │ Prompt Composer  │ (Monta Prompt: Instrução + Contexto + Query)
                     └────────┬─────────┘
                              │
                              ▼
                     ┌──────────────────┐    (Falha)    ┌────────────────┐
                     │ LLM API Client   ├──────────────►│ Fallback Local │
                     │  (With Retry)    │               │  Model Service │
                     └────────┬─────────┘               └────────────────┘
                              │ (Sucesso)
                              ▼
                     ┌──────────────────┐
                     │ Save to Cache &  │
                     │  Return to User  │
                     └──────────────────┘
```

### Padrões e Primitivas Recomendadas:
1. **Semantic Cache Pattern**: Armazenar chaves no Redis no formato `pergunta_hash` -> `vetor_pergunta`. Ao receber uma nova pergunta, gerar apenas a embedding dela e realizar um cálculo rápido de similaridade de cosseno (local ou no Redis usando módulos vetoriais) contra os vetores de perguntas já respondidas. Se houver hit com alta similaridade, recuperar a resposta associada no Redis.
2. **Dynamic Ingestion Rate Limiter**: Configurar uma fila com controle de concorrência baseada em *Token Bucket* local para despachar requisições para a API de embeddings do IDP.
3. **Partitioned HNSW Search**: Configurar o banco de dados vetorial para usar indexação HNSW. Nas consultas de similaridade, aplicar filtros booleanos de partição (como `tenant_id == 'empresa_1'`) integrados à própria travessia do grafo de busca vetorial (Single-stage Filtering), garantindo segurança dos dados e alta performance.
4. **Resilient HTTP Client with Token Budget**: O cliente que consome a LLM externa deve gerenciar janelas de retentativas usando Backoff Exponencial com Jitter, além de rastrear o consumo acumulado de tokens (Input + Output) para bloquear requisições preventivamente se estiver prestes a estourar a cota de tokens contratada da LLM.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Desempenho com Grande Volume**: O tempo de resposta da busca vetorial em um índice com mais de 100 mil vetores deve permanecer abaixo do SLA de 50ms.
- **Isolamento de Dados Confirmado**: Testes automatizados que provam que buscas vetoriais parametrizadas com `tenant_id = B` nunca retornam documentos pertencentes ao `tenant_id = A`, mesmo se o conteúdo semântico for extremamente semelhante.
- **Comportamento do Semantic Cache**: Provar o aumento de performance e redução de custos mostrando que requisições repetidas ou ligeiramente reescritas do usuário retornam do cache em menos de 5ms, sem chamar a LLM.
- **Recuperação de Falhas da LLM**: Testes de caos demonstrando que, em caso de queda simulada da LLM, o orquestrador aciona imediatamente o fallback local em menos de 100ms para manter o serviço ativo com degradação aceitável de inteligência.

---

## 6. Trade-offs

### A. Chunks Pequenos vs. Chunks Grandes
- **Chunks Pequenos (ex: 200 caracteres)**:
  - *Pró*: Ocupam menos tokens no prompt; busca vetorial mais precisa e focada; menor custo de processamento da LLM.
  - *Contra*: Perda considerável do contexto ao redor da informação; respostas da LLM podem ficar superficiais por falta de contexto global.
- **Chunks Grandes (ex: 2000 caracteres)**:
  - *Pró*: Preserva o sentido e contexto amplo do parágrafo/documento; respostas mais ricas da LLM.
  - *Contra*: Alto consumo de tokens; maior latência no processamento da LLM; risco de diluir a informação específica que o usuário precisa no meio de texto irrelevante (*Lost in the Middle*).

### B. Similaridade por Cosseno vs. Produto Escalar (Dot Product)
- **Similaridade por Cosseno**:
  - *Pró*: Normaliza o comprimento dos vetores, comparando apenas a direção angular. Ideal para quando os documentos de contexto variam muito de tamanho.
  - *Contra*: Custoso computacionalmente devido ao cálculo da magnitude de cada vetor a cada consulta (caso os vetores não estejam pré-normalizados).
- **Produto Escalar (Dot Product)**:
  - *Pró*: Muito mais rápido computacionalmente (simples soma de produtos). Se os vetores de embeddings forem pré-normalizados na geração, o resultado é matematicamente idêntico à Similaridade de Cosseno.
  - *Contra*: Se os vetores de embeddings não forem normalizados, o resultado será enviesado por documentos mais longos ou de maior frequência terminológica.
