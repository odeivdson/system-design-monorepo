# Desafio 15: Cache Híbrido Sincronizado com Invalidação por Pub/Sub (`hybrid-cache-sync`)

## 1. Contexto & Cenário
Em sistemas de altíssima performance e baixa latência (como catálogos de produtos, validação de permissões de usuário ou motores de recomendação), a latência de acesso à rede para consultar um cache centralizado distribuído (como Redis ou Memcached - considerado o Cache de Nível 2 / L2) pode ser proibitiva, variando de 1 a 5 milissegundos. Para obter tempos de resposta na escala de microsegundos (<0,1 ms), os microsserviços implementam caches locais em memória RAM da própria réplica da aplicação (Cache de Nível 1 / L1).

Essa topologia de **Cache Híbrido** gera um problema grave de consistência de dados. Quando a réplica Node A do microsserviço grava ou atualiza um registro no banco de dados centralizado e no cache L2, as outras 50 réplicas ativas da aplicação que estão rodando em paralelo não percebem a mudança e continuam servindo dados obsoletos (stale data) a partir de seus caches L1 locais.

A solução clássica de arquitetura distribuída para este problema é a **Invalidação Ativa via Pub/Sub**. Sempre que um nó atualiza um registro, ele publica uma notificação rápida contendo o ID da chave modificada em um canal Pub/Sub centralizado (geralmente via Redis Pub/Sub, NATS ou Kafka). Todas as outras réplicas inscritas nesse canal recebem a mensagem e excluem imediatamente a chave correspondente de seus caches L1 locais (Pattern: *Active Cache Invalidation*).

No entanto, essa abordagem está sujeita a uma **condição de corrida (Race Condition)** sutil, mas comum:
1. O Node B sofre um *cache miss* para a chave `user:123` e dispara uma consulta ao banco de dados, recebendo o valor antigo (Versão 1).
2. Paralelamente, o Node A atualiza a chave no banco para o valor novo (Versão 2) e dispara um evento de invalidação da chave `user:123` via Pub/Sub.
3. O Node B recebe a mensagem de invalidação do Pub/Sub e limpa o cache L1.
4. Por fim, a thread de leitura lenta do Node B conclui a operação do passo 1 e grava o valor antigo (Versão 1) no cache L1 local.
5. O Node B agora ficará com o **dado antigo e obsoleto gravado permanentemente no L1**, pois a invalidação que deveria limpá-lo já passou e ocorreu antes da escrita física no cache local.

O objetivo deste desafio é projetar uma arquitetura de cache híbrido que resolva essa condição de corrida e garanta consistência sob concorrência agressiva de leitura e escrita.

---

## 2. Requisitos Funcionais (RF)
- **Obter Dado (`Get`)**: Buscar a chave no cache L1 local. Se for um *cache miss*, buscar no L2 (Redis) ou banco de dados final, popular o L1 e retornar o valor.
- **Gravar/Atualizar Dado (`Put`)**: Atualizar o registro na base de dados centralizada/L2 e publicar um evento de invalidação com a chave alterada no barramento Pub/Sub.
- **Tratador de Invalidação (`OnInvalidationReceived`)**: Ouvir as mensagens do Pub/Sub e limpar imediatamente as chaves correspondentes do L1 local da réplica.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Prevenção de Corrida de Invalidação**: O cache deve garantir que dados obsoletos antigos lidos concorrentemente nunca sobrescrevam atualizações ou invalidações recentes ocorridas durante a viagem de ida e volta da consulta ao banco.
- **Proteção Contra Cache Stampede / Thundering Herd**: Se uma chave altamente quente (hot key) for invalidada, o sistema deve impedir que centenas de threads de leitura simultâneas no mesmo pod disparem consultas paralelas ao banco de dados. Apenas uma thread deve consultar a base (ex: usando o padrão Singleflight) enquanto as outras aguardam o resultado de forma coordenada.
- **Resiliência a Falhas do Canal de Invalidação**: Se a conexão com o broker Pub/Sub cair temporariamente, o sistema deve detectar a desconexão e invalidar preventivamente todo o L1 (ou encurtar drasticamente o TTL de chaves locais) para evitar servir dados obsoletos às cegas.

---

## 4. Guia de Implementação & Padrões

A topologia e coordenação de invalidação entre múltiplos nós de microsserviço são mapeadas a seguir:

```
 Node A (Escritor)                             Node B (Leitor)
 ┌───────────────┐                            ┌───────────────┐
 │   Cache L1    │                            │   Cache L1    │ (Lê obsoleto)
 └──────┬────────┘                            └──────┬────────┘
        │ (Escreve)                                  ▲ (3. Recebe e limpa)
        ▼                                            │
 ┌───────────────┐      2. Notificação        ┌──────┴────────┐
 │   Cache L2    ├───────────────────────────►│ Canal Pub/Sub │
 │    Redis      │       Invalidação          │     Redis     │
 └───────────────┘                            └───────────────┘
```

### Padrões e Algoritmos Recomendados:
- **Rastreamento de Versão ou Timestamp de Leitura (Lease Caching / Invalidation Checkpoints)**: Para neutralizar a condição de corrida de invalidação descrita, ao iniciar uma consulta ao banco/L2 em caso de cache miss, a thread deve associar um timestamp de início ou número de versão. Ao tentar gravar o valor de retorno no L1 local, verificar se ocorreu alguma invalidação para a chave posterior ao início da leitura. Caso tenha ocorrido, descartar a gravação no L1 local e forçar a releitura imediata.
- **Redis Client-Side Caching (Tracking Mode)**: Utilizar o protocolo RESP3 do Redis, que fornece suporte nativo a invalidações do lado do cliente (Client-Side Caching). O Redis rastreia quais chaves o cliente leu e envia mensagens automáticas de invalidação (`invalidate`) de forma transparente pela mesma conexão ou canal dedicado.
- **Lock-Free Cache Invalidation Checkpoint**: Manter uma estrutura thread-safe na memória local (`ConcurrentDictionary<string, long>`) para registrar o timestamp da última invalidação de chaves quentes recentes, servindo como barreira de validação para as escritas de retorno de cache miss.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prova de Código de Resolução de Corrida de Cache**: Demonstração explícita de como o código impede a gravação de dados antigos no L1 após a chegada de uma notificação de invalidação recente durante o ciclo de leitura de fundo.
- **Comportamento em Falha de Conexão (Degradação Suave)**: Mecanismo claro que monitora o estado da conexão do Pub/Sub. Se o canal cair por mais de X segundos, disparar um evento que limpa a memória RAM do pod (`L1.Clear()`) e define o TTL máximo de novos itens locais para 0 segundos (bypass temporário de L1, consultando apenas L2 e banco) até que a saúde do Pub/Sub seja reestabelecida.
- **Acoplamento do Padrão Singleflight**: Utilizar colapso de chamadas na saída do cache miss para evitar derrubar a base de dados downstream sob cargas pesadas imediatas após a invalidação de chaves globais.

---

## 6. Trade-offs

### A. Invalidação Ativa via Pub/Sub vs. TTL Curto Passivo (Time-To-Live)
- **Invalidação Ativa via Pub/Sub (Recomendado para este desafio)**: Consistência quase em tempo real (< 100 ms para sincronizar todas as réplicas) e ótimo aproveitamento do cache local que pode ter TTL longo.
  - *Contra*: Complexidade extrema de desenvolvimento, introdução de race conditions e dependência operacional de um broker Pub/Sub de alta disponibilidade.
- **TTL Curto Passivo (ex: L1 com TTL fixo de 2 segundos)**: Simplicidade absoluta de código. Não há race conditions de escrita e dispensa broker Pub/Sub.
  - *Contra*: O sistema aceita servir dados obsoletos por até 2 segundos. Se houver alto volume de atualizações, as leituras ao L2 continuam frequentes devido ao curto tempo de vida dos itens na memória.

### B. Invalidação (Evicção) vs. Atualização de Valor (Push-Update) no Evento Pub/Sub
- **Invalidação (Evicção - Recomendado)**: O evento Pub/Sub transmite apenas a chave modificada. O nó receptor simplesmente deleta a chave de seu L1.
  - *Pró*: Baixo consumo de banda de rede (payloads minúsculos) e evita carregar a memória RAM local de pods com dados frios que talvez nunca sejam lidos naquele nó específico.
- **Push-Update (Envio do valor novo no Pub/Sub)**: O evento transmite a chave e o novo payload de dados completo, gravando o valor atualizado direto no L1.
  - *Pró*: O L1 está sempre quente e atualizado (zero cache miss nas leituras subsequentes).
  - *Contra*: Desperdício massivo de banda e memória RAM local em pods que não precisam daquele dado, além do risco de race conditions duplicadas de ordenação física de payloads de escrita na rede.
