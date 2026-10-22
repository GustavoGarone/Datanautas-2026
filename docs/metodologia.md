# Modelo vigente e reprodução

Análise descritiva de associações entre características dos cursos, composição
dos matriculados e proporção anual de **desvínculo ou trancamento**, Brasil,
2020–2024. Unidade: curso-ano. Não estima risco individual, saída definitiva
do sistema nem efeitos causais. Apresentação e intervenção ficam para depois.

## Dados e preparação

Fonte principal: `data/raw/cursos_ano.parquet`. Das 220.686 linhas, excluir
somente 9.035 sem matrículas, necessárias aos denominadores dos perfis.
Restam 211.651 linhas, 51.603 cursos e 2.936 IES. Cursos pequenos e painel
incompleto permanecem. Conferir chave curso-ano, contagens inteiras não negativas,
identidade dos vínculos, perfis até matrículas, zeros estruturais do noturno
EAD e indicador de presença nos cinco anos. Não alterar os Parquet originais.

Definir `Y = desvinculados + trancados`, `N = vinculos` e complemento `N-Y`.
`N = matriculas + trancados + desvinculados + transferidos + falecidos`.
Concluintes já estão nas matrículas. Trancamento pode ser temporário; a soma
é um desfecho composto autorizado, não equivalência entre estados.

As sete proporções usam `matriculas`: feminino, PPI, 25 anos ou mais, escola
pública, deficiência, reserva de vagas e noturno. Dividir por 0,1 para representar
10 pp; deficiência por 0,01 para 1 pp. Os perfis descrevem os matriculados,
não os indivíduos que saíram. Noturno é interpretável no presencial.

## Especificação

Beta-binomial com parâmetros `mu`, `phi`, truncada superiormente, condicional
aos efeitos aleatórios: `P(Y=y | b) = f_BB(y | N,mu,phi)/(1-f_BB(N | N,mu,phi))`,
para `y=0,...,N-1`. Matrículas positivas tornam Y=N impossível.

`logit(mu)` inclui os seis fatores — ano, modalidade, categoria administrativa,
organização acadêmica, grau e área geral Cine —, os sete perfis, interação
ano × modalidade, log(N), modalidade × log(N), dez contextos de IES e
interceptos normais separados de IES e curso. Os 431 cursos que mudam de IES
justificam preservar a estrutura cruzada. Área não substitui curso.

Os contextos são as médias dos sete perfis, média de log(N), fração EAD e
log do número de cursos. Agregar anos com pesos iguais dentro de cada par
IES/curso, depois cursos com pesos iguais dentro da IES; padronizar com peso
igual por IES. Utilizam covariáveis de todo o período, coerentemente com o
objetivo retrospectivo. Não caracterizam previsão prospectiva.

Referências: 2020, presencial, privada com fins lucrativos, universidade,
bacharelado e Cine 04. ABI é duplicado de Cine 00: remover somente a coluna
redundante do contraste de grau, sem eliminar observações ou controles.
A matriz da média tem 50 colunas e posto completo.

`log(phi) ~ ano * modalidade + modalidade * log(N)` tem 12 colunas. Com duas
variâncias aleatórias, são 64 parâmetros populacionais e 54.539 efeitos latentes.
`mu` é a média beta-binomial subjacente; a média da proporção observada é
`(mu-P_BB(Y=N))/(1-P_BB(Y=N))`. Não interpretar diretamente seus coeficientes
como efeitos sobre a média truncada sem essa transformação.

Há 1.693 linhas com N=1: Y=0 determinístico. Permanecem no banco, com contribuição
zero da resposta à log-verossimilhança; ficam fora do Pearson e dos worm-plots.
A truncagem corrige suporte, não resolve toda a seleção por matrículas positivas.

## Ajuste e diagnóstico

TMB com Laplace, backend TMBad/OpenMP, duas threads; `nlminb`, até 1.500 iterações,
2.000 avaliações e tolerância relativa `1e-7` para triagem. Os modelos salvos
mantêm os parâmetros originalmente estimados. A consolidação de arquivos mudou
metadados e caminhos, com comparação exata dos parâmetros, objetivo e gradiente.
Para iniciar sem históricos, usa-se uma beta-binomial ordinária temporária
como inicialização computacional; não é um novo candidato para interpretação.
O precondicionamento usa a matriz ou a escala numérica preservada no modelo,
sem depender de modelos descartados. Checkpoints e compilação ficam em `.cache/`.

Diagnósticos da base completa usam 500 simulações, semente 20261021, sem
reajuste por réplica: condicionais aos modos, IES fixa com cursos sorteados,
e marginais com IES/curso sorteados. Resíduos PIT randomizam empates;
QQ-plots usam 100 pontos e referência uniforme. Calibração usa somas de
numeradores e denominadores, por ano, modalidade, porte e IES.
Resíduos versus ajustados, porte, sete perfis e seis controles complementam
Pearson, zeros e dependência temporal descritiva.

Worm-plots transformam PIT por `qnorm` e subtraem o quantil normal teórico:
referência horizontal zero, 100 pontos entre 0,5% e 99,5%, global e por
modalidade/porte. Excluem N=1, que não informa ajuste distribucional.
As bandas curvas padrão pontuais de 95% são calculadas e desenhadas por
`gamlss::wp()`, usando o n completo, não 100 observações. A curva cúbica fica
oculta; os resíduos são pontos. Essas bandas usam referência normal independente,
sem calibração para painel ou estimação dos efeitos: são descritivas e não
constituem um teste formal do modelo misto. O pacote é usado somente para
diagnóstico; o ajuste continua em TMB. Ver
[van Buuren e Fredriks (2001)](https://doi.org/10.1002/sim.746).

## Validação interna e limites

Reservar uma linha por par IES/curso com pelo menos dois anos, semente 20261022:
164.174 no treino e 47.477 na reserva, com os mesmos grupos. Reajustar a mesma
especificação somente no treino. Comparar modos fixos e integração da normal
latente conjunta de Laplace, preservando covariâncias entre IES/curso.
Usar `Q=P'LL'P` e raiz amostradora `P'L'^{-1}`; conferir fatoração e exemplo
pequeno. Um lote independente de 500 sorteios verifica momentos e zeros.

A curvatura dos efeitos latentes faz parte de Laplace; não é a Hessiana dos
parâmetros populacionais, ainda adiada. Sem `sdreport`, IC ou stepwise nesta
etapa. As respostas reservadas já influenciaram escolhas anteriores: avaliação
interna retrospectiva, não confirmação intocada, novos grupos ou previsão futura.
Não continuar buscando especificações repetidamente na mesma reserva.

Antes de inferência: estabilidade da otimização e Hessiana populacional após
revisão do usuário. Depois, stepwise bidirecional por AIC somente entre os sete
perfis, preservando controles, contextos e efeitos aleatórios. Priorizar
sensibilidade 2020–2024 versus 2022–2024; avaliar cursos pequenos e painel
completo. Essas etapas não foram executadas para o modelo vigente.

## Comandos

Executar na raiz, sem instalações imperativas. Dependências fixadas em
`flake.nix` e `flake.lock`.

```sh
nix develop path:. -c bash scripts/modelo/run.sh verificar
nix develop path:. -c bash scripts/modelo/run.sh verificar --likelihood
nix develop path:. -c bash scripts/modelo/run.sh testar
nix develop path:. -c bash scripts/modelo/run.sh worm
nix develop path:. -c bash scripts/modelo/run.sh graficos
nix develop path:. -c bash scripts/modelo/run.sh reproduzir
```

`verificar` recalcula momentos, Pearson, QQ, calibração e identidades dos arquivos.
`--likelihood` também reavalia o objetivo TMB dos dois modelos, sem reotimizar.
`testar` confere densidade, momentos, simulador, derivadas e Laplace contra
glmmTMB em casos pequenos. `worm` redesenha somente os worm-plots dos resíduos
salvos e confere os artefatos, sem novas simulações. `graficos` refaz simulações, tabelas e PNG dos modelos
salvos; `reproduzir` também prepara a base e ajusta somente se não houver modelo
compatível. `reajustar` força uma nova otimização, com maior custo e resultados
numéricos possivelmente distintos; não foi necessário na limpeza.

Saídas em `outputs/modelo/`: dois modelos, diagnósticos, validação, relatório e
verificação computacional. A base derivada e o cache são ignorados pelo Git e
regeneráveis. Apenas PNG; nenhum PDF gerado duplicado. Os documentos originais,
notebooks e entregas anteriores são preservados. Histórico resumido em
[historico.md](historico.md); uso de IA em
[registro_uso_ia_modelagem.md](registro_uso_ia_modelagem.md).
