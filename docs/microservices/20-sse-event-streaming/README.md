# Desafio 20: Streaming de Eventos via Server-Sent Events (`sse-event-streaming`)
> **Padrões de Microsserviços Associados:** Server-Sent Events (SSE), Event Streaming, Stateless Services, Smart Endpoints, HTTP Push, Reactive Streams.

## 1. Contexto & Cenário
Em plataformas de microsserviços e painéis em tempo real (como acompanhamento de status de entregas de comida, telemetria de frotas de veículos ou alertas operacionais de segurança), a latência no recebimento de atualizações de estado é crítica para a experiência do usuário. 

O polling HTTP tradicional (`GET /status` recorrente) gera uma contenda brutal de recursos: handshakes TLS repetitivos, sobrecarga na CPU das instâncias da API, e tráfego massivo e desnecessário na rede. Por outro lado, manter canais bidirecionais via WebSockets adiciona complexidade ao protocolo (exige transição de protocolo HTTP para WS, tratamentos complexos de handshake e gerenciamento de conexões ativas stateful na memória).

O **Server-Sent Events (SSE)** é o padrão intermediário ideal para transmissões **unidirecionais** (do servidor para o cliente). Utilizando o protocolo HTTP/1.1 ou HTTP/2 padrão com conexões persistentes, o SSE permite que o servidor envie eventos formatados continuamente sob uma única conexão HTTP aberta. O objetivo deste desafio é projetar uma solução de streaming SSE que suporte alta concorrência de clientes simultâneos, gerencie reconexões com histórico de mensagens e evite o vazamento de recursos no servidor.

---

## 2. Requisitos Funcionais (RF)
- **Endpoint de Streaming**: Expor o endpoint `GET /api/v1/stream/events` com o cabeçalho obrigatório `Content-Type: text/event-stream`.
- **Formato de Transmissão**: Cada mensagem enviada deve respeitar o protocolo oficial do SSE, incluindo os campos `id:`, `event:`, `data:`, `retry:` (opcional) e finalizada com duas quebras de linha (`\n\n`).
- **Recuperação de Histórico (Replay)**: Permitir que clientes reconectem e enviem o cabeçalho `Last-Event-ID`. O servidor deve ser capaz de reenviar as mensagens perdidas durante o período de desconexão.
- **Mecanismo de Keepalive (Heartbeat)**: Enviar um ping com formato de comentário (`: keepalive\n\n`) a cada 15 segundos se nenhum evento real for disparado, impedindo que roteadores e proxies de rede (como Nginx ou Cloudflare) encerrem a conexão por ociosidade.
- **Filtragem por Tenant**: Filtrar eventos na origem com base em chaves de sessão (`?tenantId={tenantId}&userId={userId}`), garantindo isolamento estrito de dados entre inquilinos.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Concorrência Não-Bloqueante (High Concurrency)**: O serviço deve ser projetado com I/O assíncrono. Não é permitido alocar ou bloquear uma thread do sistema operacional (Thread-per-Connection) para cada cliente conectado.
- **Gestão Segura de Backpressure (Limitação de Memória)**: Estabelecer buffers delimitados (bounded queues) de tamanho configurável (ex: máximo de 100 mensagens) por cliente. Se um cliente lento não consumir o stream e o buffer estourar, o servidor deve descartar os eventos mais antigos (*drop-oldest*) e registrar o descarte para evitar estouro de memória (Out-Of-Memory).
- **Limpeza Automática de Recursos (Leak Prevention)**: No momento em que um cliente desconecta (detectado pelo cancelamento do request HTTP pelo cliente ou timeout de rede), o servidor deve imediatamente liberar todas as inscrições no broker de eventos e desalocar buffers de memória associados.
- **Autenticação Pre-stream**: A verificação de tokens e escopos de acesso deve ocorrer obrigatoriamente antes de abrir o canal de streaming para evitar consumo desnecessário de sockets por conexões não autorizadas.

---

## 4. Guia de Implementação & Padrões

### Arquitetura de Event Streaming via SSE

```
                                [ Arquitetura de Event Streaming via SSE ]
    
        ┌──────────┐ (1. GET /api/v1/stream/events)
        │  Client  ├──────────────────────────────────┐
        └────▲─────┘                                  │
             │ (5. Stream de Eventos Contínuo)         ▼
             │                            ┌───────────────────────┐
             │                            │     API Gateway /     │
             │                            │    Load Balancer      │
             │                            └───────────┬───────────┘
             │                                        │ (2. Proxy Connection)
             │                                        ▼
             │                            ┌───────────────────────┐
             │                            │     SSE Streamer      │
             │                            │   (IAsyncEnumerable / │
             │                            │    HTTP Connection)   │
             └────────────────────────────┤                       │
                                          └───────────▲───────────┘
                                                      │ (3. Inscreve com filtros)
                                                      │
                                          ┌───────────┴───────────┐
                                          │   In-Memory Broker    │
                                          │    (Event Hub/Bus)    │
                                          └───────────▲───────────┘
                                                      │ (4. Publica Evento)
                                          ┌───────────┴───────────┐
                                          │  Produtores / Fila    │
                                          └───────────────────────┘
```

### Padrão de Implementação Recomendado (C# / .NET Core):
Em plataformas como o .NET, a forma ideal de expor streams assíncronos não-bloqueantes sem reter threads do pool é utilizando `IAsyncEnumerable<T>` acoplado a um `CancellationToken` de cancelamento de requisição (`HttpContext.RequestAborted`).

```csharp
[HttpGet("api/v1/stream/events")]
public async Task GetEventsStream([FromQuery] string tenantId, [FromQuery] string userId, CancellationToken cancellationToken)
{
    // 1. Validar e autenticar antes de abrir a conexão
    if (string.IsNullOrEmpty(tenantId) || !User.HasTenantAccess(tenantId))
    {
        Response.StatusCode = StatusCodes.Status403Forbidden;
        return;
    }

    // 2. Definir os cabeçalhos obrigatórios do protocolo SSE
    Response.Headers.Add("Content-Type", "text/event-stream");
    Response.Headers.Add("Cache-Control", "no-cache");
    Response.Headers.Add("Connection", "keep-alive");

    // 3. Capturar Last-Event-ID (se fornecido pelo cliente)
    if (Request.Headers.TryGetValue("Last-Event-ID", out var lastEventId))
    {
        await ReplayMissedEvents(Response.Body, lastEventId, tenantId, cancellationToken);
    }

    // 4. Inscrever-se no broker interno para escutar eventos
    using var subscription = _eventBroker.Subscribe(tenantId, userId);

    try
    {
        // 5. Loop de transmissão assíncrona
        while (!cancellationToken.IsCancellationRequested)
        {
            // Aguarda o próximo evento do buffer local de forma não-bloqueante
            var sseEvent = await subscription.Buffer.Reader.ReadAsync(cancellationToken);

            // Formata a mensagem no padrão oficial do protocolo SSE
            var payload = $"id: {sseEvent.Id}\nevent: {sseEvent.Type}\ndata: {sseEvent.Data}\n\n";
            
            await Response.WriteAsync(payload, cancellationToken);
            await Response.Body.FlushAsync(cancellationToken); // Força envio dos bytes
        }
    }
    catch (OperationCanceledException)
    {
        // Conexão encerrada de forma esperada pelo cliente/timeout
    }
    finally
    {
        // 6. Limpeza atômica (Unsubscribe) acionada na saída ou em caso de exceção
        subscription.Dispose(); 
    }
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Desalocação Eficiente em Desconexões**: O avaliador testará o encerramento agressivo de centenas de streams de forma simultânea. O serviço deve registrar a desalocação completa das inscrições, sem manter referências ou locks órfãos na memória.
- **Prevenção de Fuga de Memória por Clientes Lentos**: Demonstração explícita de como o buffer local por conexão lida com *Backpressure* (bloquear o envio, descartar mensagens antigas no buffer circular ou desconectar com segurança).
- **Atomicidade no Replay com Last-Event-ID**: Ao retomar conexões, o replay deve ser livre de race conditions (garantir que nenhum evento publicado exatamente no momento da desconexão e reconexão seja duplicado ou perdido).
- **Keepalive Amigável a Proxies**: Envio correto de comentários em texto (`: keepalive\n\n`), evitando que buffers intermediários de proxies (ex: Nginx bufferization) retenham os dados até acumularem um tamanho fixo. O cabeçalho `X-Accel-Buffering: no` deve ser injetado quando aplicável.

---

## 6. Trade-offs

### A. Server-Sent Events (SSE) vs. WebSockets
- **Server-Sent Events (SSE)**:
  - *Pró*: Simplicidade extrema (protocolo HTTP padrão). Suporte nativo de reconexão automática nos navegadores via API `EventSource`. Transpassa firewalls e proxies com mais facilidade.
  - *Contra*: Comunicação estritamente unidirecional (do servidor para o cliente). Limitação de conexões simultâneas no protocolo HTTP/1.1 (máximo de 6 por domínio), o que exige o uso de HTTP/2 ou HTTP/3 para multiplexação de conexões em larga escala.
- **WebSockets**:
  - *Pró*: Canal bidirecional de baixa latência e fluxo contínuo em ambas as direções.
  - *Contra*: Handshake complexo e propenso a falhas em redes corporativas com inspeção profunda de pacotes (DPI). Requer infraestrutura de ping-pong manual para identificar conexões fantasma no servidor.

### B. Buffer In-Memory vs. Armazenamento com Redis/Kafka para Replay
- **Buffer Local em Memória (In-Memory RingBuffer)**:
  - *Pró*: Latência mínima e zero dependências de rede para recuperar mensagens recentes.
  - *Contra*: Perda total do histórico em caso de restart da instância do microsserviço (stateless compromise).
- **Persistência Centralizada (Redis Streams / Apache Kafka)**:
  - *Pró*: Resiliência total. Clientes podem recuperar mensagens mesmo que a instância original de backend tenha caído e a requisição tenha sido roteada para outra réplica.
  - *Contra*: Adiciona latência e I/O extra para cada reconexão de cliente, exigindo leitura distribuída por offset.
