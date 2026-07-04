# 💻 Dev Senior - Trilha 2 - Etapa 4: Coding Onsite - Pareamento Geoespacial em Memória

* **Responsável:** Senior Software Engineer
* **Duração:** 60 minutos
* **Foco:** Algoritmos de busca, concorrência fina de threads (Thread-safety) e testes unitários robustos.

---

## 🎯 O Enunciado do Desafio

No serviço de despacho, precisamos manter na memória do servidor a localização dos motoristas online agrupados por células de grade geográfica simplificadas (representadas por IDs inteiros). Quando um passageiro solicita um veículo em uma célula, o sistema deve buscar concorrentemente o primeiro motorista livre naquela célula ou nas células vizinhas imediatas e alocá-lo.

O candidato deve implementar o **Gerenciador de Pareamento Geográfico** em memória thread-safe.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar uma estrutura/classe `LocalDriverMatcher` com os seguintes métodos:

### 1. `UpdateDriverLocation(driverId string, cellId int)`
* Registra ou atualiza a posição do motorista.
* O método deve ser extremamente rápido e thread-safe, pois milhares de atualizações chegam em paralelo.

### 2. `FindAndAcquireDriver(cellId int, neighborCells []int) (string, bool)`
* Recebe a célula do passageiro e suas vizinhas mais próximas.
* Deve buscar de forma thread-safe um motorista livre (status "disponível") na célula original ou nas vizinhas.
* Se achar, marca o motorista como "ocupado" (atômico) e retorna o ID do motorista e `true`.
* **Consistência:** Duas chamadas paralelas de busca **nunca** podem pegar o mesmo motorista.

### 3. Teste de Validação
* Escrever um caso de teste onde 10 threads de passageiros tentam buscar simultaneamente motoristas em uma célula que só tem 3 motoristas disponíveis, validando que exatamente 3 passageiros consigam alocar motoristas e 7 recebam falha (resultado falso).

---

## ⚖️ Rubrica de Código (Dev Senior)
* **Sinal Verde (Green Flag):** Usa mutexes ou coleções seguras para proteger a associação `cellId -> drivers`; implementa a atomicidade de alteração de status do motorista corretamente; escreve testes que validam condições de corrida.
* **Sinal Vermelho (Red Flag):** Cria código com race conditions graves nos mapas e fatias de memória; não consegue mockar ou testar o paralelismo.

---

[Ir para a Etapa 5: Behavioral Onsite ➡️](./05-leadership-onsite.md)
