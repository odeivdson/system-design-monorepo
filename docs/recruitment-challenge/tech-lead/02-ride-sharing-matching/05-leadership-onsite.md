# 👥 Tech Lead - Trilha 2 - Etapa 5: Leadership Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração:** 60 minutos
* **Foco:** Priorização ágil de incidentes, comunicação de prazos, liderança operacional do time de desenvolvimento e mitigação de bugs em produção.

---

## 🗺️ Cenários Práticos de Liderança

### Cenário 1: Gestão de Incidentes Críticos em Produção
> *"Durante a tarde de um dia chuvoso (pico de demanda), o serviço de despacho do seu time começa a registrar latências altíssimas e time-outs de conexão, fazendo com que 40% das solicitações de corrida falhem. O time de operações da empresa está cobrando uma solução rápida. Como você atua como Tech Lead para diagnosticar e mitigar o problema de forma organizada?"*

* **Respostas Esperadas do Candidato:**
  * **Triagem Organizada do Incidente:** Evitar pânico. Divisão de tarefas: delegar a um engenheiro sênior a análise dos logs/APM (identificar gargalo) e a outro a comunicação de status na sala de guerra.
  * **Aplicação de Mitigação Rápida:** Se o gargalo for sobrecarga de conexões no Redis, propor uma mitigação rápida de contorno (ex.: aumentar temporariamente o tempo de ping do GPS dos apps de 4s para 10s para aliviar I/O) em vez de tentar refatorar código no meio da crise.

### Cenário 2: Débito Técnico Herdado de Outros Times
> *"Seu time assumiu a manutenção de um serviço legado de cálculo de tarifas que vive quebrando e cujo código é extremamente confuso. O time está desmotivado por passar muito tempo corrigindo bugs nesse serviço. Como líder, como você planeja e insere a refatoração desse legado no fluxo de sprints?"*

* **Respostas Esperadas do Candidato:**
  * **Planejamento Técnico e Argumentação:** Criar um backlog do débito técnico listando as partes mais problemáticas e os impactos operacionais delas.
  * **Refatoração Incremental e Conquistas Rápidas (Quick Wins):** Dividir em pequenas melhorias que facilitem os deploys imediatos do time, em vez de planejar uma reescrita total que travaria o time por meses.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
