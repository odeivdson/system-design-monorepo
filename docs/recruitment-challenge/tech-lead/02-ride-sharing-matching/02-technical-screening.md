# 🖥️ Tech Lead - Trilha 2 - Etapa 2: Technical Screening

* **Responsável:** Senior/Staff Software Engineer
* **Duração:** 60 minutos
* **Foco:** Indexação espacial básica, APIs de atualização em lote, observabilidade e noções de paralelismo.

---

## 💬 Q&A - Fundamentos Geoespaciais e Comunicação (20 min)

### Tópico A: Indexação Geoespacial e Consultas Rápidas
* **Pergunta:** "Se o time precisa listar motoristas ativos perto de um passageiro em um mapa, quais seriam as limitações de usar apenas indexação clássica de banco relacional? Como ferramentas como Geohash ou grids simplificados ajudam?"
* **Esperado:** 
  * Explicação de que Geohashes dividem o mapa em strings, permitindo indexação por prefixos rápidos (B-Tree convencional).
  * Conhecimento das vantagens operacionais de ter um índice espacial para poupar leituras de disco.

### Tópico B: Comunicação em Tempo Real
* **Pergunta:** "Para atualizar a localização dos motoristas no painel da central de operações da equipe, quais os prós e contras de usar HTTP Polling curto (ex.: a cada 3s) vs. manter uma conexão WebSocket?"
* **Esperado:** 
  * Polling: simples de implementar e cachear, mas gera I/O e carga excessiva nos servidores do time.
  * WebSocket: conexão persistente eficiente em banda, mas exige infraestrutura para gerenciar conexões ativas.

---

## 🛠️ Mini-Desafio: Design de Schema e API Geoespacial (30 min)
* **Cenário:** Desenhe um endpoint HTTP que recebe as coordenadas de um motorista (latitude, longitude, status) e descreva como modelaria a tabela correspondente em banco de dados para consulta por proximidade.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
