# 👥 Trilha 6 - Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Resolução de incidentes massivos de segurança corporativa, governança e alinhamento legal de sistemas públicos.

---

## 🗺️ Cenários para Discussão

### Cenário 1: Ataque Massivo de Phishing (Prevenção de Abuso)
> *"Nosso encurtador de URLs começou a ser utilizado por uma campanha global automatizada de bots que gerou 10 milhões de links curtos apontando para sites falsos do banco parceiro da nossa Big Tech. A Microsoft e o Google ameaçam colocar o nosso próprio domínio raiz (`nosso-app.co`) na lista negra global de spam do Chrome e Outlook, o que derrubaria todas as comunicações legítimas da empresa com nossos clientes. Como você, como Staff Engineer, assume a liderança e resolve essa crise técnica e institucional?"*

* **Respostas Esperadas do Candidato:**
  * **Intervenção Imediata de Filtro de Domínios:** Implementar uma validação no fluxo de redirecionamento (redirection path) que consulte em tempo real em cache de memória rápida (ex.: Redis com bloom filter) os domínios banidos, abortando imediatamente o redirecionamento para URLs maliciosas.
  * **Autenticação Obrigatória / Captcha Adaptativo:** Bloquear a criação de novas URLs encurtadas por usuários anônimos, passando a exigir autenticação via OAuth ou a inclusão de Captchas difíceis caso a taxa de criação de links de um mesmo IP exceda o limite seguro.
  * **Colaboração e Resposta de Relações:** Trabalhar em conjunto com os times de Segurança da Informação (InfoSec) e Jurídico para providenciar auditoria externa e reportar à Microsoft/Google os planos de contenção adotados para remover o bloqueio do domínio raiz o mais rápido possível.

### Cenário 2: Invalidação de Cache Distribuído Global
> *"Um link incorreto e viral de uma grande campanha de publicidade da empresa foi corrigido no banco de dados operacional. Porém, devido ao cache agressivo na CDN e nas CDN locais de terceiros na borda, os usuários continuam sendo redirecionados para a URL antiga errada. Como você projeta ou atua para realizar a invalidação de cache distribuído sob demanda em nível global de forma eficiente e sem causar indisponibilidade por sobrecarga (Thundering Herd)?"*

* **Respostas Esperadas do Candidato:**
  * **Invalidação Seletiva por Purge API:** Propor a integração com APIs de controle de CDN (como Cloudflare Purge API ou Fastly Instant Purge) para invalidar especificamente a chave da URL editada em vez de limpar o cache global da CDN inteira.
  * **Prevenção contra Sobrecarga (Cache Stampede Mitigation):** Garantir que, ao invalidar a chave da URL viral (que recebe milhares de requisições por segundo), o primeiro servidor que receber o "miss" de cache faça o travamento atômico de busca no banco NoSQL central, enquanto as outras requisições concorrentes paralelas aguardam alguns milissegundos para usar o novo valor de cache reabastecido.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
