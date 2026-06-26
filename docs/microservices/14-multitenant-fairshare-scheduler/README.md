# Desafio 14: Isolamento de Recursos Multi-Tenant e Filas Justas (`multitenant-fairshare-scheduler`)

## 1. Contexto & Cenário
Em arquiteturas de software como Serviço (SaaS) multi-tenant de larga escala (como Stripe, Shopify, AWS ou Salesforce), os recursos computacionais subjacentes (threads de execução, conexões de banco de dados e CPU) são compartilhados entre múltiplos clientes (tenants). Um dos problemas operacionais mais graves nesse cenário é o efeito **Noisy Neighbor (Vizinho Barulhento)**.

Imagine que o Tenant A dispare repentinamente um lote de 1.000.000 de requisições de sincronização de dados ou processamento de faturas em massa. Em um design ingênuo onde todas as requisições de entrada caem em uma fila global unificada de processamento (`FIFO` pura), o lote massivo do Tenant A ocupará todas as vagas na fila e consumirá todos os workers da aplicação. Se o Tenant B (um usuário menor ou com uso normal) enviar uma única requisição crítica de checkout nesse momento, essa chamada ficará presa atrás do milhão de requisições do Tenant A, sofrendo timeouts severos e degradando a experiência de uso.

Embora limitadores de taxa (Rate Limiters) globais protejam a integridade geral do sistema, eles simplesmente barram requisições adicionais após o limite, sem gerenciar a distribuição justa do processamento interno que já foi aceito pelo sistema. Para garantir resiliência e estabilidade, engenheiros Staff projetam **Agendadores de Partilha Justa (Fair-Share Schedulers)** acoplados a estruturas de isolamento de recursos por Tenant. O objetivo deste desafio é projetar um agendador multi-tenant robusto baseado em partilha justa de processamento (Fair-Share Queueing).

---

## 2. Requisitos Funcionais (RF)
- **Submissão de Requisição (`SubmitRequest`)**: Receber e direcionar a chamada de um determinado tenant (`tenantId`, `payload`) para a sua respectiva estrutura de isolamento.
- **Processamento Justo (`ProcessNext`)**: O loop interno de execução dos workers deve coletar e executar as tarefas dos tenants garantindo que nenhuma fila seja totalmente ignorada ou monopolize o sistema.
- **Configuração de Prioridades (`SetTenantWeight`)**: Permitir parametrizar pesos (prioridades) dinâmicos para tenants premium, garantindo a eles uma fatia maior de alocação de tempo de processamento quando houver disputa por recursos.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Isolamento de Contágio (Noisy Neighbor Mitigation)**: A inundação de requisições do Tenant A nunca deve elevar a latência de processamento de requisições avulsas do Tenant B além de um limite aceitável e previsível.
- **Alocação de Vazão Justa sob Sobrecarga (Fairness)**: O algoritmo de distribuição de tarefas deve garantir progresso proporcional baseado em peso (`Weight`) para cada tenant ativo em caso de disputa síncrona por CPU/Workers.
- **Proteção Contra Estouro de Memória (Bounded Queues)**: Cada tenant possui uma fila delimitada em número máximo de itens em espera. Se um tenant específico inundar o sistema e estourar o limite local de sua fila, as requisições excedentes desse tenant específico devem ser rejeitadas imediatamente na borda (Fail Fast) com erro HTTP `429 Too Many Requests`, protegendo a memória do servidor contra vazamentos e travamentos por falta de memória (OOM).

---

## 4. Guia de Implementação & Padrões

Para estruturar o agendador justo, isolamos as requisições em buffers individuais de menor escala e aplicamos um algoritmo de escalonamento circular ponderado:

```
               [ Requisições de Entrada Gateway ]
                               │
            ┌──────────────────┴──────────────────┐ (Identifica Tenant)
            ▼                                     ▼
     ┌─────────────┐                       ┌─────────────┐
     │ Fila Tenant │ (Bounded)             │ Fila Tenant │ (Bounded)
     │  [Tenant A] │                       │  [Tenant B] │
     └──────┬──────┘                       └──────┬──────┘
            │                                     │
            └──────────────────┬──────────────────┘
                               │
                               ▼ [ Agendador Fair-Share (DRR / WFQ) ]
                       ┌───────────────┐
                       │  Pool de      │
                       │  Workers      │
                       └───────────────┘
```

### Padrões e Algoritmos Recomendados:
- **Deficit Round Robin (DRR) ou Weighted Fair Queueing (WFQ)**: O DRR é ideal pela simplicidade computacional de $O(1)$. Cada tenant ativo possui um "crédito de déficit" (quantum de bytes ou número de tarefas). O agendador percorre as filas ativas sequencialmente, consumindo tarefas e debitando o custo do crédito. Se o crédito expirar, o agendador passa para o próximo tenant, mantendo o saldo restante para a próxima rodada. Isso impede que filas gigantescas monopolizem os workers.
- **Fila de Tenants Ativos (Active List)**: Para evitar percorrer milhares de filas vazias desperdiçando ciclos de CPU, manter uma lista/fila encadeada dinâmica contendo apenas referências para as chaves de tenants que possuem tarefas ativas em espera.
- **Queue Map Concorrente**: Utilizar um mapa de controle `ConcurrentDictionary<TenantId, TenantQueue>` protegido por travas finas ou lock-free para manipulação segura de entrada e saída de filas de clientes.

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Verificação Matemática de Proporcionalidade**: Provar que o agendador distribui o tempo de CPU proporcionalmente aos pesos dos tenants sob carga constante. Se o Tenant A tem peso 2 e o Tenant B tem peso 1, o Tenant A deve processar o dobro de tarefas do Tenant B em cenários de saturação de fila.
- **Eficiência de Travessia e Complexidade $O(1)$**: O agendador não deve ter complexidade dependente do número total de tenants cadastrados ($O(N)$), mas sim do número de tenants ativos ou workers livres ($O(1)$ amortizado).
- **Tratamento de Envelhecimento (Starvation Prevention)**: Mostrar que mesmo tenants pequenos de baixa prioridade (peso muito baixo) eventualmente progridem e têm suas requisições executadas sem sofrer de inanição crônica de CPU.

---

## 6. Trade-offs

### A. Fila Isolada por Tenant vs. Fila Compartilhada Única com Tags de Prioridade
- **Fila Isolada por Tenant (Recomendado para este desafio)**: Isolamento físico perfeito. O estouro de limite de requisições de um tenant afeta exclusivamente a sua própria fila, permitindo Fail Fast localizado.
  - *Contra*: Maior consumo de memória do sistema para gerenciar e manter milhares de instâncias de filas em memória.
- **Fila Única Compartilhada Ponderada (ex: baseada em Heap/Priority Queue)**: Baixo consumo de memória e ordenação global unificada.
  - *Contra*: Inserção e remoção em Priority Queues escalam em $O(\log N)$, gerando gargalos de ordenação sob milhões de itens, além da dificuldade de aplicar limites individuais de fila para Fail Fast localizado de forma barata.

### B. Modelo Push (Push-based scheduling) vs. Modelo Pull (Pull-based scheduling)
- **Modelo Pull (Recomendado)**: Os workers da aplicação buscam (pull) tarefas ativamente do agendador à medida que ficam ociosos.
  - *Pró*: Distribuição natural baseada na capacidade física dos workers e excelente controle de Backpressure.
- **Modelo Push**: O agendador dispara (push) ativamente as tarefas para os canais dos workers assim que chegam.
  - *Contra*: Risco de sobrecarregar buffers internos dos workers caso a taxa de envio supere a taxa real de conclusão física dos processos.
