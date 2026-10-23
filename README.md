![Datanautas](assets/banner_datanautas.png)

# Datanautas — Impacta.dev 2026

Associações entre características dos cursos, composição dos matriculados e
proporção anual de **desvínculo ou trancamento** ((desvinculados + trancados) ÷
vínculos), Brasil, 2020–2024. Os dados são agregados por curso-ano: não permitem
inferir risco individual nem causalidade.

**Modelo adotado (`dispre`):**
- beta-binomial truncada em Y<N, com interceptos aleatórios de IES e de curso **na
  média e na dispersão**;
- controles estruturais, sete perfis dos matriculados e contextos institucionais;
- população: cursos presentes nos cinco anos e curso-anos com 30 vínculos ou mais
  (152.484 curso-anos);
- diagnósticos por simulação e validação em anos reservados aprovados com limitações;
- Hessiana positiva definida e intervalos de confiança de Wald.

## Consultar

- **[Documento completo do pipeline](pipeline_modelo.html)**
  ([fonte Quarto](pipeline_modelo.qmd)): dados, exploração, modelo, testes,
  diagnósticos, resultados e limitações, explicados para leitura.
- **[Guia para a equipe](docs/guia_equipe.md)**: o que foi feito, achados e material pronto.
- [Esqueleto do relatório de entrega](docs/relatorio_entrega.md) e
  [declaração de uso de IA](entregas_finais/declaracao_uso_ia.txt).
- [Exploração com trancamento](outputs/eda/) e
  [painel para o pitch](outputs/eda/graficos/painel_pitch.png).
- [Modelo adotado](outputs/modelo/variantes/filtrada/dispre/): ajustes, diagnóstico e
  [coeficientes](outputs/modelo/variantes/filtrada/dispre/inferencia/tabelas/coeficientes.csv).
- [Métodos e comandos](docs/metodologia.md), [histórico de decisões](docs/historico.md),
  [decisões vigentes](AGENTS.md) e [registro de uso de IA](docs/registro_uso_ia_modelagem.md).
- O modelo anterior (64 parâmetros, base completa) está preservado em
  [outputs/modelo/](outputs/modelo/relatorio.md) como referência histórica.

## Executar

Dependências (R, pacotes e Quarto) declaradas em `flake.nix` e fixadas em
`flake.lock`. **Nunca instalar imperativamente.** Na raiz:

```sh
nix develop -c quarto render pipeline_modelo.qmd                     # documento, a partir dos resultados salvos
nix develop -c quarto render pipeline_modelo.qmd -P reexecutar:true  # refaz todo o pipeline (horas)
```

Os passos individuais estão em `docs/metodologia.md`. Base derivada, cache e resíduos
de diagnóstico são regeneráveis e ignorados pelo Git. Dados originais, PDFs de
referência, notebooks e entregas anteriores estão preservados.
