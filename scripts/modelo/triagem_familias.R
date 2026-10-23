# Triagem exploratória de famílias equivalente a gamlss::chooseDist(type="binom"), sem substituir o modelo TMB.
# Simplificações declaradas: somente treino (reserva intocada), N>1, subamostra de IES
# com todos os seus cursos e famílias candidatas SEM truncagem em Y<N.
# O ranking por GAIC orienta a discussão; não escolhe automaticamente a família.
source("scripts/modelo/common.R")
suppressPackageStartupMessages(library(gamlss))
args<-commandArgs(trailingOnly=TRUE)
opt<-function(name,default){v<-sub(paste0("^--",name,"="),"",grep(paste0("^--",name,"="),args,value=TRUE))
  if(length(v))v else default}
fraction<-as.numeric(opt("fracao","0.2"));cycles<-as.integer(opt("ciclos","100"))
effects<-opt("efeitos","ies_curso");stopifnot(effects%in%c("ies_curso","ies"))
terms<-if(effects=="ies")"random(co_ies)"else c("random(co_ies)","random(co_curso)")
stopifnot(is.finite(fraction),fraction>0,fraction<=1,cycles>0)
OUT<-output_dir(paste0("triagem/",effects,"_",fraction))
d<-dados_modelo()[validacao==FALSE&vinculos>1]
set.seed(SEED)
ies<-sample(levels(droplevels(d$co_ies)),ceiling(fraction*uniqueN(d$co_ies)))
d<-droplevels(d[co_ies%in%ies])
# Mesma matriz de média do TMB, sem o intercepto e com nomes sintáticos.
X<-matriz_media(d)[,-1,drop=FALSE];map<-data.table(coluna=sprintf("x%02d",seq_len(ncol(X))),termo=colnames(X))
colnames(X)<-map$coluna
df<-data.frame(y=d$eventos_resposta,resto=d$demais_vinculos,vinculos=d$vinculos,ano=d$ano,
  modalidade=d$modalidade,co_ies=d$co_ies,co_curso=d$co_curso,X)
fm<-as.formula(paste("cbind(y,resto) ~",paste(c(map$coluna,terms),collapse=" + ")))
log_msg("Triagem:",nrow(df),"linhas,",nlevels(df$co_ies),"IES,",nlevels(df$co_curso),"cursos")
control<-gamlss.control(n.cyc=cycles,trace=FALSE)
start<-proc.time()[[3]]
base<-gamlss(fm,sigma.formula=formula_dispersao(),family=BB,data=df,control=control)
segundos_bb<-proc.time()[[3]]-start
log_msg("BB de referência:",round(segundos_bb),"s; convergiu =",base$converged)
# Mesma lógica de chooseDist(type="binom"), com erro e convergência registrados:
# no gamlss 5.4-22, chooseDist devolveu NA para todas as famílias, inclusive BB,
# e descarta as mensagens de erro dos reajustes.
families<-c("BI","BB","DBI","ZIBI","ZABI","ZIBB","ZABB")
stopifnot(identical(families,get(".binom",asNamespace("gamlss"))))
fit_family<-function(f) {
  t0<-proc.time()[[3]]
  m<-tryCatch(if(f=="BB")base else gamlss(fm,sigma.formula=formula_dispersao(),family=f,data=df,control=control),
    error=function(e)conditionMessage(e))
  if(is.character(m))return(list(modelo=NULL,linha=data.table(familia=f,AIC=NA_real_,BIC=NA_real_,
    gl=NA_real_,convergiu=FALSE,segundos=proc.time()[[3]]-t0,erro=m)))
  list(modelo=m,linha=data.table(familia=f,AIC=GAIC(m,k=2),BIC=GAIC(m,k=log(nrow(df))),gl=m$df.fit,
    convergiu=isTRUE(m$converged),segundos=if(f=="BB")segundos_bb else proc.time()[[3]]-t0,erro=NA_character_))
}
start<-proc.time()[[3]]
results<-setNames(parallel::mclapply(families,fit_family,mc.cores=TRUNC_THREADS),families)
segundos_triagem<-proc.time()[[3]]-start
ranking<-rbindlist(lapply(results,`[[`,"linha"))[order(AIC)]
ranking[,`:=`(dAIC=AIC-min(AIC,na.rm=TRUE),dBIC=BIC-min(BIC,na.rm=TRUE))]
csv(ranking,"ranking_familias");csv(map,"colunas_media")
print(ranking)
# Worm-plots da referência BB e das duas melhores por AIC (resíduos quantílicos aleatorizados).
top<-setdiff(head(ranking[is.finite(AIC)]$familia,2),"BB")
fits<-lapply(setNames(c("BB",top),c("BB",top)),function(f)results[[f]]$modelo)
grDevices::png(file.path(OUT,"graficos/worm_familias.png"),width=6*length(fits),height=10,units="in",res=150)
graphics::par(mfrow=c(2,length(fits)),mar=c(4.2,4.8,3,1),oma=c(2.5,0,2.5,0))
for(row in c("EAD","Presencial"))for(f in names(fits)) {
  r<-resid(fits[[f]])[df$modalidade==row]
  withCallingHandlers(invisible(wp(resid=r,ylim.all=1,xlim.all=3,line=TRUE,col=NA,cex=.3)),
    warning=function(w)if(grepl("Some points are missed out",conditionMessage(w),fixed=TRUE))invokeRestart("muffleWarning"))
  graphics::title(main=sprintf("%s | %s (n=%s)",f,row,length(r)),cex.main=.9)
}
graphics::mtext(paste("Triagem gamlss: treino, N>1, subamostra de IES, famílias sem truncagem; efeitos:",paste(terms,collapse=" + ")),outer=TRUE,side=3,line=.8,font=2)
graphics::mtext("Bandas padrão de 95% de gamlss::wp; referência normal independente, sem calibração para efeitos aleatórios penalizados",
  outer=TRUE,side=1,line=1,cex=.75)
grDevices::dev.off()
write_json(list(finalidade="triagem exploratória de família; não substitui o modelo TMB",
  dados="treino (reserva intocada), N>1",fracao_IES=fraction,semente=SEED,n=nrow(df),
  IES=nlevels(df$co_ies),cursos=nlevels(df$co_curso),truncagem_Y_menor_N=FALSE,
  efeitos=paste(paste(terms,collapse=" + "),"(verossimilhança penalizada, não Laplace)"),
  dispersao=paste(deparse(formula_dispersao()),collapse=" "),parametros_extras="nu/tau constantes",
  ranking=ranking,ciclos=cycles,segundos_BB=segundos_bb,segundos_familias=segundos_triagem,gamlss=as.character(packageVersion("gamlss")),
  base=hash(BASE_PATH),codigo=hash("scripts/modelo/triagem_familias.R")),file.path(OUT,"triagem.json"))
log_msg("Triagem salva em",OUT)
