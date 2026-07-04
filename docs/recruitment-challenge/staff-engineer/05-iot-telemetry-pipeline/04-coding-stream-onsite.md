# 💻 Trilha 5 - Etapa 4: Coding Onsite - Janela Deslizante de Métricas em Memória

* **Responsável:** Staff Software Engineer & Senior Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Estruturas de dados temporais, concorrência fina de threads e algoritmos de agregação estatística.

---

## 🎯 O Enunciado do Desafio

No processador de fluxo de telemetria, precisamos manter em memória uma **Janela Deslizante (Sliding Window)** que calcule a média de um valor métrico (ex.: vibração do motor) para cada ID de dispositivo nos últimos $W$ segundos (ex.: 5 minutos), recalculada a cada passo de $S$ segundos.

O candidato deve implementar, na linguagem de sua preferência, um **Agregador de Janela Deslizante** concorrente e eficiente em memória.

---

## 🛠️ Requisitos Técnicos do Código

O candidato deve criar uma estrutura/classe `SlidingWindowAggregator` com os seguintes métodos:

### 1. `RecordMetric(deviceId string, value float64, timestamp int64)`
* Registra uma métrica de um dispositivo associada a um timestamp (segundos do Unix Epoch).
* Os dados podem chegar ligeiramente fora de ordem (ex.: um timestamp menor que outro já processado).
* O método deve ser extremamente rápido e thread-safe.

### 2. `GetAverage(deviceId string, currentTimestamp int64) float64`
* Retorna a média dos valores do dispositivo dentro da janela temporal ativa $[currentTimestamp - W, currentTimestamp]$.
* Os valores que estiverem fora da janela de tempo (mais antigos que o limite máximo) devem ser descartados da memória de forma ativa ou reativa para evitar vazamento de memória (*memory leaks*).

---

## ⚖️ Rubrica de Avaliação de Código

| Nível | Indicadores Práticos no Desafio |
| :--- | :--- |
| 🟥 **Reprovado** | Mantém todas as métricas indefinidamente em memória em uma lista global protegida por um único lock pesado, fazendo com que a API consuma gigabytes de RAM desnecessariamente após minutos de execução. |
| 🟨 **Senior (L5)** | Implementa a janela usando uma fila circular (*ring buffer*) ou uma lista duplamente ligada ordenada de timestamps por dispositivo. Remove elementos antigos apenas no momento da consulta de média (limpeza reativa). Usa Mutexes de forma correta para proteger as coleções por dispositivo. |
| 🟩 **Staff (L6+)** | Desenha a solução separando a limpeza em uma goroutine/thread em background assíncrona ou implementa a estrutura com estruturas de dados baseadas em tempo (como *buckets* temporais segmentados) para acelerar a leitura. Explica como lidar de forma elegante com eventos extremamente atrasados (*late events*) que caem fora da janela válida. |

---

[Ir para a Etapa 5: Leadership & Systemic Impact ](./05-leadership-systemic-impact.md)
