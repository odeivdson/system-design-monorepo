# 👥 Trilha 2 - Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Resolução de incidentes massivos de escala real, ética em dados sensíveis de localização e gestão de times distribuídos.

---

## 🗺️ Cenários para Discussão

### Cenário 1: O Apocalipse do Ano Novo (Escala de Tráfego de Pico)
> *"Na noite de Ano Novo, entre 23:30 e 01:30, o tráfego de requisições de corrida da plataforma aumenta em 50x. Em edições anteriores, o banco de dados em memória que armazena a localização dos carros saturou a CPU, travando o aplicativo globalmente por horas. Como você, como Staff Engineer, desenharia uma estratégia de engenharia prévia para mitigar esse risco de forma sistêmica?"*

* **Respostas Esperadas do Candidato:**
  * **Degradação Graciosa de Serviço (Graceful Degradation):** Propor desativar recursos secundários em períodos de pico (ex.: desativar visualização em tempo real de carros andando no mapa do passageiro para poupar 90% das leituras do cache geográfico).
  * **Aumento do Tempo de Amostragem (Telemetry Interval Backoff):** Ajustar dinamicamente a frequência com que o app envia o ping do GPS (de 4s para 10s ou 12s) caso a carga do sistema passe de certo limiar de CPU.
  * **Rate Limiting Geográfico e Fila de Espera Virtual:** Barrar o tráfego excedente logo na borda (Edge/CDN) antes de tocar os serviços centrais.

### Cenário 2: Privacidade de Dados e Segurança da Geolocalização
> *"A equipe de Marketing quer exportar o histórico de trajetos GPS brutos dos passageiros para criar um modelo de recomendação de anúncios em shoppings parceiros. Como Staff Engineer, quais são suas preocupações de segurança e conformidade (LGPD/GDPR) e como você estruturaria essa solução protegendo os usuários?"*

* **Respostas Esperadas do Candidato:**
  * **Anonimização Física de Dados:** Recusar a exportação de dados brutos e exigir anonimização rigorosa.
  * **Ofuscação Espacial e Temporal:** Sugerir arredondar as coordenadas (ex.: usar uma resolução menor de célula H3 em vez de latitude/longitude exata de partida e chegada) e remover timestamps exatos da viagem para evitar o rastreamento cruzado de identidade.

---

## ⚖️ Rubrica de Liderança de Staff (L6+)
* **Sinal Verde:** Prioriza ativamente a segurança e a privacidade do usuário contra pressões comerciais de curto prazo. Mostra controle emocional ao desenhar estratégias para incidentes críticos de infraestrutura.
* **Sinal Vermelho:** Não conhece termos ou práticas básicas de conformidade de dados (LGPD); propõe apenas "escalar máquinas" para mitigar picos de 50x de tráfego de rede.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
