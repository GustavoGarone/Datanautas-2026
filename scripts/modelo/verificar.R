# Coerência de dados, parâmetros, diagnósticos e artefatos; não aceita inferência.
source("scripts/modelo/common.R")
d<-dados_modelo();full<-ler_modelo("completo");train<-ler_modelo("treino")
stopifnot(full$n==nrow(d),train$n==sum(!d$validacao),
  identical(full$levels,train$levels),all(d$eventos_resposta<d$vinculos))
errors<-list()
for(stage in c("diagnostico","validacao")) {
  OUT<-file.path(MODEL_OUT,stage);r<-readRDS(file.path(OUT,"residuos.rds"))
  m<-if(stage=="diagnostico")full else train
  z<-if(stage=="diagnostico")d else d[validacao==TRUE]
  stopifnot(identical(r$linha_original,z$linha_original),
    identical(r$eventos_resposta,z$eventos_resposta),identical(r$vinculos,z$vinculos),
    identical(m$levels$co_ies,levels(z$co_ies)),identical(m$levels$co_curso,levels(z$co_curso)),
    identical(unname(c(m$parameters$beta,m$parameters$betadisp,m$parameters$theta)),unname(m$fit$par)))
  X<-matriz_media(z);Z<-model.matrix(formula_dispersao(),z)
  stopifnot(identical(colnames(X),m$colnames$X),identical(colnames(Z),m$colnames$Z))
  ii<-as.integer(z$co_ies);ci<-nlevels(z$co_ies)+as.integer(z$co_curso)
  b<-m$parameters$b
  if(stage=="validacao") {
    q<-readRDS(file.path(OUT,"precisao_latente.rds"))
    stopifnot(identical(q$train_md5,hash(model_path("treino"))),identical(q$levels,m$levels))
    b<-q$bmode
  }
  mu<-plogis(drop(X%*%m$parameters$beta)+b[ii]+b[ci]);phi<-exp(drop(Z%*%m$parameters$betadisp))
  mm<-trunc_moments(mu,phi,z$vinculos);ok<-z$vinculos>1
  plug<-if(stage=="diagnostico")"condicional"else"modos_fixos_treino"
  stopifnot(max(abs(mm$mean-r[[paste0("previsto_",plug)]]))<1e-12,
    max(abs(mm$second-mm$mean^2-r[[paste0("variancia_taxa_",plug)]]))<1e-12)
  dg<-fread(file.path(OUT,"tabelas/diagnosticos.csv"));pit<-fread(file.path(OUT,"tabelas/resumo_PIT.csv"))
  ca<-fread(file.path(OUT,"tabelas/calibracao_grupos.csv"))
  contexts<-sub("^PIT_","",names(r)[startsWith(names(r),"PIT_")])
  for(k in contexts) {
    u<-r[[paste0("PIT_",k)]];p<-r[[paste0("previsto_",k)]];v<-r[[paste0("variancia_taxa_",k)]]
    stopifnot(all(is.finite(u)),all(u>=0&u<=1),all(p>=-1e-12),
      all(p<=(r$vinculos-1)/r$vinculos+1e-8),all(v[ok]>0),all(v[!ok]==0),all(p[!ok]==0))
    stat<-if(stage=="diagnostico")"dispersao_padronizada"else"Pearson2"
    p2<-mean((r$observado[ok]-p[ok])^2/v[ok])
    stopifnot(abs(p2-dg[contexto==k&estatistica==stat,observado])<1e-10,
      all(dg[contexto==k&estatistica=="zeros",observado]==sum(r$eventos_resposta==0)))
    qqmax<-max(abs(sort(u)-ppoints(nrow(r))))
    stopifnot(abs(qqmax-pit[contexto==k,maior_afastamento_uniforme])<1e-12)
    a<-r[,.(ano,modalidade,porte,eventos_resposta,vinculos)];a[,pred:=p]
    a<-a[,.(linhas=.N,vinculos=sum(vinculos),observado=sum(eventos_resposta)/sum(vinculos),
      previsto=sum(vinculos*pred)/sum(vinculos)),by=.(ano,modalidade,porte)]
    saved<-ca[contexto==k]
    for(vv in c("ano","modalidade","porte")){a[,(vv):=as.character(get(vv))];saved[,(vv):=as.character(get(vv))]}
    joined<-merge(a,saved,by=c("ano","modalidade","porte"),suffixes=c("_novo","_salvo"))
    stopifnot(nrow(joined)==40L,all(joined$linhas_novo==joined$linhas_salvo),
      all(joined$vinculos_novo==joined$vinculos_salvo),
      max(abs(joined$observado_novo-joined$observado_salvo))<1e-12,
      max(abs(joined$previsto_novo-joined$previsto_salvo))<1e-12)
  }
  meta<-jsonlite::read_json(file.path(OUT,"diagnostico.json"),simplifyVector=TRUE)
  if(stage=="diagnostico")stopifnot(identical(meta$modelo_md5,hash(model_path("completo")))) else {
    cm<-jsonlite::read_json(file.path(OUT,"complementos.json"),simplifyVector=TRUE)
    p0<-readRDS(file.path(OUT,"prob_zero.rds"))
    stopifnot(identical(meta$modelo_treino_md5,hash(model_path("treino"))),
      identical(meta$modelo_completo_md5,hash(model_path("completo"))),
      identical(cm$treino_md5,hash(model_path("treino"))),identical(p0$linha_original,r$linha_original),
      all(p0$prob_zero_integrada_lote_independente>=0),all(p0$prob_zero_integrada_lote_independente<=1+1e-8),
      all(p0$prob_zero_integrada_lote_independente[!ok]==1),
      abs(sum(p0$prob_zero_integrada_lote_independente)-cm$zeros_esperados)<1e-9)
  }
  worm<-fread(file.path(OUT,"tabelas/worm_pontos.csv"))
  stopifnot(max(abs(worm$desvio-(worm$observado-worm$teorico)))<1e-12,
    max(abs(worm$teorico-qnorm(worm$probabilidade)))<1e-12)
  wm<-jsonlite::read_json(file.path(OUT,"worm.json"),simplifyVector=TRUE)
  stopifnot(wm$pacote=="gamlss",wm$funcao=="wp",wm$n==sum(ok),wm$bandas_usam_todos_residuos,
    wm$versao==as.character(packageVersion("gamlss")),
    identical(wm$codigo,hash("scripts/modelo/worm.R")),
    identical(wm$residuos_md5,hash(file.path(OUT,"residuos.rds"))),
    identical(wm$modelo_md5,hash(model_path(if(stage=="diagnostico")"completo"else"treino"))))
  errors[[stage]]<-list(n=nrow(r),N1=sum(!ok),contextos=contexts,
    momentos_Pearson_QQ_calibracao_worm_conferidos=TRUE)
}
if("--likelihood"%in%commandArgs(trailingOnly=TRUE)) {
  trunc_compile()
  for(stage in c("completo","treino")) {
    m<-ler_modelo(stage);z<-if(stage=="completo")d else d[validacao==FALSE]
    o<-TMB::MakeADFun(trunc_data(z),m$parameters,random="b",DLL=TRUNC_DLL,silent=TRUE)
    value<-o$fn(o$par);error<-abs(value-m$fit$objective);stopifnot(error<1e-3)
    errors[[stage]]<-list(erro_objetivo=error)
    TMB::FreeADFun(o);rm(o);gc()
  }
}
fits<-rbindlist(lapply(c("completo","treino"),function(stage) {
  m<-ler_modelo(stage)
  data.table(modelo=stage,n=m$n,k=length(m$fit$par),logLik=-m$fit$objective,
    AIC=2*m$fit$objective+2*length(m$fit$par),codigo=m$fit$convergence,
    max_gradiente_bruto=max(abs(m$gradient)),
    max_gradiente_escalado=max(abs(m$gradient*m$optimizer_scale)),hessiana_inferencia=FALSE,selecao=FALSE)
}))
fwrite(fits,file.path(MODEL_OUT,"ajustes.csv"))
mp<-file.path(MODEL_OUT,"manifesto.json")
manifest<-if(file.exists(mp))jsonlite::read_json(mp,simplifyVector=FALSE)else list()
manifest$atuais<-lapply(c("completo","treino"),function(stage)list(nome=stage,
  md5=hash(model_path(stage)),proveniencia=ler_modelo(stage)$proveniencia))
manifest$ambiente<-list(R=R.version.string,flake_lock=hash("flake.lock"),
  pacotes=setNames(lapply(c("TMB","glmmTMB","nanoparquet","data.table","ggplot2","jsonlite","gamlss"),
    function(p)as.character(packageVersion(p))),c("TMB","glmmTMB","nanoparquet","data.table","ggplot2","jsonlite","gamlss")))
write_json(manifest,mp)
testfile<-file.path(CACHE,"testes/verificacao.json")
write_json(list(status="conferencia_computacional_concluida",conferencias=errors,
  implementacao=if(file.exists(testfile))jsonlite::read_json(testfile)else NULL,
  modelos=as.list(tools::md5sum(c(model_path("completo"),model_path("treino")))),
  codigo=as.list(tools::md5sum(list.files("scripts/modelo",full.names=TRUE))),
  hessiana_populacional=FALSE,selecao=FALSE,validacao_numerica_inferencial=FALSE),
  file.path(MODEL_OUT,"verificacao.json"))
log_msg("Dados, modelos e diagnósticos conferidos; inferência permanece pendente")
