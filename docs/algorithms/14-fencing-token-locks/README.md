# Desafio 26: Lock Distribuído com Fencing Tokens e Leases (`algo-fencing-token-locks`)
> **Padrões de Arquitetura Distribuída e Concorrência:** Distributed Locks (Locks Compartilhados), Leases (Prazos de Validade), Fencing Tokens (Tokens de Bloqueio), Optimistic Storage Concurrency (Consistência de Escrita).

## 1. Contexto & Cenário
Em sistemas distribuídos, frequentemente precisamos garantir que apenas um worker ou processo execute uma tarefa crítica de cada vez (ex: processar um lote de faturamento, executar um fechamento contábil ou comandar a movimentação de um robô no armazém). Para isso, utilizamos um **Lock Distribuído** apoiado por uma base compartilhada (como Redis, ZooKeeper ou Consul).

No entanto, adquirir um lock distribuído comum e assumir que a exclusão mútua está garantida é uma **falácia de design grave**. Redes IP são propensas a latências imprevisíveis e aplicações que rodam em máquinas virtuais estão sujeitas a pausas imprevistas de processamento (como pausas longas de **Garbage Collection - Stop-the-World**, instabilidades de CPU no hypervisor ou swaps de disco).

Considere o seguinte bug catastrófico de concorrência:
1. O `Worker A` adquire um lock distribuído com TTL de 10 segundos no Redis.
2. O `Worker A` inicia o processamento, mas logo em seguida entra em uma pausa longa de GC que dura 12 segundos.
3. Enquanto o `Worker A` está congelado pelo GC, o TTL de 10s expira no Redis. O lock é liberado automaticamente.
4. O `Worker B` solicita o lock, o adquire com sucesso e inicia o processamento do mesmo lote.
5. O `Worker B` grava as alterações no banco de dados com sucesso.
6. O `Worker A` acorda do GC, assume que seu lock ainda é válido (pois ele não sabe que ficou congelado) e envia suas gravações de escrita sobre o mesmo lote de dados.
7. O banco de dados aceita a escrita do `Worker A`, corrompendo os dados gravados anteriormente pelo `Worker B` (condição de corrida de escrita dividida - Split Brain).

Para blindar o sistema contra este cenário inevitável de infraestrutura, utilizamos as técnicas de **Leases** (locks temporais limitados autolimpantes) acopladas a **Fencing Tokens** (geração e validação de tokens numéricos monótonos no banco de dados).

---

## 2. Requisitos Funcionais (RF)
- **Aquisição de Lease com Token Monótono**:
  - O serviço de lock distribuído deve retornar, no ato da aquisição do lock, um **Fencing Token**: um número inteiro que é estritamente incremental (monotonicamente crescente, ex: Token 34 é maior que Token 33).
- **Validação de Fencing no Banco de Dados (Última Linha de Defesa)**:
  - A escrita física no banco de dados durável downstream (ex: PostgreSQL) para aquele lote/recurso deve exigir o envio do Fencing Token associado ao lock.
  - O banco de dados só deve aceitar a gravação se o token recebido for **maior** que o último token que gravou dados naquele mesmo recurso. Se for menor, a gravação deve ser rejeitada sumariamente via erro de concorrência, protegendo o sistema.
- **Renovação Ativa de Lease**: O cliente ativo que detém o lock deve possuir um mecanismo secundário (Heartbeat loop) para renovar o TTL do lease no Redis de forma assíncrona enquanto o processamento estiver saudável.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **footprint de Validação In-Database Sub-Milissegundo**: A checagem do Fencing Token no ato da gravação no PostgreSQL deve ocorrer via cláusula atômica (ex: `UPDATE ... WHERE fencing_token < incoming_token`), sem adicionar SELECTs prévios de rede.
- **Tolerância a Crashes de Clientes (Liveness)**: Se um worker adquirir o lock e sofrer um crash definitivo, o lock deve expirar obrigatoriamente por tempo limite de lease (TTL), impedindo locks órfãos infinitos.
- **Gerador de Tokens Monótono Resiliente**: O gerador de tokens não pode sofrer retrocessos numéricos sob reinicialização de nós ou partições de rede.

---

## 4. Guia de Implementação & Padrões

### Condição de Corrida de GC e Proteção por Fencing Token
```
 Worker A                             Worker B                          Storage / DB
    │                                    │                                    │
    │───(1. Adquire Lock (Token 33))────┼───────────────────────────────────►│ (Último Token = 33)
    │                                    │                                    │
    ▒▒▒ [ Congela em Pausa GC ]          │                                    │
    ▒▒▒ (TTL de 10s expira no Redis)     │                                    │
    ▒▒▒                                  │───(2. Adquire Lock (Token 34))────►│ (Último Token = 34)
    ▒▒▒                                  │                                    │
    ▒▒▒                                  │───(3. Grava dados (Token 34))─────►│ Aceito! (34 > 33)
    │                                    │                                    │ (Último Token = 34)
    ▒▒▒ [ Acorda do GC ]                 │                                    │
    │                                    │                                    │
    │───(4. Tenta Gravar (Token 33))────┼───────────────────────────────────►│ REJEITADO!
    │                                    │                                    │ (Filtro: 33 < 34)
```

### Padrões e Primitivas Recomendadas:
- **Cláusulas Condicionais SQL (Fencing)**: No banco relacional downstream, modele a tabela de controle com uma coluna `last_fencing_token`. As operações de escrita de negócios devem incluir uma checagem atômica inline:
  ```sql
  UPDATE business_records 
  SET data = @NewData, last_fencing_token = @IncomingToken 
  WHERE id = @RecordId AND last_fencing_token < @IncomingToken;
  ```
  Se o número de linhas afetadas (`Rows Affected`) retornar zero, a aplicação sabe que sofreu uma interceptação de concorrência por outro worker e aborta a operação realizando rollback imediato.
- **Monotonic Token Generator**: Usar mecanismos de contagem do Redis (`INCR`) ou sequências de banco de dados (`SEQUENCE` no PostgreSQL) como fonte confiável de geração de Fencing Tokens monótonos durante a fase de Lock Acquisition.
- **Lease baseada em Redis SET NX PX**: Para adquirir o lock de forma atômica no Redis:
  ```
  SET resource_lock worker_id_fencing_token NX PX 10000
  ```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Rejeição Comprovada de Escrita Atrasada**: Teste funcional onde a aplicação simula uma thread congelada (ex: `Thread.Sleep(12000)`) após adquirir o lock de token 33. Durante o congelamento, outra thread simula a aquisição com token 34 e grava dados. A primeira thread, ao acordar, deve falhar na escrita e o banco de dados deve manter intactos os dados gravados pela segunda thread.
- **Heartbeat resiliente**: Implementação correta da thread secundária de renovação de lease que monitora o progresso real do processamento. Se a thread de processamento principal travar ou entrar em loop infinito, o heartbeat deve parar de renovar o lease no Redis.
- **Prevenção de Locks Eternos**: Garantia de que o TTL do lease é configurado corretamente no Redis na mesma instrução atômica de criação, evitando race conditions onde o comando `SETNX` roda mas o `EXPIRE` falha devido a crash do cliente.

---

## 6. Trade-offs

### A. Redis Redlock vs. Consenso Forte (ZooKeeper/Chubby)
- **Redis (Base de Cache com Replicação Assíncrona)**:
  - *Pró*: Latência sub-milissegundo para adquirir locks; altíssima vazão de requisições.
  - *Contra*: Se o Redis Master sofrer crash antes de replicar a chave do lock para os Slaves, o lock pode ser adquirido duas vezes após o failover (Redlock tenta contornar isso usando múltiplas instâncias independentes, mas possui críticas teóricas complexas).
- **ZooKeeper / Consul (Base com Consenso Raft/Paxos)**:
  - *Pró*: Consistência matemática estrita; tolerância robusta a partições de rede.
  - *Contra*: Latência significativamente maior de escrita por requisição de lock devido à necessidade de consenso entre quóruns de servidores.

### B. Fencing Físico no Banco vs. Verificação Lógica no Worker
- **Fencing Físico no Banco (Recomendado)**:
  - *Pró*: Segurança absoluta. Mesmo que a aplicação tenha bugs de concorrência, o banco impede a gravação inconsistente.
  - *Contra*: Exige alterar os esquemas de todas as tabelas de negócio relevantes para incluir colunas de controle de token.
- **Verificação Lógica no Worker (Checar validade no Redis antes de escrever)**:
  - *Pró*: Simples; não altera esquemas de banco de dados.
  - *Contra*: Frágil. A thread pode verificar que o lock é válido, entrar em pausa de GC de 5ms imediatamente após a verificação e gravar dados corrompidos logo em seguida.
