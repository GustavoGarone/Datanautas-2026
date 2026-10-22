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

## Pesquisa sobre trancamento

Não foi localizada estimativa nacional defensável da conversão de trancamento
em desvínculo. Em 12 cursos de saúde da UFMG, 617 de 1.210 estudantes que
trancaram alguma vez estavam evadidos: 51,0%, tabela 14, p. 56, 2009–2015.
Não há horizonte uniforme pós-trancamento; não extrapolar nem usar para imputação.
Fonte primária conferida:
[Santos (2016)](https://repositorio.ufmg.br/bitstream/1843/BUOS-AJNNJ2/1/disserta__o_finalizada__22112016.pdf#page=56).
