source("scripts/modelo/common.R")
id<-"Modelo atual";OUT<-output_dir("validacao")
full_path<-model_path("completo");full<-ler_modelo("completo");full_hash<-hash(full_path)
d<-dados_modelo();train<-d[validacao==FALSE];test<-d[validacao==TRUE]
train_path<-model_path("treino");m<-ler_modelo("treino")
stopifnot(m$n==nrow(train),identical(m$levels,full$levels))
trunc_compile();dd<-trunc_data(train)
o<-TMB::MakeADFun(dd,m$parameters,random="b",DLL=TRUNC_DLL,silent=TRUE)
value<-o$fn(o$par)
stopifnot(abs(value-m$fit$objective)<1e-3)
# Precisão da densidade conjunta dos LATENTES, não dos parâmetros populacionais.
Q<-Matrix::forceSymmetric(o$env$spHess(o$env$last.par,random=TRUE))
bmode<-unname(o$env$last.par[o$env$random])
stopifnot(nrow(Q)==length(bmode),all(is.finite(Q@x)))
factorQ<-Matrix::Cholesky(Q,LDL=FALSE,perm=TRUE)
expanded<-Matrix::expand(factorQ);L<-expanded$L;P<-expanded$P
# Q=P' L L' P; a raiz amostradora é P' L'^{-1}, preservando covariâncias.
set.seed(SEED+101L)
probe<-matrix(rnorm(3*nrow(Q)),nrow(Q),3)
qprobe<-Q%*%probe
reconstructed<-Matrix::crossprod(P,L%*%(Matrix::t(L)%*%(P%*%probe)))
factor_error<-max(abs(qprobe-reconstructed))/max(1,max(abs(qprobe)))
smallQ<-Matrix::Matrix(matrix(c(4,1,.5,1,3,.2,.5,.2,2),3,3),sparse=TRUE)
smallF<-Matrix::expand(Matrix::Cholesky(smallQ,LDL=FALSE,perm=TRUE))
smallRoot<-Matrix::crossprod(smallF$P,Matrix::solve(Matrix::t(smallF$L),Matrix::Diagonal(3)))
root_error<-max(abs(Matrix::tcrossprod(smallRoot)-Matrix::solve(smallQ)))
stopifnot(factor_error<1e-8,root_error<1e-10)
atomic_rds(list(Q=Q,bmode=bmode,levels=m$levels,train_md5=unname(tools::md5sum(train_path)),
  Q_tipo="Hessiana latente da log-densidade conjunta negativa; parametros populacionais fixos",
  hessiana_inferencia=FALSE),file.path(OUT,"precisao_latente.rds"))
TMB::FreeADFun(o);rm(o,dd,Q,factorQ,expanded,probe,qprobe,reconstructed);gc()
X<-matriz_media(test);Z<-model.matrix(formula_dispersao(),test)
stopifnot(identical(colnames(X),m$colnames$X),identical(colnames(Z),m$colnames$Z))
eta<-drop(X%*%m$parameters$beta);phi<-exp(drop(Z%*%m$parameters$betadisp))
ni<-length(m$levels$co_ies)
ii<-match(as.character(test$co_ies),m$levels$co_ies)
ci<-match(as.character(test$co_curso),m$levels$co_curso)
stopifnot(!anyNA(ii),!anyNA(ci),all(is.finite(phi)),all(phi>0))
train_info<-tabulate(as.integer(train$co_curso[train$vinculos>1]),nbins=nlevels(d$co_curso))
strata<-ifelse(train_info[ci]==0,"0",ifelse(train_info[ci]==1,"1","2+"))
y<-test$eventos_resposta;N<-test$vinculos;n<-nrow(test);ok<-N>1;B<-500L
groups<-data.table(ano=test$ano,modalidade=test$modalidade,
  porte=cut(N,c(0,29,99,999,Inf),labels=c("1–29","30–99","100–999","1000+")))
groups[,gid:=.GRP,by=.(ano,modalidade,porte)];gi<-unique(groups);setorder(gi,gid)
gs<-function(x)as.vector(rowsum(as.numeric(x),groups$gid,reorder=TRUE))
ng<-gs(rep(1,n));ng_info<-gs(ok);den<-gs(N)
rr<-data.table(linha_original=test$linha_original,co_ies=test$co_ies,co_curso=test$co_curso,
  ano=test$ano,modalidade=test$modalidade,porte=groups$porte,eventos_resposta=y,vinculos=N,
  anos_informativos_treino=train_info[ci],estrato_informacao=strata,observado=y/N)
contexts<-c("modos_fixos_treino","latentes_integrados_treino")
globals<-calibrations<-qqs<-quantiles<-stratified<-pit_summaries<-list()
set.seed(SEED)
for(context in contexts) {
  less<-equal<-integer(n);sum_mean<-sum_second<-numeric(n)
  ys_all<-matrix(0L,n,B);rates_group<-matrix(0,nrow(gi),B);zeros<-integer(B)
  log_msg(id,context,"validação interna iniciando",B,"simulações")
  fixed_mu<-plogis(eta+bmode[ii]+bmode[ni+ci])
  fixed_mom<-trunc_moments(fixed_mu,phi,N)
  for(s in seq_len(B)) {
    if(context=="modos_fixos_treino") {
      mu<-fixed_mu;mom<-fixed_mom
    } else {
      delta<-as.numeric(Matrix::crossprod(P,Matrix::solve(Matrix::t(L),rnorm(length(bmode)))))
      sampled_b<-bmode+delta
      mu<-plogis(eta+sampled_b[ii]+sampled_b[ni+ci])
      mom<-trunc_moments(mu,phi,N)
    }
    sum_mean<-sum_mean+mom$mean;sum_second<-sum_second+mom$second
    ys<-trunc_draw(mu,phi,N);stopifnot(all(ys<N),all(ys[!ok]==0))
    ys_all[,s]<-as.integer(ys);rates_group[,s]<-gs(ys)/den;zeros[s]<-sum(ys==0)
    less<-less+(ys<y);equal<-equal+(ys==y)
    if(s%%100L==0L)log_msg(id,context,s,"/",B)
  }
  mm<-sum_mean/B;vv<-sum_second/B-mm^2
  stopifnot(all(is.finite(mm)),all(is.finite(vv)),all(vv[ok]>0),all(vv[!ok]==0),
    all(mm>=-1e-10),all(mm<=(N-1)/N+1e-8),all(mm[!ok]==0))
  pit<-(less+runif(n)*(equal+1))/(B+1)
  rr[,(paste0("PIT_",context)):=pit]
  rr[,(paste0("previsto_",context)):=mm]
  rr[,(paste0("variancia_taxa_",context)):=vv]
  pit_summaries[[context]]<-data.table(contexto=context,mediana=median(pit),
    maior_afastamento_uniforme=max(abs(sort(pit)-ppoints(n))),
    fracao_abaixo_005=mean(pit<.05),fracao_acima_095=mean(pit>.95))
  obs_p2<-mean((y[ok]/N[ok]-mm[ok])^2/vv[ok])
  sim_p2<-vapply(seq_len(B),function(s)mean((ys_all[ok,s]/N[ok]-mm[ok])^2/vv[ok]),numeric(1))
  env<-function(obs,a,stat)data.table(contexto=context,estatistica=stat,observado=obs,
    sim_media=mean(a),sim_p025=quantile(a,.025),sim_p975=quantile(a,.975))
  globals[[context]]<-rbindlist(list(env(obs_p2,sim_p2,"Pearson2"),env(sum(y==0),zeros,"zeros")))
  cal<-copy(gi);cal[,`:=`(contexto=context,linhas=ng,vinculos=den,
    observado=gs(y)/den,previsto=gs(N*mm)/den,
    sim_p025=apply(rates_group,1,quantile,.025),sim_p975=apply(rates_group,1,quantile,.975))]
  cal[,erro_pp:=100*(observado-previsto)];calibrations[[context]]<-cal
  ix<-unique(round(seq(1,n,length.out=min(100L,n))))
  qqs[[context]]<-data.table(contexto=context,teorico=ppoints(n)[ix],observado=sort(pit)[ix])
  stratified[[context]]<-rr[,.(contexto=context,linhas=.N,zeros=sum(eventos_resposta==0),
    zeros_esperados_MC=sum(rowMeans(ys_all[.I,,drop=FALSE]==0)),
    mediana_PIT=median(pit[.I]),afastamento_QQ=max(abs(sort(pit[.I])-ppoints(.N)))),
    by=estrato_informacao]
  quantiles[[context]]<-rbindlist(lapply(c("ajustado","logN"),function(variable) {
    x<-if(variable=="ajustado")mm else log(N)
    br<-unique(quantile(x,seq(0,1,length.out=21)));a<-data.table(x,pit)
    a[,bin:=cut(x,br,include.lowest=TRUE)]
    a[,.(contexto=context,variavel=variable,x=mean(x),mediana=median(pit),
      q25=quantile(pit,.25),q75=quantile(pit,.75)),by=bin]
  }))
  rm(ys_all,rates_group);gc()
}
dg<-rbindlist(globals);ca<-rbindlist(calibrations);qq<-rbindlist(qqs);pq<-rbindlist(quantiles)
csv(dg,"diagnosticos");csv(ca,"calibracao_grupos");csv(qq,"QQ_pontos")
csv(pq,"quantis_residuos");csv(rbindlist(stratified),"informacao_treino")
csv(rbindlist(pit_summaries),"resumo_PIT")
atomic_rds(rr,file.path(OUT,"residuos.rds"))
theme_set(theme_minimal(base_size=11)+theme(plot.background=element_rect(fill="white",colour=NA)))
save_plot(ggplot(qq,aes(teorico,observado))+geom_abline(slope=1,intercept=0,linetype=2,colour="#b03a2e")+
  geom_point(size=.7,colour="#247b8a")+facet_wrap(~contexto,nrow=1)+coord_equal(xlim=c(0,1),ylim=c(0,1))+
  labs(title=paste(id,"— validação interna aproximada"),
    subtitle="Reajuste no treino; 500 simulações; comparação de modos e integração latente",
    x="Quantil uniforme",y="Quantil observado PIT"),"QQ_uniforme",w=10,h=5)
save_plot(ggplot(pq,aes(x,mediana))+geom_ribbon(aes(ymin=q25,ymax=q75),alpha=.18)+
  geom_line(colour="#247b8a")+geom_hline(yintercept=c(.25,.5,.75),linetype=2)+
  facet_grid(contexto~variavel,scales="free_x")+coord_cartesian(ylim=c(0,1))+
  labs(title=paste(id,"— resíduos reservados"),x="Ajustado ou log(N)",y="PIT: mediana e quartis"),
  "residuos",w=10,h=7)
save_plot(ggplot(ca,aes(as.integer(as.character(ano)),erro_pp,colour=modalidade,group=modalidade))+
  geom_hline(yintercept=0,linetype=2)+geom_line()+geom_point()+facet_grid(contexto~porte)+
  labs(title=paste(id,"— calibração interna"),x="Ano",y="Observado − previsto (pp)"),"calibracao",w=12,h=7)
write_json(list(status="validacao_interna_calculada_revisao_pendente",id=id,n_treino=nrow(train),
  n_reserva=n,n_Pearson=sum(ok),B=B,semente=SEED,
  objeto_precisao="Q_bb latente da densidade conjunta no modo do treino",
  erro_fatoracao=factor_error,erro_raiz_amostragem_pequeno=root_error,
  hessiana_parametros_populacionais=FALSE,sdreport=FALSE,selecao=FALSE,
  otimizacao_treino=list(codigo=m$fit$convergence,controle=m$optimizer_control,
    max_gradiente_bruto=max(abs(m$gradient)),validacao_inferencial_concluida=FALSE),
  medias_variancias_integradas=TRUE,covariancias_IES_curso_preservadas=TRUE,
  reserva_confirmatoria_intocada=FALSE,revisao_visual_pendente=TRUE,
  modelo_treino_md5=unname(tools::md5sum(train_path)),modelo_completo_md5=full_hash,
  codigo=tools::md5sum("scripts/modelo/validar.R"),
  limitacoes=c("Respostas reservadas participaram da escolha anterior da especificacao",
    "Aproximacao normal de Laplace dos efeitos, parametros populacionais fixos",
    "Momentos e Pearson usam o mesmo lote Monte Carlo; conclusoes limitrofes exigem lote independente",
    "Sem incerteza populacional; nao avalia novos cursos/IES ou previsao futura",
    "Uma observacao por par IES/curso elegivel altera ponderacao frente a base completa")),
  file.path(OUT,"diagnostico.json"))
log_msg(id,"validação interna salva; revisão visual e independente necessária")
stopifnot(identical(full_hash,hash(full_path)))
