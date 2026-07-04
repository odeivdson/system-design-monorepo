# 💻 Trilha 4 - Etapa 4: Coding Onsite - Estrutura de Dados CRDT Concorrente

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Algoritmos de convergência matemática, concorrência fina de threads e design de APIs de baixo nível.

---

## 🎯 O Enunciado do Desafio

Tipos de Dados Replicados Sem Conflitos (CRDTs) são estruturas matemáticas cujas propriedades garantem que, se múltiplos nós receberem as mesmas atualizações em qualquer ordem, eles alcançarão o mesmo estado idêntico de forma determinística sem coordenação central.

O candidato deve implementar uma versão simplificada de um **PN-Counter (Positive-Negative Counter)** ou de um **LWW-Element-Set** em memória que suporte adição e leitura de forma concorrente e thread-safe.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar uma estrutura/classe `PNCounter` com os seguintes requisitos:

### 1. Estrutura Interna Replicável
* Cada réplica (nó) possui um ID único.
* O nó armazena em vetores de estado locais os incrementos e decrementos que ele mesmo fez, bem como o estado conhecido que recebeu das outras réplicas.

### 2. Métodos Necessários
* `Increment(nodeId string, value int)`: Incrementa o contador para o nó especificado.
* `Decrement(nodeId string, value int)`: Decrementa o contador.
* `Value() int`: Calcula o valor total convergido somando todos os incrementos conhecidos e subtraindo os decrementos conhecidos de todas as réplicas.
* `Merge(other PNCounter)`: Recebe o estado de outra réplica remota e funde (merge) os valores locais de forma atômica e idempotente pegando o máximo elemento de cada vetor local para garantir a convergência determinística (operação semáforo).

---

## ⚖️ Rubrica de Avaliação de Código

| Nível | Indicadores Práticos no Desafio |
| :--- | :--- |
| 🟥 **Reprovado** | A função de merge simplesmente soma os valores brutos recebidos, violando a propriedade de idempotência (se fizermos merge do mesmo estado duas vezes, o valor dobra erroneamente). |
| 🟨 **Senior (L5)** | Implementa a matemática correta de PN-Counter (maximizando as matrizes locais de estados recebidos). Protege as leituras e escritas concorrentes usando locks (`sync.Mutex` ou equivalentes). |
| 🟩 **Staff (L6+)** | Escreve código altamente desacoplado. Discute as propriedades algébricas fundamentais necessárias para um CRDT (Comutatividade, Associatividade e Idempotência - Semigrupo Limitado). Demonstra preocupação com a alocação de memória ao realizar cópias profundas (*deep copies*) de dados durante o Merge concorrente. |

---

[Ir para a Etapa 5: Leadership & Systemic Impact ](./05-leadership-systemic-impact.md)
