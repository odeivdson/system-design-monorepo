# Desafio 24: Single-Flight para Colapso de Requisições Concorrentes (`algo-singleflight-collapsing`)
> **Padrões de Arquitetura Distribuída e Concorrência:** Single-Flight (Request Collapsing), Cache Stampede Mitigation (Prevenção de Sobrecarga), Concorrência Lock-Free/Fine-Grained.

## 1. Contexto & Cenário
Em sistemas que atendem volumes massivos de tráfego de leitura (ex: catálogos de produtos de e-commerce, preços de moedas em corretoras ou perfis de celebridades em redes sociais), o cache é a principal ferramenta de escalabilidade. A estratégia clássica é o *Cache-Aside* (ou Lazy Loading): a aplicação tenta ler o dado do Redis; se não encontrar (cache miss), lê do banco relacional durável e grava de volta no cache.

No entanto, em cenários de alta concorrência global, o momento em que a chave do cache expira ou é invalidada cria uma vulnerabilidade séria conhecida como **Cache Stampede** (ou **Thundering Herd**). Se 1.000 requisições simultâneas chegarem para o mesmo produto exatamente no milissegundo em que o cache expirou, todas as 1.000 requisições sofrerão cache miss simultaneamente e dispararão a mesma query pesada `SELECT * FROM products WHERE id = X` contra o banco de dados.

Essa avalanche de consultas idênticas causa contenção de CPU, estouro de conexões e pode levar o banco de dados à indisponibilidade total (o banco cai, a latência aumenta, o que causa mais requisições acumuladas, gerando um efeito dominó de falha). O padrão **Single-Flight** (também chamado de *Request Collapsing* ou *Request Coalescing*) resolve este problema coordenando as threads de execução locais: se múltiplas requisições paralelas solicitarem a mesma chave in-flight (em trânsito), apenas a primeira thread realiza a consulta física; todas as outras aguardam a conclusão dessa mesma tarefa e compartilham o resultado.

---

## 2. Requisitos Funcionais (RF)
- **Registro de Execuções In-Flight**: Manter um mapa em memória que registre as chaves lógicas (ex: `product_123`) que estão ativamente realizando buscas downstream no banco de dados.
- **Colapso de Chamadas (Coalescing)**:
  - Se a chave NÃO existir no mapa de chamadas em andamento, disparar a função de consulta (Database Call) e registrar a promessa/tarefa de retorno no mapa.
  - Se a chave EXISTIR, bloquear a thread atual de forma assíncrona não-bloqueante para esperar pela conclusão da tarefa original registrada.
- **Distribuição de Resultados**: Quando a tarefa primária concluir com sucesso ou erro, retornar o resultado idêntico para todos os chamadores que estavam aguardando em paralelo.
- **Liberação da Chave**: Assim que a chamada finalizar, a chave deve ser imediatamente removida do mapa para permitir novas consultas reais futuras.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Overhead Temporal Mínimo (Sub-Microsegundo)**: A infraestrutura de colapso de chamadas deve introduzir latência irrisória no caminho feliz (hot path), gastando menos de 1 microsegundo de overhead interno.
- **Lock-Free Concurrency**: Evitar o uso de bloqueios globais e exclusivos (locks de nível de método) para gerenciar o dicionário de chamadas em trânsito. Usar sincronizadores refinados (como `ConcurrentDictionary` com controle de estados atômicos em C#, ou no Java `ConcurrentHashMap` com loops de computação atômica `.computeIfAbsent`).
- **Resiliência a Erros Downstream (Transient Failures)**:
  - Se a consulta downstream falhar (ex: timeout temporário de banco de dados), a falha deve ser propagada para todos os aguardantes simultâneos, mas a chave correspondente no mapa do Single-Flight deve ser limpa imediatamente para que a próxima requisição execute uma nova tentativa real em vez de prender novos usuários em um ciclo eterno de falha em cache.

---

## 4. Guia de Implementação & Padrões

### Arquitetura de Colapso de Requisições Simultâneas
```
[10 Reqs Simultâneas por "prod_123"]
   │
   ▼
┌───────────────────────────────────────────────┐
│        Single-Flight Interceptor              │
│                                               │
│  Check: key "prod_123" exists in map?         │
└──────┬───────────────────────────────┬────────┘
       │ (Não: 1ª thread chega)        │ (Sim: outras 9 threads chegam)
       ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│  Dispara Busca no Banco e   │ │  Apenas aguarda a promessa  │
│  registra Task no mapa.     │ │  da Task correspondente no  │
│  - TaskTask = QueryDB()     │ │  mapa (Awaiting TaskTask)   │
└──────────────┬──────────────┘ └──────────────┬──────────────┘
               │                               │
       (Retorna de DB)                 (Acorda do await)
               │                               │
               ▼                               ▼
     Funde e distribui o mesmo resultado para todos os 10 chamadores
               │
               ▼
   Remove chave "prod_123" do mapa do Single-Flight
```

### Padrões e Primitivas Recomendadas:
- **`ConcurrentDictionary` + Computação sob Demanda**: Utilizar o método atomizado do dicionário concorrente para inserir o wrapper de promessa na coleção de forma segura. Em C#, o uso de `Lazy<Task<T>>` ou o encapsulamento em objetos de sincronização garante que a função de criação da tarefa de banco de dados execute exatamente uma vez.
- **CancellationToken Propagation**: O Single-Flight deve tratar o cancelamento de requisições de forma isolada. Se um cliente que estava aguardando cancelar a sua chamada HTTP, a chamada original no banco de dados não deve ser cancelada se ainda existirem outros clientes aguardando pela conclusão do resultado correspondente (Reference Counting de consumidores).

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Zero Duplicação de Queries Downstream**: Execução funcional demonstrando 500 chamadas simultâneas feitas em paralelo contra a mesma chave. O mock de banco de dados associado deve registrar exatamente 1 única chamada de leitura física.
- **Mitigação de Lock Contention**: Como evitar gargalos de performance caso o dicionário de chamadas in-flight sofra escritas paralelas agressivas para chaves diferentes. O avaliador buscará estruturas de dicionário com segmentação fina (Lock Striping ou buckets concorrentes independentes).
- **Tratamento de Exceções Sem Poluição de Cache**: Garantia de que exceções lançadas pela tarefa downstream são capturadas e propagadas de forma limpa, assegurando que o dicionário de estados remova a chave para evitar estados corrompidos persistentes.
- **Thread Safety Geral**: Ausência total de condições de corrida (Race Conditions) onde uma thread tenta remover a chave após o término exatamente no mesmo nanossegundo em que uma nova thread tenta adicioná-la para iniciar uma nova busca.

---

## 6. Trade-offs

### A. Single-Flight vs. Cache Pre-warming (Aquecimento de Cache)
- **Single-Flight (Recomendado para dados dinâmicos/catálogos)**:
  - *Pró*: Reativo e automático; não requer adivinhar quais chaves expirarão; consome memória apenas temporariamente durante a janela de trânsito (frações de milissegundo).
  - *Contra*: O primeiro usuário que iniciou a chamada física arca com a latência real de leitura do banco de dados (ex: 80ms).
- **Cache Pre-warming (Job de background de aquecimento)**:
  - *Pró*: Latência zero para todos os usuários reais, já que o dado é atualizado em background antes do TTL expirar.
  - *Contra*: Complexidade operacional de agendamento; desperdício de escrita e CPU atualizando chaves frias (pouco acessadas) de forma desnecessária.

### B. Compartilhar Erros vs. Retentar Individualmente no Timeout
- **Propagar o Erro da Primeira Tarefa para Todos (Recomendado)**:
  - *Pró*: Evita que threads concorrentes continuem esperando ou inundem o banco de dados com retentativas paralelas sequenciais se o banco estiver sofrendo sobrecarga severa global.
  - *Contra*: Uma falha transiente para um usuário causa a falha imediata de todas as outras requisições conectadas ao mesmo colapso de chamada.
