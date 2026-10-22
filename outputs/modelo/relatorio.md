# Modelo atual — diagnóstico e limitações

Beta-binomial truncada superiormente em Y<N, com ligação logit subjacente,
interceptos aleatórios de IES e curso, seis controles estruturais, sete perfis,
interações temporais/porte e dez contextos institucionais. Dispersão:
`~ ano * modalidade + modalidade * log(vinculos)`; 64 parâmetros populacionais.

Resposta: **(desvinculados + trancados) / vínculos**, em 211.651 curso-anos de 2020–2024,
Brasil, matrículas positivas. Trancamento pode ser temporário; não chamar o
desfecho de abandono definitivo. Perfis descrevem matriculados, sem risco individual ou causalidade.

## Avaliação interna da mesma especificação

Reajuste em 164.174 linhas de treino; avaliação em 47.477 linhas reservadas.
Integração da normal conjunta de Laplace dos efeitos, com parâmetros populacionais
fixos e covariâncias IES/curso preservadas; 500 simulações por contexto.

| Diagnóstico reservado | Modos fixos do treino | Integração latente |
| --- | ---: | ---: |
| Pearson² | 1,214 | 1,063 |
| Maior afastamento do QQ uniforme | 0,046 | 0,063 |
| Zeros previstos (média simulada) | 1.898,334 | 1.983,380 |
| Zeros observados | 2.519 | 2.519 |

Lote independente: Pearson²=1,06353; zeros esperados=1.984,842 (erro Monte Carlo 0,366).

O parecer anterior aos worm-plots foi manter a abordagem por ora: resíduos
geralmente razoáveis para exploração, com falhas localizadas de zeros e calibração.
Cerca de metade do déficit de zeros está nos cursos com apenas um ano informativo
no treino. Persistem desvios em alguns grupos EAD grandes e nas pontas de perfis.

## Worm-plots e gráficos

Worm-plots usam `qnorm(PIT)` e mostram quantil observado menos teórico, com
referência horizontal zero e pontos entre 0,5% e 99,5%. N=1 foi excluído por
ser determinístico. As bandas curvas padrão pontuais de 95% são calculadas e
desenhadas por `gamlss::wp()`, usando todos os resíduos e não apenas os 100 pontos
exibidos. São referência normal independente, sem calibração para o painel
ou a estimação dos efeitos; não constituem teste formal do modelo misto. Ver
[van Buuren e Fredriks (2001)](https://doi.org/10.1002/sim.746).

A leitura visual mostra desvios sistemáticos de forma e caudas nos dois
contextos reservados, com diferenças entre modalidades e portes. Pearson perto
de 1 não garante a forma distribucional: estes worm-plots impedem chamar o
diagnóstico de plenamente satisfatório. Parte dos desvios pode decorrer da
aproximação latente e da estimação; o gráfico sem referência de reajuste não
isola a causa nem justifica trocar automaticamente de família. Hessiana e
seleção permanecem suspensas para discussão com o usuário.

Uma revisão independente por IA destacou centro comprimido e extremos
expandidos: não é um padrão que uma única correção de escala resolva.
Recomendou primeiro estabilizar a mesma especificação e investigar a
referência dos PIT por simulação/reestimação latente. Essa continuação e
o piloto não foram executados; não houve troca automática de família.

- [QQ reservado](validacao/graficos/QQ_uniforme.png) e [resíduos](validacao/graficos/residuos.png).
- [Worm global reservado](validacao/graficos/worm_geral.png) e [por modalidade/porte](validacao/graficos/worm_modalidade_porte.png).
- [Worm da base completa](diagnostico/graficos/worm_modalidade_porte.png), [perfis](validacao/graficos/residuos_perfis.png) e [controles](validacao/graficos/residuos_controles.png).

## Limites e próxima etapa

A reserva é retrospectiva: suas respostas influenciaram escolhas anteriores.
Não é confirmação independente, previsão futura ou avaliação de novos grupos.
A integração omite incerteza populacional e pode aproximar mal efeitos de grupos
com pouca informação. Truncagem corrige suporte, não toda a seleção da amostra.

Otimizadores: código zero; gradiente bruto máximo 92,13 no completo e 64,66 no treino.
A tolerância 1e-7 foi de triagem. A estabilidade numérica inferencial continua
pendente. Não foram calculados Hessiana populacional, IC, stepwise ou sensibilidades
do candidato atual. A curvatura interna dos latentes faz parte de Laplace.

Após revisão do usuário, conferir estabilidade e Hessiana antes de interpretar
coeficientes. Depois, seleção AIC apenas dos sete perfis e sensibilidade prioritária
2020–2024 versus 2022–2024. Apresentação e intervenção ficam para depois.

[Reprodução](../../docs/metodologia.md), [histórico](../../docs/historico.md),
[uso de IA](../../docs/registro_uso_ia_modelagem.md) e [verificação computacional](verificacao.json).
