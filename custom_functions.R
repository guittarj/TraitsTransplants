# custom functions

# ipak function: install and load multiple R packages.
# check to see if packages are installed. Install them if they are not, then load them into the R session.

loadpax <- function(pkg){
    new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
    if (length(new.pkg)) 
        install.packages(new.pkg, dependencies = TRUE)
    sapply(pkg, require, character.only = TRUE)
}


# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)

  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    ncol = cols, nrow = ceiling(numPlots/cols))
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

cwm <- function (cover.row, trait) {
  # Calculate Community Weighted Mean
  # row:   row of cover data
  # trait: trait of interest (must be a column name in trait.data)

  x <- trait.data[, trait]
  weighted.mean(x[!is.na(x)], w = cover.row[!is.na(x)])
}

dist.fun <- function(cover, trait) {
  # calculate distance matrix for 2+ communities
  # cover: a dataframe with communities (rows) and species abundances (cols)
  # trait: trait of interest, determines how distance is calculated

  if(trait == 'veg') {                                
    dmat <- as.matrix(vegdist(cover))                   # Bray-Curtis distance
  } else {                                             
    dmat <- apply(cover, 1, function(x) cwm(x, trait))  # Euclidean distance
    dmat <- as.matrix(dist(dmat))
  }
  return(dmat)
}

comp.fun <- function (dmat, dmat.meta, trait) {
  # determine mean distance between a turf and its local controls
  # dmat: distance matrix
  # dmat.meta: metadata for matrix
  # trait: trait used to calculate distance matrix
  
  comp <- transmute(dmat.meta, trait  = trait,
                               turfID = turfID, 
                               year   = Year)
  for (i in 1:nrow(dmat)) {
    controls <- with(dmat.meta, 
                  turf.year[destSiteID == destSiteID[i] & 
                            Year       == Year[i] &
                            TTtreat  %in% c('TT1', 'TTC') & 
                            turfID     != turfID[i]])
    comp$dist.tt1[i] <- mean(dmat[i, controls])
  }
  return(comp)
}

stat_sum_df <- function(fun, geom = 'crossbar', ...) {
  # For plotting
  stat_summary(fun.data = fun, geom = geom, width = 0.2, ...)
}

stat_sum_single <- function(fun, geom = 'point', ...) {
  # For plotting
  stat_summary(fun.y = fun, geom = geom, ...)
}

fmt <- function() {
  # For plotting
  function(x) as.character(round(x, 2))
}

process.comm = function(comm, trait) {
  # Takes a simulation file, and calculates distances to field controls

  comp.sims <- rep(NA, nrow(comm))

  for(i in 1:nrow(comm)) {

    # combine simturf and controls
    simturf <- paste(comm[i, 'turfID'], comm[i, 'year'], sep = '_')
    controls <- with(cover.meta, as.character(turf.year)[TTtreat  %in% c('TTC','TT1') &
                     destSiteID == destSiteID[turf.year == simturf] &
                     Year       == comm[i, 'year'] &
                     turf.year  != simturf])
    
    # Discard unnecessasry rows (won't affect distance measures)
    cover.sim <- cover[c(simturf, controls), ]
    cover.sim[simturf, ] <- as.numeric(comm[i, colnames(cover)])

    # Calculate distance
    comp.sim <- dist.fun(cover.sim, trait)
    comp.sims[i] <- mean(comp.sim[simturf, controls])
  }

  comp.sims <- data.frame(trait = trait, comm[, c('turfID', 'year', 'm', 'd')], dist.tt1 = comp.sims, reps = 1)
  return(comp.sims)
}

probfixes = function (vec, probs = names(probs), fixes = probs) {
  # A function that resolves any naming inconsitencies in a vector (vec)

  for(i in 1:length(probs)) {
    vec <- gsub(probs[i], fixes[i], vec)
  }
  return(vec)
}

facet_wrap_labeller <- function(gg.plot,labels = NULL) {
  #works with R 3.0.1 and ggplot2 0.9.3.1
  require(gridExtra)

  g <- ggplotGrob(gg.plot)
  gg <- g$grobs      
  strips <- grep("strip_t", names(gg))

  for(ii in seq_along(labels))  {
    modgrob <- getGrob(gg[[strips[ii]]], "strip.text", 
                       grep=TRUE, global=TRUE)
    gg[[strips[ii]]]$children[[modgrob$name]] <- editGrob(modgrob,label=labels[ii])
  }

  g$grobs <- gg
  class(g) = c("arrange", "ggplot",class(g)) 
  return(g)
}

# print list of loaded functions
print(data.frame(Custom_Functions = 
  c('loadpax: install+load multiple packages',
    'multiplot: aggregate multiple ggplots',
    'cwm: calculate community weighted means',
    'dist.fun: get distances among communities',
    'comp.fun: get distances to local control',
    'stat_sum_df: a plotting function', 
    'stat_sum_single: a plotting function', 
    'fmt: a plotting function',
    'process.comm: Calculates distances to controls',
    'probfixes: corrects taxonomic inconsitencies',
    'facet_wrap_labeller: use expressions in facet_wrap')))