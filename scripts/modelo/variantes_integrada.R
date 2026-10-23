# Reserva com latentes integrados: sorteia (b, bd) da normal conjunta de Laplace do ajuste
# de treino (parâmetros populacionais fixos, covariâncias preservadas, como em validar.R)
# e avalia a mistura preditiva por PIT exato, log-score e Pearson.
source("scripts/modelo/variantes.R")
args<-commandArgs(trailingOnly=TRUE)
pop<-sub("^--populacao=","",grep("^--populacao=",args,value=TRUE));if(!length(pop))pop<-"filtrada"
S<-as.integer(sub("^--sorteios=","",grep("^--sorteios=",args,value=TRUE)));if(!length(S))S<-200L
OUT<-output_dir(file.path("variantes",pop,"comparacao"))
d<-populacao(pop);tr<-which(!d$validacao);te<-which(d$validacao)
porte<-cut(d$vinculos[te],c(0,29,99,999,Inf),labels=c("1–29","30–99","100–999","1000+"))
available<-Filter(function(v)file.exists(variant_path(v,"treino",pop)),VARIANTS)
only<-sub("^--variantes=","",grep("^--variantes=",args,value=TRUE))
if(length(only))available<-intersect(available,strsplit(only,",")[[1]])
disp_compile()
evaluate<-function(v) {
  m<-readRDS(variant_path(v,"treino",pop));des<-design(v,d)
  stopifnot(identical(colnames(des$X),m$colnames$X),identical(colnames(des$Z),m$colnames$Z))
  dd<-list(X=des$X[tr,,drop=FALSE],Z=des$Z[tr,,drop=FALSE],y=d$eventos_resposta[tr],N=d$vinculos[tr],
    ies=as.integer(d$co_ies[tr])-1L,curso=as.integer(d$co_curso[tr])-1L,n_ies=nlevels(d$co_ies))
  vm<-variant_map(v,nlevels(d$co_ies),nlevels(d$co_curso));isbase<-v=="base"
  o<-TMB::MakeADFun(dd,m$parameters,random=vm$random,map=vm$map,DLL=DISP_DLL,silent=TRUE)
  value<-o$fn(o$par)+fixed_constant(m$parameters$theta,vm$fixos)
  stopifnot(abs(value-m$fit$objective)<1e-2)
  Q<-Matrix::forceSymmetric(o$env$spHess(o$env$last.par,random=TRUE))
  full<-o$env$last.par;mode<-unname(full[o$env$random]);kind<-names(full)[o$env$random]
  F<-Matrix::expand(Matrix::Cholesky(Q,LDL=FALSE,perm=TRUE));L<-F$L;P<-F$P
  TMB::FreeADFun(o);rm(o,dd,Q);gc()
  ni<-nlevels(d$co_ies);ii<-as.integer(d$co_ies[te]);ci<-as.integer(d$co_curso[te])
  eta0<-drop(des$X[te,,drop=FALSE]%*%m$parameters$beta);lphi0<-drop(des$Z[te,,drop=FALSE]%*%m$parameters$betadisp)
  y<-d$eventos_resposta[te];N<-d$vinculos[te];n<-length(te)
  below<-py<-m1<-m2<-numeric(n);set.seed(SEED+202L)
  for(s in seq_len(S)) {
    # x = modo + P' L'^{-1} z ~ N(modo, Q^{-1})
    x<-mode+as.vector(Matrix::crossprod(P,Matrix::solve(Matrix::t(L),rnorm(length(mode)))))
    # Só os bd livres são latentes; os fixados por mapa (base: todos; dispre_ies: cursos) ficam em zero.
    b<-x[kind=="b"];bd<-m$parameters$bd
    if(!isbase)bd[if(length(vm$map))!is.na(vm$map$bd)else TRUE]<-x[kind=="bd"]
    # Salvaguarda numérica para sorteios extremos (μ em 0/1 ou φ fora do ponto flutuante).
    mu<-pmin(1-1e-10,pmax(1e-10,plogis(eta0+b[ii]+b[ni+ci])))
    phi<-exp(pmin(30,pmax(-30,lphi0+bd[ii]+bd[ni+ci])))
    cp<-cdf_parts(y,N,mu,phi);mom<-trunc_moments(mu,phi,N)
    below<-below+cp$below/S;py<-py+cp$py/S;m1<-m1+mom$mean/S;m2<-m2+mom$second/S
    if(s%%50==0)log_msg(v,"sorteio",s,"de",S)
  }
  set.seed(SEED);u<-runif(n)
  data.table(variante=v,modalidade=d$modalidade[te],porte=porte,y=y,N=N,pred=m1*N,
    pearson=(y/N-m1)/sqrt(pmax(m2-m1^2,1e-300)),logp=log(py),pit=pmin(1,pmax(0,below+u*py)))
}
# Cache por variante, válido para o mesmo modelo de treino, código e número de sorteios.
cached<-function(v) {
  key<-unname(tools::md5sum(c(variant_path(v,"treino",pop),"scripts/modelo/variantes_integrada.R",
    "scripts/modelo/variantes.R")));f<-file.path(CACHE,paste0("integrada_",pop,"_",v,"_",S,".rds"))
  if(file.exists(f)){x<-readRDS(f);if(identical(x$key,key))return(x$res)}
  r<-evaluate(v);atomic_rds(list(key=key,res=r),f);r
}
res<-rbindlist(lapply(available,cached))
probs<-seq(.005,.995,length.out=100L)
worm<-function(u){z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)));q<-qnorm(probs)
  data.table(probabilidade=probs,teorico=q,desvio=unname(quantile(z,probs,type=8))-q)}
wd<-res[,worm(pit),by=.(variante,modalidade,porte)]
grp<-wd[,.(desvio_max=max(abs(desvio)),desvio_central=max(abs(desvio[abs(teorico)<=1.5])),
  desvio_caudas=max(abs(desvio[abs(teorico)>1.5]))),by=.(variante,modalidade,porte)]
summ<-res[,.(n=.N,pearson2=mean(pearson^2),logscore_medio=mean(logp),taxa_obs=sum(y)/sum(N),
  taxa_prev=sum(pred)/sum(N)),by=variante]
summ<-merge(summ,grp[,.(media_desvio_central=mean(desvio_central),media_desvio_caudas=mean(desvio_caudas)),by=variante],by="variante")
csv(summ,"reserva_integrada_resumo");csv(grp,"reserva_integrada_worm_grupos");csv(wd,"reserva_integrada_worm_pontos")
print(summ);print(grp[order(modalidade,porte,variante)])
panel<-function(u,points,title) {
  z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)))
  withCallingHandlers(invisible(gamlss::wp(resid=z,pch=NA_integer_,bg=NA,line=TRUE,col=NA,
    xlim.all=3,ylim.all=1,cex.lab=.8)),warning=function(w) {
      if(grepl("Some points are missed out",conditionMessage(w),fixed=TRUE))invokeRestart("muffleWarning")})
  graphics::abline(h=0,v=0,lty=2,col="grey55")
  graphics::points(points$teorico,points$desvio,pch=16,cex=.45,col="#247b8a")
  graphics::title(main=title,cex.main=.8)
}
groups<-unique(res[,.(modalidade,porte)])[order(modalidade,porte)]
grDevices::png(file.path(OUT,"graficos","worm_reserva_integrada.png"),width=3.2*nrow(groups),height=3*length(available),units="in",res=130)
graphics::par(mfrow=c(length(available),nrow(groups)),mar=c(4,4.2,3,.8),oma=c(3,0,3,0))
for(v in available)for(g in seq_len(nrow(groups))) {
  sel<-res[variante==v&modalidade==groups$modalidade[g]&porte==groups$porte[g]]
  panel(sel$pit,wd[variante==v&modalidade==groups$modalidade[g]&porte==groups$porte[g]],
    sprintf("%s\n%s | %s (n=%s)",v,groups$modalidade[g],groups$porte[g],nrow(sel)))
}
graphics::mtext(sprintf("Worm-plots da reserva com latentes integrados (%d sorteios de Laplace), população %s",S,pop),
  outer=TRUE,side=3,line=1,font=2)
graphics::mtext("Bandas de 95% de gamlss::wp (referência normal independente, sem calibração para painel/efeitos)",
  outer=TRUE,side=1,line=1,cex=.75)
grDevices::dev.off()
write_json(list(populacao=pop,sorteios=S,variantes=available,reserva=length(te),
  metodo="mistura preditiva sobre sorteios conjuntos dos latentes (b, bd) da aproximação de Laplace do treino",
  codigo=hash("scripts/modelo/variantes_integrada.R")),file.path(OUT,"reserva_integrada.json"))
log_msg("Reserva integrada salva em",OUT)
