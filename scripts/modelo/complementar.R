source("scripts/modelo/common.R")
id<-"Modelo atual";OUT<-output_dir("validacao")
r<-readRDS(file.path(OUT,"residuos.rds"));d<-dados_modelo()
test<-d[match(r$linha_original,linha_original)]
stopifnot(all(test$validacao),identical(test$linha_original,r$linha_original),
  identical(test$eventos_resposta,r$eventos_resposta),identical(test$vinculos,r$vinculos))
mfile<-model_path("treino")
m<-readRDS(mfile);q<-readRDS(file.path(OUT,"precisao_latente.rds"))
stopifnot(identical(q$train_md5,unname(tools::md5sum(mfile))),identical(q$levels,m$levels))
F<-Matrix::expand(Matrix::Cholesky(q$Q,LDL=FALSE,perm=TRUE))
X<-matriz_media(test);Z<-model.matrix(formula_dispersao(),test)
eta<-drop(X%*%m$parameters$beta);phi<-exp(drop(Z%*%m$parameters$betadisp))
ii<-match(as.character(test$co_ies),m$levels$co_ies)
ci<-match(as.character(test$co_curso),m$levels$co_curso);ni<-length(m$levels$co_ies)
stopifnot(!anyNA(ii),!anyNA(ci))
N<-r$vinculos;n<-nrow(r);ok<-N>1;B<-500L
first<-second<-pzero<-numeric(n);total_zero<-numeric(B)
set.seed(SEED+303L)
for(s in seq_len(B)) {
  b<-q$bmode+as.numeric(Matrix::crossprod(F$P,Matrix::solve(Matrix::t(F$L),rnorm(length(q$bmode)))))
  mu<-plogis(eta+b[ii]+b[ni+ci])
  mm<-trunc_moments(mu,phi,N);p0<-trunc_density(rep(0,n),N,mu,phi)
  stopifnot(all(is.finite(p0)),all(p0>=0&p0<=1+1e-8))
  first<-first+mm$mean;second<-second+mm$second;pzero<-pzero+p0
  total_zero[s]<-sum(p0)
  if(s%%100L==0L)log_msg(id,"momentos independentes",s,"/",B)
}
first<-first/B;second<-second/B;pzero<-pzero/B;variance<-second-first^2
stopifnot(all(variance[ok]>0),all(variance[!ok]==0),all(pzero[!ok]==1))
r[,prob_zero_integrada_lote_independente:=pzero]
oldmean<-r$previsto_latentes_integrados_treino
oldvar<-r$variancia_taxa_latentes_integrados_treino
pearson2<-mean((r$observado[ok]-first[ok])^2/variance[ok])
comparison<-data.table(
  medida=c("Pearson2","soma_zeros_esperados","diferenca_maxima_media_taxa","diferenca_maxima_variancia"),
  valor=c(pearson2,sum(pzero),max(abs(first-oldmean)),max(abs(variance-oldvar))))
csv(comparison,"conferencia_lote_independente")
contexts<-c("modos_fixos_treino","latentes_integrados_treino")
profiles<-cal_profiles<-cats<-list()
for(context in contexts) {
  pit<-r[[paste0("PIT_",context)]];pred<-r[[paste0("previsto_",context)]]
  profiles[[context]]<-rbindlist(lapply(PROP,function(v) {
    x<-test[[v]]*SCALE[v];br<-unique(quantile(x,seq(0,1,length.out=21)))
    a<-data.table(x,pit);a[,bin:=cut(x,br,include.lowest=TRUE)]
    a[,.(contexto=context,variavel=v,x=mean(x),linhas=.N,
      mediana=median(pit),q25=quantile(pit,.25),q75=quantile(pit,.75)),by=bin]
  }))
  cal_profiles[[context]]<-rbindlist(lapply(PROP,function(v) {
    x<-test[[v]]*SCALE[v];br<-unique(quantile(x,seq(0,1,length.out=11)))
    a<-data.table(x,y=r$eventos_resposta,N,pred);a[,bin:=cut(x,br,include.lowest=TRUE)]
    a[,.(contexto=context,variavel=v,x=mean(x),linhas=.N,vinculos=sum(N),
      observado=sum(y)/sum(N),previsto=sum(N*pred)/sum(N),
      erro_pp=100*(sum(y)-sum(N*pred))/sum(N)),by=bin]
  }))
  cats[[context]]<-rbindlist(lapply(CONTROLS,function(v) {
    a<-data.table(nivel=as.character(test[[v]]),pit)
    a[,.(contexto=context,controle=v,linhas=.N,mediana=median(pit),
      q25=quantile(pit,.25),q75=quantile(pit,.75)),by=nivel]
  }))
}
pq<-rbindlist(profiles);ca<-rbindlist(cal_profiles);cc<-rbindlist(cats)
csv(pq,"quantis_residuos_perfis");csv(ca,"calibracao_perfis");csv(cc,"PIT_por_controle")
zero_info<-r[,.(linhas=.N,N1=sum(vinculos==1),zeros=sum(eventos_resposta==0),
  zeros_esperados=sum(prob_zero_integrada_lote_independente),
  zeros_informativos=sum(eventos_resposta==0&vinculos>1),
  zeros_esperados_informativos=sum(prob_zero_integrada_lote_independente[vinculos>1])),by=estrato_informacao]
zero_info[,diferenca_pp:=100*(zeros-zeros_esperados)/linhas]
csv(zero_info,"zeros_por_informacao")
zi<-r[vinculos>1,.(linhas=.N,zeros=sum(eventos_resposta==0),
  zeros_esperados=sum(prob_zero_integrada_lote_independente)),by=co_ies]
zi[,deficit:=zeros-zeros_esperados];setorder(zi,-deficit);csv(zi,"zeros_por_ies")
zm<-r[vinculos>1,.(linhas=.N,zeros=sum(eventos_resposta==0),
  zeros_esperados=sum(prob_zero_integrada_lote_independente)),by=.(modalidade,porte)]
zm[,diferenca_pp:=100*(zeros-zeros_esperados)/linhas];csv(zm,"zeros_por_modalidade_porte")
# Persistência observada na base completa: descritiva, não é validação independente.
history<-d[vinculos>1,.(anos_informativos=.N,anos_zero=sum(eventos_resposta==0)),by=co_curso]
hp<-history[,.(cursos=.N,todos_anos_zero=sum(anos_zero==anos_informativos),
  pelo_menos_dois_zeros=sum(anos_zero>=2)),by=anos_informativos]
setorder(hp,anos_informativos);csv(hp,"persistencia_zeros_base_completa")
theme_set(theme_minimal(base_size=11)+theme(plot.background=element_rect(fill="white",colour=NA)))
save_plot(ggplot(pq,aes(x,mediana))+geom_ribbon(aes(ymin=q25,ymax=q75),alpha=.18)+
  geom_line(colour="#247b8a")+geom_hline(yintercept=c(.25,.5,.75),linetype=2)+
  facet_grid(contexto~variavel,scales="free_x")+coord_cartesian(ylim=c(0,1))+
  labs(title=paste(id,"— resíduos reservados pelos sete perfis"),
    x="Proporção entre matriculados",y="PIT: mediana e quartis"),"residuos_perfis",w=17,h=7)
save_plot(ggplot(cc,aes(nivel,mediana))+geom_linerange(aes(ymin=q25,ymax=q75),colour="#247b8a")+
  geom_point(size=.7,colour="#247b8a")+geom_hline(yintercept=c(.25,.5,.75),linetype=2)+
  facet_grid(contexto~controle,scales="free_x")+theme(axis.text.x=element_text(angle=90,hjust=1,vjust=.5))+
  coord_cartesian(ylim=c(0,1))+labs(title=paste(id,"— resíduos reservados por controle"),
    x=NULL,y="PIT: mediana e quartis"),"residuos_controles",w=18,h=8)
atomic_rds(r[,.(linha_original,prob_zero_integrada_lote_independente)],
  file.path(OUT,"prob_zero.rds"))
write_json(list(status="complementos_calculados_revisao_pendente",id=id,n=n,
  B=B,semente=SEED+303L,momentos_lote_independente=TRUE,Pearson2=pearson2,
  zeros_esperados=sum(pzero),erro_MC_soma_zeros=sd(total_zero)/sqrt(B),
  mesmo_modelo=TRUE,hessiana_populacional=FALSE,selecao=FALSE,
  gradiente_treino=max(abs(m$gradient)),revisao_visual_pendente=TRUE,
  treino_md5=unname(tools::md5sum(mfile)),
  codigo=tools::md5sum("scripts/modelo/complementar.R"),
  nota="Auditorias descritivas; nao usar reserva para nova busca de especificacoes"),
  file.path(OUT,"complementos.json"))
log_msg("Diagnósticos direcionados e lote independente concluídos; sem novo ajuste")
