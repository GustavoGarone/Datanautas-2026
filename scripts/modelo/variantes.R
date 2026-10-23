# Variantes exploratórias da BB truncada, autorizadas pelo usuário em 22/10/2026.
# Não substituem os modelos em outputs/modelo/modelos; saídas em outputs/modelo/variantes/.
#   base:          especificação vigente reajustada na população da variante (referência).
#   dispre:        efeitos aleatórios de IES e curso também na log-dispersão.
#   dispre_ies:    dispre com efeito aleatório de dispersão somente por IES.
#   dispre_fase:   dispre + indicadores de curso sem ingressantes e de último ano de oferta
#                  (colunas constantes na população são descartadas).
#   dispre_fase_n: dispre_fase + spline natural de log(N) por modalidade na média e na dispersão.
# População "filtrada" (pedido do usuário em 22/10, contrário à decisão anterior de não excluir):
# cursos presentes nos cinco anos e curso-anos com 30 vínculos ou mais. Isso muda a população:
# exclui cursos que fecharam ou abriram no período e seleciona linhas pelo próprio denominador.
source("scripts/modelo/common.R")

VARIANTS<-c("base","dispre","dispre_ies","dispre_fase","dispre_fase_n")
POPULATIONS<-list(completa="nenhum",filtrada="presente_5_anos == 1 & poucos_alunos == 0 (por curso-ano)")
populacao<-function(pop) {
  d<-dados_modelo()
  if(pop=="filtrada")d<-d[presente_5_anos==1L&poucos_alunos==0L]
  d
}

# Efeitos de dispersão desligados são fixados em zero por mapa (base: todos; dispre_ies: cursos).
variant_map<-function(v,n_ies,n_curso)switch(v,
  base=list(map=list(bd=factor(rep(NA,n_ies+n_curso)),theta=factor(c(1,2,NA,NA))),random="b",fixos=c(n_ies,n_curso)),
  dispre_ies=list(map=list(bd=factor(c(seq_len(n_ies),rep(NA,n_curso))),theta=factor(c(1,2,3,NA))),
    random=c("b","bd"),fixos=c(0,n_curso)),
  list(map=list(),random=c("b","bd"),fixos=c(0,0)))
# bd fixo em zero ainda soma sua densidade normal ao objetivo do .cpp: constante a remover.
fixed_constant<-function(theta,fixos)
  fixos[1]*dnorm(0,0,exp(theta[3]),log=TRUE)+fixos[2]*dnorm(0,0,exp(theta[4]),log=TRUE)

# F(y-1) somando o lado com menos termos do suporte truncado {0..N-1}, em blocos.
pit_exact<-function(y,N,mu,phi,u){p<-cdf_parts(y,N,mu,phi);pmin(1,pmax(0,p$below+u*p$py))}
# P(Y<y) e P(Y=y); usados também nas misturas sobre sorteios dos latentes.
cdf_parts<-function(y,N,mu,phi) {
  n<-length(y);py<-trunc_density(y,N,mu,phi);low<-y<=N-1-y
  cnt<-ifelse(low,y,N-1-y);from<-ifelse(low,0,y+1);s<-numeric(n)
  blocks<-split(seq_len(n),cumsum(cnt)%/%4e6)
  for(r in blocks) {
    r<-r[cnt[r]>0];if(!length(r))next
    idx<-rep(r,cnt[r]);k<-sequence(cnt[r],from=from[r])
    s[r]<-as.vector(rowsum(trunc_density(k,N[idx],mu[idx],phi[idx]),idx,reorder=TRUE))
  }
  list(below=pmax(0,ifelse(low,s,1-s-py)),py=py)
}
DISP_DLL<-"bb_truncada_dispre"
variant_path<-function(v,s,pop)file.path(MODEL_OUT,"variantes",pop,v,"modelos",paste0(s,".rds"))
disp_compile<-function(threads=TRUNC_THREADS) {
  dir.create(CACHE,recursive=TRUE,showWarnings=FALSE)
  cpp<-"scripts/modelo/bb_truncada_dispre.cpp";dst<-file.path(CACHE,paste0(DISP_DLL,".cpp"))
  so<-TMB::dynlib(sub("\\.cpp$","",dst));stamp<-file.path(CACHE,"compilacao_dispre.rds")
  sig<-list(cpp=hash(cpp),TMB=as.character(packageVersion("TMB")),R=R.version.string,
    framework="TMBad",openmp=TRUE,flags="-O2 -g0")
  if(!file.exists(so)||!file.exists(stamp)||!identical(readRDS(stamp),sig)) {
    stopifnot(file.copy(cpp,dst,overwrite=TRUE),
      TMB::compile(dst,flags=sig$flags,framework=sig$framework,openmp=TRUE,safebounds=TRUE)==0)
    atomic_rds(sig,stamp);unlink(sub("\\.cpp$",".o",dst))
  }
  if(!DISP_DLL%in%names(getLoadedDLLs()))dyn.load(so)
  TMB::openmp(threads,autopar=TRUE,DLL=DISP_DLL)
  invisible(so)
}
# Colunas extras vêm do Parquet original pela chave curso-ano (sem alterar a base preparada).
fase_data<-function(d) {
  raw<-as.data.table(nanoparquet::read_parquet("data/raw/cursos_ano.parquet"))[,
    .(co_curso=as.character(co_curso),ano=as.character(ano),ingressantes=as.numeric(ingressantes),ultimo_ano)]
  k<-d[,.(co_curso=as.character(co_curso),ano=as.character(ano))]
  m<-raw[k,on=.(co_curso,ano)]
  stopifnot(nrow(m)==nrow(d),!anyNA(m$ingressantes),!anyNA(m$ultimo_ano))
  data.table(sem_ingressantes=as.numeric(m$ingressantes==0),
    ultimo_ano_oferta=as.numeric(as.integer(m$ano)==m$ultimo_ano&m$ultimo_ano<2024))
}
# Matrizes construídas na base completa; o treino usa o subconjunto de linhas.
design<-function(v,d) {
  X<-matriz_media(d);Z<-model.matrix(formula_dispersao(),d)
  if(v%in%c("dispre_fase","dispre_fase_n")) {
    F<-as.matrix(fase_data(d));X<-cbind(X,F[,apply(F,2,function(x)length(unique(x))>1),drop=FALSE])
  }
  if(v=="dispre_fase_n") {
    lN<-log(d$vinculos);kn<-quantile(lN,c(.25,.5,.75));bk<-range(lN)
    S<-splines::ns(lN,knots=kn,Boundary.knots=bk)
    # A base spline substitui o termo linear em log(N) e sua interação com modalidade.
    ead<-as.numeric(d$modalidade=="EAD");colnames(S)<-paste0("ns_logN",1:4)
    SE<-S*ead;colnames(SE)<-paste0("EAD:ns_logN",1:4)
    X<-cbind(X[,!colnames(X)%in%c("log(vinculos)","modalidadeEAD:log(vinculos)")],S,SE)
    Z<-cbind(Z[,!colnames(Z)%in%c("log(vinculos)","modalidadeEAD:log(vinculos)")],S,SE)
  }
  # Níveis ausentes na população geram colunas nulas; descartá-las mantém o posto completo.
  X<-X[,colSums(X!=0)>0,drop=FALSE];Z<-Z[,colSums(Z!=0)>0,drop=FALSE]
  stopifnot(qr(X)$rank==ncol(X),qr(Z)$rank==ncol(Z))
  list(X=X,Z=Z)
}
if(sys.nframe()==0L) {
  args<-commandArgs(trailingOnly=TRUE)
  stopifnot(length(args)>=2L,args[1]%in%VARIANTS,args[2]%in%c("completo","treino"))
  variant<-args[1];stage<-args[2];force<-"--reajustar"%in%args
  pop<-sub("^--populacao=","",grep("^--populacao=",args,value=TRUE));if(!length(pop))pop<-"filtrada"
  stopifnot(pop%in%names(POPULATIONS))
  path<-variant_path(variant,stage,pop)
  if(file.exists(path)&&!force){log_msg(variant,stage,pop,"já ajustado; use --reajustar");quit(save="no",status=0)}
  d<-populacao(pop);des<-design(variant,d);rows<-if(stage=="treino")which(!d$validacao)else seq_len(nrow(d))
  dd<-list(X=des$X[rows,,drop=FALSE],Z=des$Z[rows,,drop=FALSE],y=d$eventos_resposta[rows],N=d$vinculos[rows],
    ies=as.integer(d$co_ies[rows])-1L,curso=as.integer(d$co_curso[rows])-1L,n_ies=nlevels(d$co_ies))
  stopifnot(all(dd$y<dd$N))
  # Cadeia de inícios: base <- modelo vigente; dispre <- base; demais <- variante anterior.
  prev<-switch(variant,base=ler_modelo(stage),dispre=readRDS(variant_path("base",stage,pop)),
    dispre_fase=readRDS(variant_path("dispre",stage,pop)),dispre_ies=readRDS(variant_path("dispre",stage,pop)),dispre_fase_n=readRDS(variant_path("dispre_fase",stage,pop)))
  pad<-function(old,names_old,names_new)unname(ifelse(names_new%in%names_old,old[match(names_new,names_old)],0))
  pars<-list(beta=pad(prev$parameters$beta,prev$colnames$X,colnames(dd$X)),
    betadisp=pad(prev$parameters$betadisp,prev$colnames$Z,colnames(dd$Z)),
    theta=if(length(prev$parameters$theta)==4L&&variant!="dispre")prev$parameters$theta else c(prev$parameters$theta[1:2],log(.1),log(.1)),
    b=prev$parameters$b,bd=if(is.null(prev$parameters$bd))rep(0,length(prev$parameters$b))else prev$parameters$bd)
  stopifnot(length(pars$b)==nlevels(d$co_ies)+nlevels(d$co_curso),
    identical(prev$levels$co_ies,levels(d$co_ies)),identical(prev$levels$co_curso,levels(d$co_curso)))
  rm(prev);gc()
  disp_compile()
  # base: mesma especificação vigente, com efeitos de dispersão desligados por mapa.
  vm<-variant_map(variant,nlevels(d$co_ies),nlevels(d$co_curso))
  if(length(vm$map))pars$bd[is.na(vm$map$bd)]<-0
  obj<-TMB::MakeADFun(dd,pars,random=vm$random,map=vm$map,DLL=DISP_DLL,silent=TRUE)
  scale<-rep(.05,length(obj$par))
  scale[names(obj$par)=="beta"]<-pmin(1,.05/pmax(sqrt(colMeans(dd$X^2)),.05))
  checkpoint<-file.path(CACHE,paste0("checkpoint_",variant,"_",stage,"_",pop,".rds"));par<-obj$par
  if(file.exists(checkpoint)){saved<-readRDS(checkpoint);if(length(saved$par)==length(par))par<-saved$par}
  start<-last<-proc.time()[[3]];best<-Inf;bestpar<-par;evals<-0L
  f<-function(p) {
    v<-obj$fn(p);evals<<-evals+1L
    if(is.finite(v)&&v<best){best<<-v;bestpar<<-p}
    if(proc.time()[[3]]-last>60) {
      log_msg(variant,stage,pop,"avaliações",evals,"objetivo",sprintf("%.6f",v))
      atomic_rds(list(par=bestpar,objetivo=best),checkpoint);last<<-proc.time()[[3]]
    }
    v
  }
  control<-list(iter.max=1500L,eval.max=2000L,rel.tol=1e-7)
  fit<-nlminb(par,f,obj$gr,scale=1/scale,control=control)
  gradient<-obj$gr(fit$par);value<-obj$fn(fit$par)
  parameters<-obj$env$parList(x=fit$par,par=obj$env$last.par)
  stopifnot(all(is.finite(unlist(parameters))),abs(value-fit$objective)<1e-3)
  k<-length(fit$par)
  fit$objective<-fit$objective+fixed_constant(parameters$theta,vm$fixos)
  m<-list(schema=1L,variante=variant,etapa=stage,populacao=pop,filtro=POPULATIONS[[pop]],
    parameters=parameters,fit=fit,gradient=gradient,n=length(rows),k=k,AIC=2*fit$objective+2*k,
    levels=list(co_ies=levels(d$co_ies),co_curso=levels(d$co_curso)),
    colnames=list(X=colnames(dd$X),Z=colnames(dd$Z)),segundos=proc.time()[[3]]-start,
    codigo=list(cpp=hash("scripts/modelo/bb_truncada_dispre.cpp"),R=hash("scripts/modelo/variantes.R")),
    base=hash(BASE_PATH),etapa_analise="exploratória; sem Hessiana populacional")
  atomic_rds(m,path);unlink(checkpoint)
  log_msg(variant,stage,pop,"n",length(rows),"convergência",fit$convergence,"objetivo",sprintf("%.4f",fit$objective),
    "AIC",sprintf("%.2f",m$AIC),"gradiente máx",signif(max(abs(gradient)),3),"segundos",round(m$segundos))
}
