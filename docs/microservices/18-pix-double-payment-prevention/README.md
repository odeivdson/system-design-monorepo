# Desafio 18: Prevenção de Duplo Pagamento no Pix (Idempotency Engine) (`pix-double-payment-prevention`)

## 1. Contexto & Cenário
O Sistema de Pagamentos Instantâneos (SPI / Pix) no Brasil exige que as transferências financeiras ocorram em tempo real, com latência de ponta a ponta inferior a poucos segundos. Em sistemas bancários e gateways de pagamento de alta vazão, a garantia de que uma transação financeira seja processada **exatamente uma vez (Exactly-once semantics)** é o requisito mais crítico de consistência.

 timeouts de rede são comuns no meio de comunicações financeiras complexas. Se um usuário inicia uma transferência Pix e a resposta demora para retornar devido a uma oscilação na internet do celular, o aplicativo ou o microsserviço de mensageria interna disparará uma retentativa automática de envio. Se a transação não estiver protegida, a instituição financeira executará a transferência de saldo duas vezes, resultando em um gravíssimo problema de **duplo pagamento (Double-payment)**, gerando prejuízos financeiros severos e problemas de conciliação difíceis de reverter.

A solução padrão de engenharia financeira para este cenário é construir um **Motor de Idempotência (Idempotency Engine)**. Cada transação de pagamento é rotulada na origem com uma chave de idempotência única (no Pix, o End-to-End ID / E2E ID). 

O fluxo concorrente de uma requisição idempotente segue um ciclo de estados rigoroso:
1. Ao receber a chamada com a chave de idempotência, o sistema verifica seu estado no banco/cache de dados.
2. Se a chave não existir, ela é registrada no estado `PROCESSING` (Processando) de forma atômica utilizando travas concorrentes. O processamento financeiro é executado (débito de saldo e envio ao BACEN). Ao concluir, o estado da chave é atualizado para `SUCCESS` (Sucesso) e a resposta do processamento é cacheada.
3. Se a chave já existir no estado `SUCCESS`, a resposta cacheada da transação anterior é retornada imediatamente ao cliente, sem reexecutar qualquer movimentação financeira.
4. Se a chave existir no estado `PROCESSING`, significa que outra réplica/thread já está processando este mesmo pagamento neste exato milissegundo. A chamada concorrente deve aguardar a conclusão ou ser rejeitada temporariamente para evitar conflitos.

O objetivo deste desafio é projetar esse motor financeiro robusto contra race conditions e falhas de rede.

---

## 2. Requisitos Funcionais (RF)
- **Transferir Saldo Idempotente (`ExecutePixTransfer`)**: Processar o débito e a transferência de valores de forma segura e idempotente baseando-se na chave do Pix (`idempotencyKey`, `sourceAccountId`, `targetAccountId`, `amount`).
- **Consultar Histórico da Transação (`GetTransaction`)**: Retornar o resultado e os metadados de uma transação Pix já processada a partir da chave de idempotência.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Neutralização de Corrida Concorrente Simultânea**: Se duas chamadas HTTP idênticas contendo a mesma chave de idempotência baterem em nós diferentes da aplicação no mesmo milissegundo, o sistema deve garantir que apenas uma consiga iniciar o processamento, enquanto a outra é bloqueada ou aguarda a conclusão, neutralizando o risco de duplo débito.
- **Tratamento de Travas Órfãs sob Crash (Lease/TTL)**: Se o pod que iniciou o processamento da transação sofrer um crash físico no meio do débito de saldo, a chave de idempotência não pode ficar eternamente travada em estado `PROCESSING`. A trava ou registro temporário deve possuir uma expiração física (Lease/TTL) que libere a chave para reprocessamento ou transite o estado para `FAILED` de forma atômica.
- **Persistência Confiável de Respostas Cacheadas**: O payload de retorno cacheado associado à chave de idempotência bem-sucedida deve ser armazenado em persistência durável (banco de dados relacional ou NoSQL com backups), evitando que a expiração física de um cache temporário (como Redis em memória) faça o sistema reexecutar pagamentos antigos que já foram liquidados.

---

## 4. Guia de Implementação & Padrões

O ciclo de coordenação de concorrência e transição de estados do motor de idempotência é detalhado a seguir:

```
                      [ Requisição Pix (Chave ID) ]
                                   │
                     ▼ (Verifica e Adquire Lock)
            ┌─────────────────────────────────────────────┐
            │  Distribuidor de Lock (Redis SETNX/Redlock) │
            └──────────────────────┬──────────────────────┘
                                   │
               ┌───────────────────┴───────────────────┐
      (Lock Negado /               │                   │ (Lock Adquirido /
    Chave PROCESSING)              │                   │  Chave Inexistente)
               ▼                   │                   ▼
     ┌───────────────────┐         │         ┌───────────────────┐
     │  Aguardar / Poll  │         │         │  Registra Chave   │
     │  ou Fail Fast     │         │         │  `PROCESSING`     │
     └───────────────────┘         │         └─────────┬─────────┘
                                   │                   │
                                   │                   ▼ (Transação de Saldo)
                                   │         ┌───────────────────┐
                                   │         │ Débito + Envio    │
                                   │         │ PIX (BACEN)       │
                                   │         └─────────┬─────────┘
                                   │                   │
                                   │                   ▼ (Finalização)
                                   │         ┌───────────────────┐
                                   │         │ Grava `SUCCESS` + │
                                   │         │ Salva Resposta DB │
                                   └────────►└─────────┬─────────┘
                                                       │
                                                       ▼ (Libera Lock)
                                             [ Retorna Resposta ]
```

### Padrões e Primitivas Recomendados:
- **Distributed Locking (Redis Redlock / SETNX)**: Utilizar um lock distribuído no Redis no início da chamada usando a chave de idempotência como identificador. O comando `SET key value NX PX 10000` adquire a exclusão mútua por 10 segundos de forma atômica.
- **Double-Check Locking Pattern**: Ao obter a trava, a aplicação deve consultar novamente o banco de dados de idempotência persistente para se certificar de que a transação não foi concluída por outra thread enquanto aguardava a liberação do lock.
- **Estados de Transição Limpos no DB**: A tabela de idempotência no banco de dados deve possuir a chave de idempotência como chave primária (`PRIMARY KEY`) ou índice único. A inserção em estado `PROCESSING` deve ser feita de forma atômica e forçada. Se houver colisão de índice único na inserção, a aplicação detecta imediatamente a chamada duplicada.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Lógica de Tratamento de Concorrência Simultânea**: O que acontece com a segunda requisição concorrente que bate enquanto a primeira ainda está `PROCESSING`? O motor de idempotência deve demonstrar comportamento robusto: ou aguarda (polling controlado com limite de tempo) até que a primeira thread conclua e retorne o resultado cacheado, ou retorna de imediato um erro amigável de conflito de concorrência com cabeçalho `Retry-After` (HTTP `425 Too Early` ou HTTP `409 Conflict`).
- **Atomicidade entre Estado de Idempotência e Saldo do Usuário**: A transação de débito do saldo da conta do cliente e a atualização da chave de idempotência de `PROCESSING` para `SUCCESS` devem ser commitadas sob a mesma transação ACID local do banco de dados, garantindo que o dinheiro nunca suma da conta do cliente sem o respectivo registro de sucesso de idempotência estar gravado.
- **Idempotência no Fluxo de Falha**: Se a transação Pix falhar de forma definitiva (ex: conta de destino inexistente), a chave de idempotência deve transitar para `FAILED` ou ser removida do banco, permitindo que o cliente tente novamente a transferência com os dados corretos mais tarde.

---

## 6. Trade-offs

### A. Idempotência em Memória (Redis) vs. Idempotência no Banco de Dados Relacional
- **Idempotência em Memória (Redis)**: Performance extrema e latência sub-milissegundo para checagens e locks atômicos rápidos.
  - *Contra*: Risco de perda de dados sob reinicialização ou falha de persistência do Redis. Se as chaves expirarem ou sumirem da memória, o sistema poderá reprocessar transações antigas de forma duplicada.
- **Idempotência no Banco de Dados Relacional (Recomendado para consistência financeira)**: Garantia ACID absoluta e durabilidade perpétua dos retornos de pagamento já efetuados.
  - *Contra*: Sobrecarga de I/O no banco de dados principal a cada requisição de pagamento recebida, além de aumentar o risco de contenção de travas e deadlocks se as transações forem longas.

### B. Polling de Espera vs. Fail Fast sob Chave Ativa (`PROCESSING`)
- **Polling de Espera (Blocking/Waiting)**: A segunda requisição concorrente fica segurando a conexão HTTP e consultando o banco periodicamente até o processamento da primeira thread terminar, retornando o resultado final de imediato.
  - *Pró*: Excelente experiência para o usuário que recebe o sucesso sem precisar recomeçar o fluxo no aplicativo.
  - *Contra*: Consome recursos de threads do servidor que ficam bloqueadas aguardando a finalização da outra operação de rede.
- **Fail Fast (HTTP 425 / 409)**: Rejeitar a segunda requisição imediatamente avisando que a transação já está sendo processada.
  - *Pró*: Libera recursos de processamento do servidor instantaneamente.
  - *Contra*: O cliente recebe erros na tela do celular e precisa lidar com lógica complexa de retentativas no frontend do app.
