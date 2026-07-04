# 👥 Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Diretor de Engenharia & Staff+ Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Liderança técnica por influência, gestão de risco, priorização estratégica de débito técnico, gestão de conflitos e cultura de post-mortem sem culpa (*blameless post-mortem*).

---

## 🎯 Por que Avaliar Liderança e Impacto Sistêmico?

No nível de **Staff Software Engineer**, a habilidade de escrever código excelente é o patamar mínimo (*baseline*). O diferencial competitivo de um Staff é a sua **alavancagem organizacional**: como ele atua como multiplicador de força para a organização de engenharia, ajudando a definir rumos tecnológicos e mentando a próxima geração de líderes técnicos.

Esta entrevista é conduzida na forma de uma discussão baseada em cenários reais que o candidato viveu (passado) ou simulações de desafios corporativos complexos (presente).

---

## 🗺️ Cenários Práticos de Discussão e Respostas Esperadas

O entrevistador deve propor os cenários abaixo e guiar a conversa com base nas respostas do candidato.

### Cenário 1: Priorização Estratégica e Débito Técnico
> *"O sistema de billing principal da empresa é um monolito de 6 anos de idade, difícil de testar e com deploys mensais lentos. O time de produto precisa lançar um novo recurso de pagamento recorrente urgente para bater a meta do trimestre, mas o time de engenharia está farto e exige parar tudo por 3 meses para reescrever o sistema em microsserviços. Como você atua nesse cenário?"*

* **O que o entrevistador busca na resposta Staff:**
  * **Alinhamento de Negócio:** O candidato deve rejeitar a ideia de "parar a empresa por 3 meses para reescrever". Ele reconhece que a tecnologia serve ao negócio.
  * **Estratégia Incremental:** Sugerir padrões de migração de arquitetura como o **Strangler Fig Pattern (Padrão Figo Estrangulador)**. Propõe implementar a nova feature de recorrência já no modelo desacoplado (microsserviço ou módulo isolado) enquanto estrangula o monolito aos poucos.
  * **Negociação e Trade-offs:** Capacidade de negociar com a gestão de produto um percentual fixo da capacidade do time (ex.: 20% do sprint) dedicado à refatoração contínua de partes críticas, apresentando métricas claras (ex.: tempo de deploy reduzido de 1 mês para 1 dia).

### Cenário 2: Mediação de Conflitos Técnicos Profundos
> *"Dois engenheiros seniores do seu grupo de produtos estão em um impasse técnico profundo sobre a escolha de tecnologia para um novo barramento de mensagens de tempo real: um quer usar Apache Kafka (altamente escalável, mas complexo operacionalmente) e o outro quer usar AWS SQS (simples de usar, serverless, mas com limitações de ordenação global e custo sob escala extrema). O debate travou a entrega e causou animosidade entre eles. Como você resolve isso?"*

* **O que o entrevistador busca na resposta Staff:**
  * **Abordagem Neutra e Guiada por Dados:** O candidato não toma um lado imediatamente baseado em sua preferência pessoal. Ele assume o papel de facilitador.
  * **Instituição de Processos de Decisão:** Introduzir o uso de **ADRs (Architecture Decision Records)** ou **RFCs (Request for Comments)** estruturados, listando requisitos funcionais e não-funcionais (escala esperada do produto, custos, capacidade operacional do time de infraestrutura).
  * **Liderança Situacional:** Caso o impasse persista mesmo após a análise de dados, o Staff assume a responsabilidade de tomar a decisão final (*Disengage and Commit*), explicando as razões técnicas com transparência para manter a moral do time alta.

### Cenário 3: Resiliência Cultural e Blameless Post-Mortem
> *"Durante um deploy crítico de migração de banco de dados na sexta-feira à noite, o script falhou em produção, causando corrupção parcial de dados e deixando a plataforma offline por 4 horas globais. O clima na empresa é tenso, com diretores buscando culpados. Como você lidera a investigação pós-incidente?"*

* **O que o entrevistador busca na resposta Staff:**
  * **Cultura Sem Culpa (Blameless):** O candidato foca em falhas de processos e ferramentas, nunca em pessoas. Frases como "quem errou deve ser treinado" são sinais vermelhos. A resposta deve ser: "como permitimos que um único erro humano causasse uma queda de 4 horas?".
  * **Técnica de 5 Porquês:** Ir além do sintoma superficial (ex.: "o desenvolvedor rodou a query errada") até a causa raiz de processo (ex.: falta de validação em Staging, ausência de testes de rollback automatizados ou falta de permissões restritas em produção).
  * **Ações Corretivas Sistêmicas:** Estabelecer planos de ação pragmáticos (ex.: automação de migrações com pipelines CI/CD de validação de schemas, estratégias de deploy Blue-Green, e documentação de planos de contingência).

---

## ⚖️ Critérios de Avaliação (Rubrica de Maturidade)

| Competência | 🟥 Red Flag (Reprovar) | 🟨 Senior Engineer (L5) | 🟩 Staff Engineer (L6+) |
| :--- | :--- | :--- | :--- |
| **Visão Estratégica** | Quer reescrever tudo do zero sem considerar o impacto financeiro ou de cronograma da empresa. | Entende a importância de refatorar de forma incremental, mas tem dificuldades para convencer stakeholders não-técnicos (produto). | Conecta decisões arquiteturais ao impacto financeiro e metas de crescimento do negócio. Fala a linguagem da liderança e da engenharia. |
| **Resolução de Conflitos** | Evita conflitos ou impõe sua própria opinião técnica ignorando os pontos de vista do time. | Tenta mediar, mas tende a delegar a decisão final para um gerente de engenharia para evitar desgaste pessoal. | Facilita a resolução técnica usando dados estruturados (ADRs/RFCs) e assume a liderança para decidir quando o time está paralisado. |
| **Cultura de Engenharia** | Aponta dedos em incidentes; vê a engenharia como um grupo de pessoas que "apenas executa tarefas". | Executa post-mortems padrão, mas foca principalmente em corrigir o bug específico em vez do sistema como um todo. | Promove ativamente a cultura de Blameless Post-Mortem. Eleva a barra de segurança da engenharia criando ferramentas e guardrails para que erros bobos não cheguem a produção. |

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
