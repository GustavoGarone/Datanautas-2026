# Triagem exploratória da família BCT (Box-Cox t, gamlss.dist) para a proporção anual Y/N.
# Não substitui o modelo TMB vigente: famílias contínuas descartam a natureza de contagem de Y.
# Simplificações declaradas: somente treino (reserva intocada), N>1, subamostra de IES com
# todos os seus cursos (mesma amostragem de triagem_familias.R), efeitos de IES penalizados.
# Variantes (--variante=):
#   cc     : correção de continuidade y=(Y+0,5)/(N+1) em todas as linhas. Equivale a somar meia
#            ocorrência a cada categoria (estimador de Haldane/Anscombe); fica em (0,1) mesmo com
#            Y=0 e Y=N-1, e reduz o encolhimento para cursos grandes (correção ~1/N). É arbitrária.
#   hurdle : duas partes. BI binária para P(Y>0) em todas as linhas e BCT para Y/N só em Y>0.
#   logit  : comparação. Logit empírico z=log((Y+0,5)/(N-Y+0,5)) com famílias na reta real.
# Pesos: não usamos weights=N. Em gamlss os pesos multiplicam a log-verossimilhança (frequência),
# então N repetiria cada linha N vezes e inflaria verossimilhança, AIC e precisão. A dependência
# da variância em N entra por sigma ~ ... + modalidade*log(vinculos) (formula_dispersao()).
# BCT usa ligação log em mu (a padrão é identidade e permite mu<=0 com efeitos aditivos).
# BCT tem suporte (0,Inf): a massa acima de 1 é registrada como falha de suporte.
# AIC só é comparável entre famílias com a mesma resposta e os mesmos dados (dentro da variante).
source("scripts/modelo/common.R")
suppressPackageStartupMessages(library(gamlss))
args<-commandArgs(trailingOnly=TRUE)
opt<-function(name,default){v<-sub(paste0("^--",name,"="),"",grep(paste0("^--",name,"="),args,value=TRUE))
  if(length(v))v else default}
fraction<-as.numeric(opt("fracao","0.02"));cycles<-as.integer(opt("ciclos","100"))
variant<-opt("variante","cc");stopifnot(variant%in%c("cc","hurdle","logit"))
stopifnot(is.finite(fraction),fraction>0,fraction<=1,cycles>0)
OUT<-output_dir(paste0("triagem/bct_",variant,"_",fraction,if(opt("metodo","RS")!="RS")paste0("_",opt("metodo","RS"))))
d<-dados_modelo()[validacao==FALSE&vinculos>1]
set.seed(SEED)
ies<-sample(levels(droplevels(d$co_ies)),ceiling(fraction*uniqueN(d$co_ies)))
d<-droplevels(d[co_ies%in%ies])
X<-matriz_media(d)[,-1,drop=FALSE];map<-data.table(coluna=sprintf("x%02d",seq_len(ncol(X))),termo=colnames(X))
colnames(X)<-map$coluna
porte<-cut(d$vinculos,c(1,29,99,999,Inf),labels=c("2-29","30-99","100-999","1000+"))
df<-data.frame(Y=d$eventos_resposta,resto=d$demais_vinculos,N=d$vinculos,vinculos=d$vinculos,ano=d$ano,
  modalidade=d$modalidade,porte=porte,co_ies=d$co_ies,co_curso=d$co_curso,X)
df$y_cc<-(df$Y+.5)/(df$N+1);df$z<-log((df$Y+.5)/(df$N-df$Y+.5));df$pos<-as.integer(df$Y>0);df$p<-df$Y/df$N
rhs<-paste(c(map$coluna,"random(co_ies)"),collapse=" + ")
f_of<-function(lhs)as.formula(paste(lhs,"~",rhs))
log_msg("Triagem BCT",variant,":",nrow(df),"linhas,",nlevels(df$co_ies),"IES,",sum(df$Y==0),"zeros")
# metodo=mixed: RS nos primeiros ciclos e CG depois (alternativa quando RS oscila com random()).
method<-opt("metodo","RS");stopifnot(method%in%c("RS","mixed"))
control<-gamlss.control(n.cyc=cycles,trace=FALSE)
# gamlss lê method por substitute(); por isso as chamadas literais.
G<-function(...)if(method=="RS")gamlss(...,method=RS())else gamlss(...,method=mixed(20,cycles))
BCTlog<-BCT(mu.link="log")
# Especificações: dados (all/pos), resposta, família e fórmulas de nu/tau.
spec<-function(dados,lhs,fam,nt="const")list(dados=dados,lhs=lhs,fam=fam,nt=nt)
specs<-c(list(BB=spec("all","cbind(Y,resto)","BB")),switch(variant,
  cc=list(BCT=spec("all","y_cc","BCT"),BCT_nt_mod=spec("all","y_cc","BCT","modalidade"),
    BE=spec("all","y_cc","BE"),LOGITNO=spec("all","y_cc","LOGITNO")),
  hurdle=list(zero_BI=spec("all","pos","BI"),BCT=spec("pos","p","BCT"),
    BCT_nt_mod=spec("pos","p","BCT","modalidade"),BE=spec("pos","p","BE")),
  logit=list(JSU=spec("all","z","JSU"),JSU_nt_mod=spec("all","z","JSU","modalidade"),
    SST=spec("all","z","SST"),NO=spec("all","z","NO"))))
data_of<-function(s)if(s$dados=="pos")df[df$Y>0,]else df
fit_spec<-function(name) {
  s<-specs[[name]];dd<-data_of(s);t0<-proc.time()[[3]]
  fam<-if(s$fam=="BCT")BCTlog else s$fam
  ntf<-if(s$nt=="const")~1 else ~modalidade
  m<-tryCatch(withCallingHandlers({
    if(s$fam=="BI")G(f_of(s$lhs),family=BI,data=dd,control=control)
    else if(s$fam%in%c("BCT","JSU","SST"))G(f_of(s$lhs),sigma.formula=formula_dispersao(),
      nu.formula=ntf,tau.formula=ntf,family=fam,data=dd,control=control)
    else G(f_of(s$lhs),sigma.formula=formula_dispersao(),family=fam,data=dd,control=control)},
    warning=function(w)invokeRestart("muffleWarning")),error=function(e)conditionMessage(e))
  sec<-proc.time()[[3]]-t0;log_msg("Ajuste",name,"terminado em",round(sec),"s",if(is.character(m))paste("ERRO:",m)else paste("convergiu =",isTRUE(m$converged)))
  if(is.character(m))return(list(modelo=NULL,linha=data.table(modelo=name,familia=s$fam,resposta=s$lhs,
    dados=s$dados,n=nrow(dd),convergiu=FALSE,segundos=sec,GD=NA_real_,AIC=NA_real_,gl=NA_real_,erro=m)))
  list(modelo=m,linha=data.table(modelo=name,familia=s$fam,resposta=s$lhs,dados=s$dados,n=nrow(dd),
    convergiu=isTRUE(m$converged),segundos=sec,GD=deviance(m),AIC=GAIC(m,k=2),gl=m$df.fit,erro=NA_character_))
}
start<-proc.time()[[3]]
# Sequencial: mclapply (fork) travou em deadlock na fração 0,1 (filhos em futex com 0% CPU).
results<-setNames(lapply(names(specs),fit_spec),names(specs))
log_msg("Ajustes:",round(proc.time()[[3]]-start),"s")
tab<-rbindlist(lapply(results,`[[`,"linha"))
tab[,dAIC_mesma_resposta:=AIC-min(AIC,na.rm=TRUE),by=.(resposta,dados)]
print(tab)
fits<-Filter(Negate(is.null),lapply(results,`[[`,"modelo"))
par_of<-function(m,par)if(par%in%m$parameters)fitted(m,par)else NULL
# nu e tau por modalidade (constantes ou ~modalidade). tau grande ~ normal; nu=1 sem assimetria na escala Box-Cox.
extras<-rbindlist(lapply(names(fits),function(k){m<-fits[[k]];if(!all(c("nu","tau")%in%m$parameters))return(NULL)
  dd<-data_of(specs[[k]]);data.table(modelo=k,modalidade=dd$modalidade,nu=fitted(m,"nu"),tau=fitted(m,"tau"))[
    ,.(nu=nu[1],tau=tau[1]),by=.(modelo,modalidade)]}))
print(extras)
# Calibração: E[Y] por grade de quantis da previsão (inclui efeitos de IES penalizados), convertida
# para contagem e somada antes de dividir. "suporte" limita cada quantil ao suporte factível de Y.
K<-500;grid<-(seq_len(K)-.5)/K
qgrid<-function(m,dd,fn) {
  pars<-lapply(setNames(m$parameters,m$parameters),function(p)fitted(m,p))
  q<-vapply(grid,function(u)do.call(paste0("q",m$family[1]),c(list(p=u),pars)),numeric(nrow(dd)))
  list(direto=rowMeans(fn(q,dd$N)),suporte=rowMeans(pmin(pmax(fn(q,dd$N),0),dd$N-1)))
}
cdf<-function(m,x)do.call(paste0("p",m$family[1]),c(list(q=x),lapply(setNames(m$parameters,m$parameters),function(p)fitted(m,p))))
back_cc<-function(q,N)q*(N+1)-.5
pred<-list();zeros<-list()
mB<-fits$BB
if(!is.null(mB)){mu<-fitted(mB,"mu");pred$BB<-list(direto=df$N*mu,suporte=df$N*mu)
  zeros$BB<-dBB(0,mu,fitted(mB,"sigma"),bd=df$N)}
if(variant=="cc")for(k in intersect(c("BCT","BCT_nt_mod","BE","LOGITNO"),names(fits))){
  pred[[k]]<-qgrid(fits[[k]],df,back_cc);zeros[[k]]<-cdf(fits[[k]],1/(df$N+1))
  attr(zeros[[k]],"fora")<-1-cdf(fits[[k]],df$N/(df$N+1))}
if(variant=="logit")for(k in intersect(c("JSU","JSU_nt_mod","SST","NO"),names(fits))){
  pred[[k]]<-qgrid(fits[[k]],df,function(q,N)plogis(q)*(N+1)-.5);zeros[[k]]<-cdf(fits[[k]],log(1/df$N))
  attr(zeros[[k]],"fora")<-1-cdf(fits[[k]],log(df$N))}
if(variant=="hurdle"&&!is.null(fits$zero_BI)){
  p0<-1-fitted(fits$zero_BI,"mu")
  for(k in intersect(c("BCT","BCT_nt_mod","BE"),names(fits))){
    # A parte positiva prevê Y/N condicional a Y>0; extrapola-se às linhas Y=0 com os mesmos coeficientes
    # e o efeito da IES estimado na parte positiva (zero para IES sem nenhum Y>0). Preditor montado à mão
    # (predict.gamlss com newdata e random() reavalia a chamada original).
    m<-fits[[k]];pars<-lapply(setNames(m$parameters,m$parameters),function(p){
      if(p=="mu"){b<-coef(m,"mu");b[is.na(b)]<-0;re<-tapply(m$mu.s[,1],droplevels(df$co_ies[df$Y>0]),mean)[as.character(df$co_ies)];re[is.na(re)]<-0
        eta<-drop(cbind(1,as.matrix(df[,map$coluna]))%*%b[c("(Intercept)",map$coluna)])+re}
      else eta<-drop(model.matrix(formula(m,p),df)%*%coef(m,p))
      make.link(m[[paste0(p,".link")]])$linkinv(eta)})
    # Sem convergência do RS, coeficientes e mu ajustado ficam ligeiramente dessincronizados: registrar.
    desv<-max(abs(as.numeric(pars$mu[df$Y>0])/as.numeric(fitted(m,"mu"))-1))
    log_msg(k,"discrepância relativa máxima de mu (manual vs ajustado):",signif(desv,3));stopifnot(desv<.05)
    q<-vapply(grid,function(u)do.call(paste0("q",m$family[1]),c(list(p=u),pars)),numeric(nrow(df)))
    cond<-list(direto=rowMeans(q*df$N),suporte=rowMeans(pmin(pmax(q*df$N,1),df$N-1)))
    pred[[k]]<-lapply(cond,function(v)(1-p0)*v);zeros[[k]]<-p0
    attr(zeros[[k]],"fora")<-(1-p0)*(1-do.call(paste0("p",m$family[1]),c(list(q=1),pars)))}
}
calib<-rbindlist(lapply(names(pred),function(k)rbindlist(lapply(c("modalidade","porte"),function(g)
  data.table(modelo=k,grupo=g,nivel=df[[g]],N=df$N,Y=df$Y,ed=pred[[k]]$direto,es=pred[[k]]$suporte,
    z0=df$Y==0,pz=zeros[[k]],fora=if(is.null(attr(zeros[[k]],"fora")))0 else attr(zeros[[k]],"fora"))[
    ,.(linhas=.N,taxa_obs=sum(Y)/sum(N),taxa_prev_direta=sum(ed)/sum(N),taxa_prev_suporte=sum(es)/sum(N),
      zeros_obs=mean(z0),zeros_prev=mean(pz),massa_fora_suporte=mean(fora)),by=.(modelo,grupo,nivel)]))))
setorder(calib,grupo,nivel,modelo);print(calib,digits=4)
csv(tab,"ajustes");csv(extras,"nu_tau");csv(calib,"calibracao");csv(map,"colunas_media")
# Resíduos quantílicos (aleatorizados nas famílias discretas). Para o hurdle, também o PIT combinado:
# Y=0 -> U(0,p0); Y>0 -> p0+(1-p0)F(Y/N). Escalas diferentes: BB em contagens, demais na resposta transformada.
set.seed(SEED)
res<-lapply(fits,function(m)resid(m));grp<-lapply(names(fits),function(k)data_of(specs[[k]]));names(grp)<-names(fits)
if(variant=="hurdle"&&!is.null(fits$zero_BI))for(k in intersect(c("BCT","BCT_nt_mod"),names(fits))){
  m<-fits[[k]];u<-runif(nrow(df))*p0;ip<-df$Y>0
  u[ip]<-p0[ip]+(1-p0[ip])*cdf(m,df$p[ip]);nm<-paste0("hurdle_",k);res[[nm]]<-qnorm(u);grp[[nm]]<-df}
worm<-function(by,levels,file){
  rows<-names(res);grDevices::png(file.path(OUT,"graficos",file),width=4.2*length(levels),height=3.6*length(rows),units="in",res=110)
  graphics::par(mfrow=c(length(rows),length(levels)),mar=c(4,4.5,2.6,1),oma=c(2.5,0,2.5,0))
  for(k in rows)for(l in levels){r<-res[[k]][grp[[k]][[by]]==l];r<-r[is.finite(r)]
    if(length(r)<10){graphics::plot.new();graphics::title(sprintf("%s | %s: n=%d",k,l,length(r)),cex.main=.8);next}
    withCallingHandlers(invisible(wp(resid=r,ylim.all=1,xlim.all=3,line=TRUE,col=NA,cex=.3)),
      warning=function(w)if(grepl("Some points are missed out",conditionMessage(w),fixed=TRUE))invokeRestart("muffleWarning"))
    graphics::title(main=sprintf("%s | %s (n=%d)",k,l,length(r)),cex.main=.85)}
  graphics::mtext(sprintf("Triagem BCT (%s): treino, N>1, fração de IES %s; mu ~ fixos + random(co_ies)",variant,fraction),outer=TRUE,side=3,line=.8,font=2)
  graphics::mtext("Bandas de 95% de gamlss::wp (referência normal iid). BB em contagens; demais na resposta transformada: escalas não comparáveis",
    outer=TRUE,side=1,line=1,cex=.75)
  grDevices::dev.off()}
worm("modalidade",levels(df$modalidade),"worm_modalidade.png")
worm("porte",levels(df$porte),"worm_porte.png")
write_json(list(finalidade="triagem exploratória da BCT; não substitui o modelo TMB nem seleciona família",
  variante=variant,dados="treino (reserva intocada), N>1",fracao_IES=fraction,semente=SEED,n=nrow(df),
  IES=nlevels(df$co_ies),cursos=nlevels(df$co_curso),zeros=sum(df$Y==0),
  efeitos="random(co_ies) em mu (verossimilhança penalizada, não Laplace)",
  dispersao=paste(deparse(formula_dispersao()),collapse=" "),ligacao_mu_BCT="log",pesos="nenhum",
  metodo=method,ajustes=tab,nu_tau=extras,calibracao=calib,ciclos=cycles,grade_quantis=K,
  gamlss=as.character(packageVersion("gamlss")),gamlss.dist=as.character(packageVersion("gamlss.dist")),
  base=hash(BASE_PATH),codigo=hash("scripts/modelo/triagem_bct.R")),file.path(OUT,"triagem.json"))
log_msg("Triagem salva em",OUT)
