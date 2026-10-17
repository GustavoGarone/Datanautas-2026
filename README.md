# datanauts - projeto para o Impacta.Dev

O desafio é propor uma solução viável para o problema da **evasão nos cursos superiores** baseada em dados. 

# Abordagem

Utilizamos as linguagens _Python_ e _R_, além de pacotes específicos para manipular o grande volume de dados (como DuckDB, Polars e Arrow) disponibilizados no formato **.csv** e **.parquet**. Após inspeção inicial e devida análise exploratória, propomos um modelo de regressão XXX para avaliar como um certo conjunto de covariáveis (as significativas) impacta as taxas de interesse (taxa de desvínculo, taxa de trancamento, taxa de conclusão anual...). Um diagnóstico do modelo é feito para garantir sua adequação aos dados.

# Interpretação

Construímos e interpretamos as estimativas intervalares para cada parâmetro e obtemos conclusões práticas a partir delas, que devem nos orientar na direção da resolução do problema em questão.

# Proposta

Dadas as interpretações realistas e fundamentadas em dados, consideramos propostas que visem mitigar os efeitos negativos detectados sobre algumas covariáveis ou, ainda, potencializar os efeitos positivos gerados por outras.