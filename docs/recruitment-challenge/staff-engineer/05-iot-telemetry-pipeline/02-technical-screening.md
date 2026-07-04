# 🖥️ Trilha 5 - Etapa 2: Technical Screening (Phone Screen)

* **Responsável:** Senior/Staff Software Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Conceitos de sistemas de mensageria distribuídos, formatos de arquivos colunares, compressão e processamento em fluxo.

---

## 💬 Q&A - Fundamentos de Engenharia de Dados (20 min)

### Tópico A: Particionamento e Ordenação no Kafka
* **Pergunta:** "Se recebemos eventos de telemetria de 1M de sensores industriais e precisamos garantir a ordem exata de processamento dos eventos de cada sensor individualmente, como você definiria a partição e as chaves no Kafka? O que acontece durante um rebalanceamento de partições do grupo de consumidores?"
* **Esperado:**
  * Uso do ID do sensor como chave de partição para garantir que todos os eventos do mesmo sensor caiam na mesma partição (ordenação estrita por partição).
  * Discussão de travamentos temporários de leitura e duplicação potencial de eventos (at-least-once) durante o rebalanceamento.

### Tópico B: Armazenamento Analítico Colunar vs. Linha
* **Pergunta:** "Por que formatos de arquivos colunares como Parquet, ORC ou tabelas Apache Iceberg são ideais para consultas analíticas de agregação (ex.: média de temperatura semanal), enquanto são péssimos para atualizações frequentes registro a registro?"
* **Esperado:**
  * Armazenamento colunar permite ler apenas as colunas necessárias da consulta da memória/disco (eliminando I/O inútil).
  * Compactação eficiente do mesmo tipo de dado na coluna.
  * Modificações registro a registro em arquivos Parquet (imutáveis por design) exigem a reescrita completa do arquivo inteiro, gerando altíssimo custo de gravação.

---

## 🛠️ Mini-Desafio: Filtro de Backpressure Concorrente (30 min)

### Cenário:
> *"Escreva um wrapper concorrente thread-safe que receba eventos de dados e os empurre para uma fila interna limitada. Se a fila interna estiver cheia (devido ao processamento lento do consumidor), o wrapper deve rejeitar novos eventos imediatamente (estratégia de descarte rápido - fail-fast) ou aplicar um bloqueio temporário por timeout para evitar o estouro de memória (Out-Of-Memory) do sistema."*

### Habilidades avaliadas:
* Controle preciso de semáforos, canais bloqueantes e timeouts (`select` com `time.After` em Go, ou `BlockingQueue.offer` com timeout em Java).

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
