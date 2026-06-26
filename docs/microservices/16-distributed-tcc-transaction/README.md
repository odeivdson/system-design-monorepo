# Desafio 16: Transações Distribuídas com Try-Confirm-Cancel (TCC) (`distributed-tcc-transaction`)

## 1. Contexto & Cenário
Em ecossistemas de microsserviços distribuídos, realizar transações que envolvem múltiplos bancos de dados e serviços independentes é um dos maiores desafios de arquitetura. O protocolo clássico de Duas Fases (Two-Phase Commit - 2PC) garante consistência atômica rígida (ACID), mas ele exige travas físicas nos bancos de dados durante todo o processo. Isso estrangula a vazão do sistema (throughput) e gera riscos graves de deadlocks. Além disso, muitos bancos NoSQL modernos e APIs de parceiros de pagamento externos (como Stripe ou gateways bancários) não suportam 2PC.

O padrão **Saga** é amplamente utilizado como alternativa baseada em consistência eventual, executando compensações assíncronas em caso de falha. Contudo, Sagas não fornecem isolamento transacional: um recurso pode ser gasto ou alterado temporariamente no meio do caminho, gerando anomalias de leitura (leitura suja) e problemas complexos de negócios (como sobrefaturamento ou reservas fantásticas de assentos de avião que depois precisam ser desfeitas).

Para cenários que exigem consistência rígida sem travas de banco de dados de baixo nível, projetamos o padrão **TCC (Try-Confirm-Cancel)** na camada da aplicação. O TCC divide a transação distribuída em três etapas distintas de negócio:
1. **Try (Tentar)**: Verificar a disponibilidade de recursos e realizar uma **reserva lógica temporária** (ex: mover o assento do voo para o estado "Reservado_Pendente", ou transferir R$ 100 de saldo ativo para um saldo especial "Saldo_Bloqueado").
2. **Confirm (Confirmar)**: Consolidar a operação definitivamente (ex: alterar o assento para "Confirmado" ou debitar o valor do "Saldo_Bloqueado"). Esta fase é executada somente se todos os participantes responderem com sucesso no `Try`.
3. **Cancel (Cancelar)**: Liberar o recurso bloqueado na fase Try caso algum participante falhe ou sofra timeout (ex: voltar o assento para "Disponível" ou estornar o valor do "Saldo_Bloqueado" de volta ao saldo ativo).

O objetivo deste desafio é desenhar um Coordenador TCC resiliente a falhas físicas de rede e de concorrência.

---

## 2. Requisitos Funcionais (RF)
- **Fase de Tentativa (`ExecuteTry`)**: Disparar chamadas `Try` concorrentes para todos os microsserviços participantes do fluxo de reserva.
- **Fase de Confirmação (`ExecuteConfirm`)**: Confirmar e finalizar a transação em todos os serviços caso a fase de Try tenha sido aprovada por todos.
- **Fase de Cancelamento (`ExecuteCancel`)**: Reverter e liberar as reservas parciais em todos os serviços se houver falha de rede ou timeout em qualquer chamada da fase Try.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Idempotência Absoluta nos Participantes**: Os endpoints de `Try`, `Confirm` e `Cancel` em cada microsserviço participante devem ser estritamente idempotentes. Se o coordenador sofrer quedas de rede e reenviar a chamada de `Confirm` 5 vezes, a ação física só pode ser executada uma única vez, retornando sucesso nas seguintes.
- **Gerenciamento de Timeouts e Reservas Expiradas (Leases)**: Se o coordenador cair no meio do caminho ou um participante travar durante a fase `Try`, as reservas lógicas locais não podem ficar bloqueadas para sempre na base de dados. Cada reserva lógica deve possuir um tempo de expiração (Lease). Um processo em background do participante deve liberar automaticamente os recursos bloqueados cujo prazo de expiração expirou sem receber a chamada `Confirm`.
- **Prevenção da Corrida Cancel-Before-Try**: Devido a atrasos de rede, uma mensagem de `Cancel` de uma transação abortada pelo coordenador pode chegar a um participante antes que a mensagem original de `Try` chegue. O participante deve registrar o cancelamento prévio de forma que, quando o `Try` tardio finalmente chegar, ele seja rejeitado imediatamente para evitar uma reserva órfã eterna.

---

## 4. Guia de Implementação & Padrões

O ciclo de estados do Coordenador de Transações TCC e a interação com os microsserviços participantes ocorrem conforme ilustrado abaixo:

```
                  ┌───────────────────────────────┐
                  │ Coordenador TCC (Orquestrador)│
                  └───────────────┬───────────────┘
                                  │
      ┌───────────────────────────┼───────────────────────────┐
      ▼ (1. Try - Reserva)        ▼ (2. Confirm - Consolida)  ▼ (3. Cancel - Libera)
┌─────────────┐             ┌─────────────┐             ┌─────────────┐
│  Serviço A  │             │  Serviço B  │             │  Serviço C  │
│ [Reservas]  │             │ [Reservas]  │             │ [Reservas]  │
└─────────────┘             └─────────────┘             └─────────────┘
```

### Padrões e Máquina de Estados Recomendados:
- **Tabela de Logs de Transação (Transaction Journal)**: O Coordenador TCC deve manter uma tabela ACID local registrando as transições da sua própria máquina de estados (`INITIAL` -> `TRYING` -> `CONFIRMING` / `CANCELLING` -> `COMPLETED` / `CANCELLED`). Se o coordenador sofrer um crash físico de servidor no meio do passo de `Confirm`, ao reiniciar ele lê o log de transações ativas e retoma os envios de confirmação pendentes até obter sucesso de 100%.
- **Chave de Idempotência Global**: Cada transação TCC gera uma chave UUID de transação única na origem. Todos os participantes associam suas reservas lógicas locais a esta chave UUID.
- **Tabela de Bloqueio de Cancelamento Prévio (Anti-Try Registry)**: Manter um registro de transações canceladas no participante. Se um `Cancel(UUID)` chega para uma transação desconhecida, o participante salva que a chave `UUID` foi preventivamente cancelada, rejeitando qualquer tentativa subsequente de `Try(UUID)`.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Implementação do Mecanismo Cancel-Before-Try**: O candidato deve mostrar no código de negócio de um participante como ele valida se um Cancel ocorreu antes do Try e impede o vazamento de recursos na base.
- **Consistência do Estado do Coordenador Pós-Crash**: Apresentar a lógica de recuperação (Recovery Loop) do coordenador. O coordenador deve ser capaz de provar que garante a entrega de confirmações/cancelamentos *at-least-once* mesmo se sofrer falhas sequenciais de energia.
- **Isolamento de Recursos em Nível de Aplicação**: Mostrar que os recursos em estado "pendente de confirmação" não estão visíveis como disponíveis para novos clientes, mas podem ser facilmente revertidos sem a necessidade de locks físicos de tabelas (`SELECT ... FOR UPDATE` de longa duração).

---

## 6. Trade-offs

### A. TCC vs. Sagas Compensatórias
- **TCC (Recomendado para consistência estrita)**: Oferece isolamento de transação na aplicação. O saldo ou recurso fica "preso" e nenhum outro processo pode utilizá-lo até a resolução, eliminando anomalias de leituras intermediárias sujas.
  - *Contra*: Requer desenvolvimento mais complexo (cada microsserviço participante precisa implementar 3 métodos: Try, Confirm e Cancel) e gera maior latência global devido ao fluxo em duas fases na camada de aplicação.
- **Sagas Compensatórias**: Mais simples em termos de endpoints (não há necessidade de método Try nem de saldo bloqueado). Bastam ações normais de negócio e suas respectivas ações inversas de compensação.
  - *Contra*: Não há isolamento. Se um usuário compra um produto, o estoque é reduzido. Se a transação falhar depois, o estoque é restaurado via compensação, mas nesse meio tempo outro usuário pode ter recebido um erro de "estoque esgotado" injustamente.

### B. Coordenador TCC Centralizado (Orquestração) vs. TCC Coreografado
- **Orquestração Centralizada (Recomendado)**: Um único serviço central controla a máquina de estados e dispara os comandos para os participantes.
  - *Pró*: Fácil de depurar, monitorar e rastrear o estado exato da transação distribuída em tempo real.
- **Coreografia (Orientada a Eventos)**: Os microsserviços reagem a eventos publicados em tópicos de mensageria para transitar de fase.
  - *Contra*: Dificuldade extrema de garantir idempotência do Confirm/Cancel sob entrega desordenada de eventos e grande complexidade para rastrear falhas de timeout de forma unificada.
