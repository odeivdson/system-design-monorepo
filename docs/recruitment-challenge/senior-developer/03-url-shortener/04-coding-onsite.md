# 💻 Dev Senior - Trilha 3 - Etapa 4: Coding Onsite - Cache LRU Concorrente Local

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Algoritmos de ordenação, estruturas encadeadas (Double-Linked List), segurança de threads local (Mutexes) e testes.

---

## 🎯 O Enunciado do Desafio

Para otimizar o redirecionamento local sem bater sempre no Redis, o encurtador de URLs do time precisa de um **cache local LRU (Least Recently Used)** em memória que limite o número de links armazenados e remova automaticamente os links menos acessados.

O candidato deve implementar o **Cache LRU** thread-safe em sua linguagem de preferência.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar a classe `LRUCache` com os seguintes métodos:

### 1. `NewLRUCache(capacity int)`
* Inicializa o cache com uma capacidade máxima limitada a $N$ elementos.

### 2. `Get(key string) (string, bool)`
* Retorna o valor associado à chave e marca a chave como a "mais recentemente usada" (move para o início da fila).
* Se a chave não existir, retorna `false`.
* O método deve rodar em tempo constante $O(1)$.

### 3. `Put(key string, value string)`
* Insere ou atualiza o valor da chave.
* Se a capacidade máxima do cache for excedida, deve remover o item mais antigo (menos recentemente usado) da memória física.
* O método deve rodar em tempo constante $O(1)$.

### 4. Segurança de Threads (Concorrência)
* Os métodos `Get` e `Put` serão chamados concorrentemente por múltiplas threads de requisições web. Proteja as estruturas usando Mutexes de forma correta para evitar race conditions na lista e mapa de dados.

---

## ⚖️ Rubrica de Código (Dev Senior)
* **Sinal Verde (Green Flag):** Implementa o cache usando combinação correta de `Map` + `Doubly Linked List` para garantir complexidade $O(1)$; usa Mutexes de forma correta ao manipular a lista e o mapa; escreve testes unitários de borda.
* **Sinal Vermelho (Red Flag):** Faz busca linear $O(N)$ em listas simples a cada acesso; não protege as escritas/leituras concorrentes no mapa.

---

[Ir para a Etapa 5: Behavioral Onsite ➡️](./05-leadership-onsite.md)
