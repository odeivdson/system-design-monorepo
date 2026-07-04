# 💻 Etapa 4: Coding & Resilience Onsite - Buffer Concorrente e Resiliente

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Concorrência multi-thread, resiliência a falhas, controle de fluxo (Rate Limiting) e estruturação de código limpo.

---

## 🎯 O Enunciado do Desafio

Em sistemas de Big Tech, a integração com APIs externas (ex.: adquirentes de cartão de crédito, bancos parceiros ou provedores de KYC) é inerentemente instável. Se dispararmos requisições de forma descontrolada ou sem tratamento de falhas, causaremos sobrecarga em cascata ou falhas em massa.

O candidato deve implementar, na linguagem de sua preferência (ex.: Go, Java, Python ou C#), um **Buffer de Processamento Concorrente e Resiliente** que receba tarefas de pagamento de múltiplos produtores paralelos e as envie a um serviço externo instável respeitando limites de taxa e políticas de retry.

---

## 🛠️ Requisitos Técnicos do Desafio

O candidato deve criar uma estrutura/classe `ResilientBuffer` que implemente as seguintes regras:

### 1. Concorrência e Segurança de Threads (Thread-Safety)
* Múltiplas threads/goroutines produtoras devem poder chamar `Buffer.Submit(payment)` simultaneamente sem corromper o estado interno do buffer ou causar travamentos permanentes (*deadlocks*).

### 2. Controle de Fluxo (Rate Limiting)
* O buffer deve garantir que as tarefas sejam despachadas para a API externa a uma taxa máxima de **$R$ requisições por segundo**. Se o volume de entrada for maior que o limite, as tarefas devem aguardar de forma ordenada no buffer interno.

### 3. Resiliência: Retries com Exponential Backoff e Jitter
* A API externa é instável e pode retornar falhas temporárias (ex.: HTTP 503, Timeouts de Rede).
* Quando uma tarefa falhar, o buffer deve reexecutá-la aplicando:
  * **Exponential Backoff:** O tempo de espera entre tentativas aumenta exponencialmente (ex.: 100ms, 200ms, 400ms, 800ms).
  * **Jitter (Ruído Aleatório):** Um elemento aleatório deve ser adicionado ao tempo de espera (ex.: se a espera calculada for 400ms, o atraso real deve ser algo aleatório entre 300ms e 500ms) para evitar o efeito de manada (*thundering herd problem*).
  * **Limite de Tentativas:** Após $N$ tentativas fracassadas, a tarefa deve ser enviada para uma Dead Letter Queue (DLQ) ou retornar erro definitivo para o produtor.

### 4. Desligamento Gracioso (Graceful Shutdown)
* Quando o método `Buffer.Stop()` for chamado, o sistema deve parar de aceitar novos envios, mas processar com sucesso todas as tarefas pendentes que já estão no buffer antes de liberar a thread principal, respeitando um timeout limite.

---

## 📝 Esboço de Assinaturas Esperadas (Interface Conceitual)

Aqui está um exemplo conceitual de como a estrutura deve se comportar (usando pseudo-código ou assinatura Go/Java):

```go
type Payment struct {
    ID     string
    Amount float64
}

type ExternalAPI interface {
    Send(payment Payment) error // Flaky API
}

type ResilientBuffer interface {
    // Submit aceita um pagamento de forma thread-safe.
    Submit(payment Payment) error
    
    // Start inicia o processamento interno em background.
    Start()
    
    // Stop finaliza o processamento e drena as tarefas existentes.
    Stop(ctx context.Context) error
}
```

---

## ⚖️ Rubrica de Avaliação de Engenharia Prática

Nesta etapa, o entrevistador deve analisar não apenas se o código compila ou passa em cenários felizes, mas como ele lida com estados de concorrência extrema e recuperação de erros.

| Tópico | 🟥 Red Flag (Reprovar) | 🟨 Senior Engineer (L5) | 🟩 Staff Engineer (L6+) |
| :--- | :--- | :--- | :--- |
| **Concorrência** | Usa compartilhamento de memória desprotegido (gerando *race conditions*) ou causa travamento permanente de threads (*deadlocks*). | Usa mutexes simples ou canais corretamente para isolar o acesso ao buffer. O código é thread-safe. | Evita contenção excessiva de locks. Se usa Go, prefere compartilhamento de dados por canais (*don't communicate by sharing memory...*). Demonstra domínio sobre locks granulares ou estruturas lock-free. |
| **Rate Limiting** | Implementa uma solução rudimentar (ex.: `sleep` fixo de 1 segundo entre envios) que não lida com rajadas de tráfego. | Implementa algoritmo clássico como Token Bucket ou Leaky Bucket usando timers nativos da linguagem de forma funcional. | Explica e implementa o algoritmo considerando precisão de temporizadores e cenários em que o consumo do bucket de tokens é extremamente rápido sob concorrência paralela. |
| **Retries e Jitter** | Faz retries imediatos em loop fechado (`while (fail) { retry }`), o que derrubaria o servidor externo. | Implementa o backoff exponencial de forma matemática simples, porém esquece de adicionar jitter aleatório. | Implementa a fórmula completa de Full Jitter para evitar sincronia de requisições falhas; separa erros recuperáveis (503/Timeout) dos não-recuperáveis (400 Bad Request) e encaminha corretamente para a DLQ. |
| **Shutdown** | Mata o processo abruptamente (`os.Exit`), perdendo todas as transações que estavam na memória do buffer. | Drena o buffer de forma síncrona, mas o processo pode travar indefinidamente se a API externa demorar a responder. | Garante encerramento gracioso com controle de contexto e timeout de cancelamento. Trata o cancelamento propagando o sinal para as requisições em andamento da API externa. |

---

[Ir para a Etapa 5: Leadership & Systemic Impact ](./05-leadership-systemic-impact.md)
