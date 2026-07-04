# 🖥️ Trilha 6 - Etapa 2: Technical Screening (Phone Screen)

* **Responsável:** Senior/Staff Software Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Protocolo HTTP, algoritmos de compressão de texto e indexação de dados.

---

## 💬 Q&A - Fundamentos de Protocolos Web e Hashing (20 min)

### Tópico A: Redirecionamentos HTTP: 301 vs. 302
* **Pergunta:** "Qual a diferença conceitual e de comportamento prático entre responder a um redirecionamento de URL curta com o status HTTP `301 Moved Permanently` e o status `302 Found`? Qual o impacto direto de cada um na latência percebida pelo usuário e no nosso pipeline analítico de contagem de cliques?"
* **Esperado:**
  * **301:** Permanente. O navegador do cliente faz cache do redirecionamento localmente. As próximas visitas não batem no nosso servidor (menor latência para o usuário, mas impede que contemos a quantidade total de cliques de analytics em tempo real).
  * **302:** Temporário. O navegador é forçado a bater no nosso servidor a cada clique (permite contabilizar 100% dos cliques em tempo real, mas consome mais banda e aumenta levemente a latência devido à ida e volta de rede adicional).

### Tópico B: Codificação Base62 vs. Hashing de Criptografia
* **Pergunta:** "Por que não devemos simplesmente aplicar SHA256 ou MD5 em uma URL longa e pegar os primeiros 7 caracteres do hash hexadecimal para gerar a URL curta? Qual a vantagem de usar um contador numérico incremental codificado em Base62?"
* **Esperado:**
  * Pegar os primeiros caracteres de SHA256/MD5 causa um risco enorme de colisão de hashes rápida devido ao paradoxo do aniversário.
  * Base62 (usando `[a-z, A-Z, 0-9]`) oferece 62 opções por caractere. Uma string de 7 caracteres Base62 suporta $62^7 \approx 3.5$ trilhões de URLs únicas sem risco de colisão se mapeada a partir de um ID autoincremental de 64 bits.

---

## 🛠️ Mini-Desafio: Conversor de Inteiro para Base62 (30 min)

### Cenário:
> *"Implemente uma função que receba um número inteiro positivo de 64 bits (ID único gerado pelo banco de dados) e retorne sua correspondente string compactada na codificação Base62 (usando caracteres de `a-z`, `A-Z` e `0-9`). A implementação deve ser determinística e performática."*

### Habilidades avaliadas:
* Divisão aritmética sucessiva por base 62.
* Uso correto de indexadores de mapeamento de caracteres e manipulação eficiente de strings/buffers em memória.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./02-technical-screening.md)
