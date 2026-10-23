# Tabela PNG dos coeficientes da média do modelo adotado (dispre), em razão de chances com IC 95%.
# Lê só coeficientes.csv (nenhum valor fixo no código) e os nomes Cine em data/raw/cursos_ano.parquet.
suppressPackageStartupMessages({library(data.table);library(ggplot2)})
D<-"outputs/modelo/variantes/filtrada/dispre";OUT<-file.path(D,"figuras");dir.create(OUT,recursive=TRUE,showWarnings=FALSE)
AZUL<-"#2a78d6";TINTA<-"#0b0b0b";TINTA2<-"#52514e";GRADE<-"#e4e3df";FUNDO<-"#fcfcfb";FAIXA<-"#f1f0ec"
fmt<-function(x,d=3)formatC(x,format="f",digits=d,decimal.mark=",")
cf<-fread(file.path(D,"inferencia/tabelas/coeficientes.csv"))
cine<-unique(nanoparquet::read_parquet("data/raw/cursos_ano.parquet")[,c("cine_area_geral","nome_cine_area_geral")])
cine<-setNames(cine$nome_cine_area_geral,cine$cine_area_geral)
# mapa termo -> (secao, rotulo); termo desconhecido interrompe a execucao
perf<-c(p_feminino="Feminino",p_ppi="PPI (preta, parda ou indígena)",p_25_anos_ou_mais="25 anos ou mais",p_escola_publica="Escola pública",
  p_deficiencia="Com deficiência",p_reserva_vagas="Reserva de vagas",p_noturno="Noturno")
ctx<-c(ies_m_p_feminino="IES: média de feminino",ies_m_p_ppi="IES: média de PPI",ies_m_p_25_anos_ou_mais="IES: média de 25 anos ou mais",
  ies_m_p_escola_publica="IES: média de escola pública",ies_m_p_deficiencia="IES: média de deficiência",ies_m_p_reserva_vagas="IES: média de reserva de vagas",
  ies_m_p_noturno="IES: média de noturno",ies_m_logN="IES: porte médio (log)",ies_frac_ead="IES: fração EAD",ies_log_n_cursos="IES: nº de cursos (log)")
SEC<-c("Perfis dos matriculados (+10 pp; deficiência +1 pp)","Ano e modalidade (ano vs 2020; interações)","Porte do curso",
  "Rede: categoria administrativa (ref.: Privada com fins lucrativos)","Organização acadêmica (ref.: Universidade)","Grau (ref.: Bacharelado)",
  "Área geral Cine (ref.: Negócios, administração e direito)","Contextos da IES (+1 desvio-padrão entre IES)")
rot<-function(t){
  if(t%in%names(perf))return(c(1,paste0(perf[t]," (",if(t=="p_deficiencia")"+1 pp" else "+10 pp",")")))
  if(t%in%names(ctx))return(c(8,paste0(ctx[t]," (+1 DP)")))
  if(grepl("^ano20\\d\\d$",t))return(c(2,paste0("Ano ",sub("ano","",t)," (presencial)")))
  if(t=="modalidadeEAD")return(c(2,"EAD (termo base; ver interações)"))
  if(grepl("^ano20\\d\\d:modalidadeEAD$",t))return(c(2,paste0("EAD × ",sub(":.*","",sub("ano","",t)))))
  if(t=="modalidadeEAD:log(vinculos)")return(c(2,"EAD × porte (log)"))
  if(t=="log(vinculos)")return(c(3,"Porte: log(vínculos) (×e ≈ 2,7)"))
  if(grepl("^categoria_administrativa",t))return(c(4,sub("^categoria_administrativa","",t)))
  if(grepl("^organizacao_academica",t))return(c(5,sub("^organizacao_academica","",t)))
  if(grepl("^grau_academico",t))return(c(6,sub("^grau_academico","",t)))
  if(grepl("^cine_area_geral",t)){k<-sub("^cine_area_geral","",t);stopifnot(k%in%names(cine));return(c(7,paste0(k," ",sub("Computação e Tecnologias da Informação e Comunicação \\(TIC\\)","Computação e TIC",cine[[k]]))))}
  stop("Termo inesperado da média: ",t)
}
b<-cf[parametro=="beta"&termo!="(Intercept)"]
r<-t(vapply(b$termo,rot,character(2)));b[,`:=`(sec=as.integer(r[,1]),rotulo=r[,2])]
ordem<-c(perf=0,0)  # ordem interna: perfis na ordem do código; ano/modalidade em ordem de leitura
b[,o:=match(termo,c(names(perf),"ano2021","ano2022","ano2023","ano2024","modalidadeEAD",paste0("ano",2021:2024,":modalidadeEAD"),"modalidadeEAD:log(vinculos)",names(ctx)))]
b[is.na(o),o:=seq_len(.N)+100L];setorder(b,sec,o)
b[,`:=`(rc=exp(estimativa),lo=exp(ic95_inf),hi=exp(ic95_sup))]
th<-cf[parametro=="theta"];nm<-c(logDP_media_IES="Média: IES",logDP_media_curso="Média: curso",logDP_disp_IES="Dispersão: IES",logDP_disp_curso="Dispersão: curso")
stopifnot(all(th$termo%in%names(nm)));th[,`:=`(rotulo=nm[termo],v=exp(estimativa),lo=exp(ic95_inf),hi=exp(ic95_sup))]
setorder(th,termo)  # ordem alfabetica estavel; reordenar abaixo
th<-th[match(names(nm),termo)][!is.na(termo)]

tabela<-function(b,th,secs,arq,notas,aleat=TRUE){
  b<-b[sec%in%secs];rows<-list();y<-0
  for(s in secs){bs<-b[sec==s];if(!nrow(bs))next;y<-y+1;rows[[length(rows)+1]]<-data.table(y=y,tipo="h",rotulo=SEC[s])
    for(i in seq_len(nrow(bs))){y<-y+1;rows[[length(rows)+1]]<-data.table(y=y,tipo="b",rotulo=bs$rotulo[i],rc=bs$rc[i],lo=bs$lo[i],hi=bs$hi[i])}}
  if(aleat&&nrow(th)){y<-y+1;rows[[length(rows)+1]]<-data.table(y=y,tipo="h",rotulo="Efeitos aleatórios: desvio-padrão, exp(θ)")
    for(i in seq_len(nrow(th))){y<-y+1;rows[[length(rows)+1]]<-data.table(y=y,tipo="t",rotulo=th$rotulo[i],rc=th$v[i],lo=th$lo[i],hi=th$hi[i])}}
  R<-rbindlist(rows,fill=TRUE);n<-y
  W<-12.2;x0<-0.15;xrc<-6.0;xic<-7.55;fx<-8.9;fw<-3.0           # colunas em polegadas
  rg<-range(log(c(R[tipo=="b",c(lo,hi)],1)));rg<-rg+c(-.05,.05)*diff(rg)
  tk<-c(.25,.5,.75,1,1.25,1.5,2,3,4);tk<-tk[log(tk)>=rg[1]&log(tk)<=rg[2]]
  fxp<-function(v)fx+(log(v)-rg[1])/diff(rg)*fw
  nl<-sapply(notas,function(s)length(strwrap(s,width=118)));nrow_nota<-sum(nl)+0.5
  top<-3.0  # linhas de título e cabeçalho
  H<-(n+top+nrow_nota+1)*0.31;Y<-function(y)-(y+top)
  R[,yy:=Y(y)];R[,faixa:=tipo!="h"&y%%2==0]
  g<-ggplot()+coord_cartesian(xlim=c(0,W),ylim=c(-(n+top+nrow_nota+1),0),expand=FALSE)+theme_void()+
    theme(plot.background=element_rect(fill=FUNDO,colour=NA))+
    annotate("text",x=x0,y=-.7,label="Associação com o desvínculo ou trancamento anual: razão de chances (IC 95%)",hjust=0,fontface="bold",size=6,colour=TINTA)+
    annotate("text",x=x0,y=-1.55,label="Modelo dispre, parte da média (logit subjacente). Efeito de cada coeficiente com os demais fixos.",hjust=0,size=4.3,colour=TINTA2)+
    geom_rect(data=R[faixa==TRUE],aes(xmin=0,xmax=W,ymin=yy-.5,ymax=yy+.5),fill=FAIXA)+
    geom_rect(data=R[tipo=="h"],aes(xmin=0,xmax=W,ymin=yy-.5,ymax=yy+.5),fill="#e2e8f0")+
    geom_text(data=R[tipo=="h"],aes(x=x0,y=yy,label=rotulo),hjust=0,fontface="bold",size=4.6,colour=TINTA)+
    geom_text(data=R[tipo!="h"],aes(x=x0+.25,y=yy,label=rotulo),hjust=0,size=4.5,colour=TINTA)+
    geom_text(data=R[tipo!="h"],aes(x=xrc,y=yy,label=fmt(rc)),hjust=1,size=4.5,colour=TINTA)+
    geom_text(data=R[tipo!="h"],aes(x=xic,y=yy,label=paste0(fmt(lo),"–",fmt(hi))),hjust=.5,size=4.5,colour=TINTA2)
  # cabecalhos de coluna
  g<-g+annotate("text",x=c(x0+.25,xrc,xic,fx+fw/2),y=-(top-.3),label=c("Termo","RC / DP","IC 95%","RC em escala log"),hjust=c(0,1,.5,.5),fontface="bold",size=4.5,colour=TINTA)+
    annotate("segment",x=0.1,xend=W-.1,y=-(top-.05),yend=-(top-.05),colour=TINTA2,linewidth=.4)
  fb<-R[tipo=="b"];yb0<-min(R[tipo=="b",yy]);ybe<-min(R$yy)-.5
  g<-g+annotate("segment",x=fxp(1),xend=fxp(1),y=-(top+.5),yend=min(R$yy)+ -.0-0.5*0+0,colour=TINTA2,linewidth=.5,linetype="dashed")+
    geom_segment(data=fb,aes(x=fxp(lo),xend=fxp(hi),y=yy,yend=yy),colour=AZUL,linewidth=.9)+
    geom_point(data=fb,aes(x=fxp(rc),y=yy),colour=AZUL,size=2.6)+
    annotate("segment",x=fxp(min(tk)),xend=fxp(max(tk)),y=min(R$yy)-.7,yend=min(R$yy)-.7,colour=TINTA2,linewidth=.4)+
    annotate("segment",x=fxp(tk),xend=fxp(tk),y=min(R$yy)-.7,yend=min(R$yy)-.9,colour=TINTA2,linewidth=.4)+
    annotate("text",x=fxp(tk),y=min(R$yy)-1.3,label=fmt(tk,2),size=3.9,colour=TINTA2)
  yn<-min(R$yy)-2.3
  for(s in notas){l<-strwrap(s,width=118);g<-g+annotate("text",x=x0,y=yn-(seq_along(l)-1)*.85,label=l,hjust=1*0,vjust=1,size=3.9,colour=TINTA2,lineheight=1);yn<-yn-length(l)*.85-.15}
  ggsave(file.path(OUT,arq),g,width=W,height=H*1.0+0.6,dpi=200,bg=FUNDO)
  cat(arq,": ",nrow(R[tipo=="b"])," termos; ",W,"x",round(H+.6,1)," pol.\n",sep="")
}
n1<-"RC = exp(coeficiente) na escala do logit da média subjacente (a média da proporção truncada não é exatamente mu). Associações ecológicas contemporâneas com a proporção anual de desvinculados + trancados; não são causais nem se referem a quem saiu. Trancamento não equivale a saída definitiva."
n2<-"EAD (termo base) refere-se a 2020 e a vínculos = 1; a comparação EAD × presencial exige combiná-lo com as interações por ano e por porte. EAD × ano = mudança da razão EAD/presencial em relação a 2020; EAD × porte = variação dessa razão por porte (log). Contextos da IES padronizados (+1 DP entre IES), perfis em +10 pp (deficiência +1 pp)."
n3<-"Efeitos aleatórios: exp(θ) é o desvio-padrão dos interceptos (não é razão de chances). Coeficientes da dispersão estão em coeficientes.csv, fora desta tabela. IC de Wald exploratório, condicional à aproximação de Laplace."
tabela(b,th,1:8,"tabela_coeficientes.png",c(n1,n2,n3))
tabela(b,th,c(1,2,4),"tabela_coeficientes_principais.png",c(n1,n2),aleat=FALSE)
