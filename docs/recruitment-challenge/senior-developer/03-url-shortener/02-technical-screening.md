# 🖥️ Dev Senior - Trilha 3 - Etapa 2: Technical Screening

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Códigos de status HTTP, Base62 básico, concorrência e estratégias de cache simples.

---

## 💬 Q&A - Fundamentos de HTTP, Codificação e Caching (20 min)

### Tópico A: Códigos de Status HTTP Semânticos
* **Pergunta:** "Se o encurtador de URLs tenta buscar uma URL a partir de um token que não existe, qual o código HTTP de erro ideal a retornar? E se o usuário enviar um link longo inválido (ex.: sem domínio)? Explique os porquês comerciais de usar os códigos de status corretos."
* **Esperado:** 
  * Token inexistente: `404 Not Found`.
  * URL inválida: `400 Bad Request` ou `422 Unprocessable Entity`.
  * O uso correto ajuda nos relatórios de erros automatizados e na integração dos times de frontend.

### Tópico B: Codificação Base62
* **Pergunta:** "Pode explicar como funciona o algoritmo de codificação Base62 de forma matemática a partir de um ID autoincremental de banco de dados?"
* **Esperado:** 
  * Conversão de base numérica tradicional (sucessivas divisões pelo divisor 62, capturando o resto de cada divisão e mapeando-os para os caracteres `[0-9a-zA-Z]`).

---

## 🛠️ Mini-Desafio: Gerador Base62 (30 min)
* **Cenário:** Escreva o código (em sua linguagem de preferência) que converta o ID inteiro `20092189` em uma string curta usando Base62 de forma limpa e otimizada. Escreva testes unitários rápidos para provar o resultado.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
