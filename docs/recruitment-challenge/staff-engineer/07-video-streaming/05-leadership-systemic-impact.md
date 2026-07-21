# 👥 Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Director of Engineering & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Liderança por influência, gestão de custos de infraestrutura vs metas de produto e resolução de incidentes sistêmicos sob estresse.

---

## 🎯 O Cenário da Simulação de Liderança

Após o lançamento de um seriado de grande audiência, a empresa bateu o recorde histórico de usuários ativos, mas os custos operacionais de cloud com a CDN explodiram em $400\%$, consumindo toda a margem de lucro projetada para o trimestre.

O time de infraestrutura quer limitar a qualidade máxima de vídeo para 720p em dispositivos móveis imediatamente para conter o prejuízo. O time de produto e negócios é radicalmente contra, afirmando que a perda de qualidade levará ao cancelamento em massa de assinaturas e danos à reputação da marca.

Como Staff Engineer, você está no centro dessa crise e precisa liderar uma solução técnica que equilibre ambos os lados.

---

## 🎯 Perguntas do Entrevistador e Comportamentos Esperados

### 1. Mediação de Conflito Técnico
* **Pergunta**: "Como você conduziria a reunião de alinhamento com o VP de Produto e o Diretor de Infraestrutura para evitar que a discussão se torne um jogo de acusações?"
* **Comportamento Esperado**: O candidato deve focar na obtenção de dados objetivos. Sugerir a criação de um modelo de simulação financeira rápida demonstrando que diminuir a qualidade não é a única alavanca (ex.: mostrar dados de que o uso de codecs mais eficientes ou o sharding inteligente de CDN trará resultados similares sem degradar a experiência visual).

### 2. Influência e Visão Sistêmica
* **Pergunta**: "Se a diretoria decidir prosseguir com o limite temporário de 720p em rede celular, como você desenharia um plano de transição para mitigar o impacto técnico e restabelecer a qualidade 4K gradualmente?"
* **Comportamento Esperado**: O candidato de nível Staff deve propor uma estratégia de **rollout progressivo (Feature Flags)**, testagem A/B do impacto real na taxa de retenção de clientes e automação do processo com base na qualidade da conexão local de cada usuário (Adaptive Degradation), em vez de uma limitação fixa e estática.

---

## ⚖️ Rubrica de Avaliação de Liderança

* **🟥 Red Flag**:
  * Tomar o lado da infraestrutura cegamente ignorando os objetivos de negócio ("eu desligo a resolução e pronto, custos são mais importantes").
  * Falta de tato diplomático ou incapacidade de lidar com a pressão de stakeholders de nível C.
* **🟩 Staff L6+**:
  * Propõe soluções estruturadas de compromisso (win-win) baseadas em engenharia avançada (ex.: compressão de vídeo dinâmica, caching de pré-aquecimento inteligente).
  * Consegue liderar a sala, acalmar os ânimos e sair da reunião com um plano acionável documentado e prazos definidos.
