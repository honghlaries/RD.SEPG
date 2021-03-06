## clean 
rm(list = ls())
library(dplyr);library(tidyr);library(ggplot2)

## Functions 
datareadln <- function() {
  read.csv("./Data/Result_PlantTillerGrowthSummary.csv") %>%
    dplyr::inner_join(read.csv("./Data/meta_PlantSampleList.csv"), by = c("SplNo" = "SplNo")) %>%
    dplyr::right_join(read.csv("./Data/meta_Quadrat.csv"), by = c("QudNo" = "QudNo")) %>%
    dplyr::inner_join(read.csv("./Data/meta_SiteGroup.csv"), by = c("SiteID" = "SiteID"))%>%
    dplyr::filter(group != "NV") %>% 
    dplyr::select(SiteID,SplMonth,group,QudNo,
                  Density = Number,
                  Height = Height_mean,
                  BasalDiameter = BsDmr_mean,
                  LeafThickness = LvThk_mean,
                  LeafCount = LvCt_mean,
                  GreenLeafCount = LvCtG_mean,
                  FallenLeafCount = LvCtY_mean,
                  AboveGroundBiomass = TlrWg_mean,
                  LeafBiomass = LvWgG_mean,
                  StemBiomass = StWg_mean,
                  SeedRate = Seed_rate) 
}

meanseCal <- function(dat) { ## calulate and output mean and se
  se <- function(v) {
    if(length(v) < 2) {NA} else {sd(v, na.rm = T)/sqrt(length(v)-sum(is.na(v)))}
  }
  dat %>%
    dplyr::group_by(SiteID, group, SplMonth) %>%
    dplyr::summarise(Density_avg = mean(Density,na.rm = T),Density_se = se(Density),
                     Height_avg = mean(Height,na.rm = T),Height_se = se(Height),
                     BasalDiameter_avg = mean(BasalDiameter,na.rm = T),BasalDiameter_se = se(BasalDiameter),
                     LeafThickness_avg = mean(LeafThickness,na.rm = T),LeafThickness_se = se(LeafThickness),
                     LeafCount_avg = mean(LeafCount,na.rm = T),LeafCount_se = se(LeafCount),
                     GreenLeafCount_avg = mean(GreenLeafCount,na.rm = T),GreenLeafCount_se = se(GreenLeafCount),
                     FallenLeafCount_avg = mean(FallenLeafCount,na.rm = T),FallenLeafCount_se = se(FallenLeafCount),
                     AboveGroundBiomass_avg = mean(AboveGroundBiomass,na.rm = T),AboveGroundBiomass_se = se(AboveGroundBiomass),
                     LeafBiomass_avg = mean(LeafBiomass,na.rm = T),LeafBiomass = se(LeafBiomass),
                     StemBiomass_avg = mean(StemBiomass,na.rm = T),StemBiomass_se = se(StemBiomass),
                     SeedRate_avg = mean(SeedRate,na.rm = T),SeedRate_se = se(SeedRate)) %>%
    write.csv("growth/log/GrowthTraits.csv")
}

shapiroTest <- function(dat, tag, grouplv, SplMonthlv) {
  dat <- dat %>% filter(traits == tag) %>% filter(!is.na(resp))
  shapiro <- NULL
  for(i in 1:length(grouplv)) {
    for(j in 1:length(SplMonthlv)) {
      subdat <- dat %>% filter(group == grouplv[i]) %>% filter(SplMonth == SplMonthlv[j])
      result <- stats::shapiro.test(subdat$resp)
      shapiro <- rbind(shapiro, data.frame(tag = tag,
                                           group = grouplv[i],
                                           SplMonth = SplMonthlv[j],
                                           W = result$statistic,
                                           Pvalue = result$p.value))
    }
  }
  shapiro
}

modelCompare <- function(dat, tag, fact, log = TRUE) {
  library(lme4)
  dat <- dat %>% filter(traits == tag) %>% filter(!is.na(resp))
  formulaList <- NULL; modlog <- NULL
  for (j in 1:length(fact)) {
    formulaList <- c(formulaList, as.formula(paste("resp","~",fact[j])))
  }
  mod.champion <- lmer(formulaList[[1]], data = dat)
  for (i in 2:length(formulaList)) {
    mod.challenger <- lmer(formulaList[[i]], data = dat)
    comp <- anova(mod.champion, mod.challenger)
    mod <- as.character(formula(mod.champion@call))[3]
    modp <- as.character(formula(mod.challenger@call))[3]
    modlog <- rbind(modlog, cbind(comp,
                                  model = c(paste(tag,"~",mod),paste(tag,"~",modp)),
                                  ref = c("champion", "challenger"),
                                  result = if (comp$AIC[2] < comp$AIC[1]) c("", "Win") else c("Win", ""),
                                  time = date())) 
    if (comp$AIC[2] < comp$AIC[1]) mod.champion <- mod.challenger
  }
  if (!file.exists("growth/log/GrowthTraitsModel.csv")) {
    write.table(t(c("Df","AIC","BIC","Loglik","deviance","Chisq","ChiDf","Pr(>Chisq)","model","ref","result","time")),
                file = "growth/log/GrowthTraitsModel.csv", sep = ",", row.names = F, col.names = F)
  } 
  if(log) {
    write.table(modlog, append = T, sep = ",", row.names = F, col.names = F,
                file = "growth/log/GrowthTraitsModel.csv")
  }
  mod.champion
}

plotFEsim2 <- function (fe, modinf = NULL, level = 0.95, stat = "mean", sd = TRUE,  
                        sigmaScale = NULL, oddsRatio = FALSE, glv, gcode, theme) {
  ## plotFEsim2, modified from merTools::plotFEsim
  if (!missing(sigmaScale)) {
    fe[, "sd"] <- fe[, "sd"]/sigmaScale
    fe[, stat] <- fe[, stat]/sigmaScale
  }
  fe[, "sd"] <- fe[, "sd"] * qnorm(1 - ((1 - level)/2))
  fe[, "ymax"] <- fe[, stat] + fe[, "sd"]
  fe[, "ymin"] <- fe[, stat] - fe[, "sd"]
  hlineInt <- 0
  if (oddsRatio == TRUE) {
    fe[, "ymax"] <- exp(fe[, "ymax"])
    fe[, stat] <- exp(fe[, stat])
    fe[, "ymin"] <- exp(fe[, "ymin"])
    hlineInt <- 1
  }
  xvar <- "term"
  fe$term <- as.character(fe$term)
  fe$term <- factor(fe$term, levels = fe[order(fe[, stat]), 1])
  
  gcol <- rep("black",length(levels(fe$term)))
  gsize <- rep(1,length(levels(fe$term)))
  gltp <- rep(2,length(levels(fe$term)))
  for (m in 1: length(glv)) {
    gcol[levels(fe$term) == glv[m]] <- gcode[m]
    gsize[levels(fe$term) == glv[m]] <- 4
  }
  llv <- c("Nov","Jul","EA","NV","WE")
  for (m in 1: length(llv)) {
    gltp[levels(fe$term) == llv[m]] <- 1
  }
  p <- ggplot(aes_string(x = xvar, y = stat, ymax = "ymax", ymin = "ymin"), data = fe) + 
    geom_hline(yintercept = hlineInt, color = I("red")) +
    geom_point(aes(col = term, size = term)) + 
    labs(x = "Group", y = "Fixed Effect") + 
    scale_color_manual("Group", breaks = levels(fe$term), values = gcol) + 
    scale_size_manual("Group", breaks = levels(fe$term), values = gsize) + 
    coord_flip() + 
    theme
  if (sd) {
    p <- p + geom_errorbar(aes(linetype = term), width = 0.2) +
      scale_linetype_manual("Group", breaks = levels(fe$term), values = gltp)
  }
  p
}

plotFEsim2facet <- function (fe, modinf = NULL, level = 0.95, stat = "mean", sd = TRUE,  
                             sigmaScale = NULL, oddsRatio = FALSE, taglv = NA, glv, gcode, ncol, theme) {
  ## plotFEsim2facet, modified from merTools::plotFEsim
  if (!missing(sigmaScale)) {
    fe[, "sd"] <- fe[, "sd"]/sigmaScale
    fe[, stat] <- fe[, stat]/sigmaScale
  }
  fe[, "sd"] <- fe[, "sd"] * qnorm(1 - ((1 - level)/2))
  fe[, "ymax"] <- fe[, stat] + fe[, "sd"]
  fe[, "ymin"] <- fe[, stat] - fe[, "sd"]
  hlineInt <- 0
  if (oddsRatio == TRUE) {
    fe[, "ymax"] <- exp(fe[, "ymax"])
    fe[, stat] <- exp(fe[, stat])
    fe[, "ymin"] <- exp(fe[, "ymin"])
    hlineInt <- 1
  }
  xvar <- "term"
  fe$term <- factor(fe$term, levels = c("WE:Jul","WE:Nov","WE","Jul","Nov","EA","EA:Jul","EA:Nov"))
  if (!is.na(taglv)) { 
    tmp <- NULL
    for (k in 1: length(taglv)) {
      tmp <- rbind(tmp, dplyr::filter(fe, tag == taglv[k]))
    }
    fe <- tmp
    fe$tag <- factor(fe$tag, levels = taglv)
  }
  gcol <- rep("black",length(levels(fe$term)))
  gsize <- rep(1,length(levels(fe$term)))
  gltp <- rep(0.5,length(levels(fe$term)))
  for (m in 1: length(glv)) {
    gcol[levels(fe$term) == glv[m]] <- gcode[m]
    gsize[levels(fe$term) == glv[m]] <- 2
  }
  llv <- c("Nov","Jul","EA","NV","WE")
  for (m in 1: length(llv)) {
    gltp[levels(fe$term) == llv[m]] <- 1
  }
  p <- ggplot(aes_string(x = xvar, y = stat, ymax = "ymax", ymin = "ymin"), data = fe) + 
    geom_hline(yintercept = hlineInt, color = I("red")) +
    geom_point(aes(col = term, size = term)) + 
    labs(x = "Group", y = "Fixed Effect") + 
    scale_color_manual("Group", breaks = levels(fe$term), values = gcol) + 
    scale_size_manual("Group", breaks = levels(fe$term), values = gsize) + 
    facet_wrap(~ tag, ncol = ncol, scales = "free") +
    # coord_flip() + 
    theme
  if (sd) {
    p <- p + geom_errorbar(aes(alpha = term), width = 0.2) +
      scale_alpha_manual("Group", breaks = levels(fe$term), values = gltp)
  }
  if(!missing(modinf)) {
    p <- p + geom_text(x = 2, y = 5, label = "abc")
  }
  p
}

multiGrowthMod <- function(dat, fact, SplMonthlv, grouplv, glv, gcode, 
                           tag = NULL, suffix = "", archiplot = TRUE, log = TRUE) {
  library(merTools);library(lsmeans);library(multcompView);library(car);library(ggplot2);library(lattice);library(tidyr)
  fe.g <- NULL; re.g <- NULL; modinf.g <- NULL; shapiro.g <- NULL; posthoc.g <- NULL; modavo.g <- NULL; 
  resid.g <- NULL;
  theme_HL <- theme_bw() + theme(legend.position = "none",axis.text = element_text(angle = 30))
  if(missing(tag)) tag <- unique(dat$traits)
  for (i in 1:length(tag)) {
    
    #shapiro
    shapiroTest(dat = dat, tag = tag[i], grouplv = grouplv, SplMonthlv = SplMonthlv) -> shapiro
    print(shapiro); 
    shapiro.g <- rbind(shapiro.g, cbind(shapiro, tag[i]))
    
    #mod choose
    mod <- modelCompare(dat = dat, tag = tag[i], fact = fact,log = log)
    paste(tag[i],"~",as.character(formula(mod@call))[3]) -> modinf
    print(modinf); 
    modinf.g <- rbind(modinf.g, cbind(modinf, tag[i]))
    
    #anova
    nyma <- anova(mod)
    nymb <- Anova(mod)
    cbind(nyma[,c(1,2,3)],Chisq = nymb[,1], Fvalue = nyma[,4],Pr = nymb[,3], 
          FixedFact = row.names(nyma), tag = tag[i]) -> modavo; print(modavo); 
    modavo.g <- rbind(modavo.g, cbind(modavo, tag[i]))
    
    #posthoc
    modfact <- strsplit(as.character(formula(mod@call))[3],"+", fixed = TRUE)[[1]]
    if (grepl('*', modfact[1], fixed = TRUE)) {
      modfact <- strsplit(modfact[1],"*", fixed = TRUE)[[1]]
    }
    modfxfact <-  modfact[!grepl('(', modfact, fixed = TRUE)]
    modfxfm <- if(length(modfxfact) == 1) {modfxfact[1]} else {paste(modfxfact[1],modfxfact[2],sep = "+")}
    posthoc <-lsmeans::cld(lsmeans(object = mod, adjust = "tukey",
                                   specs = as.formula(paste("pairwise~",modfxfm))),
                           Letters = LETTERS) 
    print(posthoc) 
    if(length(modfxfact) == 1) {
      if (modfxfact == "group ") {
        posthoc <- cbind(posthoc, SplMonth = NA)
      } else {
        if (modfxfact == "SplMonth ") {
          posthoc <- cbind(posthoc, group = NA)
        } else {stop("Kidding me?")}
      }
    }
    posthoc.g <- rbind(posthoc.g,cbind(posthoc, tag[i]))
    
    # fe
    fe <- FEsim(mod)
    fe.g <- rbind(fe.g, cbind(tag = tag[i],fe))
    ggsave(plot = plotFEsim2(fe%>% filter(term != "(Intercept)") %>%
                               mutate(term = gsub("group","",term)) %>% 
                               mutate(term = gsub("SplMonth","",term)),
                             glv = glv, gcode = gcode, theme = theme_HL), 
           paste("growth/plot/",tag[i],"_Fixeff.png",sep=""),
           width = 6, height = 4)
    #re
    re <- REsim(mod)
    re.g <- rbind(re.g, cbind(tag = tag[i],re))
    ggsave(plot = merTools::plotREsim(re), 
           paste("growth/plot/",tag[i],"_Raneff.png",sep=""),
           width = 6, height = 4)
    #resid
    png(paste("growth/plot/",tag[i],"_diag_resid.png",sep=""), 
        width = 30, height = 20, units = "cm", res = 600)
    print(plot(mod, type = c("p", "smooth")))
    dev.off()
    png(paste("growth/plot/",tag[i],"_diag_residQQ.png",sep=""), 
        width = 30, height = 20, units = "cm", res = 600)
    print(qqmath(mod, id = 0.05))
    dev.off()
    #png(paste("growth/plot/",tag[i],"_diag_zeta.png",sep=""), 
    #    width = 30, height = 20, units = "cm", res = 600)
    #something using xyplot
    #dev.off()
    #png(paste("growth/plot/",tag[i],"_diag_dens.png",sep=""), 
    #    width = 30, height = 20, units = "cm", res = 600)
    #something using densityplot
    #dev.off()
    #png(paste("growth/plot/",tag[i],"_diag_pair.png",sep=""), 
    #    width = 30, height = 20, units = "cm", res = 600)
    #something using splom
    #dev.off()
    stats::shapiro.test(resid(mod)) -> resid
    resid.g <- rbind(resid.g, 
                     data.frame(tag = tag[i],
                                W = resid$statistic,
                                Pvalue = resid$p.value))
  }
  ## output
  if (log) {write.csv(x = fe.g, file = paste("growth/log/FixedEff",suffix,".csv",sep = ""), row.names = F)
    write.csv(x = re.g, file = paste("growth/log/RandomEff",suffix,".csv",sep = ""), row.names = F)
    write.csv(x = modinf.g, file = paste("growth/log/ModelChoice",suffix,".csv",sep = ""), row.names = F) 
    write.csv(x = shapiro.g, file = paste("growth/log/ShapiroRawData",suffix,".csv",sep = ""), row.names = F) 
    write.csv(x = posthoc.g, file = paste("growth/log/Posthoc",suffix,".csv",sep = ""), row.names = F) 
    write.csv(x = modavo.g, file = paste("growth/log/ModelAnova",suffix,".csv",sep = ""), row.names = F) 
    write.csv(x = resid.g, file = paste("growth/log/ShapiroResid",suffix,".csv",sep = ""), row.names = F)
  }
  "DONE!"
}

singlePlot <- function(dat,tag) {
  dat <- dat %>% filter(trait == tag)
  ggplot(data = dat) + 
    geom_bar(aes(x = SplMonth, y = mean, fill = SiteID),stat = "identity", position = position_dodge(0.9)) +
    geom_errorbar(aes(x = SplMonth, ymin = mean - se, ymax = mean + se, fill = SiteID),
                  position = position_dodge(0.9), width = 0.3) +
    xlab("") + ylab(tag) +
    scale_fill_discrete("Location",breaks = c("EA1","EA2"),labels = c("Seaward(EA1)","Landward(EA2)")) 
}

## Basic Stat information 
datareadln() %>% write.csv("growth/log/GrowthTraitsRAW.csv", row.names = F)
meanseCal(datareadln())

## LMM fiting and ploting 
multiGrowthMod(dat = datareadln() %>% gather(key = traits, value = resp, Density:SeedRate),
                fact = c("group + (1|SiteID)",
                         "SplMonth + (1|SiteID)",
                         "group + (1|SiteID:SplMonth)",
                         "SplMonth + (1|SiteID:SplMonth)",
                         "group + (1|SiteID) + (1|SiteID:SplMonth)",
                         "SplMonth + (1|SiteID) + (1|SiteID:SplMonth)",
                         "group + SplMonth + (1|SiteID)",
                         "group + SplMonth + (1|SiteID:SplMonth)",
                         "group + SplMonth + (1|SiteID) + (1|SiteID:SplMonth)",
                         "group * SplMonth + (1|SiteID)",
                         "group * SplMonth + (1|SiteID:SplMonth)",
                         "group * SplMonth + (1|SiteID) + (1|SiteID:SplMonth)"),
                SplMonthlv = c("Apr","Jul","Nov"), grouplv = c("EA","CL","WE"), 
                glv = c("EA","WE"), gcode = c("#31B404","#013ADF"),
               tag = c("Density","Height","BasalDiameter","AboveGroundBiomass"), suffix = "_ajn")

multiGrowthMod(dat = datareadln() %>% 
                 gather(key = traits, value = resp, Density:SeedRate) %>%
                 filter(SplMonth != "Apr"),
               fact = c("group + (1|SiteID)",
                        "SplMonth + (1|SiteID)",
                        "group + (1|SiteID:SplMonth)",
                        "SplMonth + (1|SiteID:SplMonth)",
                        "group + (1|SiteID) + (1|SiteID:SplMonth)",
                        "SplMonth + (1|SiteID) + (1|SiteID:SplMonth)",
                        "group + SplMonth + (1|SiteID)",
                        "group + SplMonth + (1|SiteID:SplMonth)",
                        "group + SplMonth + (1|SiteID) + (1|SiteID:SplMonth)",
                        "group * SplMonth + (1|SiteID)",
                        "group * SplMonth + (1|SiteID:SplMonth)",
                        "group * SplMonth + (1|SiteID) + (1|SiteID:SplMonth)"),
               SplMonthlv = c("Jul","Nov"), grouplv = c("EA","CL","WE"), 
               glv = c("EA","WE"), gcode = c("#31B404","#013ADF"),
               tag = c("LeafThickness","GreenLeafCount","LeafBiomass","StemBiomass"), suffix = "_jn")

multiGrowthMod(dat = datareadln() %>% 
                 gather(key = traits, value = resp, Density:SeedRate) %>%
                 filter(SplMonth == "Nov"),
               fact = c("group + (1|SiteID)",
                        "group + (1|SiteID)"),
               SplMonthlv = c("Nov"), grouplv = c("EA","CL","WE"), 
               glv = c("EA","WE"), gcode = c("#31B404","#013ADF"),
               tag = c("FallenLeafCount","SeedRate"), suffix = "_n")

## Gather ploting 
ggsave(plot = plotFEsim2facet(read.csv("growth/log/FixedEff_ajn.csv") %>% 
                                filter(term != "(Intercept)") %>% 
                                mutate(term = gsub("group","",term)) %>% 
                                mutate(term = gsub("SplMonth","",term)),
                              glv = c("EA","WE"), gcode = c("#31B404","#013ADF"), ncol = 2,
                              theme = theme_bw() + theme(legend.position = "none",
                                                         axis.text = element_text(size= 4,angle = 30),
                                                         axis.title = element_text(size= 6),
                                                         strip.text = element_text(size= 6))), 
       "growth/plot/Fixeff_ajn.png",
       width = 6, height = 4, dpi = 600)

ggsave(plot = plotFEsim2facet(read.csv("growth/log/FixedEff_jn.csv") %>% 
                                filter(term != "(Intercept)") %>% 
                                mutate(term = gsub("group","",term)) %>% 
                                mutate(term = gsub("SplMonth","",term)),
                              glv = c("EA","WE"), gcode = c("#31B404","#013ADF"), ncol = 2,
                              theme = theme_bw() + theme(legend.position = "none",
                                                         axis.text = element_text(size= 4,angle = 30),
                                                         axis.title = element_text(size= 6),
                                                         strip.text = element_text(size= 6))), 
       "growth/plot/Fixeff_jn.png",
       width = 6, height = 4, dpi = 600)

ggsave(plot = plotFEsim2facet(read.csv("growth/log/FixedEff_n.csv") %>% 
                                filter(term != "(Intercept)") %>% 
                                mutate(term = gsub("group","",term)) %>% 
                                mutate(term = gsub("SplMonth","",term)),
                              glv = c("EA","WE"), gcode = c("#31B404","#013ADF"), ncol = 2,
                              theme = theme_bw() + theme(legend.position = "none",
                                                         axis.text = element_text(size= 4,angle = 30),
                                                         axis.title = element_text(size= 6),
                                                         strip.text = element_text(size= 6))), 
       "growth/plot/Fixeff_n.png",
       width = 6, height = 2, dpi = 600)

ggsave(plot = plotFEsim2facet(rbind(read.csv("growth/log/FixedEff_ajn.csv"),
                                    read.csv("growth/log/FixedEff_jn.csv"),
                                    read.csv("growth/log/FixedEff_n.csv")) %>% 
                                filter(term != "(Intercept)") %>% 
                                mutate(term = gsub("group","",term))%>% 
                                mutate(term = gsub("SplMonth","",term))%>% 
                                mutate(tag = factor(tag, levels = c("Density","Height","BasalDiameter","AboveGroundBiomass",
                                                                      "LeafThickness","GreenLeafCount","LeafBiomass","StemBiomass",
                                                                      "FallenLeafCount","SeedRate"))),
                              glv = c("EA","WE"), gcode = c("#31B404","#013ADF"), ncol = 4,
                              theme = theme_bw() + theme(legend.position = "none",
                                                         axis.text = element_text(size= 4,angle = 30),
                                                         axis.title = element_text(size= 6),
                                                         strip.text = element_text(size= 6))), 
       "growth/plot/Fixeff_all.png",
       width = 6, height = 5, dpi = 600)

ggsave(plot = plotFEsim2facet(rbind(read.csv("growth/log/FixedEff_ajn.csv"),
                                    read.csv("growth/log/FixedEff_jn.csv"),
                                    read.csv("growth/log/FixedEff_n.csv")) %>% 
                                filter(term != "(Intercept)") %>% 
                                mutate(term = gsub("group","",term))%>% 
                                mutate(term = gsub("SplMonth","",term))%>% 
                                mutate(tag = factor(tag, levels = c("Density","Height","BasalDiameter","AboveGroundBiomass",
                                                                    "LeafThickness","GreenLeafCount","LeafBiomass","StemBiomass",
                                                                    "FallenLeafCount","SeedRate"))),
                              glv = c("EA","WE"), gcode = c("#31B404","#013ADF"), ncol = 4,
                              theme = theme_bw() + theme(legend.position = "none",
                                                         axis.text = element_text(size= 4,angle = 30),
                                                         axis.title = element_text(size= 6),
                                                         strip.text = element_text(size= 6))), 
       "growth/plot/Fixeff_all.eps",
       width = 6, height = 5)

## Homogeneity of variance 
datareadln() %>%
  dplyr::group_by(group, SplMonth) %>%
  dplyr::summarise(Density_avg = mean(Density,na.rm = T),
                   Density_sd = sd(Density,na.rm = T), 
                   Density_rsd = Density_sd/Density_avg,
                   AboveGroundBiomass_avg = mean(AboveGroundBiomass,na.rm = T),
                   AboveGroundBiomass_sd = sd(AboveGroundBiomass,na.rm = T),
                   AboveGroundBiomass_rsd = AboveGroundBiomass_sd/AboveGroundBiomass_avg
  ) %>% write.csv("growth/log/Hov.csv")

library(car)
#Density
dat <- datareadln()
plot(Density ~ group, data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "EA" | group == "CL"))
leveneTest(Density ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "EA" | group == "CL"))
plot(Density ~ group, data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "WE" | group == "CL"))
leveneTest(Density ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "WE" | group == "CL"))

plot(Density ~ group, data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "EA" | group == "CL"))
leveneTest(Density ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "EA" | group == "CL"))
plot(Density ~ group, data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "WE" | group == "CL"))
leveneTest(Density ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "WE" | group == "CL"))

plot(Density ~ group, data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "EA" | group == "CL"))
leveneTest(Density ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "EA" | group == "CL"))
plot(Density ~ group, data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "WE" | group == "CL"))
leveneTest(Density ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "WE" | group == "CL"))


#AbovegroundBiomass

plot(AboveGroundBiomass ~ group, data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "EA" | group == "CL"))
leveneTest(AboveGroundBiomass ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "EA" | group == "CL"))
plot(AboveGroundBiomass ~ group, data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "WE" | group == "CL"))
leveneTest(AboveGroundBiomass ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Apr")%>%dplyr::filter(group == "WE" | group == "CL"))

plot(AboveGroundBiomass ~ group, data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "EA" | group == "CL"))
leveneTest(AboveGroundBiomass ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "EA" | group == "CL"))
plot(AboveGroundBiomass ~ group, data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "WE" | group == "CL"))
leveneTest(AboveGroundBiomass ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Jul")%>%dplyr::filter(group == "WE" | group == "CL"))

plot(AboveGroundBiomass ~ group, data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "EA" | group == "CL"))
leveneTest(AboveGroundBiomass ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "EA" | group == "CL"))
plot(AboveGroundBiomass ~ group, data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "WE" | group == "CL"))
leveneTest(AboveGroundBiomass ~ group, center = mean,
           data = datareadln()%>%filter(SplMonth == "Nov")%>%dplyr::filter(group == "WE" | group == "CL"))

## Site - level ANOVA comparing 
dat <- datareadln() %>% filter(SplMonth =="Nov")
library(car);library(lsmeans)

plot(SeedRate ~ SiteID, data = dat)
leveneTest(SeedRate ~ SiteID, data = dat, center = mean)
mod <- lm(SeedRate ~ SiteID, data = dat)
anova(mod)
lsmeans::cld(lsmeans(mod, adjust = "tukey", specs = "SiteID"), Letters = LETTERS)

plot(FallenLeafCount ~ SiteID, data = dat)
leveneTest(FallenLeafCount ~ SiteID, data = dat, center = mean)
mod <- lm(FallenLeafCount ~ SiteID, data = dat)
anova(mod)
lsmeans::cld(lsmeans(mod, adjust = "tukey", specs = "SiteID"), Letters = LETTERS)

## comparing before/after the dyke
dat <- datareadln() %>% 
  dplyr::filter(group == "EA") %>% 
  dplyr::select(SiteID, SplMonth, Density, Height, BasalDiameter, AboveGroundBiomass)  %>% 
  tidyr::gather(trait, value, Density:AboveGroundBiomass) 

ggplot(data = dat%>%
         dplyr::group_by(SiteID,SplMonth,trait) %>%
         dplyr::summarise(mean = mean(value,na.rm = T),se = (sd(value,na.rm = T)/sum(!is.na(value))))) + 
  geom_bar(aes(x = SplMonth, y = mean, fill = SiteID),stat = "identity", position = position_dodge(0.9)) +
  geom_errorbar(aes(x = SplMonth, ymin = mean - se, ymax = mean + se, fill = SiteID),
                position = position_dodge(0.9), width = 0.3) +
  xlab("") + ylab("") +
  scale_fill_discrete("Location",breaks = c("EA1","EA2"),labels = c("Seaward(EA1)","Landward(EA2)")) + 
  facet_wrap(facets = ~ trait, nrow = 2, scales = "free") 
ggsave(filename = "growth/plot/bar_growth_EA.png")

singlePlot(dat%>%
             dplyr::group_by(SiteID,SplMonth,trait) %>%
             dplyr::summarise(mean = mean(value,na.rm = T),se = (sd(value,na.rm = T)/sum(!is.na(value)))),
           "Density") 
ggsave(filename = "growth/plot/bar_density_EA.jpg")

singlePlot(dat%>%
             dplyr::group_by(SiteID,SplMonth,trait) %>%
             dplyr::summarise(mean = mean(value,na.rm = T),se = (sd(value,na.rm = T)/sum(!is.na(value)))),
           "Height") 
ggsave(filename = "growth/plot/bar_height_EA.png")

singlePlot(dat%>%
             dplyr::group_by(SiteID,SplMonth,trait) %>%
             dplyr::summarise(mean = mean(value,na.rm = T),se = (sd(value,na.rm = T)/sum(!is.na(value)))),
           "BasalDiameter") 
ggsave(filename = "growth/plot/bar_basalDiameter_EA.png")

singlePlot(dat%>%
             dplyr::group_by(SiteID,SplMonth,trait) %>%
             dplyr::summarise(mean = mean(value,na.rm = T),se = (sd(value,na.rm = T)/sum(!is.na(value)))),
           "AboveGroundBiomass") 
ggsave(filename = "growth/plot/bar_abovegroundBiomass_EA.png")

for (i in 1:length(unique(dat$trait))) {
  tag <- unique(dat$trait)[i]
  print(tag)
  anova(lm(value~SiteID*SplMonth, data = dat[dat$trait == tag,])) %>%
    print()
}
tapply(X = dat$value, INDEX = dat$trait,
       FUN = function(x) {with(data = x, anova(lm(value~SiteID * SplMonth)))})



#plot for Density - tiller biomass
dat <- datareadln()
dat1 <- dat %>%
  group_by(SiteID, SplMonth) %>%
  summarise(D.mean = mean(Density),
            D.sd = sd(Density),
            W.mean = mean(AboveGroundBiomass),
            W.sd = sd(AboveGroundBiomass)) %>%
  mutate(group = substr(SiteID, 1,2))
dat2 <- dat %>%
  group_by(group, SplMonth) %>%
  summarise(D.mean = mean(Density),
            D.sd = sd(Density),
            W.mean = mean(AboveGroundBiomass),
            W.sd = sd(AboveGroundBiomass)) 


ggplot() +
  geom_point(data = dat, stat = "identity", 
             aes(x = AboveGroundBiomass, y = Density, colour = SplMonth)) +
  geom_path(data = dat2, aes(y = D.mean, x = W.mean, group = group),
            col = "black", size = 0.7, arrow = arrow(length = unit(0.1, "inches"))) +
  #geom_point(data = pdata1, stat = "identity", 
  #           aes(x = W.mean, y = N.mean, colour = col), 
  #           size = 3, alpha =0.5) +
  geom_errorbar(data = dat2,
                aes(x = W.mean, ymax = D.mean + D.sd, ymin = D.mean - D.sd,
                    colour = SplMonth),
                stat = "identity", size = .5, width = 0) +
  geom_errorbarh(data = dat2,
                 aes(y = D.mean, x = W.mean, xmax = W.mean + W.sd, xmin = W.mean - W.sd, 
                     colour = SplMonth),
                 stat = "identity", size = .5, height = 0) +
  xlab("Tiller Mean Abground Biomass(g)") + ylab("Tiller Density") +
  scale_colour_discrete("Month") +
  facet_wrap(~SiteID, ncol = 4) +
  theme_bw() +
  theme(legend.position = "right",
        axis.title = element_text(size = 8),
        axis.text = element_text(size = 8),
        strip.text = element_text(size = 8))
ggsave("plot/path.Density-Biomass_site.png", width = 8, height = 5, dpi = 600)

ggplot() +
  geom_point(data = dat, stat = "identity", 
             aes(x = AboveGroundBiomass, y = Density, colour = SplMonth)) +
  geom_path(data = dat2, aes(y = D.mean, x = W.mean, group = group),
            col = "black", size = 0.7, arrow = arrow(length = unit(0.1, "inches"))) +
  #geom_point(data = pdata1, stat = "identity", 
  #           aes(x = W.mean, y = N.mean, colour = col), 
  #           size = 3, alpha =0.5) +
  geom_errorbar(data = dat2,
                aes(x = W.mean, ymax = D.mean + D.sd, ymin = D.mean - D.sd,
                    colour = SplMonth),
                stat = "identity", size = .5, width = 0) +
  geom_errorbarh(data = dat2,
                 aes(y = D.mean, x = W.mean, xmax = W.mean + W.sd, xmin = W.mean - W.sd, 
                     colour = SplMonth),
                 stat = "identity", size = .5, height = 0) +
  xlab("Tiller Mean Abground Biomass(g)") + ylab("Tiller Density") +
  scale_colour_discrete("Month") +
  facet_wrap(~group, ncol = 4, scales = "free") +
  theme_bw() +
  theme(legend.position = "right",
        axis.title = element_text(size = 8),
        axis.text = element_text(size = 8),
        strip.text = element_text(size = 8))
ggsave("plot/path.Density-Biomass_group.eps", width = 8, height = 3)
ggsave("plot/path.Density-Biomass_group.png", width = 8, height = 3, dpi = 600)

# Height structure
dat <- read.csv("./Data/Result_PlantTillerGrowth.csv") %>%
  dplyr::inner_join(read.csv("./Data/meta_PlantSampleList.csv"), by = c("SplNo" = "SplNo")) %>%
  dplyr::right_join(read.csv("./Data/meta_Quadrat.csv"), by = c("QudNo" = "QudNo")) %>%
  dplyr::inner_join(read.csv("./Data/meta_SiteGroup.csv"), by = c("SiteID" = "SiteID"))%>%
  dplyr::filter(group != "NV") 

dat$SplMonth <- as.character(dat$SplMonth)
dat$SplMonth[dat$SplMonth == "Nov"] <-  "Nov, -Breeding"
dat$SplMonth[dat$Seed == 1] <- "Nov,+Breeding"
dat$SplMonth <- as.factor(dat$SplMonth)

mean <- dat %>%
  select(group,QudNo,SplMonth,Height) %>%
  group_by(SplMonth,group,QudNo) %>%
  summarise(H1 = sum(Height <= 30),
            H2 = sum(30 < Height & Height <= 60),
            H3 = sum(60 < Height & Height <= 90),
            H4 = sum(90 < Height & Height <= 120),
            H5 = sum(120 < Height & Height <= 250),
            TOT = H1 + H2 + H3 + H4 + H5) %>%
  mutate(h1 = H1/TOT,
         h2 = H2/TOT,
         h3 = H3/TOT,
         h4 = H4/TOT,
         h5 = H5/TOT) %>%
  group_by(SplMonth,group) %>%
  summarise(h1 = mean(h1),
            h2 = mean(h2),
            h3 = mean(h3),
            h4 = mean(h4),
            h5 = mean(h5))%>%
  gather(Hgroup, mean, h1:h5)

se <- dat %>%
  select(group,QudNo,SplMonth,Height) %>%
  group_by(SplMonth,group,QudNo) %>%
  summarise(H1 = sum(Height <= 30),
            H2 = sum(30 < Height & Height <= 60),
            H3 = sum(60 < Height & Height <= 90),
            H4 = sum(90 < Height & Height <= 120),
            H5 = sum(120 < Height & Height <= 250),
            TOT = H1 + H2 + H3 + H4 + H5 ) %>%
  mutate(h1 = H1/TOT,
         h2 = H2/TOT,
         h3 = H3/TOT,
         h4 = H4/TOT,
         h5 = H5/TOT
  ) %>%
  group_by(SplMonth,group) %>%
  summarise(h1 = sd(h1)/sqrt(n()),
            h2 = sd(h2)/sqrt(n()),
            h3 = sd(h3)/sqrt(n()),
            h4 = sd(h4)/sqrt(n()),
            h5 = sd(h5)/sqrt(n()))%>%
  gather(Hgroup, se, h1:h5)

se$se[se$se == 0] <- NA

Hstru <- inner_join(mean, se, by = c("SplMonth" = "SplMonth", 
                                     "group" = "group", 
                                     "Hgroup" = "Hgroup"))

ggsave("growth/plot/out.HeightStructure.eps",
       ggplot(data = Hstru)+
         geom_bar(aes(x = Hgroup, y = mean, fill = group),
                  position = "dodge",stat = "identity") +
         geom_errorbar(aes(x = Hgroup, ymax = mean+se, ymin = mean-se, group = group),
                       stat = "identity", col = "black", 
                       position = position_dodge(width=0.9),
                       width = 0.25, size = 0.3) + 
         facet_grid(group~SplMonth) + 
         scale_y_continuous("Percent",limits = c(-0.05,1), breaks = c(0,0.2,0.4,0.6,0.8,1.0),
                            labels = c("0%","20%","40%","60%","80%","100%")) +
         scale_x_discrete("Height",labels = c("0-30","30-60","60-90",
                                              "90-120","120+")) +
         scale_fill_manual("Location",
                           values = c("#B45F04", "#31B404", "#013ADF"))+
         coord_flip()+
         theme_bw() + 
         theme(panel.grid = element_blank(),
               legend.position = "bottom",
               strip.background = element_blank(),
               legend.key = element_blank(),
               axis.text = element_text(size = 9,angle = 20),
               axis.title = element_text(size = 10),
               strip.text = element_text(size = 10),
               legend.text = element_text(size = 8),
               legend.title = element_text(size = 10)),
       width = 7.2, height = 6,scale = 1)
