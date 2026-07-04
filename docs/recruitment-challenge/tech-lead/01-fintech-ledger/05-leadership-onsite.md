# 👥 Tech Lead - Trilha 1 - Etapa 5: Leadership Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração:** 60 minutos
* **Foco:** Divisão de projetos (Slicing), estimativas, gestão técnica de sprints e facilitação de conflitos em equipe.

---

## 🗺️ Cenários Práticos de Liderança de Equipe

### Cenário 1: Slicing e Planejamento de Projeto (Foco Executivo e Ágil)
> *"Sua equipe precisa migrar a integração de pagamentos legada para um novo provedor global mais barato. A equipe estima que o projeto total levará 3 meses. A diretoria de produto não aceita ficar 3 meses sem lançar novas funcionalidades e exige entregas incrementais. Como você divide tecnicamente (slicing) essa migração em entregas menores que gerem valor a cada duas semanas?"*

* **Respostas Esperadas do Candidato:**
  * **Estratégia de Slicing Vertical:** Sugerir migrar primeiro apenas uma fatia pequena do tráfego (ex.: pagamentos com cartão de crédito de apenas um país ou de uma categoria de usuário de baixo risco).
  * **Feature Flags:** Usar chaves de funcionalidade (*feature toggles*) para subir a nova integração desligada e testar em produção de forma transparente com deploys contínuos, ativando gradualmente (Canary Release).

### Cenário 2: Negociação de Débito Técnico com Gerente de Produto
> *"O Product Manager (PM) quer lançar uma nova carteira digital imediatamente para bater a meta de crescimento de usuários. No entanto, o sistema atual de conciliação de banco está sobrecarregado, gerando travamentos constantes que exigem suporte manual diário dos desenvolvedores seniores do time. Como você negocia a priorização técnica para resolver essa sobrecarga com o PM?"*

* **Respostas Esperadas do Candidato:**
  * **Tradução em Métricas Financeiras/Tempo:** Apresentar dados quantitativos de desperdício do time (ex.: "nossos seniores perdem 15 horas semanais apenas corrigindo saldo na mão; se corrigirmos a causa raiz, poderemos acelerar o desenvolvimento da nova carteira digital em 25% a partir do próximo mês").
  * **Alocação Saudável:** Propor um acordo de percentual fixo da sprint (ex.: 80% produto, 20% engenharia/melhorias técnicas contínuas).

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
