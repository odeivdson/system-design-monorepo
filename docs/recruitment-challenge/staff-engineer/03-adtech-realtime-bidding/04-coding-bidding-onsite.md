# 💻 Trilha 3 - Etapa 4: Coding Onsite - Motor de Seleção de Lances Ultrarápido

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Concorrência sem locks (lock-free), uso otimizado de estruturas de dados na CPU e estruturas de decisão ultrarápidas.

---

## 🎯 O Enunciado do Desafio

Dentro do motor de leilão, quando chega uma requisição de bid para um usuário, o sistema precisa filtrar centenas de campanhas de anúncios disponíveis e selecionar a de maior valor que ainda possua saldo de orçamento e cujos critérios de segmentação combinem com o usuário.

O candidato deve implementar um **Selecionador de Campanhas** concorrente de baixíssima latência.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve implementar a classe/estrutura `CampaignMatcher` com os seguintes requisitos:

### 1. Modelo de Dados e Filtro Rápido
* Cada campanha tem: ID, Valor do Bid (CPM), Segmentos Alvo (Bitmask) e Saldo Local (representado por um contador de tokens de orçamento).
* O método `MatchBestCampaign(userSegments uint64) (string, float64)` deve percorrer o conjunto de campanhas ativas em memória de forma eficiente, validar a correspondência binária de segmentos usando operações bitwise e retornar a melhor campanha (maior CPM) que possua saldo.

### 2. Consumo de Orçamento Lock-Free ou de Baixa Contenção
* O saldo local de tokens de orçamento deve ser debitado a cada bid vencedor de forma concorrente.
* Como esse método será chamado por centenas de threads simultaneamente, o candidato deve evitar locks pesados e usar operações atômicas baseadas na CPU (ex.: `sync/atomic` em Go ou `AtomicLong` em Java) para decrementar o orçamento das campanhas elegíveis.

---

## ⚖️ Rubrica de Avaliação de Código

| Nível | Indicadores Práticos no Desafio |
| :--- | :--- |
| 🟥 **Reprovado** | Usa strings ou regex para validação de segmentos, comprometendo gravemente o tempo de processamento; usa loops aninhados ineficientes com locks globais na coleção de campanhas. |
| 🟨 **Senior (L5)** | Implementa a filtragem rápida usando operações bitwise corretas. Protege os contadores de orçamento com Mutexes de grão fino por campanha. |
| 🟩 **Staff (L6+)** | Utiliza primitivas de hardware atômicas baseadas em CPU (Compare-And-Swap - CAS) para decrementar orçamentos de forma totalmente livre de locks (*lock-free*). Explica a estrutura de cache lines da CPU e como evitar problemas de falsos compartilhamentos (*false sharing*) sob concorrência intensa. |

---

[Ir para a Etapa 5: Leadership & Systemic Impact ](./05-leadership-systemic-impact.md)
