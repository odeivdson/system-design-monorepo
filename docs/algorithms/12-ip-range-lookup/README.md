# Desafio 19: Validador e Busca de Faixas de IP com Árvore de Intervalos (`algo-ip-range-lookup`)

## 1. Contexto & Cenário
Em gateways de API de alta performance e firewalls de aplicações web (WAF) (como Cloudflare ou AWS WAF), cada requisição HTTP de entrada é acompanhada pelo endereço IP de origem do cliente (ex: `192.168.1.1` ou `2001:db8::1`). Por questões de segurança (bloqueio de bots maliciosos baseados em geolocalização ou regras de conformidade corporativa), o sistema deve validar se o IP de origem pertence a uma lista contendo centenas de milhares de blocos de faixas de IP conhecidos (ex: CIDR Blocks como `192.168.0.0/16` ou faixas explicitadas como `192.168.1.0-192.168.1.255`).

Se realizarmos uma busca sequencial linear ($O(N)$) varrendo a lista de regras para cada requisição HTTP recebida, a API de borda entrará em colapso devido à latência acumulada. Usar uma Tabela Hash padrão só funciona para checagens de IPs exatos, falhando na resolução de faixas de IP genéricas (intervalos). O desafio estilo Big Tech é projetar um validador de faixas de IP extremamente rápido usando uma **Árvore de Intervalos (Interval Tree / Segment Tree)** ou estrutura de dados similar que resolva buscas em **complexidade de tempo logarítmica $O(\log N)$**.

---

## 2. Requisitos Funcionais (RF)
- **Input de Dados**:
  - Lista de faixas de IP associadas a uma regra ou metadados (ex: `192.168.0.0 - 192.168.255.255` -> `ALLOW_INTERNAL`, `10.0.0.0 - 10.0.0.255` -> `DENY_OFFICE`).
  - Permite a inserção dinâmica de novas faixas no catálogo.
- **Busca por IP (Lookup)**: Receber um IP único (ex: `192.168.10.5`) e retornar todas as faixas e regras associadas que englobam este IP.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Latência de Lookup Otimizada**: A operação de busca deve responder em tempo sub-milissegundo, operando estritamente em complexidade de tempo de $O(\log N + K)$ (onde $N$ é o número de intervalos indexados e $K$ é a quantidade de faixas correspondentes encontradas).
- **Suporte a IPv4 e IPv6**: A árvore de intervalos deve gerenciar internamente a representação de endereços IPv4 (inteiros de 32 bits) e IPv6 (inteiros de 128 bits) de forma unificada e limpa.
- **Thread-Safety Não Bloqueante**: Múltiplas buscas concorrentes devem ocorrer em paralelo de forma lock-free, enquanto atualizações das faixas de IP ocorrem em background (usando imutabilidade ou locks dinâmicos).
- **Zero Allocations no Lookup**: Evitar instanciar arrays ou objetos no Heap na hot path de busca para não impactar o Garbage Collector.

---

## 4. Guia de Implementação & Padrões
A estrutura recomendada para pesquisa de intervalos unidimensionais é a **Árvore de Intervalos (Interval Tree)** baseada em uma **Árvore Binária de Busca Auto-Balanceada** (como a Red-Black Tree) ou uma **Segment Tree** estática pré-compilada.

```
                  Interval Tree (Representação)
                       [10 - 20] (Max: 40)
                       /                 \
             [5 - 12] (Max: 12)       [15 - 40] (Max: 40)
                                      /
                              [14 - 17] (Max: 17)

   * Busca do IP "16":
     1. Compara com nó raiz [10 - 20] -> 16 está contido no intervalo!
     2. Navega pelas ramificações que possuem Max >= 16 para encontrar outros candidatos.
```

### Algoritmos Recomendados:
- **Interval Tree Baseada em BST Balanceada**:
  - Cada nó da árvore armazena um intervalo $[Low, High]$ e um valor extra $Max$ representando o maior limite superior ($High$) contido na subárvore sob aquele nó.
  - O ordenamento da BST é baseado no limite inferior ($Low$) do intervalo do nó.
  - **Algoritmo de Busca (Lookup(IP))**:
    1. Iniciar no nó Raiz.
    2. Se o IP estiver dentro do intervalo do nó atual, adicionar às correspondências.
    3. Se o filho esquerdo não for nulo e o valor $Max$ do filho esquerdo for maior ou igual ao IP buscado, pesquisar recursivamente no filho esquerdo.
    4. Caso contrário (ou também, para buscas completas de sobreposição múltipla), pesquisar no filho direito.
- **Conversão de IP para Inteiros**:
  - Converter o endereço IP para um inteiro representativo de tamanho adequado (C# `uint` para IPv4 e C# `BigInteger` ou par de `ulong` para IPv6) antes de realizar as comparações, garantindo que as operações sejam puramente numéricas e rápidas na CPU.
- **Copy-On-Write Array de Segmentos**: Se a base de IPs for atualizada apenas periodicamente, pode-se pré-compilar a árvore de intervalos em um array contíguo linear ordenado por $Low$ e realizar busca binária sobre os limites inferiores, reduzindo alocações.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Implementação Eficiente de Comparação IPv6**: Demonstrar como representar e comparar IPs de 128 bits sem overhead de performance (evitando o uso lento de classes de string ou objetos `IPAddress` da linguagem para a comparação na hot path).
- **Manutenção Correta do Valor Max**: Garantir que o valor $Max$ de cada nó da árvore de intervalos seja atualizado atomicamente e de forma correta durante inserções e balanceamentos de rotação de nós da árvore.
- **Poda de Busca Eficaz**: A busca recursiva deve podar subárvores inteiras se o valor $Max$ daquela ramificação for menor que o IP buscado, mantendo a complexidade em $O(\log N)$.
- **Resiliência a Intervalos Sobrepostos Grandes**: Lidar de forma correta com o caso limite onde existem intervalos muito grandes e sobrepostos (ex: um intervalo gigante que engloba quase todos os outros).

---

## 6. Trade-offs

### A. Interval Tree vs. Segment Tree estática
- **Interval Tree (Dinâmica - Recomendada)**:
  - *Pró*: Suporta a inserção e remoção em tempo real de novas faixas de IPs na base de dados com complexidade equilibrada de $O(\log N)$.
  - *Contra*: O código de balanceamento da árvore Red-Black com controle de $Max$ é complexo e propenso a bugs.
- **Segment Tree Estática (Flattened Array)**:
  - *Pró*: Simplicidade de código de busca máxima e localidade de cache de CPU (contiguidade em memória), sem overhead de ponteiros.
  - *Contra*: Inserir ou remover uma faixa exige o rebuild completo de toda a árvore, paralisando a escrita.

### B. Indexação IPv4 e IPv6 Separada vs. Árvore Unificada
- **Estruturas Separadas (Recomendada)**:
  - *Pró*: A busca de IPv4 roda em alta performance usando inteiros nativos de 32 bits (`uint` / `int`) em registradores da CPU, sem sofrer o overhead das estruturas maiores exigidas pelo IPv6 de 128 bits.
  - *Contra*: Duplica a lógica de estruturas na base de código, aumentando a manutenção.
- **Árvore Unificada (IPv4 mapeado em IPv6)**:
  - *Pró*: Código unificado simples. Mapeia-se IPv4 como IPv6-mapped addresses (`::ffff:192.0.2.128`).
  - *Contra*: Reduz a vazão e aumenta o consumo de memória das buscas de IPv4 (que representam a maioria das requisições reais de internet).
