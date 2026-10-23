# Figuras do modelo adotado (dispre) para os slides e o relatório.
# Lê só saídas salvas (coeficientes, EDA e base filtrada); não reajusta nada.
# Paleta de referência validada (skill dataviz): azul e laranja nos dois primeiros slots.
source("scripts/modelo/variantes.R")
VAR<-"outputs/modelo/variantes/filtrada";OUT<-file.path(VAR,"dispre","figuras")
dir.create(OUT,recursive=TRUE,showWarnings=FALSE)
AZUL<-"#2a78d6";LARANJA<-"#eb6834";TINTA<-"#0b0b0b";TINTA2<-"#52514e";GRADE<-"#e4e3df";FUNDO<-"#fcfcfb"
br<-function(x,d=1)formatC(x,format="f",digits=d,decimal.mark=",")
theme_set(theme_minimal(base_size=15)+theme(
  plot.background=element_rect(fill=FUNDO,colour=NA),panel.grid.minor=element_blank(),
  panel.grid.major.y=element_blank(),panel.grid.major.x=element_line(colour=GRADE,linewidth=.4),
  plot.title=element_text(face="bold",colour=TINTA,size=19),plot.subtitle=element_text(colour=TINTA2,size=13),
  plot.caption=element_text(colour=TINTA2,size=10.5,hjust=0),axis.text=element_text(colour=TINTA2),
  axis.title=element_text(colour=TINTA2,size=12),plot.title.position="plot",plot.caption.position="plot"))
salvar<-function(p,n,w=11,h=6.2)ggsave(file.path(OUT,paste0(n,".png")),p,width=w,height=h,dpi=200,bg=FUNDO)
cf<-fread(file.path(VAR,"dispre/inferencia/tabelas/coeficientes.csv"))
d<-populacao("filtrada");p<-sum(d$eventos_resposta)/sum(d$vinculos);esc<-100*p*(1-p)   # pp por unidade de logit
fonte<-"Modelo beta-binomial misto (dispersão aleatória por IES e curso); cursos presentes em 2020–2024 com ≥30 vínculos; IC 95% de Wald."

# 1. Perfis: variação aproximada da taxa por +10 pp do perfil no curso
rot<-c(p_25_anos_ou_mais="25 anos ou mais",p_ppi="Pretos, pardos e indígenas",p_escola_publica="Egressos de escola pública",
  p_noturno="No turno noturno",p_deficiencia="Com deficiência (+1 pp)",p_reserva_vagas="Ingresso por reserva de vagas",
  p_feminino="Mulheres")
pf<-cf[termo%in%names(rot)][,`:=`(rotulo=rot[termo],pp=esc*estimativa,inf=esc*(estimativa-1.96*ep),sup=esc*(estimativa+1.96*ep))]
pf[,rotulo:=factor(rotulo,levels=rotulo[order(pp)])]
g1<-ggplot(pf,aes(pp,rotulo))+geom_vline(xintercept=0,colour=TINTA2,linewidth=.5)+
  geom_errorbarh(aes(xmin=inf,xmax=sup),height=0,colour=AZUL,linewidth=1.6)+geom_point(colour=AZUL,size=3.6)+
  geom_text(aes(x=ifelse(pp>0,sup,inf),label=paste0(ifelse(pp>0,"+",""),br(pp,2)," pp"),hjust=ifelse(pp>0,-.15,1.15)),colour=TINTA,size=4.6)+
  scale_x_continuous(limits=c(-.85,.95),breaks=seq(-.8,.8,.2),labels=function(x)paste0(ifelse(x>0,"+",""),br(x,1)))+
  labs(title="Perfil dos estudantes e taxa de desvínculo ou trancamento",
    subtitle=paste0("Variação aproximada da taxa anual (pp) para +10 pp do perfil no curso,\ncomparando cursos da mesma instituição; taxa média ",br(100*p),"%"),
    x="Pontos percentuais na taxa anual",y=NULL,caption=fonte)
salvar(g1,"perfis_efeito_pp")

# 2. Noturno: diferença bruta (EDA) contra a estimativa ajustada do modelo
nd<-fread("outputs/eda/tabelas/noturno_diurno_intra_ies.csv")[medida=="Desvínculo + trancamento"&rede=="Total"]
nt<-cf[termo=="p_noturno"]
noct<-data.table(rotulo=factor(c("Comparação direta\n(mediana entre IES)","Modelo com controles\n(curso 100% × 0% noturno)"),
    levels=c("Modelo com controles\n(curso 100% × 0% noturno)","Comparação direta\n(mediana entre IES)")),
  pp=c(nd$mediana_pp,10*esc*nt$estimativa),inf=c(NA,10*esc*(nt$estimativa-1.96*nt$ep)),sup=c(NA,10*esc*(nt$estimativa+1.96*nt$ep)),
  tipo=c("Bruto","Ajustado"))
g2<-ggplot(noct,aes(pp,rotulo,colour=tipo))+geom_vline(xintercept=0,colour=TINTA2,linewidth=.5)+
  geom_segment(aes(x=0,xend=pp,yend=rotulo),linewidth=1.2,alpha=.35)+
  geom_errorbarh(aes(xmin=inf,xmax=sup),height=0,linewidth=1.8,na.rm=TRUE)+geom_point(size=5)+
  geom_text(aes(label=paste0("+",br(pp)," pp")),colour=TINTA,size=5.4,nudge_y=.28)+
  scale_colour_manual(values=c(Bruto=LARANJA,Ajustado=AZUL),guide="none")+
  scale_x_continuous(limits=c(0,6.5),breaks=0:6,labels=function(x)paste0("+",x))+
  labs(title="Cursos noturnos perdem mais alunos, mesmo na mesma instituição",
    subtitle=paste0("Taxa anual de desvínculo ou trancamento, noturno − diurno, presencial.\n",
      "Comparação direta: ",nd$IES," IES com os dois turnos em 2024. Modelo: controla idade, origem escolar, área, porte e ano."),
    x="Diferença na taxa anual (pp)",y=NULL,caption=fonte)
salvar(g2,"noturno_bruto_ajustado",h=5.2)

# 3. EAD × presencial: taxas observadas
ev<-d[,.(taxa=sum(eventos_resposta)/sum(vinculos)),by=.(ano=as.integer(as.character(ano)),modalidade)]
ult<-ev[ano==2024];pri<-ev[ano==2020]
g3<-ggplot(ev,aes(ano,100*taxa,colour=modalidade))+geom_line(linewidth=1.3)+geom_point(size=3.4)+
  geom_text(data=ult,aes(label=paste0(modalidade," ",br(100*taxa),"%")),hjust=-.12,size=5,colour=TINTA)+
  geom_text(data=pri,aes(label=paste0(br(100*taxa),"%")),hjust=1.25,size=4.5,colour=TINTA2)+
  scale_colour_manual(values=c(EAD=AZUL,Presencial=LARANJA),guide="none")+
  scale_x_continuous(breaks=2020:2024,limits=c(2019.6,2025.2))+scale_y_continuous(limits=c(20,45),labels=function(x)paste0(x,"%"))+
  theme(panel.grid.major.y=element_line(colour=GRADE,linewidth=.4),panel.grid.major.x=element_blank())+
  labs(title="O EAD se distancia do presencial",subtitle="Taxa anual de desvínculo ou trancamento (soma dos cursos ÷ soma dos vínculos)",
    x=NULL,y=NULL,caption="Cursos presentes em 2020–2024 com ≥30 vínculos (152.484 curso-anos). Dados: Censo da Educação Superior/INEP.")
salvar(g3,"ead_presencial_taxas",w=10,h=6)

# 4. Afastamento do EAD no modelo: razão de chances ano × EAD (2020 = 1)
ai<-cf[grepl("^ano20..:modalidadeEAD$",termo)][,ano:=as.integer(substr(termo,4,7))]
ai<-rbind(data.table(ano=2020L,razao_chances_subjacente=1,rc_ic95_inf=NA,rc_ic95_sup=NA),
  ai[,.(ano,razao_chances_subjacente,rc_ic95_inf,rc_ic95_sup)])
g4<-ggplot(ai,aes(ano,razao_chances_subjacente))+geom_hline(yintercept=1,colour=TINTA2,linewidth=.5)+
  geom_errorbar(aes(ymin=rc_ic95_inf,ymax=rc_ic95_sup),width=0,colour=AZUL,linewidth=1.6,na.rm=TRUE)+
  geom_line(colour=AZUL,linewidth=1,alpha=.5)+geom_point(colour=AZUL,size=3.6)+
  geom_text(aes(y=pmax(razao_chances_subjacente,rc_ic95_sup,na.rm=TRUE),label=br(razao_chances_subjacente,2)),vjust=-.7,size=4.8,colour=TINTA)+
  scale_x_continuous(breaks=2020:2024)+scale_y_continuous(limits=c(.9,1.6),breaks=seq(1,1.6,.1),labels=function(x)br(x,1))+
  theme(panel.grid.major.y=element_line(colour=GRADE,linewidth=.4),panel.grid.major.x=element_blank())+
  labs(title="No modelo, a diferença entre EAD e presencial cresce a cada ano",
    subtitle="Razão de chances da diferença EAD − presencial em relação a 2020, comparando cursos semelhantes",
    x=NULL,y="Razão de chances (2020 = 1)",caption=fonte)
salvar(g4,"ead_interacao_ano",w=10,h=6)
jsonlite::write_json(list(figuras=list.files(OUT,pattern="png$"),taxa_media=p,
  conversao_pp="100 × beta × p(1−p), aproximação local na taxa média",
  codigo=unname(tools::md5sum("scripts/modelo/figuras_pitch.R"))),file.path(OUT,"figuras.json"),auto_unbox=TRUE,pretty=TRUE)
log_msg("Figuras do pitch salvas em",OUT)
