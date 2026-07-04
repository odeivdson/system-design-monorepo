# 👥 Tech Lead - Trilha 3 - Etapa 5: Leadership Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração:** 60 minutos
* **Foco:** Priorização estratégica de melhorias técnicas, governança de código de equipe, facilitação técnica e negociação de escopo técnico.

---

## 🗺️ Cenários Práticos de Liderança

### Cenário 1: Gerenciamento e Pagamento de Débito Técnico
> *"O encurtador de URLs do time está gerando erros intermitentes de conexão porque a biblioteca HTTP externa usada pelo código é antiga e consome recursos de sockets incorretamente. O time quer reescrever toda a camada de integração HTTP (estimativa: 2 semanas). O Product Manager (PM) quer focar em uma nova tela de relatórios de Growth. Como você atua de forma saudável?"*

* **Respostas Esperadas do Candidato:**
  * **Análise e Solução Focada (Evitar Reescrever Tudo):** Identificar que não é preciso reescrever toda a camada do encurtador, apenas ajustar o pool de conexões (HTTP Connection Pooling) do cliente de forma isolada (trabalho de 1 dia) para resolver o vazamento de sockets.
  * **Negociação Clara:** Explicar ao PM os impactos práticos da falha nos links (perda de clientes e faturamento) e propor a solução focada que atenda aos requisitos de estabilidade sem travar a sprint de produto.

### Cenário 2: Definição e Governança de Padrões Técnicos
> *"Dois desenvolvedores seniores do seu time discordam de forma insistente sobre as regras de code style e padrões de validação de dados da API. Pull requests estão travados porque eles ficam discutindo sobre formatação e se devem usar validação com decorators ou manual. Como Tech Lead, como você destrava a equipe?"*

* **Respostas Esperadas do Candidato:**
  * **Automação de Code Style (Linter):** Sugerir definir e configurar um linter automatizado no pipeline CI/CD (ex.: Prettier, ESLint, GoFmt) para que formatação não seja discutida em reuniões ou PRs.
  * **Sessão de Alinhamento Rápido:** Reunir os engenheiros em uma sala, listar os prós e contras das abordagens de validação e formalizar a decisão de forma documentada (ADR) para que o time siga um padrão único e unificado a partir dali.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
