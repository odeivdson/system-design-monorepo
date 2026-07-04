# Desafios de Complexidade $O(n)$ (Tempo Linear)

## 1. Contexto & Cenário
A complexidade de tempo linear $O(n)$ é o padrão ouro para processamento e ingestão de dados em larga escala. Em sistemas de alto desempenho (como ingestão de telemetria, parsing de mensagens de rede ou indexação de logs de transações), os dados fluem continuamente. Um algoritmo linear garante que o tempo gasto seja diretamente proporcional ao tamanho dos dados de entrada. Isso significa que se o volume de dados dobrar, o tempo de execução também dobrará, mantendo a escalabilidade sob controle e evitando explosões de consumo de CPU.

Nesta classe de desafios, focamos em otimizações que buscam converter soluções ingênuas de complexidade quadrática em soluções lineares de passagem única (single-pass), maximizando a vazão (throughput) de dados por segundo.

---

## 2. Requisitos Funcionais (RF)

### Desafio 1: Soma de Segmento Móvel (Janela Deslizante)
- **Input**: Um array de inteiros $A$ de tamanho $n$ e um inteiro $k$ representando a largura da janela ($1 \le k \le n$).
- **Output**: A maior soma possível de qualquer subarray contíguo de tamanho exatamente $k$.

### Desafio 2: Consulta de Frequência de Elementos em Fluxo
- **Input**: Um fluxo sequencial de itens recebidos em tempo real.
- **Output**: A atualização instantânea da frequência de cada item distinto à medida que ele é recebido, e a resposta imediata da contagem de qualquer elemento sob consulta.

### Desafio 3: Validação de Palíndromo com Duas Pontas
- **Input**: Uma string $S$ contendo caracteres Unicode básicos, espaços e sinais de pontuação.
- **Output**: Um booleano indicando se a string é um palíndromo (lê-se igual de trás para frente), desconsiderando espaços, pontuações e variações de caixa (case-insensitive).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Complexidade de Tempo Estrita**: Todos os algoritmos devem rodar em complexidade de tempo de pior caso $O(n)$.
- **Eficiência de Memória (In-place e Zero-Allocations)**:
  - Nos Desafios 1 e 3, a complexidade de espaço adicional deve ser $O(1)$. Não deve haver duplicação do array de entrada ou da string na Heap.
  - No Desafio 2, a memória auxiliar deve crescer no máximo proporcionalmente ao número de chaves únicas ($d \le n$), garantindo buscas de chave em tempo constante amortizado $O(1)$.
- **Segurança e Unicode**: O verificador de palíndromo deve suportar caracteres de múltiplos bytes sem corrupção ou quebra de indexação física.

---

## 4. Guia de Implementação & Padrões

Estes desafios são projetados para aplicar diretamente os padrões canônicos de complexidade linear mostrados na matriz de referência:

```
[Padrão 1: Loop Simples]        [Padrão 2: Loop de Fração N]     [Padrão 3: Loops Sequenciais]
  for (int i=0; i<n; i++)         for (int i=0; i<n/2; i++)        for (int i=0; i<n; i++) {}
            │                                │                                │
            ▼                                ▼                                ▼
   O(n) - Janela Deslizante         O(n) - Two Pointers              O(n + n) = O(n) - Segmentação
```

### Código e Padrões de Referência:

#### A. Loop Simples de Passagem Única
Utilizado no **Desafio 1**. Em vez de recalcular a soma de cada subarray de tamanho $k$ (o que levaria a uma complexidade de $O(n \times k)$), mantemos a soma acumulada da janela e a atualizamos subtraindo o elemento que sai e somando o que entra à medida que a janela desliza:
```csharp
// Padrão de Janela Deslizante O(n)
int currentSum = 0;
for (int i = 0; i < k; i++) currentSum += array[i];
int maxSum = currentSum;

for (int i = k; i < n; i++) {
    currentSum = currentSum - array[i - k] + array[i]; // Atualização em O(1)
    if (currentSum > maxSum) maxSum = currentSum;
}
```

#### B. Duas Pontas Convergentes ($N/2$)
Utilizado no **Desafio 3**. Iteramos de forma convergente a partir das extremidades utilizando dois ponteiros (esquerda e direita). A complexidade é $O(n/2) = O(n)$, pois cada caractere é verificado no máximo uma vez:
```csharp
// Padrão de Duas Pontas Convergentes (Two Pointers)
int left = 0;
int right = s.Length - 1;
while (left < right) {
    // Avançar ponteiros ignorando espaços e pontuações
    while (left < right && !IsAlphanumeric(s[left])) left++;
    while (left < right && !IsAlphanumeric(s[right])) right--;
    
    if (char.ToLower(s[left]) != char.ToLower(s[right])) return false;
    left++;
    right--;
}
```

#### C. Loops Sequenciais / Equações de Recorrência Linear
- **Loops independentes**: Se realizarmos duas passagens lineares sobre os mesmos dados, a complexidade resultante é $O(n + n) = O(n)$, e não quadrática.
- **Relação de Recorrência**: $T(n) = T(n-1) + O(1)$. Este padrão descreve uma recursão linear simples que reduz o problema em 1 unidade a cada chamada.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Eliminação de Computação Redundante**: No Desafio 1, o candidato **não** deve recalcular somas de substrings do zero a cada iteração.
- **Tratamento de Edge Cases**:
  - Casos em que $k > n$ no Desafio 1 (lançar argumento inválido ou tratar adequadamente).
  - Strings vazias ou com apenas caracteres inválidos no Desafio 3.
- **Eficiência de Mutação de Strings**: No Desafio 3, evitar chamadas como `s.Replace()`, `s.ToLower()`, ou `Regex.Replace()`, pois todas geram alocação de novas strings na Heap, violando o RNF de espaço $O(1)$. A verificação deve ser feita comparando os caracteres diretamente nos índices da string original.
- **Eficiência do Fluxo de Ingestão**: No Desafio 2, comprovar que a inserção e a leitura ocorrem de forma imediata por meio de chaves hash indexadas.

---

## 6. Trade-offs

### A. HashMap vs. Array de Frequência Fixo
- **HashMap (Tabela Hash)**: Suporta qualquer tipo de chave (Unicode, strings, objetos dinâmicos).
  - *Contra*: Tem overhead de colisão de hash e consome mais memória devido à estrutura de buckets.
- **Array de Frequência Fixo**: Caso o alfabeto seja fixo (ex: apenas caracteres ASCII de 0 a 255 ou números de intervalo restrito), podemos usar um array `int[256]` simples.
  - *Pró*: Acesso direto de memória ultrarrápido (amigável à cache de CPU), zero overhead de hash, menor uso de memória.

### B. Iterativo vs. Recursão Linear ($T(n) = T(n-1) + O(1)$)
- **Iterativo**: Usa uma estrutura de repetição simples. Consumo de espaço na pilha de execução (Stack) é $O(1)$.
- **Recursivo**: Embora modelado matematicamente como $T(n) = T(n-1) + O(1)$, a recursão física em linguagens sem suporte a *tail-call optimization* (TCO) resulta em $O(n)$ de uso de Stack.
  - *Perigo*: Risco severo de estouro de pilha (`StackOverflowException`) para valores de $n$ grandes em produção. Prefira sempre a abordagem iterativa para loops lineares sob volume massivo de dados.
