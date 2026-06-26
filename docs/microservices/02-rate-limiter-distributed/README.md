# Desafio 2: Limitador de Taxa Distribuído com Redis (`rate-limiter-distributed`)
> **Padrões de Microsserviços Associados:** API Gateway (Policiamento de Borda), Stateless Services (Escalabilidade Horizontal), Rate Limiting (Distribuído).

## 1. Contexto & Cenário
Quando uma arquitetura de microsserviços cresce e passa a ser servida por múltiplos servidores sob um balanceador de carga, o limitador de taxa em memória local ([1-rate-limiter-local](../../microservices/01-rate-limiter-local/README.md)) deixa de ser suficiente para gerenciar limites globais. Por exemplo, se o plano de um cliente Premium limita sua conta a 100 requisições por minuto e ele realiza requisições paralelas distribuídas uniformemente sobre 10 instâncias do API Gateway, um limitador local isolado permitiria que ele realizasse até 1.000 requisições por minuto (100 por instância).

Para garantir o cumprimento exato de cotas comerciais e evitar ataques de negação de serviço (DDoS) distribuídos, é fundamental que o estado de consumo de tokens seja compartilhado globalmente. O objetivo deste desafio é projetar e implementar um limitador de taxas distribuído de altíssima performance utilizando **Redis** como o store compartilhado de baixa latência, garantindo consistência e atomicidade mesmo sob forte concorrência global.

---

## 2. Requisitos Funcionais (RF)
- **Consumo de Tokens Global**: Validar se uma chave (ex: IP, Tenant ID ou Token de API) possui saldo de tokens global para prosseguir.
- **Janela de Tempo Configurável**: Suportar políticas flexíveis (ex: 50 requisições por segundo, ou 10.000 por hora).
- **Lazy Replenishment Distribuído**: A recarga dos tokens na base compartilhada deve ocorrer de forma passiva nas requisições, evitando processos batch/cron em background que asfixiem o banco de dados.
- **Respostas de Headers HTTP Padrão**: Injetar cabeçalhos de resposta HTTP padrão da indústria para orientar clientes legítimos:
  - `X-RateLimit-Limit`: O total máximo de requisições permitidas na janela.
  - `X-RateLimit-Remaining`: A quantidade de requisições restantes permitidas nesta janela.
  - `X-RateLimit-Reset`: O timestamp Epoch Unix indicando quando a janela é restaurada.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead de Rede Mínimo**: A latência adicional introduzida no API Gateway pela validação com Redis deve ser sub-2ms no P95 e sub-5ms no P99.
- **Operações Atômicas de Rede**: Impedir condições de corrida clássicas (Double-Spends) onde duas requisições paralelas reduzem o saldo para valores negativos. As verificações e reduções devem ser em lote atômico (Read-and-Update de uma única viagem de rede).
- **Alta Resiliência (Fail-Open vs. Fail-Closed com Fallback)**:
  - Se o cluster Redis sofrer um split de rede ou ficar temporariamente inacessível, o limitador deve ter um fallback gracefully (ex: rebaixar temporariamente para limitação local ou liberar tráfego sob alerta, dependendo do perfil de segurança da API).
- **Eficiência de Conexão com Redis**: Uso de pool de conexões otimizado e pipelines de escrita para evitar consumo excessivo de sockets no Gateway.

---

## 4. Guia de Implementação & Padrões
A arquitetura do limitador reside em um middleware acoplado ao API Gateway, consultando de forma síncrona um cluster de cache distribuído em memória.

```
       [ Cliente ]
            │
            ▼ (HTTP Request)
┌───────────────────────────────────────────────┐
│            API Gateway / Reverse Proxy        │
│                                               │
│  1. Extrai Chave (IP/Token)                   │
│  2. Invoca Script Lua no Redis (Atomic Match) │
└──────────────────────┬────────────────────────┘
                       │
             (Atomic Check & Decr)
                       │
                       ▼
┌───────────────────────────────────────────────┐
│               Redis Cluster                   │
│                                               │
│  - Executa Script Lua (Token/Sliding Window)   │
│  - Retorna: (Permitido? (0/1), Saldo, Reset)  │
└──────────────────────┬────────────────────────┘
                       │
            (Retorna resposta HTTP)
                       ▼
    [ HTTP 200 Ok ] ou [ HTTP 429 Too Many Requests ]
```

### Padrões e Primitivas Recomendadas:
- **Scripts Lua (Atomicidade Single-Threaded do Redis)**: Para evitar race conditions comuns de leitura-modificação-escrita (`GET` seguido de `SET`), toda a lógica do limitador (ex: Sliding Window Log ou Token Bucket) deve ser encapsulada em um script Lua executado nativamente no Redis via `EVALSHA`. O Redis garante execução atômica exclusiva do script por chave de hash.
- **Algoritmo de Janela Deslizante (Sliding Window Counter)**: Combina economia de espaço e precisão eliminando o estouro de borda comum do algoritmo de Janela Fixa (Fixed Window). Utiliza blocos lógicos ou hashes Redis (`HSET` / `HGETALL`) contendo carimbos temporais parciais.
- **Failover Local (Graceful Fallback)**:
  - Adotar uma abordagem híbrida: em caso de erro de conexão com o Redis, o Gateway ativa temporariamente um limitador local na máquina para blindar o microsserviço downstream, e dispara alarmes de monitoramento estruturado.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Zero Vazamento de Tokens em Concorrência Paralela Distribuída**: Validação estrutural sob testes de estresse em lote simulando 10 instâncias chamando a mesma chave paralelamente com saldo igual a 1. Apenas 1 requisição deve ser permitida.
- **Scripts Lua Pré-Compilados e Otimizados**: Uso de `EVALSHA` para evitar o envio repetido de strings longas de código Lua sobre a rede, minimizando o parsing de CPU do Redis.
- **Tratamento Adequado de Timeouts**: Configuração estrita de timeouts de conexão com o Redis (ex: max 15ms). O limitador não pode se tornar o gargalo de indisponibilidade da própria API.
- **Gestão de Sockets**: Uso de conexões multiplexadas ou pooling adequado (ex: StackExchange.Redis em C# ou Jedis em Java) para evitar esgotamento de conexões TCP do sistema operacional (port exhaustion).

---

## 6. Trade-offs

### A. Fail-Open vs. Fail-Closed
- **Fail-Open (Mais Comum para APIs de Consumo Geral)**: Se o Redis cair, liberamos o tráfego sem limitar.
  - *Pró*: Prioriza a experiência do usuário e mantém o sistema de pé caso o cache falhe.
  - *Contra*: Abre brechas temporárias para sobrecarga e DDoS nos microsserviços downstream.
- **Fail-Closed (Necessário para APIs Críticas/Faturamento)**: Se o Redis cair, barramos as requisições HTTP retornando status indicativo de erro interno ou indisponibilidade (`503 Service Unavailable`).
  - *Pró*: Segurança financeira e proteção absoluta do banco de dados relacional downstream.
  - *Contra*: O Redis se torna um Ponto Único de Falha (SPOF) catastrófico do sistema.

### B. Fixed Window vs. Token Bucket vs. Sliding Window Counter
- **Janela Fixa (Fixed Window)**: Simples de implementar no Redis (um `INCR` com `EXPIRE`), mas permite o dobro do tráfego permitido no limiar de transição das janelas (efeito burst).
- **Token Bucket Distribuído**: Preciso e robusto, mas requer o armazenamento de múltiplos valores por usuário (timestamp e tokens atuais), aumentando o custo de memória RAM por chave do Redis.
- **Sliding Window Counter (Recomendado)**: Oferece excelente equilíbrio entre precisão contra bursts e consumo moderado de memória, usando contadores baseados na janela anterior e atual.