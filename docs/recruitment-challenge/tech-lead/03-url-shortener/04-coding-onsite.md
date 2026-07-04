# 💻 Tech Lead - Trilha 3 - Etapa 4: Coding Onsite - Gerador de Tokens e Cache Local

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração:** 60 numutos
* **Foco:** Algoritmos de codificação (Base62), controle de colisões, concorrência e estrutura limpa de código.

---

## 🎯 O Enunciado do Desafio

No encurtador de URLs do time, precisamos de um mecanismo gerador de tokens curtos (Base62) que seja rápido, evite colisões e lide com concorrência local de threads.

O candidato deve implementar o **Gerador de Links Curto com Cache Local** aplicando Clean Code e padrões testáveis.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar uma estrutura/classe `LinkShortenerService` com os seguintes métodos:

### 1. `ShortenUrl(longUrl string) (string, error)`
* Gera um token curto usando codificação Base62 a partir de um contador numérico incremental interno thread-safe.
* Retorna a URL curta gerada.

### 2. `ResolveUrl(token string) (string, bool)`
* Consulta o link original associado ao token a partir de um cache em memória local.
* Se não estiver no cache local, simula a busca no banco central (adicionando um delay de 10ms), armazena no cache local para futuras consultas, e retorna a URL original.

### 3. Cobertura de Testes
* O código deve conter separação de responsabilidades para permitir testes unitários isolando o gerador Base62 do serviço de cache.

---

## ⚖️ Rubrica de Código (Tech Lead)
* **Sinal Verde (Green Flag):** Implementa a divisão matemática por base 62 de forma limpa; usa mutexes ou chaves exclusivas thread-safe no contador de controle; escreve testes unitários mocks eficientes; foca em legibilidade do código para o time.
* **Sinal Vermelho (Red Flag):** Mistura todo o algoritmo em uma classe gigantesca impossível de testar de forma isolada; gera colisões de token sob paralelismo.

---

[Ir para a Etapa 5: Leadership Onsite ➡️](./05-leadership-onsite.md)
