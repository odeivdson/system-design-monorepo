# 🛠️ Etapa 2: Technical Screening

* **Responsável:** Senior / Staff Engineer
* **Duração Recomendada:** 45 minutos
* **Foco:** Fundamentos de modelagem de dados para grafos sociais, caching distribuído e conceitos de processamento assíncrono (Push vs. Pull).

---

## 🎯 Perguntas Técnicas e Respostas Esperadas

### 1. Estratégias de Fan-Out: Push vs. Pull
* **Pergunta**: "Qual a diferença conceitual e prática entre Fan-Out on Write (Push) e Fan-Out on Read (Pull) para a geração de timelines de usuários? Qual o maior gargalo de cada abordagem?"
* **Resposta Esperada**:
  * **Fan-Out on Write (Push)**: O post novo do autor é escrito de forma assíncrona diretamente no cache da timeline de cada seguidor. 
    * *Gargalo*: Contas celebridades com milhões de seguidores (ex: celebridade publica e gera milhões de escritas em cache na hora, o que pode asfixiar a fila e atrasar o feed de outros usuários).
  * **Fan-Out on Read (Pull)**: O post é gravado apenas na tabela do autor. Quando um usuário lê seu feed, o sistema faz o merge ativo no momento da consulta buscando os posts de todas as pessoas que ele segue.
    * *Gargalo*: Carga de processamento e latência de leitura muito altas na hora da consulta para usuários que seguem muitas pessoas.

### 2. Modelagem de Relacionamento Social (Followers/Following)
* **Pergunta**: "Como você modelaria a relação de amizade/seguidores em uma base NoSQL chave-valor ou colunar (ex: Cassandra/DynamoDB) para garantir que consultas como 'Quem o usuário A segue?' e 'Quem segue o usuário A?' rodem em sub-10ms?"
* **Resposta Esperada**:
  * É necessário criar **duas tabelas/projeções duplicadas** devido à falta de índices secundários globais eficientes em bases NoSQL:
    * Tabela `following`: Particionada por `user_id` (Sorted por `followed_user_id`). Permite descobrir quem o usuário segue de forma linear.
    * Tabela `followers`: Particionada por `user_id` (Sorted por `follower_user_id`). Permite descobrir quem segue o usuário.
  * As atualizações em ambas devem ser atômicas via transação local ou garantidas assincronamente através de logs de transação e CDC.

---

## ⚖️ Rubrica de Avaliação Técnica

* **🟥 Red Flag**: Não compreender os problemas gerados por escritas síncronas pesadas ou desconhecer a teoria de fan-out.
* **🟩 Staff L6+**: Identifica rapidamente o problema das celebridades (Hotkeys) em caching e descreve soluções híbridas dinâmicas.
