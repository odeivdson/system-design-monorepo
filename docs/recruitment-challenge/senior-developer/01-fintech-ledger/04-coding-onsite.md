# 💻 Dev Senior - Trilha 1 - Etapa 4: Coding Onsite - Concorrência Local de Saldos

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Concorrência thread-safe estruturada na linguagem escolhida, controle de locks e testes automatizados.

---

## 🎯 O Enunciado do Desafio

No microsserviço de cartões, precisamos processar autorizações de compras locais concorrentes a partir de múltiplos terminais em memória antes de enviar ao banco.

O candidato deve implementar o **Gerenciador de Balanço em Memória** thread-safe que gerencie saldos locais e autorizações de débitos paralelos sem inconsistências.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar uma estrutura/classe `AccountBalanceManager` com os seguintes requisitos:

### 1. Métodos da Classe
* `SetBalance(accountId string, amount float64)`: Define o saldo inicial de uma conta.
* `Debit(accountId string, amount float64) (bool, error)`: Tenta debitar o valor especificado. Retorna `true` se o saldo for suficiente, caso contrário `false`.
* `GetBalance(accountId string) float64`: Retorna o saldo atual.

### 2. Segurança de Threads (Concorrência Paralela)
* O método `Debit` e `GetBalance` serão chamados concorrentemente por múltiplas threads/goroutines.
* O candidato deve usar trancamento fino (ex.: um lock Mutex por conta, ou um mapa thread-safe) para evitar que o saldo fique negativo ou inconsistente devido a corridas paralelas.

### 3. Teste de Concorrência
* Escrever um teste que simule 100 chamadas simultâneas de débito de R$ 1 em uma conta com saldo de R$ 50, garantindo que o saldo final seja exatamente R$ 0 e que exatamente 50 requisições tenham retornado sucesso.

---

## ⚖️ Rubrica de Código (Dev Senior)
* **Sinal Verde (Green Flag):** Implementa locks de grão fino corretos; demonstra facilidade em escrever testes que validam cenários reais de concorrência paralela; lida com erros de forma semântica.
* **Sinal Vermelho (Red Flag):** Ignora a necessidade de locks na memória, gerando saldo final incorreto ou pânico de mapa concorrente (`fatal error: concurrent map writes`).

---

[Ir para a Etapa 5: Behavioral Onsite ➡️](./05-leadership-onsite.md)
