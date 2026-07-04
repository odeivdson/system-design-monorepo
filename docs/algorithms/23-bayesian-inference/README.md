# Desafio 23: Inferência Bayesiana e Decisões Estatísticas Concorrentes (`algo-bayesian-inference`)
> **Padrões de Algoritmos e Estatística:** Teorema de Bayes, Distribuição Conjugada Beta-Binomial, Multi-Armed Bandits (MAB), Thompson Sampling, Filtros Bayesianos Recursivos, Algoritmos Lock-Free e Online Stream.

## 1. Contexto & Cenário de Produção
No desenvolvimento de sistemas distribuídos modernos de alta escala, as decisões de negócio não podem ser tomadas no vácuo ou com base em suposições estáticas. Engenheiros de software de alto nível aplicam **Inferência Bayesiana** para atualizar de forma contínua as probabilidades associadas a eventos dinâmicos à medida que novos dados entram em tempo real pelo fluxo de rede (*online streaming learning*).

O Teorema de Bayes:
$$P(A|B) = \frac{P(B|A) \cdot P(A)}{P(B)}$$

...fornece uma base matemática para combinar nosso conhecimento prévio (*Prior*, $P(A)$) com novas evidências observadas (*Likelihood*, $P(B|A)$) para obter a probabilidade atualizada (*Posterior*, $P(A|B)$).

Neste módulo de treinamento de elite, estudaremos três problemas práticos reais onde o Teorema de Bayes é implementado com foco em **concorrência livre de locks (lock-free)**, **otimização de alocação de memória** e **estabilidade numérica**.

---

## 2. O Pool de Desafios Bayesianos (Requisitos Funcionais)

### Desafio 1: Classificador de Moderação de Conteúdo Online (Naive Bayes Streaming)
Em redes sociais ou plataformas de e-commerce com milhares de comentários gerados por segundo, é crucial detectar comentários tóxicos ou spam de forma instantânea.
- **RF**: Classificar comentários de entrada como `"Spam"` ou `"Legítimo"` usando um classificador Naive Bayes de forma síncrona. O classificador deve atualizar seus contadores de frequência de vocabulário e probabilidades *online* de forma thread-safe à medida que moderadores confirmam classificações corretas, sem necessitar reconstruir a base de dados de treino do zero.

### Desafio 2: Multi-Armed Bandits com Amostragem de Thompson (Dynamic A/B Testing)
Testes A/B tradicionais (frequentistas) exigem dividir o tráfego estaticamente por semanas até atingir significância estatística, gerando custos de conversão desperdiçados em variações ruins.
- **RF**: Rotear dinamicamente requisições de usuários para $K$ variações diferentes de uma página web, ajustando as taxas de tráfego com base na probabilidade acumulada de conversão.
- **Abordagem**: Modelar a probabilidade de conversão de cada variação como uma **Distribuição Beta** $Beta(\alpha, \beta)$ (conjugado a priori da distribuição Binomial). Ao observar uma conversão com sucesso ou falha, atualizar imediatamente os contadores $\alpha$ (sucessos) e $\beta$ (falhas). Para cada usuário que entra, desenhar uma amostra aleatória de cada distribuição Beta (**Thompson Sampling**); a variação que retornar a maior amostra recebe o usuário.

```
                  Thompson Sampling Loop Concorrente
                  
                   [ Usuário Entra no Gateway ]
                                │
                                ▼
         [ Amostra X ~ Beta(α1,β1) ] vs [ Amostra Y ~ Beta(α2,β2) ]
                                │ (Maior Amostra Vence)
                                ▼
                   [ Roteia para Variação Vencedora ]
                                │
                  (Observa Sucesso / Falha de Conversão)
                                │
                                ▼
                  [ CAS Update: α_new ou β_new ]
```

### Desafio 3: Estimador de Saúde de Cluster (Filtro Bayesiano Recursivo)
Em ambientes de DevOps/SRE de larga escala, detectar quando um nó de servidor está com defeito físico silencioso ou degradação de hardware (ex: falhas intermitentes de disco ou throttling térmico de CPU) baseando-se apenas em telemetrias isoladas gera falsos positivos.
- **RF**: Calcular a probabilidade em tempo real de um nó estar `"Saudável"` ou `"Degradado"`.
- **Abordagem**: Implementar um **Filtro Bayesiano Recursivo**: a cada leitura periódica de telemetria ruidosa (ex: "tempo de I/O de disco excedeu 500ms"), recalcular a probabilidade a posteriori multiplicando a probabilidade prévia pela verossimilhança da leitura sob cada estado possível, seguida de uma etapa de normalização matemática.

---

## 3. Requisitos Não-Funcionais (RNF - Foco Staff)
- **Atualizações Lock-Free com CAS**: Todas as operações de incremento de estatísticas (parâmetros da distribuição Beta no Desafio 2 e contadores de vocabulário no Desafio 1) devem ser executadas concorrentemente de forma atômica (`Interlocked.Add` ou CAS loops), eliminando gargalos de travamento.
- **Proteção contra Floating-Point Underflow**: No Desafio 1 (Naive Bayes), multiplicar muitas probabilidades menores que 1 resulta em subfluxo de ponto flutuante (arredondamento para zero). É obrigatório computar e somar os **logaritmos das probabilidades** ($\ln(P)$) em vez de multiplicar probabilidades diretas.
- **Geração Rápida de Amostras Beta**: No Desafio 2, a CPU deve gerar números pseudo-aleatórios da distribuição Beta sob limites rígidos de milissegundos sem causar tráfego na Heap.

---

## 4. Guia de Implementação & Padrões

### Amostragem da Distribuição Beta para Thompson Sampling
A distribuição Beta é gerada a partir de duas variáveis aleatórias independentes da distribuição Gamma:
Se $X \sim Gamma(\alpha, 1)$ e $Y \sim Gamma(\beta, 1)$, então $\frac{X}{X + Y} \sim Beta(\alpha, \beta)$.
Utilizamos geradores de distribuição Gamma rápidos (como o algoritmo de Marsaglia e Tsang) para obter amostragens velozes in-memory.

### Código de Referência (C#)

#### A. Thompson Sampling Multi-Armed Bandits
Abaixo está o motor de teste A/B dinâmico usando o Teorema de Bayes (Beta-Binomial) de forma concorrente e sem travas síncronas.

```csharp
public class ThompsonSamplingBandits
{
    private class ArmState
    {
        // Parâmetros da distribuição Beta atualizados concorrentemente
        public int Alpha = 1; // Prior sucessos (inicia em 1 para Uniforme)
        public int Beta = 1;  // Prior falhas (inicia em 1 para Uniforme)
    }

    private readonly ArmState[] _arms;
    private readonly ThreadLocal<Random> _localRandom = new(() => new Random(Guid.NewGuid().GetHashCode()));

    public ThompsonSamplingBandits(int numVariations)
    {
        _arms = new ArmState[numVariations];
        for (int i = 0; i < numVariations; i++)
        {
            _arms[i] = new ArmState();
        }
    }

    // Registra o feedback observado de forma atômica
    public void RecordFeedback(int armIndex, bool converted)
    {
        if (armIndex < 0 || armIndex >= _arms.Length) return;

        ArmState arm = _arms[armIndex];
        if (converted)
        {
            // Incrementa sucessos (Alpha) atomicamente sem travas
            Interlocked.Increment(ref arm.Alpha);
        }
        else
        {
            // Incrementa falhas (Beta) atomicamente sem travas
            Interlocked.Increment(ref arm.Beta);
        }
    }

    // Seleciona o melhor braço (variação) de forma concorrente usando Thompson Sampling
    public int SelectArm()
    {
        int bestArm = 0;
        double maxSample = -1.0;
        Random rng = _localRandom.Value!;

        for (int i = 0; i < _arms.Length; i++)
        {
            ArmState arm = _arms[i];
            
            // Leitura volátil dos parâmetros atuais
            double alpha = Volatile.Read(ref arm.Alpha);
            double beta = Volatile.Read(ref arm.Beta);

            // Gera uma amostra aleatória da distribuição Beta para este braço
            double sample = SampleBeta(alpha, beta, rng);

            if (sample > maxSample)
            {
                maxSample = sample;
                bestArm = i;
            }
        }

        return bestArm;
    }

    // Gerador de Distribuição Beta baseado no método Gamma de Marsaglia-Tsang
    private double SampleBeta(double alpha, double beta, Random rng)
    {
        double x = SampleGamma(alpha, rng);
        double y = SampleGamma(beta, rng);
        
        if (x + y == 0) return 0.5; // Proteção contra divisão por zero
        return x / (x + y);
    }

    private double SampleGamma(double shape, Random rng)
    {
        if (shape < 1.0)
        {
            // Otimização para shape < 1.0
            double u = rng.NextDouble();
            return SampleGamma(shape + 1.0, rng) * Math.Pow(u, 1.0 / shape);
        }

        // Algoritmo de Marsaglia e Tsang (2000)
        double d = shape - 1.0 / 3.0;
        double c = 1.0 / Math.Sqrt(9.0 * d);

        while (true)
        {
            double z;
            double u;
            do
            {
                // Box-Muller para obter normal padrão
                double u1 = rng.NextDouble();
                double u2 = rng.NextDouble();
                z = Math.Sqrt(-2.0 * Math.Log(u1)) * Math.Cos(2.0 * Math.PI * u2);
                u = rng.NextDouble();
            } while (z <= -1.0 / c);

            double v = 1.0 + c * z;
            v = v * v * v;
            
            double x = d * v;
            if (u < 1.0 - 0.0331 * z * z * z * z) return x;
            if (Math.Log(u) < 0.5 * z * z + d * (1.0 - v + Math.Log(v))) return x;
        }
    }
}
```

#### B. Filtro Bayesiano Recursivo de Telemetria
Abaixo está o motor recursivo para estimar o estado de saúde de nós a partir de observações consecutivas de telemetria.

```csharp
public class BayesianTelemetryFilter
{
    // Estados do nó
    public enum HealthState { Healthy = 0, Degraded = 1 }

    // Leituras ruidosas observadas
    public enum Observation { FastResponse = 0, Timeout = 1 }

    // Probabilidades a priori acumuladas [Healthy, Degraded]
    private double[] _stateProbabilities = new double[2] { 0.8, 0.2 }; // Inicia em 80% saudável
    
    // Matriz de Verossimilhança (Sensor Model): P(Observation | State)
    // Linha 0 (Healthy):  [P(Fast | H), P(Timeout | H)]
    // Linha 1 (Degraded): [P(Fast | D), P(Timeout | D)]
    private readonly double[,] _likelihoodModel = new double[2, 2]
    {
        { 0.95, 0.05 }, // Nó saudável raramente dá timeout (5%)
        { 0.30, 0.70 }  // Nó degradado dá muito timeout (70%)
    };

    private readonly object _lock = new();

    // Processa uma nova leitura de telemetria e atualiza o estado de forma recursiva
    public (double ProbHealthy, double ProbDegraded) Update(Observation obs)
    {
        lock (_lock)
        {
            // Passo 1: Multiplicação Bayesiana (Likelihood * Prior)
            double pObsGivenHealthy = _likelihoodModel[(int)HealthState.Healthy, (int)obs];
            double pObsGivenDegraded = _likelihoodModel[(int)HealthState.Degraded, (int)obs];

            double unnormalizedHealthy = pObsGivenHealthy * _stateProbabilities[(int)HealthState.Healthy];
            double unnormalizedDegraded = pObsGivenDegraded * _stateProbabilities[(int)HealthState.Degraded];

            // Passo 2: Normalização (Para garantir que somem 1)
            double normalizationEvidence = unnormalizedHealthy + unnormalizedDegraded;

            if (normalizationEvidence > 0)
            {
                _stateProbabilities[(int)HealthState.Healthy] = unnormalizedHealthy / normalizationEvidence;
                _stateProbabilities[(int)HealthState.Degraded] = unnormalizedDegraded / normalizationEvidence;
            }

            return (_stateProbabilities[(int)HealthState.Healthy], _stateProbabilities[(int)HealthState.Degraded]);
        }
    }
}
```

---

## 5. Critérios de Sucesso (O que um Avaliador Staff busca)
- **Eliminação Absoluta de Travas no Thompson Sampling**: Verificação de que a consulta de braços e a amostragem Beta ocorrem de forma assíncrona, delegando ao `Interlocked` o incremento atômico dos parâmetros de conversão após a ação.
- **Prevenção de Underflow Numérico**: Demonstração em código do uso de somas logarítmicas ao invés de multiplicações diretas para o classificador Naive Bayes no Desafio 1.
- **Normalização Robusta**: Tratamento matemático adequado no Filtro Bayesiano Recursivo para o caso limite onde a evidência normalizadora é zero, evitando falhas de divisão por zero.

---

## 6. Trade-offs

### A. Thompson Sampling (Bayesian) vs. Upper Confidence Bound (UCB - Frequentista)
- **Thompson Sampling (Bayesian MAB)**:
  - *Pró*: Altamente robusto e adaptável sob fluxos instáveis de conversão. É naturalmente probabilístico e mais fácil de estender para modelos com dados contextuais dos usuários.
  - *Contra*: Requer a geração matemática de amostras da distribuição Beta para cada decisão, exigindo algoritmos complexos de amostragem Gamma que consomem mais ciclos de CPU.
- **Upper Confidence Bound (UCB)**:
  - *Pró*: Fórmula estritamente determinística baseada em médias e intervalos de confiança superiores de raiz quadrada simples, exigindo menos poder de computação.
  - *Contra*: É menos eficiente nos estágios iniciais de teste de tráfego, explorando braços ruins com maior frequência do que o Thompson Sampling.

### B. Filtro Bayesiano Recursivo vs. Filtros de Kalman Contínuos
- **Filtro Bayesiano Recursivo (Discreto)**:
  - *Pró*: Ideal para gerenciar variáveis de estado com classificações qualitativas e discretas (como Saudável/Degradado/Falho).
  - *Contra*: Não escala de forma eficiente para cenários onde as variáveis de estado e as medições são contínuas (ex: velocidade física de eixos de um veículo ou corrente elétrica).
- **Filtro de Kalman**:
  - *Pró*: Otimização contínua de equações lineares de matrizes gaussianas para estimativas físicas contínuas precisas.
  - *Contra*: Requer álgebra linear complexa e computação matricial custosa, sendo inapropriada para estados binários lógicos.
