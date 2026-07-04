# 👥 Dev Senior - Trilha 4 - Etapa 5: Behavioral & Teamwork Onsite

* **Responsável:** Diretor de Engenharia & Senior Engineer
* **Duração:** 60 minutos
* **Foco:** Mentoria técnica individual, mediação de discussões de design em grupo e adaptabilidade cultural em equipe.

---

## 🗺️ Cenários Práticos de Trabalho em Equipe

### Cenário 1: Desarmando Overengineering (Mentoria de Pleno/Júnior)
> *"Um desenvolvedor pleno da sua equipe está ansioso para utilizar uma arquitetura baseada em filas e eventos assíncronos para resolver uma funcionalidade onde o painel administrativo do cliente precisa buscar e exibir o total consolidado de cliques de um anúncio em tempo real na tela. O fluxo que ele propõe exige que a chamada de consulta ao endpoint HTTP `/anuncios/{id}/stats` empilhe uma mensagem em uma fila e aguarde o retorno assíncrono do processador na tela. Como você o ajuda a ver os problemas e a simplificar o design?"*

* **Respostas Esperadas do Candidato:**
  * **Comunicação Pedagógica:** Mostrar que filas são projetadas para processamento assíncrono desacoplado de escrita, e não para caminhos de leitura síncrona onde o usuário final aguarda ativamente a resposta na tela.
  * **Sugestão de Solução Simples (KISS):** Mostrar que uma consulta direta ao banco de dados com índice correto ou a leitura de uma contagem cacheada pré-agregada atende ao requisito com fração da complexidade.
  * **Trabalho em Par:** Parear com ele para desenhar um fluxo síncrono simples de leitura e deixar a arquitetura de filas para o pipeline de processamento de cliques em background.

### Cenário 2: Mediação de Decisão Arquitetural (Escolha de Shard Keys)
> *"O time está dividido sobre qual Partition Key escolher para a tabela de logs NoSQL. Duas propostas estão empatadas: a primeira defende usar `timestamp` (para buscas rápidas por data), e a segunda defende usar `id_cliente` (para agrupar logs por cliente). Como você, como sênior do time, conduz a discussão técnica para alcançar a melhor escolha?"*

* **Respostas Esperadas do Candidato:**
  * **Mapeamento de Trade-offs:** Explicar fisicamente os problemas de concorrência e hotspots de escrita de usar `timestamp` sozinho.
  * **Arquitetura de Compromisso:** Sugerir uma chave composta (ex: Partition Key como `id_cliente` e Sort Key como `timestamp`), resolvendo o problema de distribuição homogênea no cluster e permitindo consultas ordenadas por data de forma nativa.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
