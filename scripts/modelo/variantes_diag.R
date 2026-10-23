# Comparação rápida das variantes de variantes.R na mesma população.
# PIT exato e randomizado da BB truncada condicional aos modos (sem Monte Carlo):
#   base completa: modos do ajuste completo; reserva: modos do ajuste de treino.
# Bandas de gamlss::wp com referência normal independente: leitura descritiva, como em worm.R.
source("scripts/modelo/variantes.R")
args<-commandArgs(trailingOnly=TRUE)
pop<-sub("^--populacao=","",grep("^--populacao=",args,value=TRUE));if(!length(pop))pop<-"filtrada"
OUT<-output_dir(file.path("variantes",pop,"comparacao"))
d<-populacao(pop)
available<-Filter(function(v)all(file.exists(variant_path(v,c("completo","treino"),pop))),VARIANTS)
stopifnot(length(available)>0L)
log_msg("Comparando",paste(available,collapse=", "),"na população",pop)
porte<-cut(d$vinculos,c(0,29,99,999,Inf),labels=c("1–29","30–99","100–999","1000+"))
predict_rows<-function(m,v,rows) {
  des<-design(v,d);stopifnot(identical(colnames(des$X),m$colnames$X),identical(colnames(des$Z),m$colnames$Z))
  ni<-length(m$levels$co_ies);ii<-as.integer(d$co_ies[rows]);ci<-as.integer(d$co_curso[rows])
  b<-m$parameters$b;bd<-m$parameters$bd
  eta<-drop(des$X[rows,,drop=FALSE]%*%m$parameters$beta)+b[ii]+b[ni+ci]
  lphi<-drop(des$Z[rows,,drop=FALSE]%*%m$parameters$betadisp)+bd[ii]+bd[ni+ci]
  list(mu=plogis(eta),phi=exp(lphi))
}
evaluate<-function(v,context) {
  m<-readRDS(variant_path(v,if(context=="reserva")"treino"else"completo",pop))
  rows<-if(context=="reserva")which(d$validacao)else seq_len(nrow(d))
  p<-predict_rows(m,v,rows);y<-d$eventos_resposta[rows];N<-d$vinculos[rows]
  set.seed(SEED);u<-runif(length(rows))
  pit<-pit_exact(y,N,p$mu,p$phi,u);mom<-trunc_moments(p$mu,p$phi,N)
  sd_rate<-sqrt(pmax(mom$second-mom$mean^2,0))
  data.table(variante=v,contexto=context,linha=rows,modalidade=d$modalidade[rows],porte=porte[rows],
    y=y,N=N,pred=mom$mean*N,pearson=ifelse(N>1,(y/N-mom$mean)/sd_rate,NA_real_),
    logp=trunc_density(y,N,p$mu,p$phi,log=TRUE),pit=pit)
}
res<-rbindlist(lapply(available,function(v)rbindlist(lapply(c("completo","reserva"),function(k)evaluate(v,k)))))
info<-rbindlist(lapply(available,function(v){m<-readRDS(variant_path(v,"completo",pop));t<-readRDS(variant_path(v,"treino",pop))
  data.table(variante=v,k=m$k,AIC=m$AIC,convergencia=m$fit$convergence,gradiente_max=max(abs(m$gradient)),
    convergencia_treino=t$fit$convergence,gradiente_max_treino=max(abs(t$gradient)),
    DP_disp_IES=if(variant_map(v,1,1)$fixos[1]==0)exp(m$parameters$theta[3])else NA_real_,
    DP_disp_curso=if(variant_map(v,1,1)$fixos[2]==0)exp(m$parameters$theta[4])else NA_real_)}))
info[,dAIC:=AIC-min(AIC)]
probs<-seq(.005,.995,length.out=100L)
worm<-function(u){z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)));q<-qnorm(probs)
  data.table(probabilidade=probs,teorico=q,desvio=unname(quantile(z,probs,type=8))-q)}
ok<-res[N>1]
wd<-ok[,worm(pit),by=.(variante,contexto,modalidade,porte)]
summ<-ok[,.(n=.N,pearson2=mean(pearson^2),logscore_medio=mean(logp),
  taxa_obs=sum(y)/sum(N),taxa_prev=sum(pred)/sum(N)),by=.(variante,contexto)]
grp<-wd[,.(desvio_max=max(abs(desvio)),desvio_central=max(abs(desvio[abs(teorico)<=1.5])),
  desvio_caudas=max(abs(desvio[abs(teorico)>1.5]))),by=.(variante,contexto,modalidade,porte)]
summ<-merge(summ,grp[,.(media_desvio_max_grupos=mean(desvio_max),media_desvio_central=mean(desvio_central),
  media_desvio_caudas=mean(desvio_caudas)),by=.(variante,contexto)],by=c("variante","contexto"))
cal<-res[,.(n=.N,taxa_obs=sum(y)/sum(N),taxa_prev=sum(pred)/sum(N)),by=.(variante,contexto,modalidade,porte)]
csv(info,"ajustes");csv(summ,"resumo");csv(grp,"worm_grupos");csv(cal,"calibracao");csv(wd,"worm_pontos")
print(info);print(summ)
panel<-function(u,points,title,ylim) {
  z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)))
  withCallingHandlers(invisible(gamlss::wp(resid=z,pch=NA_integer_,bg=NA,line=TRUE,col=NA,
    xlim.all=3,ylim.all=ylim,cex.lab=.8)),warning=function(w) {
      if(grepl("Some points are missed out",conditionMessage(w),fixed=TRUE))invokeRestart("muffleWarning")})
  graphics::abline(h=0,v=0,lty=2,col="grey55")
  graphics::points(points$teorico,points$desvio,pch=16,cex=.45,col="#247b8a")
  graphics::title(main=title,cex.main=.8)
}
groups<-unique(ok[,.(modalidade,porte)])[order(modalidade,porte)]
for(k in c("completo","reserva")) {
  grDevices::png(file.path(OUT,"graficos",paste0("worm_",k,".png")),width=3.2*nrow(groups),height=3*length(available),units="in",res=130)
  graphics::par(mfrow=c(length(available),nrow(groups)),mar=c(4,4.2,3,.8),oma=c(3,0,3,0))
  for(v in available)for(g in seq_len(nrow(groups))) {
    sel<-ok[variante==v&contexto==k&modalidade==groups$modalidade[g]&porte==groups$porte[g]]
    panel(sel$pit,wd[variante==v&contexto==k&modalidade==groups$modalidade[g]&porte==groups$porte[g]],
      sprintf("%s\n%s | %s (n=%s)",v,groups$modalidade[g],groups$porte[g],nrow(sel)),1)
  }
  graphics::mtext(sprintf("Worm-plots por variante — %s, população %s; PIT exato condicional aos modos",k,pop),
    outer=TRUE,side=3,line=1,font=2)
  graphics::mtext("Bandas de 95% de gamlss::wp (referência normal independente, sem calibração para painel/efeitos)",
    outer=TRUE,side=1,line=1,cex=.75)
  grDevices::dev.off()
}
write_json(list(populacao=pop,filtro=POPULATIONS[[pop]],variantes=available,n=nrow(d),
  reserva=sum(d$validacao),pit="exato randomizado, condicional aos modos",
  reserva_modos="treino; curso sem linha de treino usa efeito zero",codigo=hash("scripts/modelo/variantes_diag.R"),
  modelos=lapply(setNames(available,available),function(v)hash(variant_path(v,c("completo","treino"),pop)))),
  file.path(OUT,"comparacao.json"))
log_msg("Comparação salva em",OUT)
