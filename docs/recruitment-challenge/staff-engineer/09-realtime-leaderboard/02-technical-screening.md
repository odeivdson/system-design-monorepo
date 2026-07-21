# 🛠️ Etapa 2: Technical Screening

* **Responsável:** Senior / Staff Engineer
* **Duração Recomendada:** 45 minutos
* **Foco:** Concorrência básica em memória, estruturas de dados de busca e fundamentos de conexões WebSocket persistentes de grande escala.

---

## 🎯 Perguntas Técnicas e Respostas Esperadas

### 1. SkipLists vs. B-Trees em Memória Concorrente
* **Pergunta**: "Para implementar um leaderboard que atualiza a pontuação de milhares de jogadores em tempo real na memória RAM, por que a estrutura **SkipList** costuma ser preferida em relação a uma árvore equilibrada tradicional (como B-Tree ou AVL) no quesito concorrência?"
* **Resposta Esperada**:
  * **Árvores Equilibradas (AVL/Red-Black)**: Para manter o equilíbrio sob inserções e atualizações frequentes, a estrutura exige rotações de nós complexas que afetam múltiplos níveis da árvore. Em cenários de concorrência multi-thread, isso exige locks amplos sobre grandes seções da árvore, gerando alta contenção.
  * **SkipList**: É uma estrutura baseada em níveis probabilísticos ligada puramente por ponteiros horizontais e verticais. Inserções e remoções são locais (exigem alteração de poucos ponteiros vizinhos). Isso viabiliza a implementação de algoritmos concorrentes **Lock-Free** usando operações atômicas baseadas em hardware como **Compare-And-Swap (CAS)**, reduzindo radicalmente a contenção de threads.

### 2. Esgotamento de Portas e Limites do Servidor WebSocket (File Descriptors)
* **Pergunta**: "Quando escalamos servidores WebSocket para aguentar 1 milhão de conexões simultâneas em um único host físico, quais limites de sistema operacional e de rede costumam ser os primeiros gargalos e como resolvê-los?"
* **Resposta Esperada**:
  * **Limites de File Descriptors (FDs)**: Cada conexão TCP aberta é tratada pelo Linux como um arquivo. O limite de arquivos abertos (`ulimit -n`) deve ser ajustado no kernel para mais de 1 milhão.
  * **Port Exhaustion (Esgotamento de Portas)**: Uma porta local clássica de saída IP limita conexões. No entanto, para conexões de entrada de clientes no servidor, a restrição de portas não se aplica da mesma forma, pois a conexão é identificada pela tupla de 4 elementos: `(IP Origem, Porta Origem, IP Destino, Porta Destino)`.
  * **Memória RAM**: Cada conexão WebSocket aberta consome memória de buffer de leitura e escrita do kernel (TCP socket buffers). É preciso reduzir os tamanhos desses buffers (`sysctl` net.ipv4.tcp_rmem e wmem) para valores mínimos (ex: 2KB ou 4KB) para evitar falta de memória física (OOM).

---

## ⚖️ Rubrica de Avaliação Técnica

* **🟥 Red Flag**: Desconhecer o conceito de locks concorrentes ou achar que 1 milhão de conexões WebSocket abertas exige 1 milhão de portas abertas no servidor.
* **🟩 Staff L6+**: Detalha com facilidade o funcionamento de operações Compare-And-Swap (CAS) e o consumo de memória a nível de socket de rede no Linux.
