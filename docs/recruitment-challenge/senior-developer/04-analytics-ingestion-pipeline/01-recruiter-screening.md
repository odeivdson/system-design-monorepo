# 📞 Dev Senior - Trilha 4 - Etapa 1: Recruiter Phone Screen

* **Responsável:** Gaby (Tech Recruiter)
* **Duração:** 30 a 45 minutos
* **Foco:** Trajetória individual com sistemas de dados, resiliência sob carga extrema e fit cultural.

---

## 🎯 Perguntas Comportamentais (Metodologia STAR)

### 1. Lidando com Instabilidades em Produção sob Alta Carga (15 min)
* **Pergunta:** "Conte-me sobre um cenário real em que um pipeline de dados ou serviço sob grande tráfego de gravação apresentou gargalo de performance ou falha catastrófica em produção. Quais foram suas ações imediatas para conter o incidente e como você redesenhou o sistema para evitar que o problema ocorresse novamente?"
* **Sinal Verde (Green Flag):** Identificação de gargalos físicos (CPU, I/O de disco, limites de conexão do banco), uso correto de ferramentas de observabilidade (Datadog, Prometheus), proposta de arquiteturas resilientes (ex.: introdução de filas/buffers, redimensionamento de partição ou mudança de estratégia de gravação).
* **Sinal Vermelho (Red Flag):** Soluções temporárias ineficazes (ex.: apenas aumentar o tamanho do servidor indefinidamente sem entender a causa física do gargalo), falta de análise de causa raiz estrutural.

### 2. Qualidade de Entrega vs. Prazos Apertados
* **Pergunta:** "Já passou por uma situação em que precisou entregar um pipeline crítico em um prazo curto mas sabia que a pressa poderia comprometer a qualidade (como cobertura de testes ou validação de concorrência)? Como você negociou esse escopo com o time e o que entregou na prática?"
* **Sinal Verde (Green Flag):** Slicing inteligente de features, comunicação aberta dos riscos, garantia de que os testes essenciais de sanidade/concorrência e a monitoração de alarmes básicos fossem entregues no MVP de forma estável.

---

[Ir para a Etapa 2: Technical Screening ➡️](./02-technical-screening.md)
