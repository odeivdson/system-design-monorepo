# 💻 Dev Senior - Trilha 4 - Etapa 4: Coding Onsite - Buffer de Ingestão Thread-Safe

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Concorrência paralela, manipulação rápida de ponteiros na memória (buffer swap), design assíncrono e testes automatizados.

---

## 🎯 O Enunciado do Desafio

No serviço de ingestão de eventos, precisamos acumular registros em memória RAM antes de efetuar gravações em lote no banco NoSQL. No entanto, o fluxo de entrada de requisições é massivo e contínuo. 

O candidato deve implementar o **Buffer/Batcher em Memória** thread-safe que permita inserções paralelas ultra-rápidas sem bloquear as requisições de entrada durante as descargas de dados para a base de dados.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve estruturar a classe `ConcurrentBatcher` contendo:

### 1. Métodos da Classe
* `Add(Event event)`: Insere um evento de telemetria no buffer de forma thread-safe.
* `Configure(int maxBatchSize, Duration maxFlushInterval, DatabaseWriter writer)`: Inicializa as configurações de tamanho limite do lote e intervalo de tempo máximo entre descargas, além do serviço mock de escrita.
* `Start()` / `Stop()`: Inicializa e finaliza a thread de background responsável pelo monitoramento de tempo limite.

### 2. Segurança de Threads e Desempenho Fino (SLA < 20ms)
* O método `Add` será invocado simultaneamente por centenas de requisições de entrada.
* **Armadilha Crítica:** Se o candidato bloquear todo o método `Add` com um Lock Mutex pesado enquanto o lote anterior está sendo gravado no banco de dados, a API sofrerá picos de lentidão drásticos.
* **Estratégia Esperada (Buffer Swap):** Sob um lock curto, o código deve trocar a referência da lista ativa atual por uma nova lista vazia. A lista cheia anterior é então enviada para ser persistida no banco NoSQL em background **fora do bloco bloqueado**, permitindo que novas chamadas do `Add` continuem inserindo dados na lista nova sem atrasos.

### 3. Teste de Validação
* Escrever um caso de teste que:
  * Insira concorrentemente 2.000 eventos de forma paralela usando goroutines/threads.
  * Valide se o `DatabaseWriter` mock recebeu exatamente os 2.000 registros distribuídos em lotes corretos.
  * Garanta que nenhuma perda de registros ocorra na transição do swap de buffers.

---

## ⚖️ Rubrica de Código (Dev Senior)
* **Sinal Verde (Green Flag):** Implementa o swap de buffers eficientemente usando exclusão mútua de curta duração; resolve a descarga de tempo (ticker de background) sem race conditions; escreve testes que simulam concorrência de verdade.
* **Sinal Vermelho (Red Flag):** Trava a escrita de rede/disco sob o mesmo lock de inserção, inviabilizando o SLA de latência; gera falhas de concorrência ou duplicação de dados ao resetar o buffer.

---

[Ir para a Etapa 5: Behavioral Onsite ➡️](./05-leadership-onsite.md)
