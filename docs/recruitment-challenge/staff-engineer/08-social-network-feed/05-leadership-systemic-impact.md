# 👥 Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Director of Engineering & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Liderança sem autoridade, resolução de impasses técnicos profundos, mitigação de picos de carga com base em tradeoffs de produto e negócio.

---

## 🎯 O Cenário da Simulação de Liderança

Durante um grande evento televisivo ao vivo (ex: final de um reality show de grande audiência ou evento de esporte global), o volume de posts e comentários na rede social atinge picos de **100.000 publicações por segundo**. 

A fila de fan-out do sistema de feed entra em colapso devido à lentidão na escrita nos clusters de cache Redis. O "lag de timeline" chega a **45 segundos** (um usuário posta e seus seguidores demoram quase um minuto para ver a mensagem, quebrando a experiência de tempo real do evento).

O time de engenharia de produto insiste que o cache Redis deve ser escalado horizontalmente de forma agressiva (o que custaria mais de 200 mil dólares extras por evento). O time de infraestrutura afirma que o orçamento acabou e que o produto deve "parar de propagar os posts em tempo real", exigindo consistência eventual severa.

Como Staff Engineer do time de Core Feed, você deve liderar a resolução desta crise.

---

## 🎯 Perguntas do Entrevistador e Comportamentos Esperados

### 1. Negociação de Trade-Offs Sistêmicos
* **Pergunta**: "Como você argumentaria com os líderes de produto e infraestrutura para encontrar um meio-termo viável que não estoure o orçamento nem destrua a experiência do usuário durante o evento?"
* **Comportamento Esperado**: O candidato de nível Staff deve propor soluções de **degradação inteligente**. Por exemplo:
  * Desabilitar temporariamente o fan-out push de imagens/mídias pesadas durante picos extremos (entregar primeiro o texto e carregar a imagem sob demanda).
  * Reduzir dinamicamente a contagem do threshold de celebridades (diminuir o limite de fan-out push de 25k para 5k seguidores durante o evento), transferindo o processamento para o caminho de leitura (pull) dos clientes ativos, distribuindo a carga de CPU nos celulares dos usuários.

### 2. Gestão de Pós-Incidente e Planejamento de Longo Prazo
* **Pergunta**: "Como você direcionaria o time para garantir que o sistema se auto-regule em eventos futuros, sem necessidade de intervenção humana manual de emergência?"
* **Comportamento Esperado**: Propor a automação de **Backpressure Dinâmico** na fila de fan-out e limites adaptativos de taxa de atualização de feed, permitindo que a aplicação do cliente perceba a sobrecarga no backend e diminua o ritmo de polling de atualização de forma transparente.

---

## ⚖️ Rubrica de Avaliação de Liderança

* **🟥 Red Flag**:
  * Sugere culpar o time de infraestrutura ou de produto pela falta de planejamento.
  * Não consegue formular propostas técnicas de engenharia de tráfego, limitando-se a sugerir "comprar mais servidores" ou "cancelar a feature de feed".
* **🟩 Staff L6+**:
  * Demonstra visão holística de custos e usabilidade de produto.
  * Propõe mitigação via engenharia de tráfego elegante (ex.: descarte seletivo de metadados não-essenciais, fila de priorização com base no nível de engajamento do leitor).
  * Consegue conduzir o plano de ação de forma unificada e pacífica entre os departamentos de infraestrutura e produto.
