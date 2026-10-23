# Síntese das tentativas e decisões

Em 21–22/10/2026, o usuário autorizou implementação, alterações guiadas por
diagnóstico e revisão por subagente independente. A decisão posterior foi
manter a especificação atual e avaliar estabilidade antes de inferência.
Em 22/10, autorizou excluir artefatos descartados, preservando somente esta
síntese, PNG atuais e código para regenerá-los. Protocolos e registros repetidos
foram consolidados em `metodologia.md` e `AGENTS.md`.

| Etapa | Resultado e decisão |
| --- | --- |
| Logística binomial mista, somente desvinculados | Fluxo completo com AIC e sensibilidades executado; sete perfis retidos. Forte desajuste e influência de 2020–2021; sem aceitação para inferência. |
| Beta-binomial com dispersão constante | Convergência numérica satisfatória, mas desvios de QQ, zeros e calibração; interrompida antes de seleção. |
| Ano × modalidade; dispersão por modalidade | AIC menor, mas padrões residuais persistentes; Hessiana adiada por solicitação do usuário. |
| Dispersão por modalidade × log(N) | Melhor calibração e diagnóstico condicional; QQ marginal e porte ainda problemáticos. |
| Porte também na média | Melhorou calibração presencial; não resolveu distribuição marginal. |
| Contexto institucional | Dez termos descritivos de IES reduziram discrepâncias marginais; não bastaram para validar a distribuição. Revisão independente por IA alertou sobre retração e suporte. |
| Numerador ampliado para desvinculados + trancados | Mudança substantiva autorizada; diagnóstico da beta-binomial ordinária ainda limitado. Não significa abandono definitivo. |
| Correção de suporte Y<N | Implementação TMB própria conferida em casos enumeráveis, simulação, derivadas e referência glmmTMB. Resolve fronteira impossível, sem resolver toda a seleção. |
| Dispersão também por ano × modalidade | Atual candidato, 64 parâmetros. Melhora parcial; preservado para avaliação interna da mesma especificação. |
| Reajuste no treino e integração latente | Pearson² reservado 1,063, confirmado por lote independente; resíduos geralmente razoáveis, com déficit localizado de zeros/calibração. Manter abordagem por ora; estabilidade numérica inferencial pendente. |
| Worm-plots | Acrescentados à conferência por solicitação do usuário, sem mudança de modelo. Leitura no relatório atual. |
| Triagem de famílias com gamlss (22/10) | Piloto solicitado pelo usuário para usar `chooseDist`; inconclusivo. Nenhuma família binomial do gamlss resolveu a forma dos worms. Modelo TMB mantido. |

A troca completa para gamlss foi avaliada e descartada nesta etapa. Exigiria uma
família própria para a truncagem por linha em `Y<N`, porque `gen.trun` aceita um
único ponto de corte. Os efeitos cruzados seriam penalizados, sem Laplace, e o
fluxo de validação latente teria de ser reescrito. O usuário optou por usar
`chooseDist(type="binom")` apenas como triagem.

No gamlss 5.4-22, `chooseDist` devolveu NA para as sete famílias, inclusive a BB,
que reajustada diretamente funciona; a função descarta as mensagens de erro.
O script usa um laço explícito equivalente, com erro, convergência e tempo por família.
A triagem usou somente o treino (reserva intocada), N>1, 2% das IES sorteadas
(59 IES, 1.059 cursos, 3.265 linhas), a mesma matriz de média, a mesma fórmula de
dispersão, `nu`/`tau` constantes e nenhuma truncagem.

| Família | IES + curso, 50 ciclos: ΔAIC / ΔBIC / gl / convergiu | Só IES, 150 ciclos: ΔAIC / ΔBIC / gl / convergiu |
| --- | --- | --- |
| BB | 718 / 0 / 92 / sim | 25 / 0 / 92 / sim |
| ZIBB | 0 / 2.883 / 683 / não | 0 / 30 / 101 / sim |
| ZABB | 446 / 3.201 / 662 / não | 466 / 485 / 99 / não |
| ZIBI, ZABI | ~11.004 / ~15.060 / 876 / não | ~23.480 / ~23.567 / 111 / sim |
| BI | 15.414 / 16.913 / 456 / sim | 24.312 / 24.242 / 85 / sim |
| DBI | erro numérico em `mu` | erro numérico em `mu` |

Com IES e curso, as vantagens de AIC vinham sobretudo de efeitos penalizados
menos encolhidos em ajustes não convergidos, e não são comparáveis. Com efeitos
só de IES, a ZIBB convergiu e ganhou 25 de AIC, mas perdeu 30 de BIC, com cerca
de nove graus de liberdade efetivos a mais. Seus worm-plots ficaram quase idênticos
aos da BB: a cauda superior continua fora das bandas e o padrão em S do presencial
permanece. A binomial dupla (DBI), plausível para o centro comprimido, falhou nos
dois pilotos. A amostra é pequena e as famílias não têm truncagem: isso é
triagem, não seleção de família. O JSON do primeiro piloto tem o hash de uma
versão anterior do script, que diferia apenas na opção de efeitos e no caminho de saída.

As bandas curvas padrão foram acrescentadas com `gamlss::wp()`, declarado na
flake. Referem-se a normalidade independente, sem calibração para o painel.
Uma nova revisão independente por IA identificou centro comprimido e extremos
expandidos, sem apoiar uma correção única de escala ou mudança imediata de
família. Recomendou estabilizar a mesma especificação e investigar a referência
dos PIT com reestimação dos latentes antes de escolher uma extensão de caudas.
Essa continuação e o piloto são propostas; não foram executados nesta limpeza.

AIC entre respostas diferentes não sustenta comparação de ajuste. Convergência
do otimizador não é aprovação diagnóstica ou inferencial. A leitura inicial
“insatisfatório global” dos QQ condicionados aos próprios modos foi revista
com a avaliação interna; os desvios locais e marginais permanecem documentados.
Revisões por IA não equivalem a revisão humana independente.

Binomial com heterogeneidade logit-normal por observação, IES-ano, splines e
misturas de zeros foram discutidas como possibilidades, sem substituir a
especificação atual. Custos e hipóteses adicionais precisam de justificativa.
TMB foi escolhido pela Laplace, estrutura cruzada e truncagem própria; GAMLSS
é alternativa válida. Não se afirmou superioridade universal ou prevalência
na literatura. Paralelização usa duas threads para limitar memória. Interrupções
externas de processos não foram tratadas como evidência estatística.

Na limpeza, foram removidos modelos e caches antigos, PDFs duplicados,
checkpoints e scripts exclusivos das tentativas descartadas. Os parâmetros
dos dois modelos atuais foram preservados exatamente; sua proveniência e
os hashes anteriores constam do manifesto atual. Não houve novo ajuste.

## Triagem BCT (22/10)

Ideia do usuário, testada por subagente em `scripts/modelo/triagem_bct.R`. Usou só o
treino com N>1, efeitos de IES penalizados no gamlss e nenhuma truncagem.
Saídas em `outputs/modelo/triagem/bct_*`. Respostas testadas:
- correção de continuidade `(Y+0,5)/(N+1)`, com 2% e 10% das IES;
- modelo em duas partes, com 2%;
- escala logit empírica com JSU/SST, com 2%.

Na mesma resposta, BE e normal no logit mantêm o S da BB; a BCT o achata no
geral, com `tau` ≈ 2,3–3,9 (caudas pesadas). Isso mostrou que o S é curtose.
Por faixa de N, porém, a BCT troca um S por outro: caudas pesadas demais em
N<30 e S próprio em N≥1000. Além disso, não convergiu formalmente, põe
probabilidade em Y≥N e subprevê zeros. Não adotada. AIC entre BB e
respostas contínuas não é comparável.

## Revisões descritivas (22/10)

- `.cpp` vigente conferido linha a linha e contra a densidade calculada por
  produtos de Pochhammer, sem lgamma/lbeta: 2.000 linhas, erro máximo 4,7e-12.
  O S não decorre de erro de implementação.
- FIES/ProUni: ProUni consistente na rede privada (9–10% das matrículas em IES
  com zero, estável entre anos). FIES tem zeros intermitentes em IES grandes
  (69 IES; matrículas em IES com zero sobem para 18% em 2022 e 23% em 2024),
  compatíveis com falta de registro. Nenhum dos dois foi incluído.
- Composição da cauda superior (N≥30, taxa >0,6, presencial): 62% do Y é
  trancamento; 25% sem ingressantes. 11% dos curso-anos têm zero trancados;
  correlação desvínculo × trancamento −0,20, sugerindo práticas de registro
  diferentes entre IES.

## Variantes com dispersão aleatória (22–23/10)

O usuário autorizou testar melhorias sucessivas e pediu a população filtrada
`presente_5_anos == 1 & poucos_alunos == 0`, aplicada por curso-ano. Isso
**reverte a decisão anterior** de não excluir cursos pequenos nem painel
incompleto, e vale somente para as variantes. O modelo vigente na base completa
foi preservado.

Sobre a população filtrada:
- tem 152.484 linhas, 32.953 cursos e 2.128 IES; treino 121.502, reserva 30.982;
- exclui cursos que abriram ou fecharam no período e seleciona linhas pelo
  próprio N;
- os contextos de IES continuam calculados na base completa.

Código: `bb_truncada_dispre.cpp`, `variantes.R`, `variantes_diag.R`,
`variantes_integrada.R` e `testar_variantes.R`. Os testes cobriram:
- equivalência exata ao `.cpp` vigente com os efeitos de dispersão em zero;
- densidade e gradiente;
- Laplace contra glmmTMB com efeito aleatório na dispersão (erro 5e-7);
- PIT exato uniforme em dados simulados (KS p = 0,39).

O objetivo do `base` (especificação vigente reajustada na população filtrada)
saiu inicialmente 75.461 menor, porque a densidade dos efeitos de dispersão
fixados em zero entrava no objetivo. A correção é uma constante que não
altera as estimativas; os arquivos foram corrigidos sem reajuste.

| Variante | k | ΔAIC | Log-score na reserva integrada | Pearson² na reserva integrada |
| --- | ---: | ---: | ---: | ---: |
| base | 64 | +55.995 | −4,384 | 1,02 |
| dispre (IES e curso na dispersão) | 66 | +184 | −4,170 | 1,20 |
| dispre_fase (+ sem ingressantes) | 67 | 0 | −4,169 | 1,20 |

DPs da log-dispersão no `dispre`: 1,10 entre IES e 0,58 entre cursos.

Worms da reserva com latentes integrados (200 sorteios conjuntos de Laplace):
- Presencial 100–999: o S do `base` (desvio central 0,34) virou um worm quase
  plano (0,08).
- Caudas: desvio médio de 1,62 caiu para 0,63.
- Persistem uma estreiteza leve da previsão (Pearson² 1,20; inclinação em
  Presencial 30–99) e desvios em N≥1000.

Com os modos fixos do treino, a reserva do `dispre` mostrava forte
inclinação: tratar a dispersão por curso como conhecida subestima a
incerteza preditiva. O indicador de curso sem ingressantes quase não
contribui. `dispre_fase_n` (splines em log N) foi interrompido para priorizar
a reserva integrada. Hessiana, IC e seleção continuam adiados.

## Adoção do `dispre` (23/10)

Diagnóstico por simulação, com 500 réplicas por contexto, comparando com o `base`
na mesma população (`scripts/modelo/variantes_diagnosticar.R`):

| Medida | `base` | `dispre` |
| --- | ---: | ---: |
| Zeros condicionais, observado/simulado | 1,89 | 1,15 |
| Zeros marginais, observado/simulado | 1,66 | 0,83 (no envelope) |
| Pearson² marginal | 0,92 | 0,99 (no envelope) |
| Maior afastamento do QQ condicional | 0,084 | 0,015 |
| Maior afastamento do QQ com IES fixa | 0,060 | 0,015 |
| Worm condicional, desvio central médio | 0,32 | 0,09 |
| IES fora do envelope, condicional | 5,3% | 2,6% |
| Correlação temporal dos PIT, condicional | 0,074 | 0,023 |

Restam:
- N≥1000: Presencial 1000+ com IES fixa tem a cauda inferior até −1;
- um S moderado no contexto marginal;
- calibração de até ~3 pp no EAD 1000+, semelhante à do `base`.

O usuário adotou o `dispre` na população filtrada como modelo principal e
liberou Hessiana e EP. O modelo de 64 parâmetros na base completa fica
preservado como anterior. A primeira tentativa da reserva integrada falhou por um erro de índice da IA no
`dispre_ies`: os efeitos de dispersão livres (só os das IES) foram tratados como se
fossem o vetor completo. O erro foi corrigido em `variantes_integrada.R`.
Depois disso, a reserva integrada do `dispre_ies` não foi concluída:
dois processos paralelos foram encerrados por falta de memória, e o usuário
preferiu seguir sem ela.

## EDA da equipe com trancamento (23/10)

O branch `origin/sanches` traz a EDA (`02_EDA.ipynb`) e uma regressão Beta separada
(`03_modelagem_regressao_beta.ipynb`). A EDA usa o mesmo filtro e o desvínculo como
desfecho. A pedido do usuário, foi refeita em R com a medida composta
(`scripts/eda/eda_composta.R`), sem alterar o notebook. Resultados:
- a diferença noturno − diurno dentro da IES aumenta, com mediana de +4,1 para +5,5 pp;
- o gradiente de ProUni quase some, de 14,4→17,9% para 25,8→27,4%;
- o de escola pública na privada fica mais fraco.

A regressão Beta do branch não foi integrada: tem resposta e modelo diferentes do
adotado, linguagem causal sobre o FIES e worms fora das bandas, segundo o próprio
notebook. O merge do branch em `dev` não foi feito; o único conflito é o
`requirements.txt`, removido em `dev`.

## Limpeza para o commit de 23/10

O usuário pediu o repositório o mais limpo possível. Mudanças:
- **Removidos:**
  - os modelos das variantes não adotadas (`dispre_ies`, `dispre_fase`), com resumo
    preservado em `outputs/modelo/variantes/filtrada/comparacao/tabelas/variantes_aic.csv`;
  - a triagem `bct_cc_0.02_mixed`, teste do método `mixed`, que falhou.
- **Ignorados pelo Git:** os `residuos.rds` das variantes (28 MB), regeneráveis por
  `variantes_diagnosticar.R` em minutos.
- **Mantidos:** o modelo anterior (`outputs/modelo/`), `base` e `dispre`, as
  comparações, a EDA, os resumos das triagens e todo o código.
- `README.md` reescrito para o modelo adotado e o documento `pipeline_modelo.qmd`.

## Notebooks centrais (23/10)

A pedido do usuário, a análise foi reunida em dois notebooks Quarto que partem só do
Parquet: `notebooks/01_EDA_trancamento.qmd` e `notebooks/02_modelo_inferencial.qmd`.
Os resultados conferem com os scripts. As pequenas diferenças nos diagnósticos (por
exemplo, zeros marginais 1,65 contra 1,66) vêm da sequência aleatória das simulações.

Na primeira renderização, o notebook 02 regravou `data/processed/modelo.rds` por uma
diferença só de atributo interno (índice do `data.table`). O original foi restaurado por
`preparar.R` (md5 `8e797a…`, igual ao de `preparacao.json`), o conteúdo foi conferido
como idêntico e a comparação passou a ignorar atributos.

Os notebooks antigos `01_dicionario_de_dados.ipynb` e `02_EDA.ipynb` foram removidos a
pedido do usuário, por não serem usados por nenhuma análise. O segundo era só um esboço
no `dev`; a EDA completa está no branch `sanches`.

## Pesquisa sobre trancamento

Não foi localizada estimativa nacional defensável da conversão de trancamento
em desvínculo. Em 12 cursos de saúde da UFMG, 617 de 1.210 estudantes que
trancaram alguma vez estavam evadidos: 51,0%, tabela 14, p. 56, 2009–2015.
Não há horizonte uniforme pós-trancamento; não extrapolar nem usar para imputação.
Fonte primária conferida:
[Santos (2016)](https://repositorio.ufmg.br/bitstream/1843/BUOS-AJNNJ2/1/disserta__o_finalizada__22112016.pdf#page=56).
