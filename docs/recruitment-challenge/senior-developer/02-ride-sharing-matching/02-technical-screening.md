# 🖥️ Dev Senior - Trilha 2 - Etapa 2: Technical Screening

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Protocolos de rede, APIs assíncronas e concorrência básica segura.

---

## 💬 Q&A - Fundamentos de Desenvolvimento Web e Concorrência (20 min)

### Tópico A: Comunicação em Tempo Real e Redes
* **Pergunta:** "Se precisamos atualizar a posição de um carro na tela do passageiro continuamente, quais as diferenças de overhead de rede e limitações de fazer HTTP Polling curto a cada 2s vs. usar Server-Sent Events (SSE)?"
* **Esperado:** 
  * HTTP Polling exige novas conexões TCP/TLS a cada requisição, gerando alto overhead nos servidores e na bateria do celular do cliente.
  * SSE abre uma única conexão HTTP persistente unidirecional de longa duração, ideal para streams do servidor para o cliente de forma leve.

### Tópico B: Mutexes vs. Canais/Fila
* **Pergunta:** "Quando você escolhe proteger uma coleção na memória usando travas Mutex tradicionais e quando prefere usar canais (Go Channels) ou filas de tarefas para trocar dados entre threads?"
* **Esperado:** 
  * Mutexes: melhor para acessar e atualizar variáveis de estado simples na memória rapidamente de forma granular.
  * Canais/Filas: melhor para passar propriedade de dados ou coordenar fluxos de trabalho e tarefas de forma assíncrona (*pipeline processing*).

---

## 🛠️ Mini-Desafio: Validador de Atualizações de Localização (30 min)
* **Cenário:** Escreva o código que valide coordenadas recebidas do app do motorista (rejeitar latitude/longitude inválidas e pings duplicados num intervalo de 1s), protegendo a coleção na memória concorrente de forma thread-safe.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
