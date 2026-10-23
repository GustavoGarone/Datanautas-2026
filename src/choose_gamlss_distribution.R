suppressPackageStartupMessages({
  library(arrow)
  library(gamlss)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: Rscript choose_gamlss_distribution.R <cursos_ano.parquet>")
}

df_raw <- as.data.frame(read_parquet(args[[1]]))
base <- subset(
  df_raw,
  poucos_alunos == 0 &
    presente_5_anos == 1 &
    modalidade == "Presencial" &
    matriculas > 0
)

mat <- base$matriculas
base$prop_noturno <- base$mat_noturno / mat
base$prop_escola_publica <- base$mat_escola_publica / mat
base$prop_prouni <- base$mat_prouni / mat
base$prop_fies <- base$mat_fies / mat
base$prop_cotas <- base$mat_reserva_vagas / mat
base$prop_25_mais <- base$mat_25_anos_ou_mais / mat
base$prop_ppi <- base$mat_ppi / mat
base$prop_feminino <- base$mat_feminino / mat
base$prop_deficiencia <- base$mat_deficiencia / mat
base$prop_apoio_social <- base$mat_apoio_social / mat
log_matriculas <- log1p(mat)
base$log_matriculas <- as.numeric(scale(log_matriculas))
base$eh_tecnologo <- as.integer(base$grau_academico == "Tecnológico")

mu_formulas <- list(
  Privada = taxa_desvinculo ~
    prop_noturno * prop_escola_publica +
    prop_noturno * prop_prouni +
    prop_noturno * prop_fies +
    prop_25_mais + eh_tecnologo +
    prop_ppi + prop_feminino + prop_deficiencia + prop_apoio_social +
    log_matriculas +
    factor(nome_cine_area_geral) +
    factor(regiao_principal) +
    factor(organizacao_academica) +
    factor(categoria_administrativa),
  Pública = taxa_desvinculo ~
    prop_noturno * prop_escola_publica +
    prop_noturno * prop_cotas +
    prop_25_mais + eh_tecnologo +
    prop_ppi + prop_feminino + prop_deficiencia + prop_apoio_social +
    log_matriculas +
    factor(nome_cine_area_geral) +
    factor(regiao_principal) +
    factor(organizacao_academica) +
    factor(categoria_administrativa)
)

sigma_formulas <- list(
  Privada = ~ prop_noturno + prop_escola_publica + prop_25_mais +
    log_matriculas + factor(regiao_principal) +
    factor(nome_cine_area_geral),
  Pública = ~ prop_noturno + prop_escola_publica + prop_25_mais +
    log_matriculas + factor(regiao_principal) +
    factor(nome_cine_area_geral)
)

nu_formulas <- list(
  Privada = ~ prop_noturno + prop_escola_publica + prop_prouni +
    prop_fies + prop_25_mais + eh_tecnologo + log_matriculas +
    factor(nome_cine_area_geral) + factor(regiao_principal),
  Pública = ~ prop_noturno + prop_escola_publica + prop_cotas +
    prop_25_mais + eh_tecnologo + log_matriculas +
    factor(nome_cine_area_geral) + factor(regiao_principal)
)

predictors <- list(
  Privada = c(
    "taxa_desvinculo", "prop_noturno", "prop_escola_publica",
    "prop_prouni", "prop_fies", "prop_25_mais", "eh_tecnologo",
    "prop_ppi", "prop_feminino", "prop_deficiencia",
    "prop_apoio_social", "log_matriculas", "nome_cine_area_geral",
    "regiao_principal", "organizacao_academica",
    "categoria_administrativa"
  ),
  Pública = c(
    "taxa_desvinculo", "prop_noturno", "prop_escola_publica",
    "prop_cotas", "prop_25_mais", "eh_tecnologo",
    "prop_ppi", "prop_feminino", "prop_deficiencia",
    "prop_apoio_social", "log_matriculas", "nome_cine_area_geral",
    "regiao_principal", "organizacao_academica",
    "categoria_administrativa"
  )
)

for (network in names(mu_formulas)) {
  d <- base[
    base$rede == network &
      base$ano == 2024 &
      base$nome_cine_area_geral != "Programas básicos",
    ,
    drop = FALSE
  ]
  d <- d[
    complete.cases(d[, predictors[[network]], drop = FALSE]),
    predictors[[network]],
    drop = FALSE
  ]

  if (any(d$taxa_desvinculo < 0 | d$taxa_desvinculo > 1)) {
    stop("Response is outside [0, 1] for network: ", network)
  }

  initial_fit <- gamlss(
    mu_formulas[[network]],
    family = BEZI,
    sigma.formula = sigma_formulas[[network]],
    nu.formula = nu_formulas[[network]],
    data = d,
    control = gamlss.control(n.cyc = 100, trace = FALSE)
  )
  comparison <- chooseDist(
    initial_fit,
    type = "real0to1",
    trace = FALSE
  )

  best_aic <- min(comparison[, "2"], na.rm = TRUE)
  best_rows <- which(
    abs(comparison[, "2"] - best_aic) < 1e-3
  )
  if (!length(best_rows)) {
    stop("No candidate distribution converged for network: ", network)
  }

  cat("\n--- ", network, " (n=", nrow(d), ") ---\n", sep = "")
  print(comparison, digits = 8)
  cat(
    "BEST|", network, "|",
    paste(rownames(comparison)[best_rows], collapse = ","),
    "|", sprintf("%.8f", best_aic),
    "|", sum(d$taxa_desvinculo == 0),
    "|", sum(d$taxa_desvinculo == 1),
    "\n",
    sep = ""
  )
}
