# Desafio 12: Filtro de Bloom Concorrente Otimizado (`algo-concurrent-bloom-filter`)

## 1. Contexto & Cenário
Em sistemas de alto tráfego com armazenamento de dados distribuído (como verificação de nomes de usuário disponíveis no Instagram, filtragem de URLs maliciosas no navegador ou checagem de existência de chaves antes de bater no banco de dados para mitigar ataques de cache penetration), a velocidade é tudo. Consultar o banco de dados principal ou realizar acessos frequentes a discos para checar a existência de chaves que majoritariamente não existem gera gargalos intoleráveis de performance. 

O **Bloom Filter (Filtro de Bloom)** é uma estrutura de dados probabilística e espacialmente extremamente econômica que resolve esse cenário. Ele responde se um elemento *definitivamente não está* no conjunto ou se ele *talvez esteja*. 
No entanto, sob concorrência agressiva em arquiteturas multi-threaded, a implementação básica sofre com dois grandes gargalos: a necessidade de sincronização (locks) na alteração de bits contíguos na memória e o custo computacional de calcular múltiplas funções de hash independentes a cada inserção/busca. O objetivo deste desafio é implementar um Filtro de Bloom concorrente, lock-free, com otimização matemática de hashes de CPU.

---

## 2. Requisitos Funcionais (RF)
- **Inserção Concorrente (Add)**: Adicionar um termo (string ou array de bytes) ao filtro de forma thread-safe.
- **Consulta Probabilística (Contains)**: Verificar se um termo está contido no filtro. Se retornar `false`, garante-se que o item nunca foi inserido (zero falsos negativos). Se retornar `true`, indica que o item provavelmente foi inserido (aceitando uma taxa controlada de falsos positivos).
- **Dimensionamento Matemático**: Inicializar o filtro calculando automaticamente o tamanho ideal do vetor de bits ($m$) e o número ótimo de hashes ($k$) a partir de uma capacidade de elementos esperada ($n$) e uma taxa de falsos positivos desejada ($\epsilon$).

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Throughput Concorrente Elevado**: Suportar mais de 200.000 operações por segundo em regime multi-threaded na hot path.
- **Otimização de Hashes via Kirsch-Mitzenmacher**: Minimizar o uso de CPU gerando $k$ índices de hash de forma matemática a partir de apenas 2 hashes independentes (ex: obtidos via MurmurHash3), eliminando a necessidade de recalcular $k$ funções de hash completas por elemento.
- **Operação Lock-Free baseada em CAS (Compare-And-Swap)**: As escritas concorrentes em posições adjacentes do array de bits de retaguarda não devem usar bloqueios síncronos, prevenindo contenção de CPU através do uso de primitivas atômicas de escrita.
- **Eficiência de RAM (Sem Garbage Collection)**: Evitar qualquer alocação de memória no Heap durante as verificações (`Contains`) para atingir overhead de telemetria nulo.

---

## 4. Guia de Implementação & Padrões
A estrutura armazena dados em um array contíguo de inteiros longs de 64 bits (`long[]` ou similar), onde cada bit representa um sinalizador atômico de presença.

```
       [ Elemento a Inserir ]
                 │
                 ├──────────────────────────────┐
                 ▼ (Hash Murmur3_1)             ▼ (Hash Murmur3_2)
             [ Hash H1 ]                    [ Hash H2 ]
                 │                              │
                 └──────────────┬───────────────┘
                                ▼
                   Kirsch-Mitzenmacher Logic:
                   For i from 0 to k-1:
                     BitIndex = (H1 + i * H2) % BitArraySize
                                │
                                ▼ (Atomic Set / CAS)
                 ┌──────────────────────────────┐
                 │ Bit Array Backing (long[])   │
                 │ [0][1][0][0][1][1][0]...     │
                 └──────────────────────────────┘
```

### Padrões e Primitivas Recomendadas:
- **Otimização Kirsch-Mitzenmacher**: Permite computar $k$ posições de bits de forma ultraveloz com a fórmula:
  $$g_i(x) = h_1(x) + i \cdot h_2(x) \pmod m$$
  Onde $h_1(x)$ e $h_2(x)$ são as metades superior e inferior de um único hash de 128 bits (ex: MurmurHash3_x64_128).
- **Fórmulas de Dimensionamento Ótimo**:
  - Tamanho do vetor de bits ($m$):
    $$m = -\frac{n \cdot \ln(\epsilon)}{(\ln 2)^2}$$
  - Número de funções de hash ($k$):
    $$k = \frac{m}{n} \cdot \ln 2$$
- **Mutação Atômica por Bitwise CAS**: Para setar um bit em um array de longs sem corromper alterações concorrentes em bits adjacentes do mesmo inteiro longo de 64 bits:
  1. Identificar o índice do array: `longIndex = bitIndex / 64`.
  2. Criar a máscara de bit: `mask = 1L << (bitIndex % 64)`.
  3. Atualizar atomicamente usando CAS:
     ```
     do {
         oldValue = array[longIndex];
         newValue = oldValue | mask;
     } while (CompareExchange(ref array[longIndex], newValue, oldValue) != oldValue);
     ```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Implementação Bitwise Atômica Correta**: Demonstrar por que o uso de `bitArray[idx] = true` é incorreto em cenários concorrentes (devido a race conditions de gravação concorrente no mesmo segmento de memória) e como o loop CAS baseado em inteiros do tamanho de word da CPU (32/64 bits) resolve este problema.
- **Velocidade de Geração de Hashes**: Evitar a alocação de strings temporárias ou arrays na transformação de bytes para inteiros durante a fase de hash.
- **Tratamento de Overflow de Hash**: Garantir que as operações aritméticas do método Kirsch-Mitzenmacher não estourem o limite máximo de inteiros positivos e que o módulo ($m$) seja aplicado de forma segura (lidando com hashes que podem retornar valores negativos).
- **Zero Allocations**: Não gerar nenhuma alocação de Heap no método `Contains`.

---

## 6. Trade-offs

### A. Filtro de Bloom Standalone vs. Filtro de Bloom Segmentado (Blocked Bloom Filter)
- **Filtro de Bloom Standalone (Recomendado)**:
  - *Pró*: Distribuição estatística perfeita dos falsos positivos.
  - *Contra*: O acesso aos bits calculados é disperso ao longo de todo o array na memória RAM, gerando falhas frequentes de cache de CPU (Cache Misses) quando o filtro é maior que o cache L3.
- **Blocked Bloom Filter**: Divide o filtro em pequenos blocos de tamanho de linha de cache de CPU (tipicamente 64 bytes).
  - *Pró*: Altíssima localidade de cache de CPU (L1/L2), pois todos os bits de um elemento ficam no mesmo bloco físico de memória.
  - *Contra*: Taxa estatística levemente superior de falsos positivos sob a mesma quantidade de bits totais.

### B. MurmurHash3 vs. SHA-256
- **MurmurHash3 (Recomendada)**:
  - *Pró*: Velocidade de cálculo absurda, projetada especificamente para estruturas em memória.
  - *Contra*: Não é criptograficamente segura (vulnerável a ataques de colisão intencional de hash, embora seja irrelevante para a maioria dos casos de uso de cache).
- **SHA-256**:
  - *Pró*: Criptograficamente seguro contra ataques de colisão de hash.
  - *Contra*: Alto consumo de CPU, reduzindo drasticamente o throughput de checagens na hot path do sistema.
