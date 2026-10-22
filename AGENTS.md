# Datanautas — decisões vigentes

## Trabalho e limites

- Comunicar em português. Implementação autorizada em 21/10/2026; atualizações em 22/10.
- Nunca instalar dependências imperativamente: usar `flake.nix`/`flake.lock` ou shell Nix temporário.
- Preservar dados originais, PDFs de referência, notebooks, `src/utils.py` e entregas anteriores. Slides, pitch e proposta de intervenção ficam para depois.
- Usuário autorizou a limpeza: manter somente resumo das tentativas descartadas, modelos atuais, PNG e código para regenerar. Sem arquivo histórico pesado. Decisões em `docs/historico.md`; métodos e comandos em `docs/metodologia.md`.
- Distinguir sucesso computacional, diagnóstico e validação inferencial. Não apresentar hipótese como resultado, associação como causalidade ou IA como revisão humana.
- Uso de IA autorizado pelo desafio; registrar ferramentas, etapas e conferências em `docs/registro_uso_ia_modelagem.md`.

## Modelo atual

- Pergunta: quais características dos cursos e da composição dos matriculados se associam à proporção anual de desvínculo ou trancamento, considerando ano, IES e curso?
- População: Brasil, pública/privada, presencial/EAD, 2020–2024, matrículas positivas; uma linha por curso-ano. 211.651 linhas, 51.603 cursos e 2.936 IES. Não excluir cursos pequenos ou painel incompleto da análise principal.
- Resposta composta autorizada: `Y = desvinculados + trancados`, `N = vinculos`, complemento `N-Y`. Trancamento não equivale a saída definitiva. Não voltar silenciosamente à resposta anterior, que continha somente desvinculados.
- Família vigente: beta-binomial truncada superiormente em `Y<N`, ligação logit para a média subjacente, estimada por Laplace/TMBad/OpenMP em duas threads.
- Média: seis fatores estruturais (ano, modalidade, categoria administrativa, organização acadêmica, grau e área geral Cine), sete perfis, ano × modalidade, log(N), modalidade × log(N) e dez contextos de IES.
- Perfis: feminino, PPI, 25 anos ou mais, escola pública, deficiência, reserva de vagas e noturno, todos `mat_* / matriculas`. Escala de 10 pp, exceto deficiência, 1 pp. Noturno zero no EAD é estrutural.
- Contextos: médias institucionais dos sete perfis, média de log(N), fração EAD e log do número de cursos. Anos com pesos iguais no par IES/curso; cursos com pesos iguais por IES; padronização com IES de pesos iguais.
- Interceptos aleatórios separados de IES e curso. Preservar estrutura cruzada: 431 cursos mudam de IES. Área geral Cine continua fixa; não substitui o efeito de curso.
- Dispersão: `~ ano * modalidade + modalidade * log(vinculos)`. São 50 coeficientes na média, 12 na dispersão e duas variâncias aleatórias: 64 parâmetros populacionais.
- ABI duplica Cine 00: remover apenas o contraste redundante de grau, sem remover controle ou linhas. Referências e escalas estão no código e na metodologia.
- Matrículas positivas implicam Y<N; truncar condicionalmente aos efeitos, antes de integrar. `mu` não é diretamente a média da proporção truncada. N=1 é determinístico em zero (1.693 linhas): preservar no banco; excluir somente de diagnósticos que precisam de variância positiva, incluindo Pearson e worm-plots.
- A truncagem corrige suporte, não toda a seleção por matrículas positivas. Não acrescentar pesos de N à resposta de duas contagens, pois duplicaria a ponderação.

## Diagnósticos, pendências e sequência

- Priorizar QQ-plots, resíduos e, por solicitação do usuário, worm-plots. QQ sempre em pontos, sem curva ligando-os. PIT tem referência uniforme; worm-plot usa `qnorm(PIT)` menos quantil normal teórico.
- Usar as bandas curvas padrão de 95% do pacote `gamlss::wp`, declarado na flake. Banda usa todos os resíduos com N>1; mostrar 100 pontos sem curva cúbica. Bandas são referência normal independente, sem calibração para o painel/modos, e não teste formal do GLMM. As imagens didáticas enviadas pelo usuário são referências de interpretação, não resultados do modelo.
- Diagnóstico da base completa: 500 simulações condicionais, parciais com IES fixa e marginais. Considerar retração dos modos e dependência; não exigir uniformidade perfeita condicionada aos efeitos estimados nas próprias respostas.
- Validação interna da mesma especificação executada: 164.174 linhas no treino e 47.477 reservadas, uma por par IES/curso elegível. Integração da normal conjunta latente preserva covariâncias IES/curso. Lote independente confirma Pearson² aproximadamente 1,063.
- Parecer anterior aos worm-plots: resíduos geralmente razoáveis para exploração, com déficit localizado de zeros e falhas de calibração, sobretudo em alguns grupos EAD. Manter abordagem por ora; não declarar modelo inferencial final.
- Worm-plots executados: desvios sistemáticos de forma e caudas nos dois contextos reservados e diferenças por modalidade/porte. Não chamar o diagnóstico de plenamente satisfatório com base em Pearson perto de 1; não isolar a causa pelo gráfico nem trocar família automaticamente. Discutir antes de Hessiana e seleção.
- Revisão independente dos worms com bandas: localização global pequena, centro comprimido e extremos expandidos; uma correção única de escala não resolve ambos. Próxima proposta, ainda não executada: estabilizar a mesma especificação por continuação sem Hessiana populacional e calibrar o fluxo por piloto de simulação/reestimação dos latentes, antes de escolher família com flexibilidade de caudas. Bandas iid não decidem essa escolha.
- A reserva é retrospectiva: suas respostas participaram de escolhas anteriores. Não é confirmação intocada, previsão futura nem avaliação de novos cursos/IES. Não usar repetidamente a reserva para procurar um ajuste visual perfeito.
- Otimizador encerrou com código zero, mas estabilidade dos parâmetros populacionais permanece pendente (gradiente bruto completo 92,13; treino 64,66; tolerância de triagem 1e-7). A escala numérica usada não é validação inferencial.
- Hessiana populacional, `sdreport`, IC e stepwise continuam adiados até revisão do usuário. Curvatura interna dos efeitos latentes é necessária a Laplace e não equivale à Hessiana inferencial adiada.
- Não repetir toda a otimização para desenhar resíduos do modelo salvo. Verificar identidade dos dados, parâmetros, objetivo e momentos após mudanças no fluxo.
- Depois da estabilidade e aprovação diagnóstica: stepwise bidirecional por AIC somente entre os sete perfis, preservando controles estruturais, contexto e efeitos aleatórios. Documentar completo e selecionado; seleção não implica causalidade ou significância garantida.
- Sensibilidades posteriores: priorizar 2020–2024 versus 2022–2024; avaliar influência de cursos pequenos e painel completo. Essas etapas não foram executadas para a especificação atual.
- Binomial histórica apresentou desajuste; não é alternativa validada. Novas famílias/estruturas precisam ser discutidas se o diagnóstico atual não justificar avançar. Não interpretar a limpeza como autorização de novas especificações.

## Regras essenciais dos dados

- `vinculos = matriculas + trancados + desvinculados + transferidos + falecidos`; concluintes já estão nas matrículas. Complemento de Y não significa apenas permanência.
- Somar contagens antes de dividir para taxas anuais agregadas. Não fazer média simples das taxas de cursos. Somar vínculos entre anos não conta pessoas únicas.
- Perfis dos matriculados não identificam características de quem saiu; são associações ecológicas contemporâneas, sujeitas a seleção, simultaneidade e sobrevivência.
- Taxa anual do curso (0–1), desistência acumulada por turma (0–100, inclui transferência interna) e evasão oficial do sistema (0–100) têm definições diferentes. Nomear medida, denominador, período e população.
- Trajetórias: ponderar pelos ingressantes e comparar no mesmo tempo desde ingresso. Curso-ano e curso-turma-ano não são a mesma unidade; validar chaves e cardinalidade de junções.
- Para evolução temporal, usar painel completo como referência comparável e explicitar a população selecionada. Não confundir mudanças de composição com evolução dos mesmos cursos.
- Cine usa classificação mais recente; preservar zeros à esquerda e verificar reclassificação TIC em 2024 ao cruzar fontes.
- Território: usar UF de oferta; UF principal do EAD e sede da IES não representam todos os estudantes. EAD da trajetória não tem UF.
- Apoio social zero pode significar ausência de informação; série privada muda em 2022/2023. Não incluir automaticamente apoio, FIES/ProUni, docentes, contexto territorial, qualidade ou PNAES no modelo vigente.
- Qualidade descreve formandos, tem ciclos e viés de sobrevivência; ausência de conceito não é zero. Contexto estadual não é renda dos estudantes. PNAES cobre federais e exige atenção a inflação e cobertura; não extrapolar.
- Não há microdados individuais para transições trancamento→desvínculo. Pesquisa não encontrou estimativa nacional defensável; resultado local não deve ser usado para imputação.

## Organização e referências

- `data/raw/`: dez Parquet originais. `data/processed/`: base derivada regenerável, ignorada pelo Git.
- `scripts/modelo/`: fluxo vigente; `outputs/modelo/`: dois modelos, tabelas, PNG, relatório, manifesto e verificação. `.cache/`: compilação e checkpoints regeneráveis, ignorados pelo Git.
- Documentos originais lidos: `docs/briefing_impacta.pdf`, `docs/armadilhas_e_perguntas.pdf` e `docs/dicionario_dados.pdf`.
- Desafio Impacta.dev 2026: pergunta sobre desistência no ensino superior; futura entrega de slides, material de análise e declaração de IA. Submissão indicada no briefing: 23/10 às 12h; pitch de cinco minutos às 17h. Não produzir essas peças nesta etapa.
