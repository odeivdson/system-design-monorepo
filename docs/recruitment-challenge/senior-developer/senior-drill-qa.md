# Q&A de Elite: Perguntas & Respostas para Entrevistas de Senior Developer

Este documento reúne perguntas clássicas de nível **Senior Developer (L5)** focadas em implementação técnica sólida, algoritmos de concorrência local, modelagem de banco de dados relacional e testes unitários.

---

## 🧭 Seção 1: Concorrência e Thread-Safety local

### Q1: Se você estiver implementando um contador de requisições local na memória da aplicação em uma linguagem que compila para threads nativas (como Java ou Go), quais os problemas de usar apenas inteiros primitivos comuns incrementados em paralelo? Como você corrige isso?
* **Resposta Ideal**:
  * Incrementos simples em variáveis comuns (ex: `count++`) não são operações atômicas no nível da CPU. Um incremento envolve três etapas físicas: ler o valor atual da memória para o registrador, incrementar o valor no registrador, e gravar o valor de volta na memória.
  * Sob concorrência de múltiplas threads paralelas, ocorre uma **Condição de Corrida (Race Condition)**: duas threads podem ler o mesmo valor inicial ao mesmo tempo, incrementar localmente e gravar o mesmo resultado, gerando perda de atualizações (*lost updates*).
  * Para corrigir isso, podemos adotar duas abordagens seguras:
    1. **Bloqueio Síncrono (Locks/Mutex):** Envolver a leitura e escrita com um Mutex (ex: `sync.Mutex` em Go) para garantir exclusão mútua.
    2. **Operações Atômicas (Lock-Free):** Usar primitivas atômicas do processador baseadas na instrução Compare-And-Swap (CAS) (ex: `sync/atomic` em Go ou `AtomicInteger` em Java), que efetuam o incremento de forma atômica direta no hardware, sendo muito mais eficientes que locks síncronos pesados.

---

## 🧭 Seção 2: Banco de Dados Relacional & Locks

### Q2: Qual é a diferença de escopo e comportamento entre o bloqueio otimista (Optimistic Locking) e o bloqueio pessimista (Pessimistic Locking) no controle de concorrência de saldos em bancos de dados SQL?
* **Resposta Ideal**:
  * **Bloqueio Pessimista (`SELECT FOR UPDATE`):**
    * *Funcionamento:* Bloqueia fisicamente a linha correspondente no banco de dados no momento em que ela é lida, impedindo que qualquer outra transação leia com lock ou modifique a linha até que a transação atual dê commit/rollback.
    * *Quando usar:* Alta contenda de dados (muitas requisições atualizando a mesma conta no mesmo instante). Evita falhas de processamento, mas diminui o paralelismo geral do banco.
  * **Bloqueio Otimista (Versionamento / `Version Column`):**
    * *Funcionamento:* Não coloca travas na leitura. Cada linha da tabela possui uma coluna de `version` ou timestamp. Na escrita, a query valida se a versão continua a mesma (ex: `UPDATE accounts SET balance = 100, version = version + 1 WHERE id = 1 AND version = 5`). Se nenhuma linha for atualizada, significa que outra transação alterou os dados antes; o sistema então rejeita a escrita ou tenta novamente.
    * *Quando usar:* Baixa contenda (conflitos raros). Muito mais eficiente e escalável do que travas pessimistas, pois não bloqueia leitores paralelos.

---

## 🧭 Seção 3: Estruturas de Dados e Algoritmos

### Q3: Por que a implementação ideal de um cache LRU (Least Recently Used) usa uma combinação de um Mapa (Hash Map) e uma Lista Duplamente Encadeada (Doubly Linked List)? Qual a complexidade de tempo de obter (`Get`) e inserir (`Put`) itens?
* **Resposta Ideal**:
  * Para atingir complexidade de tempo constante **$O(1)$** tanto em buscas quanto em inserções/atualizações de prioridade de expiração no cache LRU:
    * **Hash Map:** Guarda a associação da chave ao nó físico da lista. Permite consultar a existência de qualquer elemento instantaneamente em tempo constante $O(1)$.
    * **Lista Duplamente Encadeada:** Mantém a ordem de acesso físico dos elementos. O item no topo é o mais recentemente usado, e o item no rodapé da lista é o mais antigo (candidato à remoção). 
    * A lista encadeada permite remover um nó e reinseri-lo no topo da lista em tempo constante $O(1)$ apenas alterando os ponteiros dos vizinhos (seus nós anterior e próximo), sem precisar reorganizar outros elementos na memória, o que seria necessário se usássemos um vetor ($O(N)$).

---

## 🧭 Seção 4: APIs HTTP e Semântica de Erros

### Q4: Se um cliente tenta submeter uma proposta de transação onde o remetente não possui saldo suficiente para a transferência, qual código de status HTTP você retorna no endpoint REST e por quê?
* **Resposta Ideal**:
  * O código ideal a retornar é **`422 Unprocessable Entity`** (ou alternativamente **`400 Bad Request`** com código de erro interno detalhado).
  * **`422 Unprocessable Entity`** indica que os dados da requisição estão no formato correto (JSON sintaticamente válido) e as credenciais são válidas, mas o servidor não pôde processar a instrução devido a regras de negócio semânticas violadas (saldo insuficiente).
  * Retornar códigos semânticos corretos (como evitar usar `500 Internal Server Error` para erros de negócio) é crucial porque ferramentas de APM e monitoramento tratam erros 5xx como falhas de infraestrutura/código da aplicação, acionando alertas do suporte desnecessariamente.
