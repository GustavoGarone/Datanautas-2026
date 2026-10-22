# Registro de uso de IA — modelagem

Ferramenta: OpenAI Codex, com execução local de R/TMB no ambiente Nix declarado.
Período: 21–22/10/2026. Uso autorizado pelo usuário e pelo desafio.

A IA apoiou leitura de documentação, planejamento estatístico, programação,
preparação de dados, ajustes, diagnósticos, interpretação de limitações e
organização dos artefatos. As decisões substantivas e mudanças de escopo foram
submetidas ao usuário. Apresentação e intervenção não foram produzidas.

Subagentes de IA, solicitados pelo usuário, pesquisaram transições após
trancamento e revisaram diagnósticos sem histórico da análise. A revisão
independente recomendou considerar retração dos efeitos e suporte; a revisão
atual apoiou manter a abordagem, com limitações locais. Isso não equivale a
revisão humana independente. A pesquisa não identificou taxa nacional defensável;
o resultado local UFMG e sua fonte estão no histórico.

Após acrescentar as bandas, outra revisão independente por IA recomendou
estabilidade e calibração dos PIT antes de escolher nova família. Sua leitura
separou localização, escala, assimetria e caudas; não ajustou modelos.

Conferências executadas: identidades contábeis, granularidade, fatores, posto,
resposta e denominador, simulação, momentos, gradientes em exemplos pequenos,
Laplace contra glmmTMB, calibração e coerência de modelos/tabelas/gráficos.
A verificação computacional não comprova adequação estatística nem causalidade.

Na consolidação, a base foi regenerada do Parquet e comparada coluna a coluna;
parâmetros, objetivo e gradientes dos dois modelos atuais foram preservados
exatamente. O código consolidado regenerou diagnósticos e PNG, incluindo
worm-plots solicitados posteriormente e suas bandas padrão por `gamlss::wp()`;
o pacote foi declarado na flake, sem instalação imperativa. Artefatos históricos foram excluídos
com autorização, mantendo resumo e proveniência dos modelos atuais.

O relatório registra resultados e limites; Hessiana populacional, inferência,
seleção e sensibilidades atuais continuam pendentes. Números gerados por IA
foram confrontados com artefatos computacionais; recomenda-se revisão humana
antes de divulgação científica ou uso em decisão pública.
