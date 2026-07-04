# 🖥️ Trilha 4 - Etapa 2: Technical Screening (Phone Screen)

* **Responsável:** Senior/Staff Software Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Consistência eventual, protocolos WebSockets vs. SSE, ordenação lógica de eventos e vetores de relógio (Vector Clocks).

---

## 💬 Q&A - Fundamentos de Sistemas Colaborativos (20 min)

### Tópico A: Ordenação de Eventos e Tempo Lógico
* **Pergunta:** "Em um editor colaborativo global, por que usar timestamps físicos de servidores para ordenar as edições dos usuários é perigoso? O que são Lamport Clocks e Vector Clocks e como eles ajudam a estabelecer causalidade em sistemas distribuídos sem depender de relógios sincronizados?"
* **Esperado:**
  * Desvio de relógio (Clock Skew) impede a confiança absoluta em timestamps de máquinas diferentes.
  * Relógios lógicos de Lamport fornecem ordenação causal simples ($A$ aconteceu antes de $B$).
  * Vetores de relógio identificam concorrência real e ajudam a detectar conflitos de escrita.

### Tópico B: Comunicação em Tempo Real na Web
* **Pergunta:** "Para enviar pequenas deltas de edições continuamente para os clientes no navegador, você escolheria WebSockets ou Server-Sent Events (SSE)? Quais os prós e contras operacionais de cada um em termos de gerenciamento de conexões e reconexão em redes instáveis?"
* **Esperado:**
  * WebSockets: bidirecional, melhor para escrita/leitura frequentes, mas mais complexo de balancear e manter em gateways.
  * SSE: unidirecional (servidor -> cliente), HTTP puro, reconexão automática nativa, necessita de requisições POST avulsas para escrita do cliente.

---

## 🛠️ Mini-Desafio: Merge Conceitual de LWW (Last-Write-Wins-Register) (30 min)

### Cenário:
> *"Implemente uma função que simule um registrador LWW-Register. A função deve fundir (merge) de forma atômica e thread-safe dois estados de um registrador contendo um valor (string) e um timestamp lógico de alteração. O registrador com o maior timestamp lógico deve vencer. Em caso de empate exato do timestamp lógico, utilize uma regra determinística secundária baseada na ordenação lexicográfica do ID do autor da alteração."*

### Habilidades avaliadas:
* Garantia de determinismo matemático (essencial para convergência em sistemas P2P/CRDT).
* Uso correto de tipos concorrentes e proteção de memória.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
