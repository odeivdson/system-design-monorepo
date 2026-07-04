# Desafio 11: Extremos em Janela Deslizante com Fila Monotônica (`algo-sliding-window-extremes`)

## 1. Contexto & Cenário
Em sistemas de monitoramento de infraestrutura e telemetria em tempo real (como acompanhamento de latências de APIs do gateway do Uber ou volume de requisições de servidores da Netflix), a detecção precoce de anomalias é crucial. Uma métrica padrão utilizada por engenheiros de confiabilidade de sites (SRE) é o cálculo do menor e maior valor de tempo de resposta (latência máxima/mínima) em uma janela de tempo deslizante recente (ex: a latência máxima registrada nas últimas 10.000 requisições recebidas).

Se o sistema precisar recalcular linearmente o menor e maior elemento varrendo a janela inteira a cada novo dado inserido, o tempo gasto por elemento será $O(W)$, onde $W$ é o tamanho da janela. Sob altas taxas de ingestão (ex: 100k métricas/segundo), essa travessia linear consumiria toda a CPU e inviabilizaria a telemetria em tempo real. O desafio estilo HackerRank consiste em projetar e implementar um buffer deslizante capaz de calcular os valores mínimo e máximo da janela ativa em **tempo constante amortizado $O(1)$** por elemento inserido.

---

## 2. Requisitos Funcionais (RF)
- **Inserção Incremental (Push)**: Adicionar um novo ponto de dados (valor numérico associado ou não a um timestamp) ao final do fluxo.
- **Remoção por Deslizamento (Pop)**: Excluir elementos que caíram fora da janela deslizante ativa (seja por tamanho máximo fixo de itens ou por expiração de limite de tempo).
- **Consulta de Extremos em $O(1)$**: Expor métodos `GetMin()` e `GetMax()` que retornam instantaneamente o menor e maior elemento presentes dentro da janela ativa.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Operação Amortizada em $O(1)$**: Todas as operações (`Push`, `Pop`, `GetMin` e `GetMax`) devem rodar em tempo constante amortizado $O(1)$ no pior caso.
- **Complexidade de Espaço Linear $O(W)$**: O consumo de memória RAM deve ser estritamente linear em relação ao tamanho da janela de visualização atual, evitando duplicar dados do fluxo na memória.
- **Thread-Safety Não Bloqueante**: A estrutura deve suportar leituras de monitoramento rápidas em threads de telemetria paralelas sem bloquear a hot path de ingestão de dados.

---

## 4. Guia de Implementação & Padrões
Para obter complexidade de tempo constante amortizada $O(1)$ na busca de valores mínimos ou máximos em uma fila deslizante dinâmica, a estrutura ideal é a **Fila Monotônica (Monotonic Queue)** implementada por meio de uma lista ligada de duas pontas (**Deque - Double-Ended Queue**).

```
   Fluxo de Entrada: 1 -> 3 -> -1 -> -3 -> 5 -> 3 ... (Janela tamanho 3)
   
   * Processando o elemento 5:
     1. Elementos mais antigos menores que 5 são descartados da Fila Monotônica.
     2. Deque de Máximos passa a conter apenas: [5]
     3. GetMax() retorna instantaneamente o Head do Deque: 5
```

### Algoritmos Recomendados:
- **Deque Monotônico (Decrescente para Máximos / Crescente para Mínimos)**:
  - Ao fazer o **Push** de um novo elemento $X$:
    1. Remover elementos do final (Tail) do Deque de Máximos enquanto eles forem menores ou iguais a $X$. Isso garante que o Deque esteja ordenado de forma estritamente decrescente do Head para o Tail.
    2. Adicionar $X$ no final (Tail) do Deque de Máximos.
  - Ao fazer o **Pop** (deslizar a janela e remover o item mais antigo $Y$):
    - Se o valor do Head do Deque de Máximos for igual a $Y$, remover o Head.
  - **GetMax()**: Retornar o valor contido no Head do Deque de Máximos (garante o máximo em $O(1)$).
  - Repetir a lógica espelhada usando um segundo Deque de Mínimos (mantido em ordem crescente) para a operação `GetMin()`.
- **Representação Indexada por Posição**: Em vez de armazenar os valores brutos nos Deques, armazenar os índices originais do fluxo de dados para permitir identificar facilmente quando um elemento expirou por tempo/tamanho em $O(1)$.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prova de Complexidade Amortizada $O(1)$**: Demonstração de que, embora um determinado `Push` possa remover múltiplos elementos do Deque no pior caso, cada elemento é inserido e removido do Deque no máximo uma vez, resultando em complexidade média por operação de exatamente $O(1)$.
- **Prevenção de Fugas de Limites (Off-by-One)**: Rastrear de forma correta a saída de elementos antigos da janela, garantindo que o Deque seja atualizado apenas quando o item de fato deslizar para fora dos limites espaciais ou temporais.
- **Eficiência de Memória (Sem Coleções Dinâmicas Ineficientes)**: Utilizar arrays circulares simples de tamanho fixo $W$ ou deques estruturados de baixo custo de ponteiros para evitar alocações de Heap na hot path.

---

## 6. Trade-offs

### A. PriorityQueue (Min/Max Heap) vs. Fila Monotônica (Monotonic Deque)
- **PriorityQueue (Heap)**:
  - *Pró*: Simplicidade conceitual ampla, disponível nativamente na maioria das linguagens de programação.
  - *Contra*: O tempo de atualização da janela é $O(\log W)$ devido à necessidade de reajustar a árvore binária de prioridade a cada inserção ou remoção. Em escala massiva de ingestão de telemetria, consome ciclos valiosos de CPU.
- **Fila Monotônica (Monotonic Deque - Recomendada)**:
  - *Pró*: Performance máxima absoluta com complexidade de tempo linear garantida $O(1)$ por operação.
  - *Contra*: Exige o desenvolvimento de uma estrutura de dados de suporte customizada (Deque) e controle minucioso do fluxo de índices e valores.

### B. Janela de Tamanho Fixo vs. Janela Baseada em Tempo (Time Window)
- **Tamanho Fixo (ex: últimas 10.000 métricas)**:
  - *Pró*: O consumo de memória RAM do buffer é previsível e estático, determinado na inicialização do sistema.
  - *Contra*: A janela física de tempo coberta varia de acordo com a vazão de rede do sistema (pode cobrir 1 segundo em horários de pico e 1 hora em momentos ociosos).
- **Tempo Fixo (ex: últimos 60 segundos - Time-based sliding window)**:
  - *Pró*: Consistência no significado das métricas (latência de 1 minuto).
  - *Contra*: O consumo de memória RAM do buffer oscila de acordo com as flutuações de tráfego, exigindo estratégias de limites máximos de segurança para evitar OOM em momentos de picos súbitos de RPS.
