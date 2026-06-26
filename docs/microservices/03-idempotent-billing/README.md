# Desafio 3: Proxy de Idempotência Estrita para APIs de Pagamento (`idempotency-proxy`)
> **Padrões de Microsserviços Associados:** API Gateway (Intercepção), Polyglot Persistence (Redis + PostgreSQL fallback), Sidecar (Proxy Interceptor).

## 1. Contexto & Cenário
Em ecossistemas de e-commerce e serviços financeiros em escala extrema (como Mercado Livre, Netflix ou Stripe), a confiabilidade no processamento de transações é crítica. Redes IP não são confiáveis e falhas de conexão no "último milha" (last mile) são comuns. Quando um cliente móvel ou serviço de checkout envia uma requisição de pagamento e a conexão cai antes de receber a resposta HTTP, a reação padrão da aplicação cliente é retentar a operação.

Sem um mecanismo de idempotência estrita, essa retentativa resultará em cobrança duplicada (double-charge), gerando frustração ao usuário final, custos operacionais massivos de estorno (chargebacks) e possível quebra de conformidade regulatória. O objetivo deste desafio é projetar e implementar um middleware/proxy de idempotência distribuído que intercepte e garanta a execução exata de uma única vez (exactly-once processing) para transações mutativas críticas.

---

## 2. Requisitos Funcionais (RF)
- **Interceptação de Chaves de Idempotência**: O sistema deve expor uma API que exige o header `X-Idempotency-Key` (identificador único universal da transação, ex: UUIDv4).
- **Detecção de Duplicidade em Tempo Real**:
  - Se a chave for inédita, processar o pagamento e persistir o par `(chave, resposta)`.
  - Se a chave já tiver sido processada com sucesso, retornar imediatamente o payload HTTP salvo em cache, sem invocar os microsserviços downstream de faturamento.
- **Tratamento de Requisições em Trânsito (In-Flight)**: Se uma requisição com a mesma chave chegar enquanto o primeiro processamento ainda estiver em andamento, o sistema deve retornar um status HTTP indicativo de conflito temporário (ex: `409 Conflict` ou `202 Accepted` indicando processamento em andamento) para evitar condições de corrida concorrentes no gateway de pagamento.
- **Persistência de Estados da Transação**: Manter o ciclo de vida da transação com estados bem definidos: `PENDING`, `SUCCESS`, `FAILED`.
- **TTL Automatizado**: As chaves de idempotência e seus payloads associados devem ser automaticamente invalidados após um período parametrizável (ex: 24 a 48 horas).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Latência Ultra Baixa**: O overhead inserido pelo proxy para checagem e locking de chaves deve ser sub-10ms no percentil P99.
- **Alta Concorrência**: Suportar cargas superiores a 10.000 RPS (Requests Per Second) sob concorrência agressiva de retentativas idênticas disparadas no mesmo milissegundo.
- **Consistência Estrita (Linearidade)**: Garantia absoluta de zero double-charge. Sob nenhuma condição de corrida (race conditions ou splits de rede) duas threads de execução paralelas podem prosseguir com o faturamento para a mesma chave.
- **Alta Disponibilidade e Resiliência (Partition Tolerance vs Consistency)**: 
  - Se o store de cache de idempotência (ex: Redis) ficar temporariamente indisponível, o sistema deve adotar um comportamento explícito de segurança: *Fail-Closed* para faturamento (bloquear novos pagamentos para evitar riscos de duplicidade) ou *Fail-Open com fallback de banco relacional transacional*.
- **Eficiência de Armazenamento**: O payload armazenado no cache deve ser otimizado (ex: compressão gzip/brotli se o payload for maior que 2KB) para evitar estouro de memória no cluster de cache.

---

## 4. Guia de Implementação & Padrões
A arquitetura do proxy deve ser baseada em filtros/middleware distribuídos apoiados por uma camada de cache distribuída e um banco de dados transacional durável.

```
       [ Cliente ]
            │
            ▼ (POST /payments com X-Idempotency-Key)
┌───────────────────────────────────────────────┐
│              Idempotency Proxy                │
│                                               │
│  1. Check Redis for Key (Atomic Get/Lock)     │
│     - State: SUCCESS -> Return cached response │
│     - State: PENDING -> Return HTTP 409       │
│     - State: None    -> Set PENDING & Acquire │
│                         Distributed Lock      │
└──────────────────────┬────────────────────────┘
                       │
             (Lock acquired & state = PENDING)
                       │
                       ▼
┌───────────────────────────────────────────────┐
│        Billing downstream Service             │
│   (Executa débito e insere no banco de dados)  │
└──────────────────────┬────────────────────────┘
                       │
            (Transaction complete)
                       │
                       ▼
┌───────────────────────────────────────────────┐
│  2. Update State to SUCCESS in Cache & DB      │
│  3. Release Distributed Lock                  │
└───────────────────────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Lock Distribuído via Redis (Redlock ou SETNX com TTL)**: Usado para garantir exclusão mútua distribuída durante a fase inicial em que o status passa de "inexistente" para `PENDING`.
- **Scripts Lua no Redis**: Para garantir atomicidade de leitura e escrita (Read-and-Set) no primeiro check da chave, reduzindo as viagens de ida e volta da rede (network roundtrips).
- **Máquina de Estados de Idempotência**:
  - `None` $\rightarrow$ `PENDING` (Locks adquiridos, chamada downstream iniciada).
  - `PENDING` $\rightarrow$ `SUCCESS` (Processamento finalizado, payload salvo).
  - `PENDING` $\rightarrow$ `FAILED` (Erro tratável ou timeout; liberação da chave para retentativa segura dependendo do tipo do erro).
- **Garantia no Banco de Dados (Última Linha de Defesa)**: Índice único (`UNIQUE CONSTRAINT`) na coluna `idempotency_key` da tabela de transações do banco de dados relacional (ex: PostgreSQL), prevenindo gravação duplicada mesmo que o cache falhe totalmente.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Tratamento de Race Conditions no Limiar do Milissegundo**: Como a solução impede que duas requisições idênticas recebidas por nós diferentes do balanceador de carga ao mesmo tempo acessem o serviço de faturamento downstream.
- **Diferenciação de Tipos de Erro para Retentativa**:
  - Se o serviço downstream retornar erro de validação de dados (`400 Bad Request`), o proxy deve salvar essa resposta e nunca retentar.
  - Se ocorrer uma falha de infraestrutura (`503 Service Unavailable` ou timeout de rede), o proxy deve permitir que o cliente tente novamente (removendo o estado `PENDING` ou revertendo para `FAILED` de forma limpa).
- **Ciclo de Vida do Lock**: O lock do Redis deve ter um TTL curto (suficiente para cobrir o timeout máximo da chamada downstream, ex: 10s) para evitar locks órfãos permanentes em caso de crash do worker do proxy.
- **Serialização Eficiente**: Design do armazenamento da resposta HTTP original (status code, headers críticos e body).
- **Abordagem de Disaster Recovery**: Tratamento de cenários onde o Redis cai no meio da transação.

---

## 6. Trade-offs

### A. Fail-Open vs. Fail-Closed
- **Fail-Open**: Se o banco de cache ou o proxy de idempotência falhar, ignoramos a checagem e enviamos a transação diretamente para o billing. 
  - *Pró*: Não impede o cliente de comprar (preserva receita no curto prazo).
  - *Contra*: Alto risco de transações duplicadas em cenários de instabilidade global.
- **Fail-Closed (Recomendado para Finanças)**: Bloqueamos a transação se não conseguirmos garantir a idempotência.
  - *Pró*: Consistência e segurança financeira absoluta.
  - *Contra*: Perda temporária de conversão em caso de indisponibilidade da infraestrutura de idempotência.

### B. Cache Distribuído (Redis) vs. Banco de Dados Relacional
- Armazenar o cache de resposta apenas no Redis traz latência sub-milissegundo, mas se o Redis reiniciar, o histórico de idempotência recente é perdido (a menos que configurado com AOF síncrono agressivo, o que reduz performance). A estratégia híbrida de registrar a chave no banco relacional como fallback garante a persistência regulatória, embora aumente a latência geral de escritas bem-sucedidas.

### C. Lock Distribuído Global vs. DB Unique Constraints
- Confiar apenas na Unique Constraint do banco de dados é simples e seguro, mas expõe a API downstream a processamentos pesados desnecessários antes que a query falhe. O Lock distribuído no proxy filtra a carga de forma barata na borda da arquitetura, mas introduz complexidade de gestão de locks distribuídos de rede.