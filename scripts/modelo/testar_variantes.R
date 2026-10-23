# Conferências de bb_truncada_dispre.cpp em casos pequenos.
source("scripts/modelo/variantes.R")
trunc_compile();disp_compile()
set.seed(SEED)
n<-400;N<-sample(c(1:5,10,30,200),n,TRUE);y<-vapply(N,function(k)sample(0:(k-1),1),numeric(1))
dd<-list(X=cbind(1,rnorm(n)),Z=cbind(1,rnorm(n)),y=y,N=N,ies=sample(0:2,n,TRUE),curso=sample(0:5,n,TRUE),n_ies=3L)
b<-rnorm(9,0,.4);bd<-rnorm(9,0,.3);base<-list(beta=c(-.5,.4),betadisp=c(1,.3),theta=log(c(.4,.3)),b=b)
# 1. Com bd=0, a log-probabilidade condicional coincide com a do modelo vigente.
o0<-TMB::MakeADFun(c(dd,upper_truncated=1L),base,DLL=TRUNC_DLL,silent=TRUE)
o1<-TMB::MakeADFun(dd,c(base[1:2],list(theta=log(c(.4,.3,.2,.2)),b=b,bd=0*bd)),DLL=DISP_DLL,silent=TRUE)
e1<-max(abs(o0$report()$logprob-o1$report()$logprob))
# 2. Com bd≠0, coincide com trunc_density usando phi deslocado.
o2<-TMB::MakeADFun(dd,c(base[1:2],list(theta=log(c(.4,.3,.2,.2)),b=b,bd=bd)),DLL=DISP_DLL,silent=TRUE)
mu<-plogis(drop(dd$X%*%base$beta)+b[dd$ies+1]+b[3+dd$curso+1])
phi<-exp(drop(dd$Z%*%base$betadisp)+bd[dd$ies+1]+bd[3+dd$curso+1])
e2<-max(abs(o2$report()$logprob-trunc_density(y,N,mu,phi,log=TRUE)))
# 3. Gradiente contra diferenças finitas.
p<-o2$par;h<-1e-5
fd<-vapply(seq_along(p),function(j){pp<-pm<-p;pp[j]<-pp[j]+h;pm[j]<-pm[j]-h;(o2$fn(pp)-o2$fn(pm))/(2*h)},numeric(1))
e3<-max(abs(o2$gr(p)-fd))
# 4. Laplace contra glmmTMB, sem truncagem não disponível: compara a parte truncada fixando N grande
# (P(Y=N) desprezível) e efeito de dispersão só por IES.
small<-data.table(ies=factor(rep(1:6,each=40)),curso=factor(rep(1:24,each=10)),N=sample(200:400,240,TRUE))
pp<-plogis(-1+rnorm(6,0,.5)[as.integer(small$ies)]+rnorm(24,0,.3)[as.integer(small$curso)])
ph<-exp(2+rnorm(6,0,.6)[as.integer(small$ies)])
small[,y:=rbinom(.N,N,rbeta(.N,pp*ph,(1-pp)*ph))]
g<-tryCatch(glmmTMB(cbind(y,N-y)~1+(1|ies)+(1|curso),dispformula=~1+(1|ies),family=betabinomial(),data=small,se=FALSE),
  error=function(e)conditionMessage(e))
e4<-NA_real_
if(!is.character(g)) {
  ds<-list(X=matrix(1,240,1),Z=matrix(1,240,1),y=small$y,N=small$N,ies=as.integer(small$ies)-1L,
    curso=as.integer(small$curso)-1L,n_ies=6L)
  # Variância do efeito de curso na dispersão fixada em quase zero (mapa), equivalente ao glmmTMB.
  print(g$fit$par);th<-g$fit$par[grepl("theta",names(g$fit$par))]
  pars<-list(beta=unname(fixef(g)$cond),betadisp=unname(fixef(g)$disp),theta=c(unname(th),-12),
    b=rep(0,30),bd=rep(0,30))
  oo<-TMB::MakeADFun(ds,pars,random=c("b","bd"),DLL=DISP_DLL,silent=TRUE,map=list(theta=factor(c(1,2,3,NA))))
  e4<-abs(oo$fn(oo$par)+as.numeric(logLik(g)))
}
res<-list(erro_bd_zero=e1,erro_densidade=e2,erro_gradiente=e3,erro_laplace_glmmTMB=e4,
  glmmTMB=if(is.character(g))g else "ok")
print(res)
stopifnot(e1<1e-10,e2<1e-10,e3<1e-4)
write_json(res,file.path(CACHE,"testes","variantes.json"))
