# Bandas padrão de 95% calculadas/desenhadas por gamlss::wp().
# Somente diagnóstico: o modelo ajustado continua sendo TMB.
source("scripts/modelo/common.R")
stopifnot(requireNamespace("gamlss",quietly=TRUE))
probs<-seq(.005,.995,length.out=100L)
labels<-c(condicional="Condicional",parcial_IES_fixa="IES fixa",marginal="Marginal",
  modos_fixos_treino="Modos do treino",latentes_integrados_treino="Latentes integrados")
worm<-function(u,context,mod="Todos",size="Todos") {
  stopifnot(all(is.finite(u)),all(u>=0&u<=1),length(u)>30L)
  z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)));q<-qnorm(probs)
  data.table(contexto=context,modalidade=mod,porte=size,n=length(u),probabilidade=probs,
    teorico=q,observado=unname(quantile(z,probs,type=8)),
    desvio=unname(quantile(z,probs,type=8))-q)
}
panel<-function(u,points,title,ylim) {
  z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)))
  # wp 5.4.22 referencia fit no retorno mesmo com line=FALSE. Usar line=TRUE
  # com col=NA oculta a curva cúbica. As bandas padrão permanecem visíveis.
  # pch=NA oculta apenas a nuvem completa; a banda usa TODOS os resíduos.
  withCallingHandlers(invisible(gamlss::wp(resid=z,pch=NA_integer_,bg=NA,
    line=TRUE,col=NA,xlim.all=3,ylim.all=ylim,cex.lab=.85)),warning=function(w) {
      if(grepl("Some points are missed out",conditionMessage(w),fixed=TRUE))invokeRestart("muffleWarning")
    })
  graphics::abline(h=0,v=0,lty=2,col="grey55")
  graphics::points(points$teorico,points$desvio,pch=16,cex=.5,col="#247b8a")
  graphics::title(main=title,cex.main=.9)
}
render<-function(path,w,h,rows,cols,draw,title) {
  grDevices::png(path,width=w,height=h,units="in",res=150)
  on.exit(grDevices::dev.off())
  graphics::par(mfrow=c(rows,cols),mar=c(4.2,4.8,3,1),oma=c(3,0,3,0))
  draw()
  graphics::mtext(title,outer=TRUE,side=3,line=1,font=2,cex=1.05)
  graphics::mtext("Bandas padrão pontuais de 95% — gamlss::wp; 100 pontos; banda usa n completo (N > 1)",
    outer=TRUE,side=1,line=.7,cex=.8)
  graphics::mtext("Referência normal independente: leitura descritiva, sem calibração para o painel ou estimação dos efeitos",
    outer=TRUE,side=1,line=1.8,cex=.7)
}
for(stage in c("diagnostico","validacao")) {
  OUT<-output_dir(stage);rfile<-file.path(OUT,"residuos.rds");r<-readRDS(rfile)
  contexts<-sub("^PIT_","",names(r)[startsWith(names(r),"PIT_")])
  r<-r[vinculos>1]
  geral<-rbindlist(lapply(contexts,function(k)worm(r[[paste0("PIT_",k)]],k)))
  groups<-rbindlist(lapply(contexts,function(k)r[,worm(get(paste0("PIT_",k)),k)[,
    !c("modalidade","porte")],by=.(modalidade,porte)]))
  all<-rbindlist(list(geral,groups),use.names=TRUE)
  csv(all,"worm_pontos")
  csv(all[,.(n=first(n),maior_desvio_central=max(abs(desvio)),desvio_mediano=median(desvio)),
    by=.(contexto,modalidade,porte)],"worm_resumo")
  ylim_global<-max(.7,1.15*max(abs(geral$desvio)))
  render(file.path(OUT,"graficos/worm_geral.png"),12,5,1,length(contexts),function() {
    for(k in contexts)panel(r[[paste0("PIT_",k)]],geral[contexto==k],
      sprintf("%s (n=%s)",labels[k],nrow(r)),ylim_global)
  },paste("Worm-plot —",stage))
  ylim_group<-max(1,1.15*max(abs(groups$desvio)))
  render(file.path(OUT,"graficos/worm_modalidade_porte.png"),20,10,length(contexts),8,function() {
    for(k in contexts)for(mod in c("EAD","Presencial"))for(size in c("1–29","30–99","100–999","1000+")) {
      ix<-which(r$modalidade==mod&r$porte==size)
      panel(r[[paste0("PIT_",k)]][ix],groups[contexto==k&modalidade==mod&porte==size],
        paste(labels[k],paste(mod,size,sep=" | "),paste0("n=",length(ix)),sep="\n"),ylim_group)
    }
  },paste("Worm-plots por modalidade e porte —",stage))
  write_json(list(pacote="gamlss",versao=as.character(packageVersion("gamlss")),funcao="wp",
    bandas="padrao_normal_pontuais_95_porcento",bandas_usam_todos_residuos=TRUE,
    pontos_exibidos=100L,n=nrow(r),N1_excluido=TRUE,curva_cubica_visivel=FALSE,
    calibradas_para_dependencia=FALSE,hessiana_populacional=FALSE,reajuste=FALSE,
    modelo_md5=hash(model_path(if(stage=="diagnostico")"completo"else"treino")),
    residuos_md5=hash(rfile),codigo=hash("scripts/modelo/worm.R")),file.path(OUT,"worm.json"))
}
log_msg("Worm-plots com bandas padrão gamlss::wp gerados; modelos e resíduos preservados")
