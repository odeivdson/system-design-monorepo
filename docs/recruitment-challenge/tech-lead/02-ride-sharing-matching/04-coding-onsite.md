# 💻 Tech Lead - Trilha 2 - Etapa 4: Coding Onsite - Despachador de Tarefas Concorrente

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração:** 60 minutos
* **Foco:** Concorrência controlada, segurança de threads (Thread-Safety), legibilidade de código para a equipe e testes.

---

## 🎯 O Enunciado do Desafio

No serviço de despacho do time, quando novas solicitações de corridas chegam, elas devem ser enfileiradas e processadas por um grupo de workers concorrentes (Worker Pool) que tentará encontrar e alocar um motorista para o passageiro.

O candidato deve implementar o **Gerenciador de Alocação de Corridas** concorrente que processe essa fila de forma controlada.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar uma estrutura/classe `MatchJobProcessor` com os seguintes requisitos:

### 1. Fila de Trabalho Concorrente (Thread-Safe)
* Suportar a inserção concorrente de solicitações de corrida (`SubmitRideRequest(request RideRequest)`).
* O processamento das solicitações deve ser executado em segundo plano por um pool limitado de $K$ workers paralelos para evitar sobrecarga no banco de dados.

### 2. Evitar Concorrência Duplicada
* O pool de workers deve garantir que duas threads não tentem processar a mesma solicitação de corrida ao mesmo tempo.

### 3. Código Limpo e Legível
* O código deve conter separação de responsabilidades limpa, bom tratamento de erros e estruturas nativas da linguagem (ex.: canais/goroutines em Go, ou `ExecutorService` em Java).

---

## ⚖️ Rubrica de Código (Tech Lead)
* **Sinal Verde (Green Flag):** Usa pools de threads/workers adequados e controlados; evita loops de consumo ocupado (*busy waiting*); escreve código estruturado de fácil manutenção para engenheiros seniores do time.
* **Sinal Vermelho (Red Flag):** Cria novas threads dinamicamente sem limite para cada requisição (estouro de memória); usa locks gigantescos globais que paralisam a execução concorrente.

---

[Ir para a Etapa 5: Leadership Onsite ➡️](./05-leadership-onsite.md)
