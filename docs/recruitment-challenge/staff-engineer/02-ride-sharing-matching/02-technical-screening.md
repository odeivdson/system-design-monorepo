# 🖥️ Trilha 2 - Etapa 2: Technical Screening (Phone Screen)

* **Responsável:** Senior Engineer / Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Indexação espacial, comunicação bidirecional de baixa latência e consumo de eventos em memória.

---

## 💬 Q&A - Fundamentos de Sistemas Geoespaciais (20 min)

### Tópico A: Indexação Espacial (H3 vs S2 vs Geohash)
* **Pergunta:** "Se precisamos localizar rapidamente os 10 motoristas mais próximos de um passageiro em São Paulo, por que usar um banco de dados relacional clássico com queries de raio ($x^2 + y^2$) é ineficiente? Qual a diferença conceitual entre indexação por grid hexagonal (H3 da Uber) e grid quadrático (S2 do Google)?"
* **Esperado:** 
  * Explicação de que queries espaciais brutas exigem varredura completa da tabela (Table Scan) a menos que indexadas.
  * H3 usa hexágonos (excelente para cálculos de vizinhos com distância constante entre centros).
  * S2 usa quad-trees baseados em projeção cúbica (ótimo para agrupamento hierárquico).

### Tópico B: Comunicação Bidirecional de Localização
* **Pergunta:** "Os motoristas enviam suas coordenadas GPS a cada 4 segundos. Que protocolo de transporte você escolheria para essa ingestão em massa e por quê? (gRPC sobre HTTP/2, WebSockets, HTTP/1.1 bruto)?"
* **Esperado:** Discussão de overhead de conexão, gRPC streaming bidirecional para eficiência de cabeçalhos ou WebSockets para persistência leve.

---

## 🛠️ Mini-Desafio: Agrupador de Coordenadas (Geohash Aggregator) (30 min)

### Cenário:
> *"Escreva uma função que receba um stream contínuo de atualizações de motoristas (ID, latitude, longitude) e agrupe o número de motoristas ativos por células H3 de resolução 8 em tempo real. O sistema deve reter esses dados em memória para fornecer uma API HTTP que retorna o mapa térmico de oferta da cidade."*

### Habilidades avaliadas:
* Uso correto de estruturas de mapa concorrentes (`sync.Map` em Go ou `ConcurrentHashMap` em Java).
* Consciência de vazamento de memória (Memory Leak) ao lidar com motoristas que ficam offline (necessidade de expiração de dados - TTL).

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
