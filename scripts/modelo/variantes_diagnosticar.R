# Diagnóstico por simulação de uma variante (padrão: dispre), adaptado de diagnosticar.R.
# Efeitos aleatórios na média (b) e na log-dispersão (bd), de IES e curso.
# Contextos: condicional (modos de b e bd), parcial com IES fixa (b e bd de IES nos modos,
# de curso sorteados) e marginal (todos sorteados). Momentos por Gauss-Hermite 2D.
source("scripts/modelo/variantes.R")
args<-commandArgs(trailingOnly=TRUE)
v<-if(length(args)&&args[1]%in%VARIANTS)args[1]else"dispre"
pop<-sub("^--populacao=","",grep("^--populacao=",args,value=TRUE));if(!length(pop))pop<-"filtrada"
id<-paste("Variante",v);validation<-TRUE   # população filtrada: sem a contagem fixa de pares da base completa
OUT<-output_dir(file.path("variantes",pop,v,"diagnostico"));d<-populacao(pop)
path<-variant_path(v,"completo",pop);m<-readRDS(path)
stopifnot(m$n==nrow(d))
des<-design(v,d);X<-des$X;Z<-des$Z
stopifnot(identical(m$colnames$X,colnames(X)),identical(m$colnames$Z,colnames(Z)))
eta<-drop(X%*%m$parameters$beta);lphi<-drop(Z%*%m$parameters$betadisp)
group_names<-c("co_ies","co_curso")
sizes<-vapply(m$levels,length,integer(1))
fx<-variant_map(v,sizes[1],sizes[2])$fixos
th<-exp(m$parameters$theta)
sds<-setNames(th[1:2],group_names)
sdd<-setNames(ifelse(fx>0,0,th[3:4]),group_names)
offsets<-c(0L,sizes[1]);modes<-dmodes<-indices<-list()
for(j in 1:2) {
  g<-group_names[j];indices[[g]]<-match(as.character(d[[g]]),m$levels[[g]]);stopifnot(!anyNA(indices[[g]]))
  modes[[g]]<-m$parameters$b[offsets[j]+seq_len(sizes[j])];dmodes[[g]]<-m$parameters$bd[offsets[j]+seq_len(sizes[j])]
}
fixed_re<-Reduce(`+`,lapply(group_names,function(g)modes[[g]][indices[[g]]]))
fixed_dre<-Reduce(`+`,lapply(group_names,function(g)dmodes[[g]][indices[[g]]]))
mu<-plogis(eta+fixed_re);phi<-exp(lphi+fixed_dre)
stopifnot(all(is.finite(mu)),all(is.finite(phi)))
n<-nrow(d);y<-d$eventos_resposta;N<-d$vinculos
gh<-function(k){J<-matrix(0,k,k);J[cbind(seq_len(k-1),2:k)]<-sqrt(seq_len(k-1));e<-eigen(J+t(J),symmetric=TRUE)
  list(x=e$values,w=e$vectors[1,]^2)}
# Média e dispersão latentes independentes a priori: produto de quadraturas.
quadrature<-function(bm,sm,bp,sp,k) {
  if(sm==0&&sp==0)return(trunc_moments(plogis(bm),exp(bp),N))
  q<-gh(k);xm<-if(sm>0)q$x else 0;wm<-if(sm>0)q$w else 1;xp<-if(sp>0)q$x else 0;wp<-if(sp>0)q$w else 1
  a<-a2<-numeric(n)
  for(i in seq_along(xm))for(j in seq_along(xp)) {
    z<-trunc_moments(plogis(bm+sm*xm[i]),exp(pmin(30,bp+sp*xp[j])),N)
    a<-a+wm[i]*wp[j]*z$mean;a2<-a2+wm[i]*wp[j]*z$second
  }
  list(mean=a,second=a2)
}
contexts<-c("condicional","parcial_IES_fixa","marginal")
bases<-list(eta+fixed_re,eta+modes$co_ies[indices$co_ies],eta)
dbases<-list(lphi+fixed_dre,lphi+dmodes$co_ies[indices$co_ies],lphi)
sm<-c(0,sds[["co_curso"]],sqrt(sum(sds^2)));sp<-c(0,sdd[["co_curso"]],sqrt(sum(sdd^2)))
moments<-lapply(1:3,function(k)quadrature(bases[[k]],sm[k],dbases[[k]],sp[k],20L))
qe<-max(vapply(2:3,function(k){z<-quadrature(bases[[k]],sm[k],dbases[[k]],sp[k],30L)
  max(abs(z$mean-moments[[k]]$mean),abs(z$second-moments[[k]]$second))},numeric(1)))
log_msg(id,"erro de quadratura (20 vs 30 nós):",signif(qe,3))
stopifnot(qe<1e-4)
vv<-lapply(moments,function(a)a$second-a$mean^2)
informative<-N>1
stopifnot(all(vapply(vv,function(x)all(x[informative]>0),logical(1))))
groups <- data.table(ano=d$ano,modalidade=d$modalidade,porte=cut(N,c(0,29,99,999,Inf),labels=c("1–29","30–99","100–999","1000+")))
groups[, gid:=.GRP,by=.(ano,modalidade,porte)]; gi<-unique(groups); setorder(gi,gid)
gs <- function(x) as.vector(rowsum(as.numeric(x),groups$gid,reorder=TRUE))
ng<-gs(rep(1,n))
ng_pearson<-gs(informative);stopifnot(all(ng_pearson>0))
ies <- unique(as.character(d$co_ies)); ii <- match(as.character(d$co_ies),ies)
isum<-function(x) as.vector(rowsum(as.numeric(x),ii,reorder=TRUE))
ni<-isum(N); oi<-isum(y)/ni
rr <- data.table(linha_original=d$linha_original,co_ies=d$co_ies,co_curso=d$co_curso,
  ano=d$ano,modalidade=d$modalidade,porte=groups$porte,vinculos=N,eventos_resposta=y,
  desvinculados=d$desvinculados,trancados=d$trancados,observado=y/N,phi=phi,mu_BB_subjacente=mu)
envelope <- function(obs,a) list(observado=obs,sim_media=mean(a),sim_p025=unname(quantile(a,.025)),sim_p975=unname(quantile(a,.975)))
all_global<-all_group<-all_ies<-all_cal<-all_qq<-all_quant<-list()
B<-500L; set.seed(SEED)
for (k in seq_along(contexts)) {
  type<-contexts[k]; mm<-moments[[k]]$mean
  obs_pearson<-numeric(n)
  obs_pearson[informative]<-(y[informative]/N[informative]-mm[informative])/sqrt(vv[[k]][informative])
  less<-equal<-integer(n)
  stats<-matrix(0,B,3); zg<-pg<-matrix(0,nrow(gi),B); irate<-matrix(0,length(ies),B)
  log_msg(id,type,"iniciando",B,"simulações")
  for(s in seq_len(B)) {
    es<-eta;ps<-lphi
    for(g in group_names) {
      if(k==1L || (k==2L && g=="co_ies")) {
        es<-es+modes[[g]][indices[[g]]];ps<-ps+dmodes[[g]][indices[[g]]]
      } else {
        es<-es+rnorm(length(modes[[g]]),sd=sds[g])[indices[[g]]]
        ps<-ps+rnorm(length(dmodes[[g]]),sd=sdd[g])[indices[[g]]]
      }
    }
    ys<-trunc_draw(plogis(es),exp(pmin(30,ps)),N)
    stopifnot(all(ys<N),all(ys[!informative]==0))
    pear<-numeric(n)
    pear[informative]<-(ys[informative]/N[informative]-mm[informative])^2/vv[[k]][informative]
    stats[s,]<-c(mean(pear[informative]),sum(ys==0),sum(ys==N))
    zg[,s]<-gs(ys==0); pg[,s]<-gs(pear)/ng_pearson; irate[,s]<-isum(ys)/ni
    less<-less+(ys<y); equal<-equal+(ys==y)
    if(s%%100L==0L) log_msg(id,type,s,"/",B)
  }
  pit<-(less+runif(n)*(equal+1))/(B+1)
  rr[,(paste0("PIT_",type)):=pit]; rr[,(paste0("previsto_",type)):=mm]
  rr[,(paste0("variancia_taxa_",type)):=vv[[k]]]
  z<-rbindlist(list(as.data.table(envelope(mean(obs_pearson[informative]^2),stats[,1])),
    as.data.table(envelope(sum(y==0),stats[,2])),as.data.table(envelope(sum(y==N),stats[,3]))))
  z[,`:=`(contexto=type,estatistica=c("dispersao_padronizada","zeros","fronteira_superior"))]
  z[,razao_obs_sim:=observado/sim_media]
  z[,fora_envelope:=observado<sim_p025|observado>sim_p975]
  z[,falha_triagem_historica:=fora_envelope & (razao_obs_sim<.8|razao_obs_sim>1.25)]
  z[estatistica=="fronteira_superior",`:=`(razao_obs_sim=NA_real_,falha_triagem_historica=FALSE)]
  z[,por_construcao:=estatistica=="fronteira_superior"]
  all_global[[type]]<-z
  all_group[[type]]<-rbindlist(lapply(c("Pearson2","zeros"),function(stat) {
    a<-if(stat=="zeros")zg else pg; obs<-if(stat=="zeros")gs(y==0) else gs(obs_pearson^2)/ng_pearson
    out<-copy(gi);out[,`:=`(contexto=type,estatistica=stat,linhas=ng,linhas_estatistica=if(stat=="zeros")ng else ng_pearson,observado=obs,sim_media=rowMeans(a),
      sim_p025=apply(a,1,quantile,.025),sim_p975=apply(a,1,quantile,.975))];out
  }))
  all_ies[[type]]<-data.table(co_ies=ies,contexto=type,vinculos=ni,observado=oi,
    previsto=isum(N*mm)/ni,sim_p025=apply(irate,1,quantile,.025),sim_p975=apply(irate,1,quantile,.975))
  a<-copy(rr[,.(ano,modalidade,porte,vinculos,eventos_resposta)]);a[,pred:=mm]
  cal<-a[,.(linhas=.N,vinculos=sum(vinculos),observado=sum(eventos_resposta)/sum(vinculos),
    previsto=sum(vinculos*pred)/sum(vinculos),media_cursos_observada=mean(eventos_resposta/vinculos),
    media_cursos_prevista=mean(pred)),by=.(ano,modalidade,porte)]
  cal[,`:=`(contexto=type,erro_pp=100*(observado-previsto))];all_cal[[type]]<-cal
  ix<-unique(round(seq(1,n,length.out=min(100L,n))))
  all_qq[[type]]<-data.table(contexto=type,teorico=ppoints(n)[ix],observado=sort(pit)[ix])
  all_quant[[type]]<-rbindlist(lapply(c("ajustado","logN",PROP),function(v) {
    x<-if(v=="ajustado")mm else if(v=="logN")log(N) else d[[v]]*SCALE[v]
    br<-unique(quantile(x,seq(0,1,length.out=21)));aa<-data.table(x,pit)
    aa[,bin:=cut(x,br,include.lowest=TRUE)]
    aa[,.(contexto=type,variavel=v,x=mean(x),mediana=median(pit),q25=quantile(pit,.25),q75=quantile(pit,.75)),by=bin]
  }))
}
dg<-rbindlist(all_global);gg<-rbindlist(all_group);ic<-rbindlist(all_ies);ca<-rbindlist(all_cal);qq<-rbindlist(all_qq);pq<-rbindlist(all_quant)
csv(dg,"diagnosticos");csv(gg,"diagnosticos_grupos");csv(ic,"calibracao_ies");csv(ca,"calibracao_grupos");csv(pq,"quantis_residuos")
csv(qq,"QQ_pontos")
csv(rbindlist(lapply(contexts,function(k) {
  u<-rr[[paste0("PIT_",k)]]
  data.table(contexto=k,mediana=median(u),maior_afastamento_uniforme=max(abs(sort(u)-ppoints(n))),
    fracao_abaixo_005=mean(u<.05),fracao_acima_095=mean(u>.95))
})),"resumo_PIT")
csv(rbindlist(lapply(contexts,function(k) {
  a<-copy(rr[,.(co_curso,ano,PIT=get(paste0("PIT_",k)))]);setorder(a,co_curso,ano)
  a[,`:=`(curso_anterior=shift(co_curso),anterior=shift(PIT),
    ano_anterior=shift(as.integer(as.character(ano))))]
  a<-a[co_curso==curso_anterior & as.integer(as.character(ano))-ano_anterior==1L & !is.na(anterior)]
  if(!validation)stopifnot(nrow(a)==159350L)
  data.table(contexto=k,pares=nrow(a),correlacao=cor(a$PIT,a$anterior),
    nota="Descritiva, dependência e retração; sem referência iid ou reajuste")
})),"dependencia_temporal")
cats<-rbindlist(lapply(contexts,function(k)rbindlist(lapply(CONTROLS,function(v){
  a<-data.table(nivel=as.character(d[[v]]),PIT=rr[[paste0("PIT_",k)]])
  a[,.(contexto=k,controle=v,linhas=.N,mediana=median(PIT),q25=quantile(PIT,.25),q75=quantile(PIT,.75)),by=nivel]
}))))
csv(cats,"PIT_por_controle")
atomic_rds(rr,file.path(OUT,"residuos.rds"))
theme_set(theme_minimal(base_size=11)+theme(plot.background=element_rect(fill="white",colour=NA)))
save_plot(ggplot(qq,aes(teorico,observado))+geom_abline(slope=1,intercept=0,linetype=2,colour="#b03a2e")+
  geom_point(size=.6,colour="#247b8a")+facet_wrap(~contexto,nrow=1)+coord_equal(xlim=c(0,1),ylim=c(0,1))+
  labs(title=paste("Desvínculo ou trancamento —",id,"— população",pop),subtitle="100 quantis; 500 simulações sem reajuste; três níveis de condicionamento",
    x="Quantil uniforme",y="Quantil observado PIT"),"QQ_uniforme",w=12,h=5)
save_plot(ggplot(pq[variavel%in%c("ajustado","logN")],aes(x,mediana))+geom_ribbon(aes(ymin=q25,ymax=q75),alpha=.18)+
  geom_line(colour="#247b8a")+geom_hline(yintercept=c(.25,.5,.75),linetype=2)+facet_grid(contexto~variavel,scales="free_x")+
  coord_cartesian(ylim=c(0,1))+labs(title=id,x="Ajustado ou log(N)",y="PIT: mediana e quartis"),"residuos",w=10,h=8)
save_plot(ggplot(pq[variavel%in%PROP],aes(x,mediana))+
  geom_ribbon(aes(ymin=q25,ymax=q75),alpha=.18)+geom_line(colour="#247b8a")+
  geom_hline(yintercept=c(.25,.5,.75),linetype=2)+facet_grid(contexto~variavel,scales="free_x")+
  coord_cartesian(ylim=c(0,1))+labs(title=id,x="Proporção de perfil",y="PIT: mediana e quartis"),"residuos_perfis",w=16,h=8)
save_plot(ggplot(cats,aes(nivel,mediana))+
  geom_linerange(aes(ymin=q25,ymax=q75),colour="#247b8a")+geom_point(size=.7,colour="#247b8a")+
  geom_hline(yintercept=c(.25,.5,.75),linetype=2)+facet_grid(contexto~controle,scales="free_x")+
  theme(axis.text.x=element_text(angle=90,hjust=1,vjust=.5))+
  coord_cartesian(ylim=c(0,1))+labs(title=paste(id,"— resíduos por controle"),x=NULL,y="PIT: mediana e quartis"),
  "residuos_controles",w=18,h=10)
save_plot(ggplot(ca[contexto=="condicional"],aes(as.integer(as.character(ano)),erro_pp,colour=modalidade,group=modalidade))+
  geom_hline(yintercept=0,linetype=2)+geom_line()+geom_point()+facet_wrap(~porte)+
  labs(title=paste(id,"— calibração condicional"),x="Ano",y="Observado − previsto (pp)"),"calibracao_porte")
save_plot(ggplot(ic,aes(previsto,observado))+geom_abline(slope=1,intercept=0,linetype=2)+geom_point(alpha=.25,size=.5)+
  facet_wrap(~contexto)+labs(title=paste(id,"— calibração por IES"),x="Taxa prevista",y="Taxa observada"),"calibracao_ies",w=12,h=5)
write_json(list(id=id,validacao_reservada=validation,n=n,B=B,semente=SEED,erro_quadratura=qe,
  n_Pearson=sum(informative),n_deterministico_N1=sum(!informative),suporte="0,...,N-1",
  hessiana_inferencia=FALSE,selecao=FALSE,revisao_visual_pendente=TRUE,
  resposta="desvinculados + trancados",modelo_md5=unname(tools::md5sum(path)),codigo=tools::md5sum(c("scripts/modelo/variantes_diagnosticar.R","scripts/modelo/variantes.R")),variante=v,populacao=pop,validacao_reservada_nota="falso: base completa da população; flag só desliga a contagem de pares da base completa",
  nota="Triagem descritiva, sem incerteza dos modos; truncagem condicional aos RE, N1 preservados mas sem variância; fronteira por construção não valida modelo; não corrige toda a seleção"),file.path(OUT,"diagnostico.json"))
log_msg(id,"diagnóstico salvo; revisão visual necessária")
# Worm-plots dos PIT simulados, como em worm.R (bandas padrão de gamlss::wp; N=1 excluído).
probs<-seq(.005,.995,length.out=100L)
wormd<-function(u){z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)));q<-qnorm(probs)
  data.table(probabilidade=probs,teorico=q,desvio=unname(quantile(z,probs,type=8))-q)}
r<-rr[vinculos>1];sizes_g<-levels(droplevels(r$porte))
wp_all<-rbindlist(lapply(contexts,function(k)r[,wormd(get(paste0("PIT_",k))),by=.(modalidade,porte)][,contexto:=k]))
csv(wp_all,"worm_pontos")
csv(wp_all[,.(desvio_max=max(abs(desvio)),desvio_central=max(abs(desvio[abs(teorico)<=1.5]))),by=.(contexto,modalidade,porte)],"worm_resumo")
grDevices::png(file.path(OUT,"graficos","worm_modalidade_porte.png"),width=3.2*2*length(sizes_g),height=3*length(contexts),units="in",res=130)
graphics::par(mfrow=c(length(contexts),2*length(sizes_g)),mar=c(4,4.2,3,.8),oma=c(3,0,3,0))
for(k in contexts)for(mod in c("EAD","Presencial"))for(size in sizes_g) {
  u<-r[modalidade==mod&porte==size][[paste0("PIT_",k)]];z<-qnorm(pmin(1-1e-12,pmax(1e-12,u)))
  withCallingHandlers(invisible(gamlss::wp(resid=z,pch=NA_integer_,bg=NA,line=TRUE,col=NA,xlim.all=3,ylim.all=1,cex.lab=.8)),
    warning=function(w)if(grepl("Some points are missed out",conditionMessage(w),fixed=TRUE))invokeRestart("muffleWarning"))
  pts<-wp_all[contexto==k&modalidade==mod&porte==size]
  graphics::abline(h=0,v=0,lty=2,col="grey55");graphics::points(pts$teorico,pts$desvio,pch=16,cex=.45,col="#247b8a")
  graphics::title(main=sprintf("%s\n%s | %s (n=%s)",k,mod,size,length(u)),cex.main=.8)
}
graphics::mtext(paste("Worm-plots —",id,"— população",pop,"— 500 simulações"),outer=TRUE,side=3,line=1,font=2)
graphics::mtext("Bandas padrão de 95% de gamlss::wp; referência normal independente, sem calibração para painel/efeitos",outer=TRUE,side=1,line=1,cex=.75)
grDevices::dev.off()
log_msg(id,"worm-plots salvos")
