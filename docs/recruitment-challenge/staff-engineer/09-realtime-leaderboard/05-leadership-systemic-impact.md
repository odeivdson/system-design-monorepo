# 👥 Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Director of Engineering & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Liderança técnica de mudança de arquitetura, gestão de débito técnico legado e mediação de conflitos sobre paradigmas de bancos de dados.

---

## 🎯 O Cenário da Simulação de Liderança

O time de engenharia herdou um sistema de placar legado rodando sobre um banco de dados PostgreSQL tradicional. Conforme o quiz ao vivo cresceu em audiência, a disputa concorrente por locks nas linhas quentes da tabela de `users` causou o travamento completo do banco (Connection Pool Exhaustion) em todas as últimas três partidas de teste, inviabilizando o lançamento de um patrocinador importante.

Os desenvolvedores seniores do time argumentam que "bancos em memória (como Redis) não são confiáveis", e querem resolver o problema criando partições complexas e aumentando os recursos da máquina do PostgreSQL na nuvem (o que custaria mais de 25 mil dólares mensais).

Como Staff Engineer, você deve liderar a equipe para fora desse gargalo arquitetural de forma sustentável e convencer os desenvolvedores seniores da transição tecnológica.

---

## 🎯 Perguntas do Entrevistador e Comportamentos Esperados

### 1. Influência Baseada em Fatos e Evidências
* **Pergunta**: "Como você convenceria o desenvolvedor sênior defensor do PostgreSQL tradicional de que o modelo relacional em disco atingiu um limite físico instransponível sob 100k TPS concorrentes de escrita no mesmo conjunto de registros?"
* **Comportamento Esperado**: O candidato de nível Staff deve conduzir uma explicação baseada em física de banco de dados:
  * Explicar o funcionamento de locks de gravação, latência física de I/O de disco (WAL sync), contenção em páginas de índice B-Tree, e como a replicação em memória assíncrona (como Redis) combinada com checkpoints periódicos em disco no banco relacional é a melhor combinação arquitetural (Polyglot Persistence).

### 2. Gestão de Risco de Migração e Treinamento
* **Pergunta**: "Uma vez convencida a equipe, como você planejaria a migração para a nova arquitetura baseada em cache in-memory sem causar interrupções de serviço para os jogos que continuam acontecendo diariamente?"
* **Comportamento Esperado**: Propor a técnica de **Transactional Outbox / CDC** ou **Dual-Write**.
  * Gravar temporariamente em ambas as fontes, realizar testes de sombra (Shadow Reads) comparando os resultados do placar Redis com o PostgreSQL e aplicar o corte definitivo (Cutover) somente após consistência validada de 100% de acerto.

---

## ⚖️ Rubrica de Avaliação de Liderança

* **🟥 Red Flag**:
  * Impor a tecnologia de cache sem explicar os fundamentos físicos dos gargalos, criando atrito e desmotivação no time.
  * Ignorar os riscos reais de perda de dados trazidos pela equipe (como a volatilidade de dados na RAM) e não planejar redundância de disco ou WAL.
* **🟩 Staff L6+**:
  * Resolve o impasse técnico atuando como mentor do time; promove o entendimento das limitações físicas de IO/Disk.
  * Apresenta um plano de migração estruturado livre de downtime (como Shadowing de leituras).
  * Equilibra robustez técnica e viabilidade econômica para a organização.
