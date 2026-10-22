source("scripts/modelo/common.R")
args<-commandArgs(trailingOnly=TRUE)
stopifnot(length(args)>=1L,args[1]%in%c("completo","treino"),all(args[-1]%in%c("--reajustar","--do-zero")))
stage<-args[1];training<-stage=="treino";sig<-assinatura(training)
path<-model_path(stage);force<-"--reajustar"%in%args||"--do-zero"%in%args
if(file.exists(path)&&!force){ler_modelo(stage);log_msg(stage,"salvo e conferido; reutilizando");quit(save="no",status=0)}
d<-dados_modelo();if(training)d<-d[validacao==FALSE]
trunc_compile();dd<-trunc_data(d)
initial<-if(file.exists(path)&&!"--do-zero"%in%args)path else if(training)model_path("completo")else NULL
if(!is.null(initial)) {
  previous<-readRDS(initial);stopifnot(identical(previous$colnames$X,colnames(dd$X)),
    identical(previous$colnames$Z,colnames(dd$Z)),identical(previous$levels$co_ies,levels(d$co_ies)),
    identical(previous$levels$co_curso,levels(d$co_curso)))
  pars<-previous$parameters
  scale<-previous$optimizer_scale
  rm(previous);gc()
} else {
  # Inicialização computacional, não candidato da análise; não é salvo ou interpretado.
  warm<-glmmTMB(formula_media(),dispformula=formula_dispersao(),data=d,
    contrasts=model_contrasts(d),family=betabinomial(link="logit"),se=FALSE,
    control=glmmTMBControl(parallel=TRUNC_THREADS,optCtrl=list(iter.max=1500L,eval.max=2000L)))
  stopifnot(warm$fit$convergence==0L,identical(names(fixef(warm)$cond),colnames(dd$X)),
    identical(names(fixef(warm)$disp),colnames(dd$Z)),
    identical(warm$modelInfo$grpVar,c("co_ies","co_curso")))
  for(g in warm$modelInfo$grpVar)stopifnot(identical(levels(d[[g]]),
    levels(warm$modelInfo$reTrms$cond$flist[[g]])))
  pars<-list(beta=unname(fixef(warm)$cond),betadisp=unname(fixef(warm)$disp),
    theta=unname(warm$fit$par[names(warm$fit$par)=="theta"]),
    b=unname(warm$fit$parfull[names(warm$fit$parfull)=="b"]))
  scale<-NULL;rm(warm);gc()
}
obj<-TMB::MakeADFun(dd,pars,random="b",DLL=TRUNC_DLL,silent=TRUE)
if(is.null(scale)) {
  # Precondicionamento positivo derivado da matriz; sem Hessiana ou modelo histórico.
  scale<-rep(.05,length(obj$par))
  scale[names(obj$par)=="beta"]<-pmin(1,.05/pmax(sqrt(colMeans(dd$X^2)),.05))
}
stopifnot(length(scale)==length(obj$par),all(is.finite(scale)),all(scale>0))
checkpoint<-file.path(CACHE,paste0("checkpoint_",stage,".rds"));par<-obj$par
if(file.exists(checkpoint)) {
  saved<-readRDS(checkpoint)
  if(identical(saved$signature,sig))par<-saved$par
}
start<-last<-proc.time()[[3]];best<-Inf;bestpar<-par;evals<-0L
last_gradient<-last_par<-NULL
g<-function(p){v<-obj$gr(p);last_gradient<<-v;last_par<<-p;v}
f<-function(p) {
  v<-obj$fn(p);evals<<-evals+1L
  if(is.finite(v)&&v<best){best<<-v;bestpar<<-p}
  if(proc.time()[[3]]-last>40) {
    log_msg(stage,"avaliações",evals,"objetivo",sprintf("%.8f",v))
    atomic_rds(list(signature=sig,par=bestpar,objetivo=best),checkpoint);last<<-proc.time()[[3]]
  }
  v
}
control<-list(iter.max=1500L,eval.max=2000L,rel.tol=1e-7)
fit<-nlminb(par,f,g,scale=1/scale,control=control)
if(!identical(last_par,fit$par))g(fit$par)
value<-obj$fn(fit$par);parameters<-obj$env$parList(x=fit$par,par=obj$env$last.par)
stopifnot(fit$convergence==0L,all(is.finite(unlist(parameters))),all(is.finite(last_gradient)),
  abs(value-fit$objective)<1e-3,
  identical(unname(c(parameters$beta,parameters$betadisp,parameters$theta)),unname(fit$par)))
m<-list(schema=1L,parameters=parameters,fit=fit,gradient=last_gradient,signature=sig,
  optimizer_control=control,optimizer_scale=scale,framework="TMBad",threads=TRUNC_THREADS,
  n=nrow(d),levels=list(co_ies=levels(d$co_ies),co_curso=levels(d$co_curso)),
  colnames=list(X=colnames(dd$X),Z=colnames(dd$Z)),formula=formula_media(),dispformula=formula_dispersao(),
  resposta="desvinculados + trancados",denominador="vinculos",se=FALSE,
  etapa="triagem; validacao inferencial pendente",segundos=proc.time()[[3]]-start,
  proveniencia=list(codigo=hash("scripts/modelo/ajustar.R"),inicializacao=if(is.null(initial))"BB ordinaria temporaria"else hash(initial)))
atomic_rds(m,path);unlink(checkpoint)
log_msg(stage,"salvo sem Hessiana populacional; recalcular os diagnósticos após reajuste")
