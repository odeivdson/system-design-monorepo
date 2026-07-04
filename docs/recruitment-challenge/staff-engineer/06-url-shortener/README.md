# 🔗 Trilha 6: URL Shortener & Analytics Platform (Encurtador de URLs)

Esta trilha aborda o clássico desafio do encurtador de links, mas sob uma lente de altíssima escala e controle de tráfego. O foco está em desenhar e programar sistemas otimizados para volumes massivos de leitura (redirecionamentos) com baixa latência, enquanto capturamos de forma assíncrona métricas analíticas de cliques sem degradar o tempo de resposta do usuário.

---

## 🗺️ O Pipeline de Contratação

1. **[Etapa 1: Recruiter Phone Screen](./01-recruiter-screening.md)**
   * *Responsável:* Gaby.
   * *Foco:* Gestão de abusos operacionais (phishing/spam) e cooperação estratégica com times jurídicos e de segurança da informação.
2. **[Etapa 2: Technical Screening](./02-technical-screening.md)**
   * *Responsável:* Senior Engineer.
   * *Foco:* Comportamento de redirecionamentos HTTP (301 vs 302), algoritmos de hashing, codificação Base62 e DNS resolve latency.
3. **[Etapa 3: System Design Onsite](./03-system-design-onsite.md)**
   * *Responsável:* Staff Engineer (Alex).
   * *Foco:* Projeto de arquitetura da **Plataforma Global de Redirecionamento e Analytics** (100k QPS leitura, KGS distribuído, processamento analítico assíncrono).
4. **[Etapa 4: Coding & Concurrency Onsite](./04-coding-shortener-onsite.md)**
   * *Responsável:* Staff Engineer.
   * *Foco:* Implementação de um gerador de tokens e encurtador de URLs thread-safe resiliente a colisões de hash locais.
5. **[Etapa 5: Leadership & Systemic Impact Onsite](./05-leadership-systemic-impact.md)**
   * *Responsável:* Director of Engineering.
   * *Foco:* Resolução de campanhas de ataque cibernético massivas via URLs curtas maliciosas e gerenciamento de cache global sob tráfego severo.
