# Desafio 19: Estimador de Cardinalidade HyperLogLog (`algo-hyperloglog-cardinality`)

## 1. Contexto & Cenário
Em sistemas de Big Data e análise de dados em tempo real (como contagem de usuários ativos diários/mensais no Facebook, requisições de IPs únicos em firewalls de borda da Cloudflare ou termos de pesquisa únicos no Google), contabilizar a quantidade exata de elementos distintos (cardinalidade) em fluxos massivos de informações é um desafio de computação em escala.

A solução ingênua de armazenar todas as chaves em um conjunto Hash (`HashSet`) em memória torna-se inviável quando o número de elementos únicos chega aos bilhões. O consumo de memória RAM escalará linearmente com a quantidade de dados, consumindo dezenas de gigabytes para uma única métrica simples.

Para resolver essa limitação física, utilizamos algoritmos e estruturas de dados probabilísticos. O **HyperLogLog (HLL)** é o algoritmo padrão ouro para estimar a cardinalidade de conjuntos gigantescos usando memória constante de poucos kilobytes, aceitando uma pequena margem de erro estatístico pré-definido (normalmente inferior a 1%).

O HLL fundamenta-se em uma observação probabilística simples: ao aplicarmos uma função hash uniforme sobre elementos de um conjunto, a distribuição binária das saídas gerará sequências de bits aleatórios. A quantidade máxima observada de zeros consecutivos à esquerda no início da representação binária do hash indica a escala do número de itens únicos inseridos (por exemplo, a probabilidade de observar uma sequência de 5 zeros seguidos à esquerda é de $1/2^5 \approx 3.1\%$). Para reduzir a variância matemática dessa medição, o HLL divide o fluxo em múltiplos buckets de controle (registradores) baseados nos bits iniciais do hash e calcula a média harmônica de seus valores.

---

## 2. Requisitos Funcionais (RF)
- **Adicionar Elemento (`Add`)**: Registrar um novo item (como string, número ou array de bytes) no estimador.
- **Contar Elementos (`Count`)**: Retornar a estimativa atual da quantidade de chaves únicas inseridas no estimador.
- **Mesclar Estimadores (`Merge`)**: Unificar o estado de dois estimadores HyperLogLog em um único estimador unificado. A operação deve computar a união matemática dos conjuntos sem perda de precisão, suportando agregações paralelas e distribuídas (MapReduce).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Uso Estrito e Limitado de Memória**: O consumo de memória RAM deve ser constante e delimitado no momento da inicialização (ex: exatamente 16384 registradores de 6 bits consumindo aproximadamente 12 KB de RAM), independentemente se processarmos dezenas de itens ou bilhões de chaves únicas.
- **Escrita Concorrente Concorrente (Thread-Safe)**: O método `Add` deve operar de forma thread-safe sob dezenas de threads simultâneas sem gerar gargalos de travamento (ex: usando operações atômicas baseadas em CAS nos índices de registradores).
- **Otimização de Operações Binárias (Bitwise)**: A indexação de registradores e a contagem de zeros à esquerda (Leading Zeros) devem ser executadas utilizando operações bitwise eficientes, aproveitando recursos nativos de hardware da CPU.

---

## 4. Guia de Implementação & Padrões

O fluxo de processamento de um elemento para obter e computar a estimativa é estruturado conforme o diagrama abaixo:

```
                      [ Elemento (Ex: "user_123") ]
                                   │
                                   ▼ [ Função Hash Murmur3_64 ]
                      [ Hash de 64 bits (Binário) ]
             ┌─────────────────────┴─────────────────────┐
             ▼ (Primeiros p bits)                        ▼ (Bits restantes)
     [ Índice do Registrador (m) ]              [ Contar Zeros à Esquerda (ρ) ]
             │                                           │
             ▼                                           ▼
      ┌──────────────┐                            ┌─────────────┐
      │ Registrador  │ ◄───────────────────────── │ Se ρ > Max  │ (Atualiza)
      │  [0..2^p-1]  │   (Interlock / Atômico)    │   Guarda ρ  │
      └──────┬───────┘                            └─────────────┘
             │
             ▼ (Na chamada do Count)
  [ Média Harmônica de Todos os Registradores ] ──► [ Aplica Correção de Bias ] ──► [ Retorna Estimativa ]
```

### Padrões e Algoritmos Recomendados:
- **Função Hash de Alta Uniformidade**: Utilizar MurmurHash3 de 64 bits ou xxHash64 para garantir dispersão e uniformidade de bits adequadas, mitigando desvios na estimativa final.
- **Parametrização por Precisão ($p$)**: O número de registradores é dado por $m = 2^p$. Uma precisão padrão de $p = 14$ gera $16384$ registradores. A margem de erro teórica típica é dada pela fórmula de aproximação de Flajolet: $\text{Erro} \approx 1.04 / \sqrt{m} \approx 0.81\%$.
- **Contagem Rápida de Zeros à Esquerda (CLZ)**: Utilizar funções nativas de contagem de bits da plataforma (ex: `BitOperations.LeadingZeroCount` em .NET, `Long.numberOfLeadingZeros` em Java, ou `bits.LeadingZeros64` em Go), que se traduzem em instruções assembly nativas da CPU em tempo de execução.
- **Atualização Atômica Livre de Locks**: O registrador de 6 bits pode ser armazenado em pacotes (como 8 registradores por inteiro de 64 bits) ou utilizando arrays de inteiros atômicos padrão. O método `Add` deve realizar um loop de CAS para atualizar o valor do registrador caso a nova sequência de zeros $\rho$ seja maior que o valor armazenado atualmente.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Correções de Faixa Estereotipadas**: O HyperLogLog original sofre com desvios estatísticos severos em conjuntos pequenos ou gigantescos. O candidato deve demonstrar domínio e aplicação das seguintes correções matemáticas:
  - **Linear Counting (Pequenas Cardinalidades)**: Se a estimativa preliminar for menor que $\frac{5}{2}m$ e houver registradores vazios (com valor zero), usar a fórmula alternativa de Linear Counting baseada na razão de buckets intocados.
  - **Correção de Grande Range**: Se a estimativa for muito próxima do limite superior de hashes de 64 bits ($> 2^{32}$), aplicar a correção logarítmica de estouro de intervalo.
- **Média Harmônica Correta**: A computação da média harmônica deve ser implementada com cuidado para evitar problemas de estouro de ponto flutuante (`double`). A média harmônica é essencial porque amortece a influência de outliers (picos isolados de zeros causados por ruídos eventuais).
- **Validação de Erro Desvio Padrão**: Apresentar testes práticos inserindo milhões de chaves conhecidas para comprovar se a variação percentual da estimativa mantém-se consistentemente sob a linha limite teórica determinada por $1.04 / \sqrt{m}$.

---

## 6. Trade-offs

### A. HyperLogLog vs. Filtros de Bloom Concorrentes
- **HyperLogLog**: Estimativa pura de contagem em memória constante e ínfima ($< 12$ KB). As instâncias podem ser mescladas via união bitwise rápida (`max` elemento por registrador) de forma distribuída.
  - *Contra*: Não permite checar se um elemento específico pertence ao conjunto (só fornece a contagem agregada).
- **Bloom Filter**: Permite testar pertinência de elementos individuais e fazer estimativa de cardinalidade aproximada.
  - *Contra*: O consumo de memória cresce proporcionalmente ao tamanho estimado do conjunto para evitar colapso de falsos positivos.

### B. Tamanho dos Registradores: 5 bits vs. 6 bits
- **Registradores de 5 bits**: Permitem armazenar contagens de zeros de 0 a 31. Limita o valor máximo estimado de cardinalidade a aproximadamente $2^{32} \approx 4$ bilhões de itens únicos.
- **Registradores de 6 bits (Recomendado)**: Permitem armazenar contagens de zeros de 0 a 63 (hashes de 64 bits). Oferece suporte prático a cardinalidades infinitas sem o perigo de saturação dos contadores de zeros.
