# 🖥️ Dev Senior - Trilha 4 - Etapa 2: Technical Screening

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Concorrência, mecanismos de buffering em memória, conceitos de Sharding e noções de durabilidade de dados.

---

## 💬 Q&A - Fundamentos de Engenharia de Escrita (25 min)

### Tópico A: Buffering & Batching em Memória
* **Pergunta:** "Ao receber um volume maciço de escritas (ex.: cliques ou telemetria), por que é mais vantajoso acumular os eventos na memória RAM e fazer gravações em lote (*batch*) no banco de dados NoSQL do que salvar cada evento individualmente de forma síncrona? Quais os trade-offs de durabilidade envolvidos se o servidor cair fisicamente?"
* **Esperado:** 
  * Economia em I/O de rede e de disco (fazer 1 request contendo 1000 registros é muito mais rápido do que fazer 1000 requests individuais).
  * Redução do overhead de conexões e locks no banco de dados.
  * **Trade-off de Durabilidade:** Perda de dados voláteis acumulados na RAM se a máquina sofrer pane antes do flush/descarga para o disco (eventual consistency / trade-off de durabilidade).

### Tópico B: Escolha de Chaves de Particionamento (Sharding & Hotspots)
* **Pergunta:** "O que é sharding (particionamento horizontal) no banco de dados? Se você estiver modelando um banco de dados NoSQL distribuído para salvar leituras de sensores industriais e escolher a chave de partição (`Partition Key`) como a coluna `data_registro` (com granularidade de dia), qual o problema técnico grave que ocorrerá sob alto tráfego contínuo?"
* **Esperado:**
  * Sharding divide e distribui as linhas de uma tabela fisicamente entre múltiplos servidores com base em uma chave.
  * Escolher `data_registro` (por dia, ex: `2026-07-04`) cria um **Hotspot (Hot Shard)**. Como todas as gravações do dia de hoje vão possuir a mesma partição, 100% das escritas do pipeline atingirão um único nó do cluster NoSQL em paralelo, deixando os outros nós ociosos.
  * Solução: Escolher uma chave mais distribuída (ex.: `id_sensor` ou uma combinação composta de `id_sensor + timestamp_hora`).

---

## 🛠️ Mini-Desafio: Design de Ingestão Resiliente (35 min)
* **Cenário:** O candidato deve esboçar verbalmente ou desenhar na lousa um pseudocódigo básico de uma classe `TelemetryBuffer` que:
  1. Aceita eventos de telemetria através do método `add(Event event)`.
  2. Acumula os eventos em uma lista thread-safe local.
  3. Dispara uma thread de descarga (`flush`) quando o buffer atinge 500 itens ou a cada 2 segundos.
* **Rubrica de Avaliação:**
  * O candidato usou locks corretos para proteger a lista local de acessos concorrentes em paralelo?
  * Ele garantiu que a thread de descarga não bloqueie as requisições de entrada de novos dados por muito tempo? (Uso de técnicas de cópia rápida ou troca de referência do buffer para a descarga ocorrer em background).

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
