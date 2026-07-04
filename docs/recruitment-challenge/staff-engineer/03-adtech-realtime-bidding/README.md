# 📢 Trilha 3: AdTech Real-Time Bidding (Leilões de Ultra Latência)

Esta trilha foca em sistemas de latência crítica extrema. No ecossistema de AdTech, o leilão de um anúncio na web precisa acontecer em menos de **100 milissegundos ponta a ponta** (incluindo ida e volta da rede), exigindo que a tomada de decisões no servidor ocorra em sub-10ms.

---

## 🗺️ O Pipeline de Contratação

1. **[Etapa 1: Recruiter Phone Screen](./01-recruiter-screening.md)**
   * *Responsável:* Gaby.
   * *Foco:* Capacidade de comunicação com stakeholders de negócio e foco em eficiência financeira.
2. **[Etapa 2: Technical Screening](./02-technical-screening.md)**
   * *Responsável:* Senior Engineer.
   * *Foco:* Gerenciamento de memória de baixo nível (GC tuning, alocação de objetos), protocolos de rede de alta velocidade (HTTP/3, UDP) e serialização binária (Protobuf/FlatBuffers).
3. **[Etapa 3: System Design Onsite](./03-system-design-onsite.md)**
   * *Responsável:* Staff Engineer (Alex).
   * *Foco:* Projeto de arquitetura do **Motor de Leilão Real-Time Bidding (RTB)** com gerenciamento de orçamentos (*budget pacing*) distribuído.
4. **[Etapa 4: Coding & Latency Onsite](./04-coding-bidding-onsite.md)**
   * *Responsável:* Staff Engineer.
   * *Foco:* Implementação de um selecionador de ofertas concorrente com filtragem ultrarápida por critérios de exclusão e orçamento.
5. **[Etapa 5: Leadership & Systemic Impact Onsite](./05-leadership-systemic-impact.md)**
   * *Responsável:* Director of Engineering.
   * *Foco:* Gestão de custos astronômicos de infraestrutura em nuvem vs. margem de retorno de negócio do leilão.
