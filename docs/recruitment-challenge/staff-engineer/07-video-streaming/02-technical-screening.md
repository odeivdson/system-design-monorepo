# 🛠️ Etapa 2: Technical Screening

* **Responsável:** Senior / Staff Engineer
* **Duração Recomendada:** 45 minutos
* **Foco:** Fundamentos rápidos de redes, protocolos de transmissão de mídia e noções de concorrência/buffering em memória.

---

## 🎯 Perguntas Técnicas e Respostas Esperadas

### 1. Protocolos de Transporte de Mídia: TCP vs UDP (e HTTP/3 QUIC)
* **Pergunta**: "Para streaming de vídeo sob demanda (VoD), costumamos usar HLS/DASH sobre HTTP/2 ou HTTP/3. Por que escolhemos esses protocolos em vez de streams puros de UDP? Em qual cenário UDP seria preferível?"
* **Resposta Esperada**:
  * **VoD (Video on Demand)**: Exige entrega confiável e ordenada de todos os bytes de um chunk para que o reprodutor consiga decodificar os frames perfeitamente. Portanto, o HTTP (sobre TCP ou QUIC/UDP com confiabilidade na camada de aplicação) é ideal. O HTTP aproveita os mecanismos de caching globais de CDNs.
  * **UDP puro (ou WebRTC)**: É preferido para transmissões em tempo real de baixíssima latência (ex.: chamadas de vídeo, lives interativas), onde a perda de alguns frames é preferível em relação a um atraso (latência) acumulado por retentativas de pacotes perdidos.

### 2. Cabeçalhos de Caching e CDNs
* **Pergunta**: "Quais diretivas de cabeçalhos HTTP (`Cache-Control`) são críticas para garantir que arquivos de manifesto `.m3u8` e chunks de vídeo `.ts` sejam cacheados eficientemente na borda (CDN) sem entregar conteúdo desatualizado?"
* **Resposta Esperada**:
  * **Manifestos (`.m3u8` / `.mpd`)**: Atualizam frequentemente durante transmissões de live stream. O cache deve ser muito curto ou usar diretivas como `max-age=1, stale-while-revalidate=2`.
  * **Segmentos/Chunks de vídeo (`.ts` / `.m4s`)**: São imutáveis após criados. Devem ser cacheados com `max-age=31536000` (um ano) e cache imutável (`immutable`) para evitar revalidações desnecessárias com o servidor de origem.

---

## ⚖️ Rubrica de Avaliação Técnica

* **🟥 Red Flag**: Não saber a diferença básica entre TCP e UDP ou desconhecer o conceito de CDN/Edge Caching.
* **🟩 Staff L6+**: Explica com precisão os gargalos de TCP Head-of-Line Blocking e como o HTTP/3 resolve isso usando fluxos independentes multiplexados sobre QUIC.
