# 💻 Trilha 6 - Etapa 4: Coding Onsite - Gerador de Chaves e Cache de Redirecionamento

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Concorrência thread-safe, geração determinística de IDs, e caching local eficiente com limites.

---

## 🎯 O Enunciado do Desafio

No servidor de encurtamento, para acelerar os redirecionamentos sem sobrecarregar a rede, cada instância mantém um cache em memória local das URLs curtas mais acessadas. Quando ocorre uma escrita (criação de URL curta), o servidor consome um token de chave de um buffer pré-carregado.

O candidato deve implementar o **Gerenciador de Chaves Local e Cache Resiliente** thread-safe.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve implementar a classe/estrutura `ResilientLinkShortener` com os seguintes métodos:

### 1. `SubmitKeyRange(start int64, end int64)`
* O KGS fornece um intervalo exclusivo de chaves numéricas para este servidor local (ex.: de `100.000` a `200.000`).
* O método deve carregar esse intervalo em uma estrutura de dados de fila ou buffer concorrente e thread-safe.

### 2. `Shorten(longUrl string) (string, error)`
* Consome o próximo ID numérico disponível no buffer local de chaves.
* Converte esse ID numérico para Base62 para obter o token curto (ex.: `12345` -> `3d7`).
* Salva a associação `longUrl -> token` no cache local de gravação e simula a escrita assíncrona no banco central. Retorna o link encurtado.
* Se o buffer local de chaves esvaziar, deve retornar um erro específico informando falta de tokens.

### 3. `Resolve(shortToken string) (string, bool)`
* Consulta a URL original associada ao token no cache local.
* Se estiver presente, retorna o link (cache hit).
* Se não estiver, simula a busca no banco central NoSQL (adicionando um delay fictício de 10ms), salva a associação no cache local para requisições subsequentes (cache read-through) e retorna a URL.

---

## ⚖️ Rubrica de Avaliação de Código

| Nível | Indicadores Práticos no Desafio |
| :--- | :--- |
| 🟥 **Reprovado** | Implementa conversão Base62 ineficiente (ex.: usando concatenações repetidas de strings em loops lentos); gera colisões ou condições de corrida ao distribuir chaves locais. |
| 🟨 **Senior (L5)** | Implementa a fila concorrente de chaves corretamenta com Mutexes. Implementa a lógica de cache local com mapa concorrente simples. |
| 🟩 **Staff (L6+)** | Implementa a fila local usando canais com buffer ou estruturas baseadas em anéis de forma altamente performática. Lida de forma proativa com o problema do estouro de memória no cache local implementando políticas de despejo simples (como limite de tamanho do cache ou um mecanismo simplificado de LRU/LFU). |

---

[Ir para a Etapa 5: Leadership & Systemic Impact ](./05-leadership-systemic-impact.md)
