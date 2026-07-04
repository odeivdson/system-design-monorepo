# 🖥️ Dev Senior - Trilha 1 - Etapa 2: Technical Screening

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Concorrência local (threads/goroutines), modelagem relacional de banco e validação de APIs.

---

## 💬 Q&A - Fundamentos de Desenvolvimento (20 min)

### Tópico A: Concorrência Local e Condições de Corrida
* **Pergunta:** "Se duas threads paralelas em sua aplicação tentam incrementar o saldo do mesmo usuário em memória ao mesmo tempo, o que acontece? Como você evita esse problema usando as ferramentas nativas da sua linguagem de escolha?"
* **Esperado:** 
  * Explicação sobre condições de corrida (Race Conditions) e perda de dados.
  * Uso correto de Mutexes (`sync.Mutex` em Go, `synchronized` ou `ReentrantLock` em Java) ou variáveis atômicas (`sync/atomic` ou `AtomicInteger`).

### Tópico B: Índices e Performance SQL
* **Pergunta:** "Em um banco relacional Postgres com milhões de transações, a consulta de extrato por data está lenta. Como você investigaria essa lentidão? Como um índice ajudaria e qual o impacto dele nas operações de escrita?"
* **Esperado:** 
  * Uso de comandos de plano de execução (ex.: `EXPLAIN ANALYZE`).
  * Criação de índice (B-Tree) no campo de consulta.
  * Consciência de que índices aumentam a velocidade de leitura, mas tornam as escritas (INSERT/UPDATE) ligeiramente mais lentas devido à manutenção do índice físico.

---

## 🛠️ Mini-Desafio: Escrita de Teste Unitário (30 min)
* **Cenário:** Escreva o código e o respectivo teste de unidade para um validador de transferência que checa se o saldo do remetente é suficiente e se as contas estão ativas. Use mock de interface de banco de dados.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
