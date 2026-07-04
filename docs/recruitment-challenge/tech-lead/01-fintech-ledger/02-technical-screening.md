# 🖥️ Tech Lead - Trilha 1 - Etapa 2: Technical Screening

* **Responsável:** Senior/Staff Software Engineer
* **Duração:** 60 minutos
* **Foco:** SOLID, isolamento de transações, APIs robustas e noções de sistemas de filas.

---

## 💬 Q&A - Fundamentos de Arquitetura e Código (20 min)

### Tópico A: Princípios SOLID e Clean Code
* **Pergunta:** "Pode explicar como o Princípio de Inversão de Dependência (Dependency Inversion Principle) ajuda a manter um sistema testável e extensível? Como você garante que o seu time siga esse padrão?"
* **Esperado:** 
  * Uso de interfaces para desacoplar lógica de negócio (ex.: serviços de pagamento) de implementações físicas (ex.: gateways externos ou bancos de dados).
  * Habilidade em revisar pull requests de forma educativa reforçando esse princípio.

### Tópico B: Transações em Bancos de Dados
* **Pergunta:** "Qual a diferença prática entre os níveis de isolamento `Read Committed` e `Serializable` em bancos de dados relacionais? Em quais cenários do ecossistema financeiro do time você exigiria isolamento estrito e por quê?"
* **Esperado:** 
  * `Read Committed` evita dirty reads mas permite phantom reads e non-repeatable reads.
  * `Serializable` é o nível mais seguro (evita race conditions de saldo), mas gera concorrência de locks (deadlocks) sob alta carga.

---

## 🛠️ Mini-Desafio: Design de API de Pagamento (30 min)
* **Cenário:** Desenhe o contrato de API (JSON) e a assinatura de métodos de serviço para um endpoint que processa transferências entre usuários. 
* **O que avaliar:** Inclusão de chaves de idempotência, validação rica de dados de entrada, e manuseio de tratamento de erros com códigos HTTP semânticos (ex.: 422 Unprocessible Entity para saldo insuficiente).

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
