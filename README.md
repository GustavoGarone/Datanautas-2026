![Datanautas](assets/banner_datanautas.png)

# Datanautas — Impacta.dev 2026

Associações entre características dos cursos, composição dos matriculados e
proporção anual de **desvínculo ou trancamento**, Brasil, 2020–2024.
Dados agregados por curso-ano; não permitem inferir risco individual ou causalidade.

O candidato atual é uma beta-binomial truncada em Y<N, com interceptos de IES
e curso, controles estruturais, perfis dos matriculados, contexto institucional
e dispersão por ano, modalidade e porte. Validação interna melhora a avaliação
de dispersão, mas worm-plots mostram desvios de forma e caudas. **Estabilidade numérica e inferência
permanecem pendentes**; não houve Hessiana populacional nem seleção nesta rodada.

## Consultar

- [Relatório atual e limitações](outputs/modelo/relatorio.md).
- [QQ em pontos](outputs/modelo/validacao/graficos/QQ_uniforme.png), [resíduos](outputs/modelo/validacao/graficos/residuos.png) e [worm-plots](outputs/modelo/validacao/graficos/worm_modalidade_porte.png).
- [Modelos salvos](outputs/modelo/modelos/), [verificação](outputs/modelo/verificacao.json) e [proveniência](outputs/modelo/manifesto.json).
- [Métodos e reprodução](docs/metodologia.md), [histórico resumido](docs/historico.md), [decisões vigentes](AGENTS.md) e [uso de IA](docs/registro_uso_ia_modelagem.md).

## Executar

Dependências declaradas em `flake.nix` e fixadas em `flake.lock`.
**Nunca instalar imperativamente.** Na raiz:

```sh
nix develop path:. -c bash scripts/modelo/run.sh verificar
nix develop path:. -c bash scripts/modelo/run.sh graficos
nix develop path:. -c bash scripts/modelo/run.sh reproduzir
```

`verificar` confere os artefatos sem reotimizar. `graficos` regenera simulações,
tabelas e PNG dos modelos salvos. `reproduzir` também prepara os dados e ajusta
modelos ausentes; `reajustar` força nova otimização. Mais opções na metodologia.

Dados originais, PDFs de referência, notebooks e entregas anteriores preservados.
Modelos descartados estão documentados somente no resumo histórico. Base derivada
e cache são regeneráveis e ignorados pelo Git. Apresentação e intervenção ficam
para uma etapa posterior.
