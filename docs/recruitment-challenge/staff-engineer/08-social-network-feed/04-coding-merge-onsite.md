# 💻 Etapa 4: Coding & Resilience Onsite - Fusão de Timelines (K-Way Merge)

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Algoritmos em memória, gestão de estruturas de dados (Heaps/Priority Queues) e controle de alocação de memória (GC pressure) sob alta concorrência.

---

## 🎯 O Enunciado do Desafio

Em uma arquitetura de News Feed híbrido, para compor a timeline final do usuário leitor, o sistema precisa ler os posts mais recentes criados pelas celebridades que ele segue e mesclá-los cronologicamente com os posts armazenados no seu cache de timeline pré-computada.

O candidato deve implementar, na linguagem de sua preferência (ex.: Go, Java, Python ou C#), um motor de **Fusão Concorrente Ordenada de Timelines (K-Way Merge)** que receba $K$ listas de posts (já individualmente ordenadas de forma cronológica reversa) e produza uma única lista contendo os $N$ posts mais recentes consolidados, otimizando o consumo de CPU e memória.

---

## 🛠️ Requisitos Técnicos do Desafio

O candidato deve projetar a classe/estrutura `TimelineMerger` atendendo às seguintes regras:

### 1. Complexidade de Algoritmo Ótima
* Realizar a mesclagem das listas sem simplesmente concatená-las e reordenar o array resultante global (o que seria uma solução lenta $O(M \log M)$, onde $M$ é a soma total de elementos).
* O candidato deve usar uma **Fila de Prioridade (Heap)** ou algoritmo equivalente para realizar o merge em tempo $O(M \log K)$, lendo os ponteiros de forma incremental.

### 2. Eficiência de Memória e GC Pressure
* Evitar alocações desnecessárias na Heap para cada post mesclado.
* Em linguagens com Garbage Collection (ex: Java, Go), o algoritmo deve reutilizar fatias/arrays de memória ou trabalhar com índices diretos nas listas originais para não gerar picos de consumo de memória que acionem o Garbage Collector de forma agressiva sob concorrência.

### 3. Concorrência e Tolerância a Timeouts
* A busca das $K$ timelines originais deve ocorrer de forma paralela.
* Se uma das timelines originais demorar mais que o tempo de timeout definido (ex: 30ms), o motor de merge deve ignorar essa timeline atrasada e prosseguir com a mesclagem das fontes que responderam a tempo, garantindo que o feed do usuário seja montado de forma parcial mas rápida (degradação graciosa).

---

## 📝 Esboço de Assinaturas Esperadas (Interface Conceitual)

Exemplo de estrutura conceitual (Go/Java):

```go
type Post struct {
    ID        string
    AuthorID  string
    Timestamp int64 // UNIX Epoch
}

type TimelineSource interface {
    // FetchRecentPosts busca posts ordenados do autor concorrentemente
    FetchRecentPosts(ctx context.Context, authorID string) ([]Post, error)
}

type TimelineMerger interface {
    // MergeHomeFeed consolida os feeds de múltiplos autores em um único feed ordenado de tamanho limite N
    MergeHomeFeed(ctx context.Context, authors []string, sources TimelineSource, limit int) ([]Post, error)
}
```

---

## ⚖️ Rubrica de Avaliação de Engenharia Prática

| Tópico | 🟥 Red Flag (Reprovar) | 🟨 Senior Engineer (L5) | 🟩 Staff Engineer (L6+) |
| :--- | :--- | :--- | :--- |
| **Algoritmo de Merge** | Une todos os arrays em uma lista gigante e ordena tudo do zero, gerando performance inaceitável. | Utiliza algoritmo de intercalação com fila de prioridade de forma linear e funcional. | Implementa a lógica K-Way Merge com Heap otimizando a leitura do iterador em tempo $O(M \log K)$ sem leituras duplicadas. |
| **Concorrência e Timeouts** | Busca as timelines de forma sequencial (fazendo a chamada HTTP/gRPC de uma por uma), aumentando a latência total do endpoint. | Paraleliza as buscas usando primitivas assíncronas simples (ex: `Future`, `go channel`), mas uma chamada travada paralisa todo o merge. | Garante paralelismo com controle de timeout granular via contexto; reconstrói o feed de forma coerente mesmo na falha de frações dos servidores. |
| **Uso de Memória e Garbage Collection** | Aloca coleções enormes repetidamente na heap, causando pico de alocação de memória a cada requisição de feed. | Limita o tamanho das estruturas temporárias criadas e libera ponteiros assim que possível. | Otimiza o uso de ponteiros locais; em Go, usa pooling de objetos (`sync.Pool`) ou fatias reaproveitadas para garantir zero alocação extra de Heap durante o processamento do merge. |
