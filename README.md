# System Design & High-Performance Algorithms Monorepo

Este monorepo centraliza soluções práticas, especificações técnicas e desafios voltados para problemas complexos de sistemas distribuídos, alta concorrência, resiliência de software e algoritmos de infraestrutura. 

> [!NOTE]
> **Aviso de Propósito**: Este repositório é de caráter estritamente **pessoal para fins de treinamento, estudo e desenvolvimento de engenharia**. As especificações, desafios e soluções aqui presentes não possuem qualquer viés, ligação ou representação de alguma empresa de tecnologia específica.

O conteúdo é modelado sob a perspectiva de engenharia de software avançada (Senior, Tech Lead, Especialista e Staff/Principal), focando no entendimento de trade-offs reais de hardware, rede, I/O e consistência de dados.

---

## 🛠️ Princípios de Engenharia

- **Pragmatismo**: Desenvolver soluções diretas que equilibram perfeitamente tempo de entrega, custo de manutenção e robustez de código.
- **Resiliência Nativa**: Tolerância a falhas parciais implementada de forma explícita (circuit breakers, retries com backoff/jitter, idempotência e isolamento).
- **Entendimento sob Concorrência**: Todas as soluções são pensadas para operar sob concorrência agressiva de threads e dados (sincronização de granularidade fina, concorrência lock-free baseada em CAS e localidade de cache).

---

## 📁 Estrutura do Repositório

O repositório está organizado de forma modular, dividindo as especificações conceituais e os códigos práticos:

```plainText
├── apps/                  # Aplicações e Provas de Conceito (POCs) funcionais
├── packages/              # Bibliotecas compartilhadas (ex: core de resiliência e utilitários)
│   └── core-resilience/
├── scripts/               # Scripts de utilidade e governança de repositório
│   └── validate_links.ps1
└── docs/                  # Guias conceituais e desafios de engenharia divididos por tema
    ├── recruitment-challenge/ # Portal central de desafios de recrutamento e entrevistas
    │   ├── senior-developer/  # Desafios focados no nível Dev Senior (L5)
    │   ├── tech-lead/         # Desafios focados no nível Tech Lead (L5/L6)
    │   ├── staff-engineer/    # Desafios focados no nível Staff Engineer (L6+)
    │   └── interview-prep/    # Perguntas & Respostas de simulação de entrevistas de elite (Q&A)
    ├── microservices/     # Padrões de microsserviços e sistemas distribuídos
    │   ├── 01-rate-limiter-local/
    │   ├── ...
    │   ├── 19-distributed-workflow-coordinator/
    │   └── microservices-patterns-training.md  <-- Guia Principal de Microsserviços
    └── algorithms/        # Algoritmos de alta performance e estruturas concorrentes
        ├── 01-threadsafe-lru-cache/
        ├── ...
        ├── 19-hyperloglog-cardinality/
        └── README.md                           <-- Guia Principal de Algoritmos
```

---

## 🧭 Guias de Treinamento Principais

Para iniciar seus estudos, navegue pelos índices e matrizes de cobertura dos dois tópicos fundamentais:

* **[Guia de Microsserviços & System Design](./docs/microservices/microservices-patterns-training.md)**: Mapeamento de 31 padrões de arquitetura distribuída, cobrindo desde API Gateways e Sagas até mecanismos de isolamento multi-tenant, migração ao vivo sem downtime e transações distribuídas (TCC).
* **[Guia de Algoritmos & Concorrência](./docs/algorithms/README.md)**: Mapeamento de 23 estruturas de dados e algoritmos de alta performance, cobrindo os 15 padrões de código essenciais (como Sliding Window e Topological Sort) e 8 estruturas avançadas de Big Techs (como LSM-Tree, HyperLogLog, CAS SkipList e Quadtree Concorrente).
* **[Portal de Desafios de Recrutamento (Multi-Nível)](./docs/recruitment-challenge/README.md)**: Simulações ponta a ponta de processos seletivos de Big Tech (Tech Recruiter & Staff Engineer), englobando triagem, Q&A técnico, desafios Onsite de arquitetura/código e liderança divididos por níveis (Senior Developer, Tech Lead e Staff Engineer).
* **[Guia de Simulação de Entrevistas Staff (Q&A de Elite)](./docs/recruitment-challenge/interview-prep/staff-drill-qa.md)**: Sessão prática de perguntas e respostas técnicas aprofundadas sobre os cenários mais complexos do monorepo (como concorrência Pix, limitações Dataprev, race conditions de cache híbrido, fency tokens e pointer tagging).


---

## 🚀 Como Validar a Integridade das Referências

Para garantir que todos os links e caminhos cruzados entre os desafios e os guias estejam saudáveis, o monorepo conta com um script de validação de referências em lote:

```powershell
# Executar o validador de links locais
powershell -ExecutionPolicy Bypass -File ./scripts/validate_links.ps1
```

*(Nota: O script varre recursivamente todos os arquivos `.md` garantindo que as conexões entre os desafios permaneçam consistentes).*
