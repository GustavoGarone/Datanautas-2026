source("scripts/modelo/common.R")
raw_path<-"data/raw/cursos_ano.parquet"
stamp<-file.path(MODEL_OUT,"preparacao.json")
sig<-list(raw=hash(raw_path),codigo=hash("scripts/modelo/preparar.R"),
  escalas=as.list(SCALE),referencias=as.list(REFERENCES))
if(file.exists(BASE_PATH)&&file.exists(stamp)) {
  saved<-jsonlite::read_json(stamp,simplifyVector=FALSE)
  if(identical(saved$entrada,sig)&&identical(saved$base,hash(BASE_PATH))) {
    log_msg("Base preparada conferida; reutilizando");quit(save="no",status=0)
  }
}
d<-as.data.table(nanoparquet::read_parquet(raw_path))
counts<-c("matriculas","trancados","desvinculados","transferidos","falecidos","vinculos",paste0("mat_",PROFILES))
required<-c("co_curso","co_ies",CONTROLS,counts,"presente_5_anos","poucos_alunos")
stopifnot(all(required%in%names(d)),is.character(d$cine_area_geral),
  !anyNA(d[,..required]),!anyDuplicated(d[,.(co_curso,ano)]),all(d$ano%in%2020:2024))
for(v in counts) {
  set(d,j=v,value=as.numeric(d[[v]]))
  stopifnot(all(is.finite(d[[v]])),all(d[[v]]>=0),all(d[[v]]==floor(d[[v]])))
}
stopifnot(all(d$vinculos>0),
  all(d$vinculos==d$matriculas+d$trancados+d$desvinculados+d$transferidos+d$falecidos),
  all(d$poucos_alunos==as.integer(d$vinculos<30)))
for(v in paste0("mat_",PROFILES))stopifnot(all(d[[v]]<=d$matriculas))
panel<-d[,.(n_anos=uniqueN(ano),minimo=min(presente_5_anos),maximo=max(presente_5_anos)),by=co_curso]
stopifnot(all(panel$minimo==panel$maximo),all(panel$minimo==as.integer(panel$n_anos==5)))
n_raw<-nrow(d);excluded<-sum(d$matriculas==0)
d<-d[matriculas>0]
stopifnot(all((d$grau_academico=="Não aplicável (ABI)")==(d$cine_area_geral=="00")),
  all(d[modalidade=="EAD",mat_noturno]==0))
for(v in CONTROLS)d[[v]]<-relevel(factor(d[[v]]),ref=REFERENCES[[v]])
for(j in seq_along(PROP))d[[PROP[j]]]<-d[[paste0("mat_",PROFILES[j])]]/d$matriculas/SCALE[j]
d[,`:=`(co_curso=factor(co_curso),co_ies=factor(co_ies))]
setorder(d,co_curso,ano);keep<-unique(c(required,PROP));d<-d[,..keep]
d[,linha_original:=.I]
a<-d[,c(lapply(.SD,mean),list(logN=mean(log(vinculos)),ead=mean(modalidade=="EAD"))),
  by=.(co_ies,co_curso),.SDcols=PROP]
ctx<-a[,c(lapply(.SD,mean),list(log_n_cursos=log(.N))),by=co_ies,.SDcols=c(PROP,"logN","ead")]
setnames(ctx,c(PROP,"logN","ead","log_n_cursos"),CTX)
scales<-rbindlist(lapply(CTX,function(v)data.table(variavel=v,centro=mean(ctx[[v]]),escala=sd(ctx[[v]]))))
stopifnot(all(scales$escala>0),uniqueN(ctx$co_ies)==nrow(ctx))
for(v in CTX)ctx[,(v):=(get(v)-scales[variavel==v,centro])/scales[variavel==v,escala]]
for(v in CTX)d[,(v):=ctx[[v]][match(co_ies,ctx$co_ies)]]
set.seed(20261022L)
held<-d[,if(.N>=2L).(linha=sample(linha_original,1L))else .(linha=integer()),by=.(co_ies,co_curso)]$linha
d[,validacao:=linha_original%in%held]
d[,`:=`(eventos_resposta=desvinculados+trancados,demais_vinculos=vinculos-desvinculados-trancados)]
stopifnot(nrow(d)==211651L,all(d$eventos_resposta<d$vinculos),
  sum(d$validacao)==47477L,all(d$demais_vinculos==d$matriculas+d$transferidos+d$falecidos),
  uniqueN(d[validacao==FALSE]$co_ies)==nlevels(d$co_ies),
  uniqueN(d[validacao==FALSE]$co_curso)==nlevels(d$co_curso))
dd<-trunc_data(d);rm(dd)
atomic_rds(d,BASE_PATH)
dir.create(MODEL_OUT,recursive=TRUE,showWarnings=FALSE)
fwrite(scales,file.path(MODEL_OUT,"escalas_contextos.csv"))
write_json(list(entrada=sig,base=hash(BASE_PATH),original=n_raw,excluidos_matriculas_zero=excluded,
  n=nrow(d),cursos=nlevels(d$co_curso),IES=nlevels(d$co_ies),treino=sum(!d$validacao),
  reserva=sum(d$validacao),N1=sum(d$vinculos==1),
  cursos_mudam_IES=d[,uniqueN(co_ies),by=co_curso][V1>1,.N]),stamp)
log_msg("Base e contextos preparados diretamente do Parquet")
