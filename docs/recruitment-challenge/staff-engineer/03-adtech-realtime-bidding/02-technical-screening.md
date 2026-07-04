# 🖥️ Trilha 3 - Etapa 2: Technical Screening (Phone Screen)

* **Responsável:** Senior/Staff Software Engineer
* **Duração Recomendada:** 60 minutos
* **Foco:** Performance de baixo nível, garbage collection, latência de rede e formatos de dados compactos.

---

## 💬 Q&A - Fundamentos de Sistemas de Baixa Latência (20 min)

### Tópico A: Gerenciamento de Memória e GC Pause
* **Pergunta:** "Se o seu motor de decisão roda em Java ou Go e você tem picos de tráfego de 500k RPS, como o comportamento do Garbage Collector pode prejudicar o SLA de 10ms do sistema? Quais estratégias você adota no código para evitar alocações excessivas de memória e pausas longas do GC?"
* **Esperado:**
  * Uso de *Object Pools* para reutilizar objetos em vez de instanciar milhares por requisição.
  * Entendimento de alocação em Stack vs. Heap (Escape Analysis).
  * Go: tuning de `GOGC` e uso de buffers pré-alocados. Java: discussões sobre coletores ZGC ou Shenandoah de baixa pausa.

### Tópico B: Protocolos de Serialização (JSON vs. Protobuf vs. FlatBuffers)
* **Pergunta:** "Por que enviar payloads em JSON é desaconselhável em leilões de anúncios em tempo real? Qual o benefício do FlatBuffers em comparação com o Protobuf nesse cenário específico?"
* **Esperado:** 
  * JSON exige parseamento em strings (alto consumo de CPU e memória).
  * FlatBuffers permite acessar dados serializados sem precisar de uma etapa explícita de decodificação em memória (zero-copy deserialization).

---

## 🛠️ Mini-Desafio: Validador de Bitmask de Segmentos (30 min)

### Cenário:
> *"Um anunciante deseja exibir anúncios apenas para usuários que pertençam a certos segmentos de interesse (ex.: Tecnologia, Esportes, Moda). O perfil de segmentos do usuário é armazenado como um inteiro binário de 64 bits (Bitmask), onde cada bit representa um segmento. Escreva uma função concorrente thread-safe que receba uma requisição de bid (contendo o ID do usuário e a bitmask de segmentos exigida pelo anúncio) e valide instantaneamente se o usuário é elegível consultando o perfil dele em memória."*

### Habilidades avaliadas:
* Uso de operações binárias bit a bit (Bitwise AND `&`).
* Acesso ultra-rápido thread-safe em memória a tabelas de consulta de dados de usuários.

---

[Ir para a Etapa 3: System Design Onsite ➡️](./03-system-design-onsite.md)
