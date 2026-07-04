# 👥 Trilha 3 - Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Relação custo-benefício de infraestrutura vs. margem de negócio, influência técnica em decisões de larga escala e gestão de recursos de nuvem.

---

## 🗺️ Cenários para Discussão

### Cenário 1: O Custo de Cloud vs. Faturamento
> *"Sua equipe propõe expandir o cluster de leilão para processar 2 milhões de RPS (o dobro do tráfego atual) para capturar mais mercado. Porém, a fatura de nuvem (GCP/AWS) estimada da expansão é de R$ 500.000 mensais extras, enquanto a estimativa de faturamento de anúncios adicionais capturados é de apenas R$ 400.000 (prejuízo operacional). Como você, como Staff Engineer, guia o time técnico e de negócios para resolver esse impasse?"*

* **Respostas Esperadas do Candidato:**
  * **Filtros Inteligentes na Borda (Edge Pruning / Request Filtering):** Propor a implementação de modelos de classificação rápida na borda (usando infraestrutura barata de filtragem) para rejeitar requisições de leilão de tráfego com baixa probabilidade de conversão ou de usuários irrelevantes antes que eles toquem nossos servidores caros.
  * **Otimização de Hardware:** Sugerir compilar o binário em arquiteturas eficientes como ARM64 (ex.: AWS Graviton) para economizar até 40% em custos de computação mantendo o mesmo throughput.

### Cenário 2: Tomada de Decisão Tecnológica Incompatível
> *"O arquiteto chefe de infraestrutura quer migrar todos os caches Aerospike locais em memória para um banco de dados relacional gerenciado único na nuvem para centralizar os dados e simplificar a operação. Essa decisão vai aumentar a latência de acesso de 1ms para 15ms. Como você gerencia essa discussão e reverte a decisão sem causar animosidade política?"*

* **Respostas Esperadas do Candidato:**
  * **Foco em Métricas Frias e SLA:** Demonstrar quantitativamente (através de testes de carga controlados e simulação de concorrência) que aumentar a latência para 15ms no acesso a dados fará com que o sistema estoure o SLA de 10ms da Ad Exchange, gerando perda imediata de 100% de lances válidos de anúncios.
  * **Educação e Parceria:** Trabalhar em parceria com o time de infraestrutura para encontrar formas alternativas de simplificar a operação (ex.: automatizar o provisionamento do Aerospike via Terraform/Kubernetes) mantendo os requisitos cruciais de latência.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
