# 💻 Etapa 4: Coding & Resilience Onsite - Simulador de Gateway de Vídeo Concorrente

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Concorrência multi-thread, controle de banda (Throttling) e backpressure reativo sob I/O de rede.

---

## 🎯 O Enunciado do Desafio

Em servidores de streaming, quando o cliente (player) inicia a reprodução, ele costuma solicitar os chunks de vídeo o mais rápido possível. No entanto, se o usuário fechar o vídeo após os primeiros segundos, toda a banda de download utilizada para baixar os chunks em segundo plano que não foram assistidos é desperdiçada, gerando custos de egress injustificados.

O candidato deve implementar, na linguagem de sua preferência (ex.: Go, Java, Python ou C#), um **Simulador de Gateway de Vídeo Concorrente** que lê um fluxo de bytes simulado (chunks) e o repassa para uma conexão de cliente, aplicando controle de banda dinâmica (Throttling) e backpressure para não saturar o buffer e evitar o consumo excessivo de dados não visualizados.

---

## 🛠️ Requisitos Técnicos do Desafio

O candidato deve projetar a classe/estrutura `VideoStreamGateway` atendendo às seguintes regras:

### 1. Limitação Dinâmica de Banda (Throttling)
* O gateway deve ler blocos de bytes simulando a leitura de arquivos e transmiti-los ao cliente.
* O fluxo deve ser limitado a uma taxa máxima de **$B$ bytes por segundo** (ex: limitar o download a 1.2x do bitrate do vídeo) de forma precisa, sem causar oscilações severas de latência.

### 2. Controle Concorrente Multi-Conexão
* O gateway deve suportar múltiplas threads ou conexões concorrentes lendo fluxos de vídeos diferentes ou o mesmo vídeo, aplicando o limite de throttling de forma independente por conexão de usuário.

### 3. Backpressure no Buffer
* A conexão do cliente possui um buffer limitado de recepção.
* Se a conexão de rede do cliente ficar lenta, o gateway deve pausar imediatamente a leitura e o processamento local (backpressure) em vez de continuar gerando cache em memória RAM local, evitando estouro de buffer (*Out Of Memory*).

### 4. Desconexão Abrupta e Limpeza
* Caso o cliente feche a conexão a qualquer momento, o gateway deve encerrar imediatamente todas as tarefas associadas àquela sessão de streaming, liberando os recursos locais (file descriptors, sockets simulados e buffers) sem vazamentos de memória.

---

## 📝 Esboço de Assinaturas Esperadas (Interface Conceitual)

Exemplo de estrutura conceitual (usando assinaturas próximas ao padrão Go/Java):

```go
type VideoChunk struct {
    Data []byte
}

type ChunkReader interface {
    ReadNext() (VideoChunk, error)
}

type ClientConnection interface {
    Write(data []byte) error
    Close() error
    IsWritable() bool // Rastreia se o buffer de escrita da rede está livre
}

type VideoStreamGateway interface {
    // StreamVideo inicia a transmissão do leitor de chunks aplicando throttling e backpressure
    StreamVideo(ctx context.Context, reader ChunkReader, conn ClientConnection, maxBytesPerSec int) error
}
```

---

## ⚖️ Rubrica de Avaliação de Engenharia Prática

| Tópico | 🟥 Red Flag (Reprovar) | 🟨 Senior Engineer (L5) | 🟩 Staff Engineer (L6+) |
| :--- | :--- | :--- | :--- |
| **Throttling de Banda** | Usa um loop fechado sem delay ou faz sleep fixo que não acompanha dinamicamente o volume real de dados transmitidos. | Implementa algoritmo de Token Bucket ou Leaky Bucket associado à contagem de bytes transmitidos, regulando o fluxo com temporizadores nativos. | O cálculo de throttling é altamente preciso sob rajadas, contabilizando a diferença temporal de nanosegundos; evita drifts temporais acumulados. |
| **Backpressure** | Continua lendo chunks infinitamente da origem e salvando na memória da aplicação, ignorando a saturação ou lentidão do cliente. | Verifica o estado da conexão e pausa/retoma o fluxo usando locks simples ou sinalizadores de barramento. | Implementa controle assíncrono não-bloqueante de fluxo, travando a leitura física do canal somente quando o buffer de escrita do kernel do cliente estiver cheio. |
| **Vazamento de Recursos** | Sockets de conexões caídas continuam ativos na memória em threads órfãs consumindo recursos de CPU. | Detecta o encerramento do canal e cancela as loops internas, liberando a maior parte dos recursos. | Utiliza tratamento robusto de cancelamento de contexto propagado em cascata; garante que 100% de conexões órfãs ou lentas sofram timeout e tenham seus buffers retornados ao pool imediatamente. |
