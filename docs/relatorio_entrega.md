# Datanautas — desvínculo e trancamento no ensino superior (2020–2024)

> **Esqueleto (23/10/2026, madrugada).** Números marcados como conferidos vêm das saídas
> do repositório. Os itens `[PENDENTE]` dependem de etapas ainda não concluídas ou de
> decisões da equipe. Público: banca do Datathon Impacta.dev 2026 (dados, social, projeto).
> Material de apoio da submissão; os slides do pitch são outra peça.

## 1. Problema e recorte

- **Pergunta:** quais características dos cursos e da composição dos seus matriculados se
  associam à proporção anual de alunos que **perdem o vínculo ou trancam** o curso,
  comparando cursos dentro da mesma instituição e ao longo dos anos?
- **Por que importa:** [PENDENTE — contexto social e conexão com a SempreFEA; ver briefing:
  o desvínculo anual subiu de 17,1% (2020) para 22,6% (2024) no Brasil].
- **Recorte escolhido:** [PENDENTE — frase da equipe ligando o achado à intervenção].

## 2. Dados e definição da medida

- **Fonte:** Censo da Educação Superior 2020–2024, tabela `cursos_ano` (dados agregados
  por curso, nunca por aluno).
- **Medida:** taxa anual de **desvínculo ou trancamento** do curso =
  (desvinculados + trancados) ÷ vínculos. Os vínculos somam matriculados (cursando ou
  formados), trancados, desvinculados, transferidos e falecidos.
  - O trancamento pode ser temporário: a medida **não é** evasão definitiva nem a evasão
    oficial do INEP.
  - As transferências internas ficam no complemento, não contam como saída.
- **População analisada** (conferido): cursos presentes nos cinco anos, curso-anos com 30
  vínculos ou mais e com matrículas positivas. São **152.484 curso-anos, 32.953 cursos e
  2.128 IES**, 72% das linhas da base com matrículas positivas.
  - Os resultados valem para cursos estáveis e não muito pequenos.
  - Ficam de fora os cursos que abriram ou fecharam no período e os curso-anos com menos
    de 30 vínculos.
- **Taxas agregadas na população analisada** (conferido; soma de numeradores ÷ soma de
  denominadores):

| Ano | Desvínculo ou trancamento | Desvínculo | Trancamento |
| --- | ---: | ---: | ---: |
| 2020 | 29,7% | 16,7% | 12,9% |
| 2021 | 31,0% | 17,5% | 13,5% |
| 2022 | 33,5% | 20,5% | 13,0% |
| 2023 | 33,2% | 20,5% | 12,8% |
| 2024 | 33,5% | 22,0% | 11,6% |

| Modalidade | 2020 | 2021 | 2022 | 2023 | 2024 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Presencial | 27,4% | 26,8% | 27,1% | 25,8% | 24,4% |
| EAD | 33,3% | 36,3% | 40,2% | 40,2% | 41,4% |

[PENDENTE — gráfico descritivo para os slides; leitura: o EAD sobe de 33% para 41%,
enquanto o presencial cai levemente.]

### 2.1 Análise exploratória da equipe (branch `sanches`, `notebooks/02_EDA.ipynb`)

A EDA usa o mesmo filtro do modelo (`poucos_alunos == 0` e `presente_5_anos == 1`), com
152.943 curso-anos. O modelo exclui ainda 459 curso-anos sem matrículas, ficando com
152.484. **A EDA usa como desfecho só o desvínculo**, sem o trancamento. Ao citar seus
números, nomear a medida.

Taxas por rede e modalidade, de 2020 a 2024, somando numeradores e denominadores
(conferido, reproduzido com os dados):

| Rede / modalidade | Desvínculo (EDA) | Desvínculo + trancamento (modelo) |
| --- | ---: | ---: |
| Privada EAD | 25,2% | 39,0% |
| Privada presencial | 16,8% | 28,9% |
| Pública EAD | 13,7% | 33,0% |
| Pública presencial | 10,8% | 21,8% |

O trancamento muda a leitura: no EAD público, ele mais que dobra a taxa. É um argumento
para a medida composta e para dizer sempre qual medida está sendo usada.

**A EDA foi refeita com o trancamento** em `scripts/eda/eda_composta.R`, com as mesmas
definições de grupos do notebook e três medidas lado a lado (desvínculo, trancamento e
composta). As saídas estão em `outputs/eda/`. Reproduz exatamente os números do notebook
para o desvínculo. São **associações descritivas, sem controles**:

| Achado | Só desvínculo (EDA original) | Desvínculo + trancamento (medida do modelo) |
| --- | ---: | ---: |
| Noturno − diurno na mesma IES, presencial 2024, mediana (589 IES) | +4,1 pp (78% das IES > 0) | **+5,5 pp** (79% > 0) |
| … na rede privada (389 IES) | +4,7 pp | **+6,7 pp** |
| … na rede pública (200 IES) | +2,8 pp | **+4,4 pp** |
| Escola pública, privada presencial, quartil 1 → 4 | 13,8% → 19,9% | 25,9% → 30,6% (Q2–Q4 ≈ 30%) |
| Escola pública, pública presencial, quartil 1 → 4 | 7,9% → 13,3% | 17,7% → 25,2% |
| ProUni, privada presencial 2024, quartil 1 → 4 | 14,4% → 17,9% | **25,8% → 27,4% (quase plano)** |

Leitura:
- **Noturno:** é o achado mais robusto. A diferença dentro da mesma IES **aumenta** quando
  o trancamento entra, ou seja, cursos noturnos também trancam mais. Bom candidato para o
  pitch.
- **ProUni:** o gradiente crescente do desvínculo **praticamente some** na medida composta,
  porque o trancamento cai com a cobertura do ProUni. Não sustentar no pitch que ProUni
  "aumenta" a desistência. A composição entre trancar e desvincular muda, e a taxa total
  quase não muda.
- **Escola pública:** na privada, a medida composta sobe sobretudo do 1º para o 2º quartil
  e depois estabiliza. O gradiente fica mais fraco que no desvínculo isolado.
- **Área Cine e evolução anual:** em `outputs/eda/tabelas/area_cine.csv` e
  `evolucao_anual.csv`.

Figuras:
- **`outputs/eda/graficos/painel_pitch.png`** substitui o `assets/pitch_eda_dashboard.png`
  do branch `sanches`. Mostra rede, ProUni e noturno − diurno, com desvínculo e com
  desvínculo + trancamento.
- `rede_modalidade.png`, `evolucao_anual.png`, `noturno_diurno_intra_ies.png`,
  `escola_publica_quartis.png` e `area_cine.png`.

[PENDENTE — conferir os achados da EDA contra os coeficientes do modelo (noturno,
escola pública) quando a Hessiana sair. Se o sinal se mantiver com os controles e os
efeitos de IES e curso, o achado fica mais forte.]

## 3. Método

- **Modelo:** beta-binomial com efeitos mistos, truncada para respeitar que nenhum curso
  com matrículas perde todos os vínculos (Y < N).
- **Média (escala logit):**
  - ano, modalidade, categoria administrativa, organização acadêmica, grau e área geral
    Cine;
  - sete perfis dos matriculados: feminino, PPI, 25 anos ou mais, escola pública,
    deficiência, reserva de vagas e noturno;
  - ano × modalidade, porte do curso (log N) por modalidade;
  - dez contextos da IES;
  - interceptos aleatórios de **IES** e de **curso**, que fazem cada curso ser comparado
    consigo mesmo e com cursos da mesma instituição.
- **Dispersão:** ano × modalidade, porte por modalidade e **efeitos aleatórios de IES e de
  curso**. Isso permite que a variabilidade de um ano para outro seja diferente entre
  instituições, o que foi decisivo para o ajuste.
- **Estimação:** máxima verossimilhança com aproximação de Laplace (TMB), 66 parâmetros.
  Código: `scripts/modelo/variantes.R` e `bb_truncada_dispre.cpp`.
- **Por que este modelo** (conferido):
  - O modelo anterior, sem efeitos na dispersão, deixava resíduos em forma de S (caudas
    pesadas).
  - Famílias alternativas (gamlss: BI, BB, DBI, ZIBB, ZABB; Box-Cox t) não resolveram.
  - A dispersão aleatória reduziu o AIC em 55.811 e melhorou a previsão de anos reservados
    (log-score −4,384 → −4,170).
- **Uso de IA:** ver a seção 8 e `docs/registro_uso_ia_modelagem.md`.

## 4. Diagnóstico e validação (conferido)

Comparação com o modelo anterior na mesma população, com 500 simulações por contexto:

| Medida | Modelo anterior | Modelo adotado |
| --- | ---: | ---: |
| Zeros observados ÷ simulados (condicional) | 1,89 | 1,15 |
| Maior afastamento do QQ uniforme (condicional) | 0,084 | 0,015 |
| IES com taxa fora do envelope de 95% | 5,3% | 2,6% |
| Log-score em anos reservados (latentes integrados) | −4,384 | −4,170 |

- **Figuras:**
  - `outputs/modelo/variantes/filtrada/dispre/diagnostico/graficos/worm_modalidade_porte.png`
  - `outputs/modelo/variantes/filtrada/dispre/diagnostico/graficos/QQ_uniforme.png`
  - `outputs/modelo/variantes/filtrada/comparacao/graficos/worm_reserva_integrada.png`
- **Limitações que persistem:**
  - cursos com 1.000 ou mais vínculos, sobretudo presenciais, quando o efeito do curso não
    é condicionado;
  - calibração de até ~3 pp no EAD com 1.000+;
  - previsão um pouco estreita em anos reservados (Pearson² 1,20).
- A reserva é **retrospectiva**: um ano sorteado por curso, já usado na escolha entre
  variantes. Não é previsão de futuro nem de cursos novos.

## 5. Resultados: associações estimadas

Estabilidade (conferido):
- A Hessiana dos 66 parâmetros é positiva definida (menor autovalor 7,25; condição 5,8e5).
- Um passo de Newton reduziu o gradiente máximo de 39 para 0,02, com variação desprezível
  do objetivo (−0,02).
- Tabela completa: `outputs/modelo/variantes/filtrada/dispre/inferencia/tabelas/coeficientes.csv`.

Perfis dos matriculados: razão de chances da média subjacente por +10 pp (deficiência:
+1 pp), ajustada pelos controles, pelos contextos da IES e pelos efeitos aleatórios de IES
e curso, com IC 95% de Wald (conferido):

| Perfil | RC | IC 95% |
| --- | ---: | --- |
| 25 anos ou mais | 1,029 | 1,026–1,032 |
| PPI | 1,024 | 1,020–1,027 |
| Escola pública | 1,018 | 1,016–1,021 |
| Noturno | 1,012 | 1,011–1,014 |
| Deficiência (+1 pp) | 0,994 | 0,992–0,996 |
| Reserva de vagas | 0,985 | 0,981–0,990 |
| Feminino | 0,976 | 0,974–0,978 |

Outros (conferido):
- EAD contra presencial em 2020: RC 0,61 (0,58–0,65).
- A interação ano × EAD cresce até 1,48 em 2024 (1,45–1,52). O EAD se distancia do
  presencial ao longo do período, coerente com a EDA.

[PENDENTE:
- traduzir em pontos percentuais para um curso típico;
- lembrar que, com os efeitos de curso, as associações dos perfis vêm em boa parte da
  variação **dentro do curso ao longo dos anos** e dos contextos;
- os EP são condicionais à aproximação de Laplace e à especificação; com 152 mil linhas,
  quase tudo é "significativo", e a magnitude importa mais que o p.]

- Apresentar os sete perfis como razões de chances da média subjacente, por +10 pp (por +1
  pp para deficiência).
- Apresentar modalidade, categoria administrativa, ano × modalidade e porte.
- Traduzir em pontos percentuais da taxa para um curso típico. [PENDENTE]
- Dizer explicitamente que são **associações ecológicas**: o perfil dos matriculados não
  identifica quem saiu, e isso não é causalidade.

## 6. Leitura dos achados

Proposta de três achados. Cada um combina a exploração (sem controles) com o modelo
(com controles e comparação dentro da mesma IES) (conferido):

1. **O EAD se distancia do presencial.** A taxa composta do EAD vai de 33,3% (2020) para
   41,4% (2024); o presencial cai de 27,4% para 24,4%. No modelo, a interação ano × EAD
   cresce até RC 1,48 (1,45–1,52) em 2024.
2. **Cursos noturnos perdem mais alunos, mesmo dentro da mesma instituição.** Na
   exploração, a diferença é de +5,5 pp (mediana em 589 IES). No modelo, um curso 100%
   noturno contra um diurno comparável dá RC 1,13 (1,12–1,15), ≈ **+2,7 pp**. Parte da
   diferença bruta vem da idade e da origem escolar.
3. **Perfis de estudantes mais vulneráveis se associam a taxas maiores.** Por +10 pp no
   curso: 25 anos ou mais ≈ +0,6 pp, PPI ≈ +0,5 pp, escola pública ≈ +0,4 pp. Mulheres
   (≈ −0,5 pp) e reserva de vagas (≈ −0,3 pp) se associam a taxas menores. A
   variabilidade das taxas é sobretudo uma característica da instituição: DP da
   log-precisão 1,10 entre IES.

Base inferencial dos achados exploratórios (detalhe em `pipeline_modelo.html`):
- **Com base:** noturno, escola pública, EAD × ano, rede.
- **Em parte:** área Cine. Depois dos controles, Engenharia e TIC ficam abaixo de Negócios.
- **Sem base:** ProUni, que não está no modelo. Na medida composta, o gradiente quase
  some.

[PENDENTE — escolher com a equipe quais achados vão para o pitch.]

## 7. Proposta de intervenção

[PENDENTE — equipe. O briefing pede quem executa, o público, os passos e o mecanismo pelo
qual reduziria a desistência. Ideia compatível com o modelo: um indicador de risco por
curso, comparado a cursos semelhantes da mesma IES, a partir do previsto contra o
observado e da dispersão aleatória (cursos/IES instáveis).]

## 8. Limitações

- Dados agregados: os achados valem para cursos, não para alunos.
- A medida inclui trancamento, que pode ser temporário.
- População filtrada: cursos estáveis com 30 vínculos ou mais. Pode excluir justamente
  cursos em crise.
- Perfis contemporâneos dos matriculados: seleção, simultaneidade e sobrevivência.
- FIES fora por zeros que parecem falta de registro. ProUni e apoio social não incluídos.
- EP de Wald condicionais à aproximação de Laplace e à especificação. [PENDENTE: estabilidade
  após o passo de Newton.]
- A seleção de perfis por AIC (stepwise) não foi executada.

## 9. Reprodução e declaração de IA

- Ambiente Nix (`flake.nix`). Comandos em `docs/metodologia.md`; decisões em
  `docs/historico.md`.
- Declaração de IA (`entregas_finais/declaracao_uso_ia.txt`): [PENDENTE — redigir no final
  a partir de `docs/registro_uso_ia_modelagem.md`; OpenAI Codex (Sol 6.1) e Claude Code
  (Claude Opus 5.5).]
