# Hessiana dos parâmetros populacionais de uma variante (padrão: dispre), por diferenças
# finitas do gradiente de Laplace (optimHess), um passo de Newton para estabilizar o ótimo
# e erros-padrão de Wald. Autorizada pelo usuário em 23/10/2026; resultados exploratórios.
source("scripts/modelo/variantes.R")
args<-commandArgs(trailingOnly=TRUE)
v<-if(length(args)&&args[1]%in%VARIANTS)args[1]else"dispre"
pop<-sub("^--populacao=","",grep("^--populacao=",args,value=TRUE));if(!length(pop))pop<-"filtrada"
OUT<-output_dir(file.path("variantes",pop,v,"inferencia"))
path<-variant_path(v,"completo",pop);m<-readRDS(path);d<-populacao(pop);des<-design(v,d)
stopifnot(identical(colnames(des$X),m$colnames$X),identical(colnames(des$Z),m$colnames$Z))
dd<-list(X=des$X,Z=des$Z,y=d$eventos_resposta,N=d$vinculos,ies=as.integer(d$co_ies)-1L,
  curso=as.integer(d$co_curso)-1L,n_ies=nlevels(d$co_ies))
vm<-variant_map(v,nlevels(d$co_ies),nlevels(d$co_curso));disp_compile()
obj<-TMB::MakeADFun(dd,m$parameters,random=vm$random,map=vm$map,DLL=DISP_DLL,silent=TRUE)
p0<-m$fit$par;f0<-obj$fn(p0);g0<-obj$gr(p0)
log_msg(v,"objetivo",sprintf("%.4f",f0),"gradiente máx",signif(max(abs(g0)),3),"; Hessiana iniciando")
t0<-proc.time()[[3]];H<-optimHess(p0,obj$fn,obj$gr);H<-(H+t(H))/2
log_msg(v,"Hessiana em",round(proc.time()[[3]]-t0),"s")
ev<-eigen(H,symmetric=TRUE,only.values=TRUE)$values
stopifnot(all(is.finite(H)))
# Passo de Newton com retrocesso; aceito só se o objetivo diminuir.
step<-solve(H,g0);p1<-p0;f1<-f0;acc<-0
for(a in c(1,.5,.25,.125)){pt<-p0-a*step;ft<-obj$fn(pt);if(is.finite(ft)&&ft<f1){p1<-pt;f1<-ft;acc<-a;break}}
f1<-obj$fn(p1);g1<-obj$gr(p1)
log_msg(v,"Newton: passo",acc,"objetivo",sprintf("%.4f -> %.4f",f0,f1),"gradiente máx",signif(max(abs(g0)),3),"->",signif(max(abs(g1)),3))
# O modelo salvo passa a ser o ponto polido (parâmetros e modos latentes em p1), e a Hessiana
# é recalculada nesse ponto: todo o fluxo a jusante usa o mesmo "modelo atual".
H0<-H
if(acc>0) {
  m$parameters<-obj$env$parList(x=p1,par=obj$env$last.par);m$fit$par<-p1
  m$fit$objective<-f1+fixed_constant(m$parameters$theta,vm$fixos);m$gradient<-g1;m$AIC<-2*m$fit$objective+2*m$k
  m$newton<-list(passo=acc,objetivo_antes=f0,objetivo_depois=f1,gradiente_max_antes=max(abs(g0)),gradiente_max_depois=max(abs(g1)))
  atomic_rds(m,path)
  t0<-proc.time()[[3]];H<-optimHess(p1,obj$fn,obj$gr);H<-(H+t(H))/2
  ev<-eigen(H,symmetric=TRUE,only.values=TRUE)$values;stopifnot(all(is.finite(H)))
  log_msg(v,"modelo polido salvo; Hessiana no ponto final em",round(proc.time()[[3]]-t0),"s")
}
V<-solve(H);se<-sqrt(pmax(diag(V),0))
nm<-names(p0);lab<-nm
lab[nm=="beta"]<-colnames(dd$X);lab[nm=="betadisp"]<-paste0("disp:",colnames(dd$Z))
lab[nm=="theta"]<-c("logDP_media_IES","logDP_media_curso","logDP_disp_IES","logDP_disp_curso")[seq_len(sum(nm=="theta"))]
tab<-data.table(parametro=nm,termo=lab,estimativa=p1,ep=se,z=p1/se,ic95_inf=p1-1.96*se,ic95_sup=p1+1.96*se)
tab[parametro=="beta",`:=`(razao_chances_subjacente=exp(estimativa),rc_ic95_inf=exp(ic95_inf),rc_ic95_sup=exp(ic95_sup))]
csv(tab,"coeficientes")
atomic_rds(list(H=H,H_antes=H0,V=V,par_antes=p0,par_newton=p1,objetivo=c(antes=f0,newton=f1),
  gradiente=list(antes=g0,newton=g1),autovalores=ev,termos=lab,modelo=hash(path)),file.path(OUT,"hessiana.rds"))
write_json(list(variante=v,populacao=pop,objetivo_antes=f0,objetivo_newton=f1,passo_newton=acc,
  gradiente_max_antes=max(abs(g0)),gradiente_max_newton=max(abs(g1)),
  autovalor_min=min(ev),autovalor_max=max(ev),condicao=max(ev)/min(ev),hessiana_positiva=all(ev>0),
  metodo="optimHess sobre gradiente de Laplace (TMB); EP de Wald; sem sdreport dos latentes",
  nota="Exploratório: EP condicionais à especificação e à aproximação de Laplace; associação, não causalidade",
  codigo=hash("scripts/modelo/variantes_hessiana.R"),modelo=hash(path)),file.path(OUT,"inferencia.json"))
log_msg(v,"inferência salva; Hessiana positiva definida:",all(ev>0))
