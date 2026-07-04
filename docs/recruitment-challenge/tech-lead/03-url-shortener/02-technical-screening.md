# 🖥️ Tech Lead - Trilha 3 - Etapa 2: Technical Screening

* **Responsável:** Senior/Staff Software Engineer
* **Duração:** 60 minutos
* **Foco:** Redirecionamento HTTP, Base62 básico, concorrência e padrões de cache.

---

## 💬 Q&A - Fundamentos de Redirecionamento e Hashing (20 min)

### Tópico A: Redirecionamentos HTTP 301 vs. 302
* **Pergunta:** "Qual a diferença de comportamento prático para o navegador do cliente ao receber um redirecionamento HTTP `301 Moved Permanently` vs. `302 Found`? Como cada escolha impacta nossa capacidade de contabilizar estatísticas de cliques?"
* **Esperado:** 
  * 301 é cacheado permanentemente pelo cliente, poupando requisições ao servidor, mas inviabilizando rastrear cliques recorrentes de forma exata.
  * 302 força o cliente a bater no servidor a cada clique, ideal para analytics, embora consuma mais banda.

### Tópico B: Codificação Base62
* **Pergunta:** "O que é codificação Base62 e como ela difere de Base64 e Hexadecimal em termos de tamanho do token gerado para encurtar links?"
* **Esperado:** 
  * Base62 usa `[a-zA-Z0-9]`, ideal para URLs porque não contém caracteres especiais (`+`, `/`) que precisam de escape em URLs como em Base64.
  * É muito mais compacta que Hexadecimal (Base16).

---

## 🛠️ Mini-Desafio: Algoritmo de Hashing e Concorrência (30 min)
* **Cenário:** Projete um método que receba uma URL longa e gere um token curto determinístico usando hashes e lide com colisões. Discuta a segurança concorrente de múltiplos threads salvando esses dados em um mapa em memória.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
