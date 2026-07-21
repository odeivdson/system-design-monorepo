# 💻 Etapa 4: Coding & Resilience Onsite - SkipList Concorrente Lock-Free

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Concorrência avançada de baixo nível, manipulação atômica de ponteiros (CAS), algoritmos probabilísticos de ordenação e otimização de cache lines.

---

## 🎯 O Enunciado do Desafio

Para suportar milhões de atualizações de pontuação concorrentes em tempo real sem sofrer com gargalos de mutexes globais, precisamos de uma estrutura de dados de busca e classificação em memória extremamente performática e segura sob múltiplas threads.

O candidato deve implementar, na linguagem de sua preferência (ex.: Go, Java, C++ ou C#), uma **SkipList Concorrente Lock-Free** (ou baseada em locks de granularidade fina como Lock Striping/Hand-over-hand) que permita a inserção atômica de pontuações de usuários e retorne a posição (rank) de um jogador de forma eficiente.

---

## 🛠️ Requisitos Técnicos do Desafio

O candidato deve projetar a classe/estrutura `ConcurrentLeaderboard` atendendo às seguintes regras:

### 1. Busca e Atualização em Tempo Logarítmico
* As operações de `Insert`, `UpdateScore` e `GetRank` devem rodar em complexidade de tempo de pior caso ou caso médio de **$O(\log N)$**.
* A estrutura deve usar múltiplos níveis probabilísticos de ponteiros encadeados (SkipList) para permitir travessias rápidas pulando elementos irrelevantes.

### 2. Segurança de Threads Sem Bloqueio Global
* Múltiplas threads escritoras devem poder inserir ou atualizar pontuações simultaneamente.
* O candidato deve evitar o uso de um único Mutex/Lock exclusivo que trave a SkipList inteira para leitura e escrita.
* **Foco Staff**: Empregar travas refinadas por nó ou operações atômicas baseadas em CPU Compare-And-Swap (CAS) para sincronização de ponteiros, reduzindo a contenção de cache line de CPU.

### 3. Evitar Vazamentos e Corrupção sob CAS
* Se implementar um design Lock-Free baseado em CAS, lidar com a consistência de remoções/atualizações de nós concorrentes de forma segura, evitando leituras de referências deletadas (o clássico problema *ABA* em linguagens de baixo nível ou problemas de race na alteração do valor de ponteiros).

---

## 📝 Esboço de Assinaturas Esperadas (Interface Conceitual)

Exemplo de interface (Go/Java):

```go
type UserScore struct {
    UserID string
    Score  int
}

type ConcurrentLeaderboard interface {
    // UpdateScore atualiza ou insere a pontuação do usuário de forma thread-safe
    UpdateScore(userID string, newScore int) error
    
    // GetRank retorna o rank (posição 1-indexada) com base na ordenação decrescente de pontuações
    GetRank(userID string) (int, error)
    
    // GetTopK retorna os K usuários com maiores pontuações de forma consistente
    GetTopK(k int) ([]UserScore, error)
}
```

---

## ⚖️ Rubrica de Avaliação de Engenharia Prática

| Tópico | 🟥 Red Flag (Reprovar) | 🟨 Senior Engineer (L5) | 🟩 Staff Engineer (L6+) |
| :--- | :--- | :--- | :--- |
| **Algoritmo SkipList** | Não sabe construir os níveis probabilísticos (coin flip) ou implementa uma lista ligada simples linear $O(N)$ disfarçada. | Constrói a SkipList clássica de forma funcional com inserção estruturada de ponteiros. | Implementa a SkipList com limites precisos de altura máxima de níveis; detalha a matemática de balanceamento probabilístico. |
| **Sincronização Concorrente** | Trava toda a estrutura com um `sync.Mutex` global a cada operação, estrangulando o paralelismo. | Usa travas de leitura e escrita (`RWMutex`) ou Locks granulares por nó com Hand-over-hand Locking. | Implementa SkipList totalmente Lock-Free usando operações atômicas baseadas em hardware (CAS) com CompareAndSwapPointer; explica contenda de cache lines. |
| **ABA / Memory Safety** | Ignora o problema de mutação de nós vizinhos concorrentes, gerando ponteiros órfãos ou quebras de memória (Segmentation Faults). | Trata as referências lógicas travando os nós vizinhos imediatos de forma ordenada para prevenir deadlocks lógicos. | Emprega técnicas de Pointer Tagging ou gerencia exclusão lógica atômica em múltiplos níveis de ponteiros de forma consistente sem suspender threads. |
