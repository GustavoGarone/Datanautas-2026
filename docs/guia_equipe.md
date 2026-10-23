# Guia para a equipe: o que foi feito na modelagem e como usar

*Atualizado em 23/10/2026, madrugada. Submissão hoje às 12h; pitch às 17h.*

Este guia resume, sem jargão, o que a frente de modelagem fez nos últimos dias, quais
são os achados e onde está cada material pronto para vocês usarem nos slides, no pitch e
na proposta. **Não é preciso rodar nenhum código**: tudo o que está listado aqui já foi
gerado e está no branch `dev` do repositório.

---

## 1. Em uma frase

Montamos um modelo estatístico que compara cursos **dentro da mesma instituição** e
mostra três achados sólidos:

1. o **EAD está se distanciando do presencial**;
2. **cursos noturnos perdem mais alunos**, mesmo comparados a cursos diurnos da mesma
   instituição;
3. cursos com mais estudantes **mais velhos, PPI e de escola pública** têm taxas
   maiores.

---

## 2. O que medimos (importante para falar certo no pitch)

**Taxa anual de desvínculo ou trancamento** de cada curso:

> (alunos desvinculados + alunos que trancaram) ÷ vínculos do curso no ano

- **Por que incluir o trancamento?** O trancamento muitas vezes antecede a desistência, e
  as instituições registram de formas diferentes o que é "trancado" e o que é
  "desvinculado". Somando os dois, a comparação fica mais justa. No EAD público, por
  exemplo, a taxa vai de 13,7% (só desvínculo) para 32,9% (com trancamento).
- **Não é** a evasão oficial do INEP nem "abandono do ensino superior". É saída ou pausa
  **do curso**.
- **População:** cursos que existiram nos cinco anos (2020–2024) e curso-anos com pelo
  menos 30 alunos. São 152.484 curso-anos, 32.953 cursos e 2.128 instituições. É o
  **mesmo filtro da EDA** do branch `sanches`.

---

## 3. Os achados, com números

| # | Achado | Dados brutos | Modelo (com controles) |
|---|---|---|---|
| 1 | **O EAD se distancia do presencial** | EAD: 33,3% (2020) → 41,4% (2024). Presencial: 27,4% → 24,4% | Cursos comparáveis de porte típico: razão de chances EAD/presencial de 0,95 (2020) a **1,40** (2024), ou chances ~40% maiores |
| 2 | **Cursos noturnos perdem mais alunos** | +5,5 pp contra cursos diurnos da mesma instituição (mediana em 589 IES) | **+2,7 pp** para um curso 100% noturno contra um diurno comparável |
| 3 | **Perfil dos estudantes** | — | Por +10 pp no curso: 25 anos ou mais **+0,6 pp**; PPI **+0,5 pp**; escola pública **+0,4 pp**; mulheres **−0,5 pp**; reserva de vagas **−0,3 pp** |

**Como ler o achado 2.** A diferença bruta (+5,5 pp) cai para +2,7 pp quando o modelo
leva em conta idade, origem escolar, área, porte e ano. Isso indica que parte da
diferença vem de quem estuda à noite (mais velhos, mais de escola pública). Mesmo assim,
**sobra uma diferença clara**, o que sugere algo ligado ao próprio turno.

**Um achado que NÃO se sustenta: ProUni.** Olhando só o desvínculo, cursos com mais
bolsistas do ProUni parecem perder mais alunos (14,4% → 17,9%). Com o trancamento, a
relação quase some (25,8% → 27,4%), porque esses cursos trancam menos e desvinculam mais.
**Não usem "ProUni aumenta a desistência" no pitch.**

---

## 4. Material pronto para usar

### Figuras para os slides

Todas em PNG, com título que já diz o achado e fonte no rodapé.

| Para | Arquivo |
|---|---|
| Achado 1 (dados) | `outputs/modelo/variantes/filtrada/dispre/figuras/ead_presencial_taxas.png` |
| Achado 1 (modelo, opcional) | `outputs/modelo/variantes/filtrada/dispre/figuras/ead_interacao_ano.png` |
| Achado 2 | `outputs/modelo/variantes/filtrada/dispre/figuras/noturno_bruto_ajustado.png` |
| Achado 3 | `outputs/modelo/variantes/filtrada/dispre/figuras/perfis_efeito_pp.png` |
| Panorama (rede, ProUni, noturno; com e sem trancamento) | `outputs/eda/graficos/painel_pitch.png` |
| Outros da exploração | `outputs/eda/graficos/` (por rede e modalidade, evolução anual, área, escola pública) |

### Notebooks (a análise completa, a partir dos dados)

| Notebook | Para que serve |
|---|---|
| **`notebooks/01_EDA_trancamento.html`** | A exploração inteira, com gráficos e tabelas: rede, modalidade, evolução, noturno × diurno, escola pública, ProUni, área. |
| **`notebooks/02_modelo_inferencial.html`** | O modelo inteiro: preparação, testes, ajuste, diagnósticos, coeficientes com IC 95%, figuras e a tabela "esse achado da EDA se sustenta?". |

Basta abrir os `.html` no navegador. Os `.qmd` são as fontes e devem ir na submissão
como material de análise. Os notebooks antigos `01_dicionario_de_dados.ipynb` e
`02_EDA.ipynb` (este era só um esboço no `dev`) foram removidos, porque nenhuma análise
os usava; continuam recuperáveis pelo histórico do Git. O dicionário oficial está em
`docs/dicionario_dados.pdf`.

### Documentos

| Documento | Para que serve |
|---|---|
| **`pipeline_modelo.html`** | Documento-síntese: a história completa em um arquivo (dados, exploração, modelo, resultados, limitações). Bom para quem quer a visão geral. |
| `pipeline_modelo.qmd` | A fonte do HTML acima. |
| `docs/relatorio_entrega.md` | Base de texto para os slides: achados, figuras com sugestão de uso, notas para quem apresenta e limitações. |
| `entregas_finais/declaracao_uso_ia.txt` | A declaração de uso de IA. **Falta o trecho de vocês** (ver seção 6). |
| `outputs/eda/tabelas/*.csv` | Números da exploração, se precisarem de algum valor específico. |

### Como ler os coeficientes (razões de chances)

- **Razão de chances (RC)** compara as chances de desvínculo ou trancamento de dois cursos
  iguais em tudo, exceto na característica. Acima de 1, a taxa tende a ser maior; abaixo
  de 1, menor.
- Com taxa média de 32%, RC 1,13 corresponde a cerca de 1,09 vez a taxa. Por isso também
  damos os valores em **pontos percentuais**.
- **Unidades:**
  - perfis: +10 pp no curso (deficiência: +1 pp);
  - contextos da IES: +1 desvio-padrão entre instituições;
  - categorias: contra a referência (2020, presencial, privada com fins lucrativos,
    universidade, bacharelado, Negócios).
- **EAD × presencial:** o coeficiente "EAD" sozinho não é essa comparação, porque o
  modelo tem interações com o ano e com o porte. Num curso de porte típico (150
  vínculos), comparando cursos semelhantes, a RC EAD/presencial vai de **0,95 em 2020**
  a **1,40 (1,37–1,44) em 2024**. Ou seja, as chances do EAD ficaram ~40% maiores; para
  um presencial com 25%, isso dá ~32% no EAD. Em cursos grandes, a distância é maior:
  1,76 com 2.000 vínculos.
- A figura "interação ano × EAD" (1,22 a 1,48) mostra **quanto a diferença mudou desde
  2020**, não a diferença em si.

### Os efeitos aleatórios: instituição e curso

O modelo tem quatro efeitos aleatórios:

| Onde | De quem | Desvio-padrão | O que significa |
|---|---|---:|---|
| Média da taxa | IES | 0,51 | A instituição perde mais ou menos alunos do que se esperaria pelas suas características |
| Média da taxa | Curso | 0,29 | Dentro da instituição, o curso perde mais ou menos que o esperado |
| Estabilidade da taxa | IES | 1,10 | As taxas da instituição oscilam muito ou pouco de um ano para outro |
| Estabilidade da taxa | Curso | 0,58 | O mesmo, para o curso |

**Na média (o nível da taxa):**
- 95% das instituições ficam entre **0,37 e 2,7 vezes** as chances de uma IES típica com
  as mesmas características. Mesmo comparando cursos com o mesmo perfil de alunos, área
  e modalidade, a instituição pode quase triplicar ou reduzir a um terço as chances de
  desvínculo.
- Cerca de **76% dessa variação não explicada está na instituição** e 24% no curso:
  *onde* o aluno estuda pesa mais do que *qual curso* ele faz.

**Na estabilidade.** Para um curso com taxa média de 30% e 200 vínculos, a oscilação típica
de um ano para outro é de ±7,6 pp numa IES de estabilidade mediana, ±5,1 pp numa IES mais
estável e ±12,1 pp numa menos estável. Em algumas instituições a taxa salta muito sem
mudança aparente: um sinal possível de registros irregulares ou de gestão instável. O
modelo não identifica a causa. Esse componente foi o que corrigiu o ajuste do modelo.

**Por que "aleatórios".** São mais de 2 mil IES e 33 mil cursos. Em vez de um coeficiente
livre para cada um, o modelo estima a variação entre eles e "encolhe" cada estimativa em
direção à média, conforme a quantidade de dados. Se a proposta usar um ranking de
instituições, ele deve ser apresentado como **sinal de alerta**, não como nota exata.

---

## 5. O que dizer e o que não dizer

**Pode dizer:**
- "Cursos noturnos têm taxas maiores do que cursos diurnos **comparáveis da mesma
  instituição**: cerca de 3 pontos percentuais por ano."
- "A interrupção no EAD subiu de 33% para 41% entre 2020 e 2024, enquanto no presencial
  caiu."
- "Cursos com mais estudantes de 25 anos ou mais, PPI e de escola pública têm taxas
  maiores."
- "Nossa medida inclui trancamento, porque ele costuma anteceder a desistência."

**Não diga:**
- que o noturno, a idade ou a raça **causam** a desistência. São associações em dados
  agregados por curso;
- que o modelo identifica **quais alunos** vão sair. Os dados não são por aluno;
- que o ProUni aumenta ou o FIES reduz a desistência. O ProUni não se sustenta (seção
  3), e os dados de FIES têm falhas de registro: há instituições grandes com zero em
  anos isolados;
- "evasão" sem qualificar. Prefiram "desvínculo ou trancamento do curso".

---

## 6. O que falta (com vocês)

| Item | Observação |
|---|---|
| **Proposta de intervenção** | Pesa nas notas "Social" e "Projeto". O briefing pede quem executa, para quem, os passos e por que reduziria a desistência. Os achados apontam para **cursos noturnos** e para o **EAD**, e os perfis (mais velhos, PPI, escola pública) sugerem o público. |
| **Slides do pitch (5 min)** | O `entregas_finais/datanauts_slides.pdf` é de 17/10 e está desatualizado. Usem as figuras da seção 4. |
| **Declaração de IA** | Em `entregas_finais/declaracao_uso_ia.txt` há um `[PENDENTE]`: cada um informa se usou IA nos notebooks, slides, pitch ou proposta, e qual ferramenta. |
| **Escolher os achados do pitch** | Sugestão: os três da seção 3, um por slide. |

---

## 7. Perguntas que a banca pode fazer

**"Por que esse modelo e não uma regressão simples?"**
Cada curso aparece cinco vezes, cursos da mesma instituição se parecem, e a taxa de um
curso de 40 alunos é bem menos precisa que a de um de 4.000. O modelo (beta-binomial
misto) trata isso e **compara cursos dentro da mesma instituição**. Testamos várias
alternativas (gamlss, Box-Cox t), e esta foi a que passou nos diagnósticos.

**"Os resultados são confiáveis?"**
- O modelo foi testado com simulações e com a **previsão de anos que ele não viu**: um
  ano de cada curso foi separado antes do ajuste.
- Ele acerta a taxa geral, prevê bem os cursos sem nenhuma saída e não deixa padrões
  sobrando entre anos.
- O ponto mais fraco são os cursos muito grandes (mais de 1.000 alunos).

**"Associação ou causa?"**
Associação. O modelo reduz comparações injustas, porque olha cursos da mesma instituição,
mas não prova causa. Por exemplo, não sabemos quais alunos trabalham.

**"E os cursos pequenos ou que fecharam?"**
Ficaram fora da análise (menos de 30 alunos, ou não presentes nos cinco anos). Os
resultados valem para cursos estáveis.

**"Usaram IA?"**
Sim, o desafio permite, e está declarado. As decisões sobre dados, medida e modelo foram
da equipe, e os números foram conferidos contra o código.

---

## 8. Se precisarem de mais detalhes

- Análise completa, a partir dos dados: `notebooks/01_EDA_trancamento.html` e
  `notebooks/02_modelo_inferencial.html`.
- Documento-síntese: `pipeline_modelo.html`.
- Decisões e tentativas descartadas: `docs/historico.md`.
- Métodos e comandos: `docs/metodologia.md`.
- Tabela completa de coeficientes:
  `outputs/modelo/variantes/filtrada/dispre/inferencia/tabelas/coeficientes.csv`.
