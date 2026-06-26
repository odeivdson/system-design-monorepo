# Desafio 22: Proxy Sidecar de Malha de Serviços (`service-mesh-sidecar-proxy`)
> **Padrões de Microsserviços Associados:** Sidecar (Desacoplamento de Infraestrutura), Service Registry (Descoberta Dinâmica), Consumer-Driven Contracts (Garantia de Acordo), Shadow Deployment (Teste de Tráfego Real).

## 1. Contexto & Cenário
À medida que uma organização migra de uma arquitetura monolítica para dezenas de microsserviços, surge um problema crítico: a gestão uniforme da comunicação de rede. Cada serviço precisa gerenciar segurança (TLS/mTLS), roteamento de requisições, retentativas com backoff, circuit breaking, monitoramento de métricas e rastreamento distribuído.

Se implementarmos essa lógica diretamente no código dos microsserviços usando bibliotecas/SDKs específicas (como Spring Cloud para Java ou Polly para C#), criamos sérios problemas:
- **Poliglotismo Bloqueado**: Obriga todos os times a usarem a mesma stack tecnológica ou a reimplementarem as mesmas bibliotecas complexas em Node.js, Go, Python, C#, etc.
- **Acoplamento de Infraestrutura**: Atualizar a política de TLS ou o tempo de timeout exige recompilar e implantar todos os microsserviços do ecossistema.

Para resolver este acoplamento, utilizamos o padrão **Sidecar**. Executamos um proxy leve (como Envoy ou Linkerd) em um container/processo anexo, rodando na mesma rede local (`localhost`) do container da aplicação principal. Toda entrada e saída de tráfego de rede da aplicação é interceptada e gerenciada pelo Sidecar. O Sidecar realiza consultas dinâmicas no **Service Registry**, valida se o payload atende ao **Consumer-Driven Contract** pactuado e pode até clonar o tráfego de escrita em background para validar novas versões (**Shadow Deployment**).

---

## 2. Requisitos Funcionais (RF)
- **Interceptação Outbound**: Interceptar requisições HTTP enviadas pela aplicação local (ex: chamada para `http://payment-service/charge`).
- **Descoberta Dinâmica de Serviços (Service Discovery)**:
  - O proxy Sidecar deve consultar periodicamente um registro central (**Service Registry**) para traduzir o nome do serviço (`payment-service`) em uma lista de IPs reais e portas ativas.
  - Executar balanceamento de carga local (ex: Round Robin ou Least Connections) nos IPs resolvidos.
- **Validação de Contrato de Consumidor (Contract Verification)**:
  - Validar a estrutura do payload JSON de saída da aplicação contra o arquivo de contrato (JSON Schema) do serviço de destino antes de enviar a requisição física sobre a rede. Se violado, bloquear e alertar.
- **Espelhamento de Tráfego (Shadow Routing)**:
  - Duplicar uma porcentagem parametrizada do tráfego de leitura de produção (ex: 10% das requisições) e enviá-las para uma instância experimental paralela (Shadow Service), descartando a resposta do shadow de forma assíncrona.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead Temporal Sub-Milissegundo**: Como o Sidecar intercepta cada salto de rede, o processamento interno do proxy (parsing de cabeçalhos, checagem de contratos, roteamento) deve ser inferior a 1ms no P99.
- **Consumo de Memória Extremamente Baixo**: O agente Sidecar deve possuir um footprint de memória RAM mínimo (sub-30MB) para viabilizar sua implantação em milhares de pods sem encarecer a infraestrutura de clusters Kubernetes.
- **Isobariedade de Rede (Loopback Isolation)**: A comunicação entre o contêiner da aplicação e o Sidecar via Loopback Local (`localhost`) não deve passar por firewalls de rede externos ou placas físicas, utilizando preferencialmente Unix Domain Sockets (UDS) para latência quase zero.

---

## 4. Guia de Implementação & Padrões

### Arquitetura de Comunicação via Sidecar Proxy
```
┌────────────────────────────────────────────────────────┐
│                        Pod Local                       │
│                                                        │
│  ┌─────────────────────────┐                           │
│  │  Application Container  │                           │
│  └────────────┬────────────┘                           │
│               │ (Outbound HTTP via localhost/UDS)      │
│               ▼                                        │
│  ┌─────────────────────────┐      (Queries)            │
│  │   Sidecar Proxy Agent   │────────────────────────┐  │
│  └────────────┬────────────┘                        │  │
└───────────────┼─────────────────────────────────────┼──┘
                │                                     │
       (Roteia Requisições)                           ▼
                │                          ┌──────────────────┐
                ├─────────────────────────►│ Service Registry │
                │                          └──────────────────┘
                ├─────────────────────────┐
                ▼ (Prod Traffic)          ▼ (Shadow Traffic 10%)
       ┌──────────────────┐      ┌──────────────────┐
       │ Payment-Service  │      │ Payment-Shadow   │
       │     (Prod)       │      │  (Experimental)  │
       └──────────────────┘      └──────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Redirecionamento de Tráfego via iptables**: O Sidecar ou script de inicialização do pod configura regras de firewall locais (`iptables` / `ip route`) para interceptar automaticamente e redirecionar todo o tráfego TCP destinado a portas externas para a porta local de escuta do Proxy, tornando a interceptação totalmente transparente para o código da aplicação.
- **Unix Domain Sockets (UDS)**: Para comunicação ultrarrápida entre a aplicação e o Sidecar na mesma máquina, configurar a troca de pacotes HTTP sobre soquetes Unix em vez de usar a pilha TCP/IP padrão (localhost:port), eliminando o overhead de checksums TCP e encapsulamento de pacotes IP.
- **Asynchronous Shadow Processing**: O envio de tráfego Shadow deve rodar em uma thread/tarefa em background de forma totalmente desacoplada da thread principal. A resposta do serviço Shadow deve ser imediatamente descartada e qualquer erro de timeout ou conexão dele não pode interferir no ciclo de vida da requisição real.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Latência de Interceptação Controlada**: Logs e testes comparativos mostrando que `App -> Downstream` tem latência quase idêntica a `App -> Sidecar -> Downstream` (overhead P99 < 1.5ms).
- **Consistência do Shadow Routing**: Teste funcional comprovando o espelhamento exato do payload da requisição de produção para o destino shadow, garantindo que o tempo de resposta percebido pela aplicação principal não seja alterado pelo shadow.
- **Verificação de Contrato na Borda**: O Sidecar deve interceptar um payload inválido de saída (ex: faltando campo obrigatório) e retornar um código HTTP `400 Bad Request` localmente, impedindo a requisição malformada de atravessar a rede física e sobrecarregar o microsserviço de destino.

---

## 6. Trade-offs

### A. Sidecar Proxy vs. SDK Compartilhado (Client Libraries)
- **Sidecar Proxy (Recomendado para ecossistemas grandes/poliglotas)**:
  - *Pró*: Independência total de linguagem; upgrades de infraestrutura centralizados; simplificação drástica do código da aplicação.
  - *Contra*: Complexidade operacional adicional de deployment; aumento do consumo total de memória do cluster; insere dois saltos de rede adicionais locais por requisição (latência de ~1ms).
- **SDK Compartilhado (Recomendado para times mono-stack)**:
  - *Pró*: Latência zero de interceptação de rede; consumo mínimo de CPU/RAM.
  - *Contra*: Bloqueia a diversificação tecnológica; pesadelo operacional para atualizar versões do SDK em dezenas de repositórios.

### B. Shadow Routing em Camada de Proxy (Sidecar) vs. Camada de Aplicação
- **Shadow Routing no Proxy (Sidecar)**:
  - *Pró*: O código da aplicação principal fica 100% livre de lógica experimental e paralelismo.
  - *Contra*: O proxy consome mais CPU e recursos de rede para duplicar bytes e lidar com o descarte assíncrono.
- **Shadow Routing na Aplicação**:
  - *Pró*: Permite maior controle granular de dados de teste (ex: injetar flags específicas no payload).
  - *Contra*: Suja o código produtivo com lógica de infraestrutura e corre o risco de vazamentos de memória (memory leaks) se as tarefas paralelas shadow não forem controladas.
