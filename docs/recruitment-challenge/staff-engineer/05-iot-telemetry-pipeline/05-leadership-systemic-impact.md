# 👥 Trilha 5 - Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Gestão de times desfeitos, resiliência a desastres organizacionais de dados, governança de dados e controle de custos de Data Platform.

---

## 🗺️ Cenários para Discussão

### Cenário 1: O Monstro das Queries Ineficientes (Custos de Big Data)
> *"Seu time de Data Platform gerencia um Data Warehouse (ex.: BigQuery / Snowflake) centralizado. Recentemente, a equipe de marketing e analistas de negócios começaram a rodar queries ad-hoc extremamente ineficientes que realizam varreduras completas (full tables scans) em tabelas de petabytes diariamente, fazendo a fatura de nuvem subir R$ 100.000 por semana. O time de marketing diz que precisa das consultas para tomar decisões. Como você atua sistemicamente para resolver isso?"*

* **Respostas Esperadas do Candidato:**
  * **Governança por Cotas e Limites:** Propor a implementação de cotas diárias estritas de custo de queries por time ou usuário, forçando-os a priorizar o que rodam.
  * **Materialização de Views e Criação de Data Marts:** Criar pipelines automatizados de agregação diária/horária que geram tabelas consolidadas menores (Data Marts). Assim, os analistas rodam queries em megabytes de dados pré-agregados em vez de petabytes de dados brutos.
  * **Treinamento e Parceria Técnica:** Dedicar tempo de Staff Engineer para treinar as lideranças analíticas dos outros times em melhores práticas de particionamento e ordenação de queries.

### Cenário 2: O Pipeline "Órfão" (Herança de Débito Técnico)
> *"A equipe que desenvolveu o pipeline Spark crítico de ingestão de dados de vendas foi dissolvida. O código não possui testes unitários, a documentação é inexistente e o pipeline falha silenciosamente de forma intermitente gerando relatórios de faturamento incorretos para a diretoria. Como você lidera a assunção de controle técnica desse sistema sem desmoronar a moral do seu time atual?"*

* **Respostas Esperadas do Candidato:**
  * **Visibilidade e Observabilidade Primeiro:** Antes de alterar o código, adicionar telemetria e alertas de qualidade de dados (data quality checks) nas saídas e entradas do pipeline para capturar inconsistências de forma visível e imediata.
  * **Defesa de Linha de Base (Baseline Tests):** Criar testes de integração simples na caixa preta (*black-box tests*) usando dados históricos de produção para garantir que refatorações não quebrem o comportamento básico.
  * **Refatoração Incremental Baseada em Valor:** Não reescrever tudo de uma vez. Identificar o componente que mais falha (ex.: a etapa de desduplicação) e refatorá-lo isoladamente.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
