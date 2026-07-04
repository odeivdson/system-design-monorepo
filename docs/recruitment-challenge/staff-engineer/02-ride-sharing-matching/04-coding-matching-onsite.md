# 💻 Trilha 2 - Etapa 4: Coding Onsite - Fila de Despacho Geoespacial

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Concorrência, estruturas de dados geoespaciais em memória e controle de concorrência thread-safe.

---

## 🎯 O Enunciado do Desafio

No sistema de despacho de corridas, quando um passageiro solicita um veículo, o motor de pareamento precisa buscar os motoristas livres em um raio geográfico crescente (ex.: buscar em 1km, se não achar, expandir para 2km, depois 3km).

O candidato deve implementar, na linguagem de sua preferência, um **Gerenciador de Disponibilidade de Motoristas** thread-safe que suporte o registro de posições de motoristas em tempo real e a busca concorrente baseada em grids hexagonais (simplificados).

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve implementar uma classe `DriverGeoRegistry` com os seguintes métodos:

### 1. `RegisterDriver(driverId string, cellId int)`
* Registra ou atualiza a posição do motorista em uma célula específica do grid (representada por um ID inteiro simplificado).
* O método deve ser extremamente rápido e suportar concorrência de escrita massiva.

### 2. `AcquireDriverForMatch(cells []int) (string, error)`
* Recebe uma lista de células do grid (ordenadas por proximidade do passageiro, do centro para as bordas).
* Deve encontrar o primeiro motorista disponível em uma dessas células, marcá-lo como "ocupado" (removendo-o da fila de disponíveis) e retornar o seu ID.
* **Consistência Crítica:** Duas requisições paralelas para buscar motoristas na mesma área **não podem** receber o mesmo motorista. O processo de seleção e remoção deve ser atômico.

### 3. `ReleaseDriver(driverId string)`
* Libera o motorista, tornando-o disponível novamente na última célula em que foi registrado.

---

## ⚖️ Rubrica de Avaliação de Código

| Nível | Indicadores Práticos no Desafio |
| :--- | :--- |
| 🟥 **Reprovado** | Usa locks globais em toda a estrutura, o que trava a API inteira durante qualquer leitura ou escrita geográfica; gera condições de corrida onde dois passageiros recebem o mesmo motorista. |
| 🟨 **Senior (L5)** | Implementa a indexação usando estruturas de mapas aninhadas (ex.: `Map<int, List<string>>` para representar célula -> motoristas). Usa locks de leitura/escrita (`sync.RWMutex` em Go) para proteger o estado de forma adequada. |
| 🟩 **Staff (L6+)** | Desenha a solução usando **locks granulares por célula** (ex.: um mutex por chave de célula do grid) para evitar contenção global. Discute como otimizar o uso de memória descartando referências antigas de motoristas que ficaram inativos (limpeza em background). |

---

[Ir para a Etapa 5: Leadership & Systemic Impact ](./05-leadership-systemic-impact.md)
