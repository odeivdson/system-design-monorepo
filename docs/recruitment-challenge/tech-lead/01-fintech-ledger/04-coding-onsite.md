# 💻 Tech Lead - Trilha 1 - Etapa 4: Coding Onsite - Clean Architecture & SOLID

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração:** 60 minutos
* **Foco:** Clean Architecture, SOLID, acoplamento e injeção de dependências.

---

## 🎯 O Enunciado do Desafio

Um desenvolvedor júnior do seu time escreveu um processador de pagamentos misturando lógica de controle de banco, validações HTTP e chamadas diretas a APIs externas em um único arquivo de 500 linhas de código altamente acoplado e sem testes.

O candidato deve **refatorar a arquitetura desse componente** aplicando os conceitos de **Clean Architecture** e princípios de **SOLID** para torná-lo testável e extensível para novos adquirentes de pagamento.

---

## 🛠️ Requisitos de Código Esperados do Candidato

1. **Separação de Camadas (Arquitetura em Cebola):**
   * **Domain Entities:** Modelos puros da regra de negócio (ex.: `Transaction`).
   * **Use Cases (Lógica de Negócio):** Regras de negócio puras (ex.: `ProcessPaymentUseCase`), sem referências a bibliotecas HTTP ou ORMs específicos de banco.
   * **Adapters/Infrastructure:** Drivers HTTP, repositórios de banco de dados e adaptadores de clientes externos.

2. **Inversão de Dependências (DIP):**
   * Definir interfaces claras de repositórios (ex.: `PaymentRepository`) e gateways de pagamento (ex.: `PaymentGateway`).
   * O caso de uso deve receber essas interfaces no construtor (Injeção de Dependência).

3. **Código Concorrente Seguro e Testabilidade:**
   * Escrever um teste unitário mockando as interfaces criadas para provar a isolação e testabilidade da lógica de negócio.

---

## ⚖️ Rubrica de Código (Tech Lead)
* **Sinal Verde (Green Flag):** Cria interfaces separadas para o banco e para o adquirente; injeta dependências de forma limpa; demonstra foco em criar código que sua equipe conseguirá ler e estender sem introduzir regressões.
* **Sinal Vermelho (Red Flag):** Mantém código acoplado; escreve testes que batem diretamente no banco de dados operacional; desconhece os princípios de Clean Architecture.

---

[Ir para a Etapa 5: Leadership Onsite ➡️](./05-leadership-onsite.md)
