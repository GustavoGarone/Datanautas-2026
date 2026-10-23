# Registro de uso de IA — modelagem

Ferramentas e modelos, conforme informado pelo usuário:
- OpenAI Codex, com o modelo Sol 6.1, em todo o trabalho feito no Codex (21–22/10/2026);
- Claude Code (Anthropic), com o modelo Claude Opus 5.5, em todo o trabalho feito no
  Claude Code (22–23/10/2026), incluindo os subagentes.

Execução local de R/TMB no ambiente Nix declarado. Uso autorizado pelo usuário e pelo desafio.

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

Em 22/10, Claude Code (Anthropic, Claude Opus 5.5) avaliou o custo de migrar o
modelo para o gamlss. A pedido do usuário, escreveu e executou a triagem de
famílias em `scripts/modelo/triagem_familias.R`. A IA diagnosticou que
`chooseDist` devolvia NA sem mensagens de erro e o substituiu por um laço
explícito equivalente. A leitura de AIC, BIC, convergência e worm-plots foi
conferida contra as tabelas e PNG gerados. O resultado inconclusivo está em
`historico.md`; não houve troca de família nem novo ajuste TMB.

Ainda em 22–23/10, com Claude Code (Claude Opus 5.5):
- Um subagente testou a BCT, por ideia do usuário.
- A IA conferiu o `.cpp` vigente contra uma referência exata independente e
  revisou descritivamente FIES/ProUni e a composição da resposta.
- A IA implementou e testou as variantes com dispersão aleatória, incluindo a
  população filtrada pedida pelo usuário.
- Identificou e corrigiu um erro próprio na constante do objetivo do `base`.
- Os números relatados foram conferidos contra as tabelas geradas.
- Escolhas de especificação e da população foram decisões do usuário.
- Em 23/10, a IA:
  - adaptou o diagnóstico por simulação às variantes;
  - calculou a Hessiana e os EP do `dispre`;
  - montou o esqueleto do relatório de entrega.
- A adoção do `dispre` foi decisão do usuário, com base nas comparações acima.

A declaração de uso de IA da submissão está em `entregas_finais/declaracao_uso_ia.txt`
(23/10). A IA a redigiu a partir deste registro; falta a equipe complementar o uso de IA
nas demais etapas.

O relatório registra resultados e limites. A Hessiana do `dispre` foi liberada em 23/10;
seleção e sensibilidades continuam pendentes. Números gerados por IA
foram confrontados com artefatos computacionais; recomenda-se revisão humana
antes de divulgação científica ou uso em decisão pública.
