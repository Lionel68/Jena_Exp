###########
#a function to generate ANOVA-like table for GLMM
######


#using PBmodcomp to do parametric bootstraping
library(pbkrtest)

#very slow for GLMM!
anova_merMod<-function(model,w=FALSE,seed=round(runif(1,0,100),0),nsim=0,fixed=TRUE){
  require(pbkrtest)
  data<-model@frame
  if(w){
    weight<-data[,which(names(data)=="(weights)")]
    data<-data[,-which(names(data)=="(weights)")]
  }
  f<-formula(model)
  resp<-as.character(f)[2]
  rand<-lme4:::findbars(f)
  rand<-lapply(rand,function(x) as.character(x))
  rand<-lapply(rand,function(x) paste("(",x[2],x[1],x[3],")",sep=" "))
  rand<-paste(rand,collapse=" + ")
  
  #generate a list of reduced model formula
  fs<-list()
  fs[[1]]<-as.formula(paste(resp,"~ 1 +",rand))
  nb_terms<-length(attr(terms(model),"term.labels"))
  if(nb_terms>1){
    #the next two line will make that the terms in the formula will add first the most important term, and the least important one at the end 
    #going first through the interactions and then through the main effects
    mat<-data.frame(term=attr(terms(model),"term.labels"),SSQ=anova(model)[,3],stringsAsFactors = FALSE)
    mat_inter<-mat[grep(":",mat$term),]
    mat_main<-mat[!rownames(mat)%in%rownames(mat_inter),]
    if(!fixed){
      mat_main<-mat_main[do.call(order,list(-mat_main$SSQ)),]
      mat_inter<-mat_inter[do.call(order,list(-mat_inter$SSQ)),]
      mat<-rbind(mat_main,mat_inter)
    }    
    for(i in 1:nb_terms){
      tmp<-c(mat[1:i,1],rand)
      fs[[i+1]]<-reformulate(tmp,response=resp)
    }      
  }

  #fit the reduced model to the data

  
  fam<-family(model)[1]$family
  if(fam=="gaussian"){
    m_fit<-lapply(fs,function(x) lmer(x,data,REML=FALSE))
  }
  else if(fam=="binomial"){
    m_fit<-lapply(fs,function(x) glmer(x,data,family=fam,weights=weight))
  }
  else{
    m_fit<-lapply(fs,function(x) glmer(x,data,family=fam))
  }

  if(nb_terms==1){
    m_fit[[2]]<-model
  }
  #compare nested model with one another and get LRT values (ie increase in the likelihood of the models as parameters are added)
  tab_out<-NULL
  
  for(i in 1:(length(m_fit)-1)){
    if(nsim>0){
      comp<-PBmodcomp(m_fit[[i+1]],m_fit[[i]],seed=seed,nsim=nsim)    
      term_added<-mat[i,1]
      #here are reported the bootstrapped p-values, ie not assuming any parametric distribution like chi-square to the LRT values generated under the null model
      #these p-values represent the number of time the simulated LRT value (under null model) are larger than the observe one
      tmp<-data.frame(term=term_added,LRT=comp$test$stat[1],p_value=comp$test$p.value[2])
      tab_out<-rbind(tab_out,tmp)
      print(paste("Variable ",term_added," tested",sep=""))
    }
    else{
      comp<-anova(m_fit[[i+1]],m_fit[[i]])
      term_added<-mat[i,1]
      tmp<-data.frame(term=term_added,LRT=comp[2,6],p_value=comp[2,8])
      tab_out<-rbind(tab_out,tmp)
    }
    
  }  
  print(paste("Seed set to:",seed))
  return(tab_out)  
}

