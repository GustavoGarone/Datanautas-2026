suppressPackageStartupMessages({library(data.table);library(glmmTMB);library(ggplot2)})
options(stringsAsFactors=FALSE,contrasts=c("contr.treatment","contr.poly"))
data.table::setDTthreads(2)
MODEL_OUT<-Sys.getenv("DATANAUTAS_OUTPUT","outputs/modelo")
BASE_PATH<-"data/processed/modelo.rds"
CACHE<-".cache/modelo"
SEED<-20261021L
TRUNC_DLL<-"bb_truncada_openmp"
TRUNC_THREADS<-2L
PROFILES<-c("feminino","ppi","25_anos_ou_mais","escola_publica","deficiencia","reserva_vagas","noturno")
PROP<-paste0("p_",PROFILES)
SCALE<-setNames(c(.1,.1,.1,.1,.01,.1,.1),PROP)
CONTROLS<-c("ano","modalidade","categoria_administrativa","organizacao_academica","grau_academico","cine_area_geral")
CTX<-c(paste0("ies_m_",PROP),"ies_m_logN","ies_frac_ead","ies_log_n_cursos")
REFERENCES<-c(ano="2020",modalidade="Presencial",categoria_administrativa="Privada com fins lucrativos",
  organizacao_academica="Universidade",grau_academico="Bacharelado",cine_area_geral="04")
log_msg<-function(...)cat(format(Sys.time(),"%Y-%m-%d %H:%M:%S"),...,"\n")
hash<-function(p)unname(tools::md5sum(p))
output_dir<-function(stage) {
  path<-file.path(MODEL_OUT,stage)
  for(folder in c("tabelas","graficos"))dir.create(file.path(path,folder),recursive=TRUE,showWarnings=FALSE)
  path
}
model_path<-function(stage)file.path(MODEL_OUT,"modelos",paste0(stage,".rds"))
atomic_rds<-function(x,path) {
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  tmp<-paste0(path,".tmp");saveRDS(x,tmp,compress="gzip");stopifnot(file.rename(tmp,path))
}
write_json<-function(x,path) {
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  jsonlite::write_json(x,path,pretty=TRUE,auto_unbox=TRUE,digits=16)
}
csv<-function(x,name)fwrite(as.data.table(x),file.path(OUT,"tabelas",paste0(name,".csv")))
save_plot<-function(p,name,w=9,h=6)ggsave(file.path(OUT,"graficos",paste0(name,".png")),p,width=w,height=h,dpi=150)
model_contrasts<-function(d) {
  lev<-levels(d$grau_academico)
  stopifnot(lev[1]=="Bacharelado","Não aplicável (ABI)"%in%lev)
  ct<-contr.treatment(lev,base=1)
  list(grau_academico=ct[,colnames(ct)!="Não aplicável (ABI)",drop=FALSE])
}
matriz_media<-function(d)model.matrix(reformulate(c(CONTROLS,PROP,"ano:modalidade",
  "log(vinculos)","modalidade:log(vinculos)",CTX)),d,contrasts.arg=model_contrasts(d))
formula_media<-function()as.formula(paste("cbind(eventos_resposta,demais_vinculos) ~",
  paste(c(CONTROLS,PROP,"ano:modalidade","log(vinculos)","modalidade:log(vinculos)",CTX,
    "(1|co_ies)","(1|co_curso)"),collapse=" + ")))
formula_dispersao<-function()~ano*modalidade+modalidade*log(vinculos)
dados_modelo<-function() {
  d<-readRDS(BASE_PATH)
  stopifnot(nrow(d)==211651L,all(d$eventos_resposta==d$desvinculados+d$trancados),
    all(d$demais_vinculos==d$vinculos-d$eventos_resposta),all(d$matriculas>0))
  d
}
assinatura<-function(treino=FALSE)list(schema=1L,base=hash(BASE_PATH),treino=treino,
  formula=paste(deparse(formula_media()),collapse=" "),dispersao=paste(deparse(formula_dispersao()),collapse=" "),
  familia="beta-binomial truncada superiormente em Y<N, condicional aos efeitos",
  cpp=hash("scripts/modelo/bb_truncada.cpp"),TMB=as.character(packageVersion("TMB")),
  framework="TMBad",threads=TRUNC_THREADS,se=FALSE)
ler_modelo<-function(stage) {
  m<-readRDS(model_path(stage))
  stopifnot(m$schema==1L,identical(m$signature,assinatura(stage=="treino")),
    m$fit$convergence==0L,is.finite(m$fit$objective),all(is.finite(unlist(m$parameters))))
  m
}
trunc_data<-function(d) {
  X<-matriz_media(d);Z<-model.matrix(formula_dispersao(),d)
  stopifnot(all(d$eventos_resposta<d$vinculos),ncol(X)==50L,ncol(Z)==12L,
    qr(X)$rank==ncol(X),qr(Z)$rank==ncol(Z))
  list(X=X,Z=Z,y=d$eventos_resposta,N=d$vinculos,ies=as.integer(d$co_ies)-1L,
    curso=as.integer(d$co_curso)-1L,n_ies=nlevels(d$co_ies),upper_truncated=1L)
}
trunc_compile<-function(threads=TRUNC_THREADS) {
  dir.create(CACHE,recursive=TRUE,showWarnings=FALSE)
  cpp<-"scripts/modelo/bb_truncada.cpp";dst<-file.path(CACHE,"bb_truncada_openmp.cpp")
  so<-TMB::dynlib(sub("\\.cpp$","",dst));stamp<-file.path(CACHE,"compilacao.rds")
  sig<-list(cpp=hash(cpp),TMB=as.character(packageVersion("TMB")),R=R.version.string,
    framework="TMBad",openmp=TRUE,flags="-O2 -g0")
  if(!file.exists(so)||!file.exists(stamp)||!identical(readRDS(stamp),sig)) {
    stopifnot(file.copy(cpp,dst,overwrite=TRUE),
      TMB::compile(dst,flags=sig$flags,framework=sig$framework,openmp=TRUE,safebounds=TRUE)==0)
    atomic_rds(sig,stamp);unlink(sub("\\.cpp$",".o",dst))
  }
  if(!TRUNC_DLL%in%names(getLoadedDLLs()))dyn.load(so)
  TMB::openmp(threads,autopar=TRUE,DLL=TRUNC_DLL)
  stopifnot(TMB::openmp(DLL=TRUNC_DLL)==threads)
  invisible(so)
}
trunc_density<-function(y,N,mu,phi,truncated=TRUE,log=FALSE) {
  a<-mu*phi;bb<-(1-mu)*phi
  lp<-lchoose(N,y)+lbeta(y+a,N-y+bb)-lbeta(a,bb)
  if(truncated) {
    lu<-lbeta(N+a,bb)-lbeta(a,bb);lp<-lp-log(-expm1(lu));lp[y>=N]<--Inf
    lp[N==1&y==0]<-0
  }
  if(log)lp else exp(lp)
}
trunc_moments<-function(mu,phi,N) {
  a<-mu*phi;bb<-(1-mu)*phi
  lu<-lbeta(N+a,bb)-lbeta(a,bb);pn<-exp(lu);den<--expm1(lu)
  first<-(mu-pn)/den
  second<-(mu^2+mu*(1-mu)*(phi+N)/(N*(phi+1))-pn)/den
  first[N==1]<-second[N==1]<-0
  stopifnot(all(is.finite(first)),all(is.finite(second)),all(first>=-1e-10),all(first<=1))
  list(mean=first,second=second,upper=pn)
}
trunc_draw<-function(mu,phi,N) {
  stopifnot(length(mu)==length(N),length(phi)==length(N),all(is.finite(mu)),
    all(is.finite(phi)),all(mu>0&mu<1),all(phi>0),all(N>=1))
  y<-numeric(length(N));left<-which(N>1);attempts<-0L
  while(length(left)) {
    attempts<-attempts+1L
    if(attempts>10000L)stop("Rejeições excessivas: auditar parâmetros de fronteira.")
    q<-rbeta(length(left),mu[left]*phi[left],(1-mu[left])*phi[left])
    y[left]<-rbinom(length(left),N[left],q);left<-left[y[left]==N[left]]
  }
  y
}
