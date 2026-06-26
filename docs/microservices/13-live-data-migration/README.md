# Desafio 13: Migração de Dados Live Sem Downtime (`live-data-migration`)

## 1. Contexto & Cenário
Em arquiteturas de microsserviços em escala de Big Tech, a evolução tecnológica e o aumento de tráfego frequentemente exigem a substituição ou particionamento das bases de dados originais. Um cenário clássico de entrevista de nível Staff/Principal envolve migrar um repositório de dados transacionais de altíssima criticidade (como a base de dados de cartões ou pagamentos dos clientes) de um banco legado (ex: PostgreSQL) para uma nova persistência de alta escalabilidade (ex: DynamoDB ou Cassandra), sob tráfego ativo de milhares de requisições por segundo, com **zero downtime** (nenhuma janela de manutenção aceitável).

Se tentarmos desligar o sistema para rodar um script de exportação, causaremos perdas financeiras massivas e violaremos SLAs rigorosos. Se tentarmos simplesmente redirecionar o tráfego de gravação de forma abrupta enquanto copiamos os dados antigos, causaremos inconsistência grave ou indisponibilidade parcial durante a transição.

A solução padrão de engenharia distribuída para esse problema é a **Migração em 4 Fases**:
1. **Dual-Write (Escrita Dupla)**: A aplicação passa a gravar dados de forma atômica/paralela na base antiga e na base nova.
2. **Sincronização Histórica (Backfill)**: Um processo assíncrono copia todos os registros legados criados antes do início do dual-write para a base nova.
3. **Reconciliação Contínua (Reconciliation)**: Um worker inspeciona e compara os registros de ambas as bases periodicamente, identificando divergências e executando auto-correções na nova base.
4. **Corte Gradual (Cutover)**: O tráfego de leitura é chaveado aos poucos para a base nova. Após a estabilização, a escrita na base antiga é desativada definitivamente.

O objetivo deste desafio é projetar esta arquitetura tolerante a falhas, concorrência e falhas parciais de rede.

---

## 2. Requisitos Funcionais (RF)
- **Escrita Dupla (`WriteRecord`)**: Gravar novos registros em ambas as bases de dados (Legada e Nova).
- **Processador de Backfill (`RunBackfill`)**: Sincronizar dados históricos anteriores ao início do dual-write em lotes limitados por throughput (throttling) para não sobrecarregar as bases.
- **Serviço de Reconciliação (`Reconcile`)**: Comparar dados de uma janela temporal, corrigindo a nova base em caso de diferenças (updates faltantes ou exclusões).
- **Roteador de Tráfego (`RouteTraffic`)**: Mapear chaves de configuração dinâmicas para gerenciar as permissões de leitura/escrita em cada base nas fases de transição.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Isolamento e Resiliência na Nova Base**: Falhas de escrita, timeouts ou indisponibilidade da nova base de dados durante a fase de dual-write nunca devem causar falha no fluxo principal da aplicação. A base legada é a fonte da verdade e o sucesso nela determina a resposta ao cliente.
- **Garantia Anti-Sobrescrita (Out-of-Order Mitigation)**: O backfill histórico ou o reconciliador nunca podem substituir dados mais novos já gravados pelo dual-write na base nova com valores antigos. Cada registro deve possuir controle de versão (`Version`) ou timestamp de última atualização (`UpdatedAt`) para validação atômica in-database.
- **Rollback Imediato**: Se problemas forem identificados após chavear as leituras para a nova base, a arquitetura deve permitir reverter as leituras para a base legada instantaneamente sem perda de dados ou indisponibilidade.

---

## 4. Guia de Implementação & Padrões

O ciclo de vida da migração e os fluxos de sincronia concorrentes operam de acordo com as seguintes fases:

```
 Fase 1: [Escrita Dupla (Dual-Write)]
              ┌───────────────┐
              │  Aplicação    │
              └───┬───────┬───┘
   (Sucesso)      │       │      (Falha Isolada)
                  ▼       ▼
           ┌────────┐   ┌────────┐
           │ Legacy │   │  New   │ (Ignora erro no app /
           │   DB   │   │   DB   │  recupera via Reconciler)
           └────────┘   └────────┘
 
 Fase 2 & 3: [Backfill & Reconciliador Assíncrono]
  ┌────────┐                     ┌────────┐
  │ Legacy │ ────► [Worker] ────►│  New   │ (Verifica Timestamp/Versão
  │   DB   │   Reconcile/Backfill│   DB   │  antes de gravar)
  └────────┘                     └────────┘
```

### Padrões e Primitivas Recomendados:
- **Write Path Abstraction**: Utilizar o padrão Repository ou Strategy para encapsular as chamadas de banco de dados por trás de uma interface limpa. A lógica de chaveamento de fases é injetada nessa camada de forma transparente para as regras de negócio.
- **Versionamento de Registros (Optimistic Concurrency)**: Usar expressões SQL condicionais (ex: `UPDATE ... WHERE version < incoming_version`) ou travas otimistas na base nova. Isso impede que o backfill assíncrono sobrescreva atualizações ricas criadas em tempo real.
- **Mapeamento de Feature Flags Dinâmicas**: Utilizar um serviço de configurações centralizado (ex: Consul, ZooKeeper ou Redis) para alternar os estados da migração:
  - `Phase_1_Legacy_Only`: Leitura/Escrita apenas na antiga.
  - `Phase_2_Dual_Write_Read_Legacy`: Escrita em ambas, leitura na antiga.
  - `Phase_3_Dual_Write_Read_New`: Escrita em ambas, leitura na nova.
  - `Phase_4_New_Only`: Leitura/Escrita apenas na nova (Fim).

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Prova de Tratamento de Erros e Deadlocks**: O candidato deve mostrar como lida com falhas parciais (ex: gravação na legada funciona, mas falha na nova). As chaves falhas devem ser catalogadas (ex: via logs de erro ou fila dead-letter) para reconciliação prioritária imediata.
- **Logica de Reconciliação Bidirecional**: O reconciliador deve checar exclusões. Se um dado foi excluído da base legada, ele deve ser excluído da nova. O reconciliador não deve gerar duplicações artificiais.
- **Estratégia de Throttling**: O processo de backfill histórico deve rodar com limitadores de vazão baseados em métricas de capacidade de I/O das bases para evitar sobrecarregar o banco de produção e causar lentidão geral para os usuários.

---

## 6. Trade-offs

### A. Escrita Dupla na Aplicação vs. Replicação Baseada em CDC (Change Data Capture)
- **Escrita Dupla na Aplicação (Recomendado para este desafio)**: Total controle sobre o fluxo e facilidade de manipulação de formato/esquema das tabelas diretamente no código da aplicação.
  - *Contra*: Adiciona latência na escrita (executa duas chamadas de rede em paralelo/sequência) e aumenta a complexidade lógica do microsserviço.
- **Replicação CDC (ex: Debezium + Kafka)**: Desacoplamento total do app. As escritas na base legada são capturadas dos logs físicos (WAL) e gravadas assincronamente na base nova.
  - *Pró*: Latência zero adicionada no fluxo principal da aplicação.
  - *Contra*: Complexidade operacional de manter infraestrutura de streaming adicional ativa e maior dificuldade para mapear transformações de dados complexas entre tabelas relacionais e NoSQL.

### B. Reconciliação Exaustiva vs. Amostragem Estatística
- **Reconciliação Exaustiva**: Compara 100% de todos os registros existentes.
  - *Pró*: Garante consistência matemática absoluta antes do desligamento da base antiga.
  - *Contra*: Elevadíssimo custo de computação e leitura sobre as bases de produção.
- **Reconciliação por Amostragem**: Compara apenas chaves atualizadas recentemente ou blocos aleatórios amostrais.
  - *Pró*: Baixo impacto operacional nas bases de dados.
  - *Contra*: Risco de manter dados frios corrompidos ou inconsistentes na nova base de forma invisível.
