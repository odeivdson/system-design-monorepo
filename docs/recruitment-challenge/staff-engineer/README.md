# 🎯 Central de Desafios de Recrutamento: Staff Software Engineer

Bem-vindo ao repositório de simulações de contratação para posições de **Staff Software Engineer (L6+)** da nossa Big Tech. 

Este espaço reúne **6 trilhas completas de desafios** cobrindo diferentes domínios arquiteturais e de negócios. Cada trilha é autônoma e guia o candidato e os entrevistadores de ponta a ponta: desde a triagem inicial do recrutador até as sessões Onsite presenciais de código, design de sistemas e liderança sistêmica.

---

## 👥 Personas Envolvidas no Processo

* **💼 Gaby (Tech Recruiter):** Avalia inteligência emocional, alinhamento cultural com a organização, liderança sem autoridade formal e gestão de carreira.
* **🛠️ Alex (Staff Engineer):** Conduz o escrutínio técnico em design de sistemas de grande porte, concorrência thread-safe, tratamento de falhas em rede e custos.

---

## 🗺️ As 6 Trilhas de Desafios por Domínio

Selecione abaixo o domínio correspondente à vaga pretendida para visualizar a documentação completa de todas as etapas:

### 💳 [Trilha 1: FinTech Ledger Platform](./01-fintech-ledger/README.md)
* **Domínio:** Finanças e Core Banking.
* **System Design:** Ledger de Transações Financeiras Global e Idempotente.
* **Coding:** Buffer de Processamento Concorrente com Rate Limiting e Retries com Jitter.
* **Liderança:** Padrão Estrangulador em monolitos financeiros legados e gestão de blameless post-mortem.

### 🚗 [Trilha 2: Ride-Sharing Matching & Pricing](./02-ride-sharing-matching/README.md)
* **Domínio:** Mobilidade Urbana e Logística em Tempo Real.
* **System Design:** Motor de pareamento geoespacial de alta concorrência (H3/S2) e precificação dinâmica (*pricing surge*).
* **Coding:** Fila de prioridade geoespacial concorrente para alocação rápida de motoristas.
* **Liderança:** Gestão de incidentes em eventos sazonais massivos de alta demanda e congestionamento de infraestrutura.

### 📢 [Trilha 3: AdTech Real-Time Bidding](./03-adtech-realtime-bidding/README.md)
* **Domínio:** AdTech e Leilões de Ultra Latência.
* **System Design:** Plataforma de leilão em tempo real (DSP/SSP) com SLA de sub-10ms e controle distribuído de orçamentos de anunciantes.
* **Coding:** Motor de leilão concorrente baseado em prioridade com verificação rápida de orçamentos.
* **Liderança:** Negociação com produto sobre custos astronômicos de cloud vs latência operacional de leilões.

### 📝 [Trilha 4: Collaborative Document Editor](./04-collaborative-editor-crdt/README.md)
* **Domínio:** Ferramentas de Produtividade e Sistemas Eventualmente Consistentes.
* **System Design:** Editor colaborativo global usando tipos de dados replicados sem conflito (CRDTs) e Operational Transformation (OT).
* **Coding:** Implementação de um registrador CRDT concorrente (LWW-Element-Set) thread-safe.
* **Liderança:** Migração de arquitetura de sincronização de rede impactando milhões de clientes legados ativos.

### 📟 [Trilha 5: IoT Telemetry & Analytics Pipeline](./05-iot-telemetry-pipeline/README.md)
* **Domínio:** Big Data, Ingestão Industrial e Stream Processing.
* **System Design:** Pipeline de ingestão de telemetria em tempo real para 10M+ de dispositivos industriais com processamento fora de ordem (*out-of-order*).
* **Coding:** Janela deslizante de agregações temporais em memória com suporte a descarte de dados tardios.
* **Liderança:** Lidar com grandes volumes de débito técnico deixados por times de dados desfeitos de forma invisível.

### 🔗 [Trilha 6: URL Shortener & Analytics Platform](./06-url-shortener/README.md)
* **Domínio:** Infraestrutura Web e Analytics em Larga Escala.
* **System Design:** Encurtador de URLs resiliente com KGS (Key Generation Service) em lote, cache distribuído com Master-Slave e pipeline de clickstream assíncrono.
* **Coding:** Gerador de chaves local e cache com política de limpeza concorrente (LRU).
* **Liderança:** Combater ataques em massa de phishing/spam e gerenciar invalidação global de CDN sob tráfego crítico.

---

> [!IMPORTANT]
> **Expectativas Gerais de Nível Staff (L6+)**:
> Em qualquer uma das 6 trilhas, o candidato não será medido apenas pelo sucesso do "caminho feliz" (*happy path*). Ele deve ser capaz de falar com autoridade sobre gerenciamento de riscos sistêmicos, custos operacionais, facilidade de manutenção por outros engenheiros, e o impacto direto das escolhas técnicas nos objetivos estratégicos de negócio da empresa.
