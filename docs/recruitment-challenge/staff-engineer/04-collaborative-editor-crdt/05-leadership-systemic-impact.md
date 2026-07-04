# 👥 Trilha 4 - Etapa 5: Leadership & Systemic Impact Onsite

* **Responsável:** Diretor de Engenharia & Staff Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Migração de protocolos em larga escala, gerenciamento de quebras de compatibilidade (Breaking Changes) e governança técnica.

---

## 🗺️ Cenários para Discussão

### Cenário 1: Migração de Protocolo sob Alta Carga
> *"Sua plataforma roda um protocolo antigo baseado em pooling HTTP de JSON que consome muita CPU e banda. Você liderou o desenvolvimento de uma nova infraestrutura baseada em WebSockets binários usando Yjs que reduz o custo de rede em 80%. No entanto, há 5 milhões de clientes ativos rodando versões antigas do aplicativo móvel que não podem ser atualizadas forçadamente. Como você planeja e executa a migração do protocolo sem indisponibilidade e mantendo retrocompatibilidade total?"*

* **Respostas Esperadas do Candidato:**
  * **Camada de Adaptação / Proxy Transacional:** Implementar uma camada intermediária no backend (Adapter Pattern) que receba os updates via JSON HTTP das versões antigas, traduza-os para o formato binário do Yjs e os injete na nova arquitetura, e vice-versa.
  * **Canary Deploys Geográficos por Documento:** Migrar o tráfego de forma gradual (ex.: primeiro 1% dos documentos, depois 5%, etc.), permitindo validação contínua em produção sob carga.
  * **Monitoramento de Inconsistências:** Criar mecanismos automatizados de auditoria em background que comparam hashes de documentos editados sob o formato antigo vs o formato novo para capturar bugs de conversão silenciosos.

### Cenário 2: Gestão de Débito Técnico e Desgaste do Time
> *"A biblioteca open-source de CRDT usada no core do editor foi descontinuada pelo criador original e possui problemas conhecidos de segurança e vazamento de memória sob certos tipos de arquivos complexos. O time de desenvolvimento quer criar uma biblioteca própria do zero (estimativa: 4 meses). Como Staff Engineer, como você aborda esse problema estratégico?"*

* **Respostas Esperadas do Candidato:**
  * **Análise Comprar vs. Criar (Build vs. Buy):** Avaliar outras alternativas open-source ativas no mercado antes de autorizar o desenvolvimento do zero.
  * **Fork e Correção Focada:** Se nenhuma alternativa existir, sugerir fazer um *fork* da biblioteca descontinuada, focar apenas na correção cirúrgica dos vazamentos de memória e das brechas de segurança conhecidas, assumindo temporariamente a manutenção interna e adiando o esforço de reescrever do zero para quando for estritamente viável para o negócio.

---

[Ir para o README principal para rever o Pipeline ➡️](../README.md)
