# EDA da equipe (branch sanches, notebooks/02_EDA.ipynb) refeita com o trancamento.
# Mesmas definições de grupos do notebook original; três medidas lado a lado:
#   desvinculo = desvinculados / vinculos (medida da EDA original)
#   trancamento = trancados / vinculos
#   composta = (desvinculados + trancados) / vinculos (resposta do modelo principal)
# População do modelo: presente_5_anos == 1, poucos_alunos == 0 e matriculas > 0.
# Taxas agregadas somam numeradores e denominadores; associações descritivas, sem controles.
suppressPackageStartupMessages({library(data.table);library(ggplot2)})
data.table::setDTthreads(2)
OUT<-"outputs/eda";for(p in c("tabelas","graficos"))dir.create(file.path(OUT,p),recursive=TRUE,showWarnings=FALSE)
d<-as.data.table(nanoparquet::read_parquet("data/raw/cursos_ano.parquet"))
n_eda<-d[poucos_alunos==0&presente_5_anos==1,.N]
d<-d[poucos_alunos==0&presente_5_anos==1&matriculas>0]
stopifnot(nrow(d)==152484L,!anyNA(d$rede))
num<-c("desvinculados","trancados","vinculos","matriculas","mat_noturno","mat_escola_publica","mat_prouni")
for(v in num)set(d,j=v,value=as.numeric(d[[v]]))
d[,`:=`(prop_noturno=mat_noturno/matriculas,prop_escola_publica=mat_escola_publica/matriculas,prop_prouni=mat_prouni/matriculas)]
MED<-c(desvinculo="Desvínculo",trancamento="Trancamento",composta="Desvínculo + trancamento")
taxas<-function(g)g[,.(vinculos=sum(vinculos),desvinculo=sum(desvinculados)/sum(vinculos),
  trancamento=sum(trancados)/sum(vinculos),composta=sum(desvinculados+trancados)/sum(vinculos))]
longo<-function(x,ids)melt(x,id.vars=ids,measure.vars=names(MED),variable.name="medida",value.name="taxa")[,
  medida:=factor(MED[as.character(medida)],levels=MED)]
csv<-function(x,n)fwrite(x,file.path(OUT,"tabelas",paste0(n,".csv")))
png<-function(p,n,w=10,h=6)ggsave(file.path(OUT,"graficos",paste0(n,".png")),p,width=w,height=h,dpi=150)
theme_set(theme_minimal(base_size=11)+theme(plot.background=element_rect(fill="white",colour=NA),legend.position="bottom"))
cores<-c("Desvínculo"="#d95f02","Trancamento"="#7570b3","Desvínculo + trancamento"="#1b9e77")
pct<-scales::label_percent(accuracy=1)

# 1. Rede × modalidade, 2020–2024 agregado (seção 5 do notebook)
rm_<-d[,taxas(.SD),by=.(rede,modalidade)][order(rede,modalidade)];csv(rm_,"rede_modalidade")
png(ggplot(longo(rm_,c("rede","modalidade","vinculos")),aes(paste(rede,modalidade,sep="\n"),taxa,fill=medida))+
  geom_col(position="dodge")+geom_text(aes(label=scales::percent(taxa,.1)),position=position_dodge(.9),vjust=-.3,size=3)+
  scale_fill_manual(values=cores,name=NULL)+scale_y_continuous(labels=pct)+
  labs(title="Taxas anuais por rede e modalidade, 2020–2024",subtitle="Soma de numeradores ÷ soma de vínculos; cursos presentes nos 5 anos, ≥30 vínculos",x=NULL,y=NULL),"rede_modalidade")

# 2. Evolução anual por rede × modalidade
ev<-d[,taxas(.SD),by=.(ano,rede,modalidade)];csv(ev,"evolucao_anual")
png(ggplot(longo(ev,c("ano","rede","modalidade","vinculos")),aes(ano,taxa,colour=medida))+geom_line()+geom_point(size=1)+
  facet_grid(rede~modalidade)+scale_colour_manual(values=cores,name=NULL)+scale_y_continuous(labels=pct)+
  labs(title="Evolução das taxas anuais, 2020–2024",subtitle="Mesma população em todos os anos (painel de 5 anos)",x=NULL,y=NULL),"evolucao_anual")

# 3. Noturno × diurno dentro da mesma IES, presencial 2024 (seção 6): noturno ≥70%, diurno ≤30%
p24<-d[ano==2024&modalidade=="Presencial"]
p24[,turno:=fifelse(prop_noturno>=.7,"Noturno",fifelse(prop_noturno<=.3,"Diurno",NA_character_))]
pr<-p24[!is.na(turno),taxas(.SD),by=.(rede,co_ies,turno)]
pw<-dcast(pr,rede+co_ies~turno,value.var=names(MED))
pw<-pw[!is.na(desvinculo_Noturno)&!is.na(desvinculo_Diurno)]
for(m in names(MED))pw[,(paste0("dif_",m)):=100*(get(paste0(m,"_Noturno"))-get(paste0(m,"_Diurno")))]
pareado<-melt(pw,id.vars=c("rede","co_ies"),measure.vars=paste0("dif_",names(MED)),variable.name="medida",value.name="dif_pp")[,
  medida:=factor(MED[sub("^dif_","",medida)],levels=MED)]
pres<-rbind(pareado[,.(rede="Total",IES=.N,mediana_pp=median(dif_pp),media_pp=mean(dif_pp),positiva=mean(dif_pp>0)),by=medida],
  pareado[,.(IES=.N,mediana_pp=median(dif_pp),media_pp=mean(dif_pp),positiva=mean(dif_pp>0)),by=.(medida,rede)],use.names=TRUE)
csv(pres,"noturno_diurno_intra_ies");csv(pw,"noturno_diurno_intra_ies_por_ies")
set.seed(2026)
png(ggplot(pareado,aes(medida,dif_pp,colour=medida))+geom_hline(yintercept=0,linetype=2)+
  geom_jitter(width=.18,alpha=.25,size=.7)+geom_boxplot(fill=NA,colour="black",outlier.shape=NA,width=.45)+
  facet_wrap(~rede)+scale_colour_manual(values=cores,guide="none")+coord_cartesian(ylim=c(-30,30))+
  labs(title="Noturno − diurno dentro da mesma IES, presencial 2024",subtitle="Cada ponto é uma IES com cursos noturnos (≥70%) e diurnos (≤30%); diferença em pontos percentuais",x=NULL,y="Noturno − diurno (pp)"),
  "noturno_diurno_intra_ies",w=11,h=6)

# 4. Quartis de escola pública por rede, presencial 2020–2024 (seção 7)
pp<-d[modalidade=="Presencial"]
pp[,quartil:=cut(prop_escola_publica,unique(quantile(prop_escola_publica,0:4/4)),include.lowest=TRUE,labels=FALSE),by=rede]
ep<-pp[,c(taxas(.SD),list(prop_media=mean(prop_escola_publica))),by=.(rede,quartil)][order(rede,quartil)];csv(ep,"escola_publica_quartis")
png(ggplot(longo(ep,c("rede","quartil","vinculos","prop_media")),aes(factor(paste0("Q",quartil)),taxa,colour=medida,group=medida))+
  geom_line()+geom_point()+facet_wrap(~rede)+scale_colour_manual(values=cores,name=NULL)+scale_y_continuous(labels=pct)+
  labs(title="Taxas por quartil de egressos de escola pública, presencial 2020–2024",subtitle="Quartis dentro de cada rede; associação descritiva sem controles",x="Quartil (Q1 = menor proporção)",y=NULL),"escola_publica_quartis")

# 5. Quartis de ProUni, privada presencial 2024 sem Programas básicos (painel do pitch)
pv<-p24[rede=="Privada"&nome_cine_area_geral!="Programas básicos"]
pv[,quartil:=cut(rank(prop_prouni,ties.method="first"),4,labels=FALSE)]
pu<-pv[,c(taxas(.SD),list(cursos=.N,cobertura_media=mean(prop_prouni))),by=quartil][order(quartil)];csv(pu,"prouni_quartis_2024")

# 6. Área geral Cine, presencial 2020–2024 (seção 9)
ci<-pp[,taxas(.SD),by=nome_cine_area_geral][order(composta)];csv(ci,"area_cine")
png(ggplot(longo(ci,c("nome_cine_area_geral","vinculos")),aes(taxa,factor(nome_cine_area_geral,levels=ci$nome_cine_area_geral),fill=medida))+
  geom_col(position="dodge")+scale_fill_manual(values=cores,name=NULL)+scale_x_continuous(labels=pct)+
  labs(title="Taxas por área geral Cine, presencial 2020–2024",x=NULL,y=NULL),"area_cine",w=11,h=7)

# 7. Painel do pitch (equivalente a assets/pitch_eda_dashboard.png), medida composta e desvínculo
rd<-longo(p24[nome_cine_area_geral!="Programas básicos",taxas(.SD),by=rede],c("rede","vinculos"))[medida!="Trancamento"]
a<-ggplot(rd,aes(rede,taxa,fill=medida))+geom_col(position="dodge")+
  geom_text(aes(label=scales::percent(taxa,.1)),position=position_dodge(.9),vjust=-.3,size=3.2)+
  scale_fill_manual(values=cores,name=NULL)+scale_y_continuous(labels=pct)+labs(title="Por rede",x=NULL,y=NULL)
b<-ggplot(longo(pu,c("quartil","vinculos","cursos","cobertura_media"))[medida!="Trancamento"],
  aes(paste0("Q",quartil,"\n",scales::percent(cobertura_media,1)," média"),taxa,colour=medida,group=medida))+
  geom_line()+geom_point(size=2.5)+geom_text(aes(label=scales::percent(taxa,.1)),vjust=-.9,size=3,show.legend=FALSE)+
  scale_colour_manual(values=cores,name=NULL)+scale_y_continuous(labels=pct)+labs(title="ProUni (privada): associação descritiva",x=NULL,y=NULL)
cc<-ggplot(pareado[medida!="Trancamento"],aes(rede,dif_pp,colour=medida))+geom_hline(yintercept=0,linetype=2)+
  geom_boxplot(outlier.shape=NA,position=position_dodge(.8),width=.6)+scale_colour_manual(values=cores,name=NULL)+
  coord_cartesian(ylim=c(-15,20))+labs(title="Noturno − diurno dentro da IES (pp)",x=NULL,y=NULL)
# Três painéis lado a lado com grid (base R), sem dependências extras.
grDevices::png(file.path(OUT,"graficos","painel_pitch.png"),width=17,height=6.5,units="in",res=150)
grid::grid.newpage();lay<-grid::grid.layout(2,3,heights=grid::unit(c(.8,5.7),"in"))
grid::pushViewport(grid::viewport(layout=lay))
grid::grid.text("Presencial 2024: desvínculo com e sem trancamento",y=.65,gp=grid::gpar(fontsize=17,fontface="bold"),
  vp=grid::viewport(layout.pos.row=1,layout.pos.col=1:3))
grid::grid.text("Cursos presentes nos 5 anos, ≥30 vínculos; associação entre cursos, não efeito causal nem abandono do ensino superior",
  y=.2,gp=grid::gpar(fontsize=11),vp=grid::viewport(layout.pos.row=1,layout.pos.col=1:3))
for(i in 1:3)print(list(a,b,cc)[[i]],vp=grid::viewport(layout.pos.row=2,layout.pos.col=i))
grDevices::dev.off()
jsonlite::write_json(list(origem="notebooks/02_EDA.ipynb (branch origin/sanches)",linhas_filtro_eda=n_eda,
  linhas=nrow(d),nota="Associações descritivas agregadas por curso; não identificam alunos nem efeitos causais",
  codigo=unname(tools::md5sum("scripts/eda/eda_composta.R"))),file.path(OUT,"eda.json"),auto_unbox=TRUE,pretty=TRUE)
cat("EDA com trancamento salva em",OUT,"\n")
