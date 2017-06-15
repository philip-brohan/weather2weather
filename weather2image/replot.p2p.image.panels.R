#!/usr/bin/env Rscript 

# Convert a p2p packed image into something a human can look at
# 4 panels - composite, air.2m, prmsl, & prate

library(GSDF)
library(GSDF.WeatherMap)
library(grid)
library(getopt)
library(jpeg)

opt = getopt(c(
  'image',   'i', 2, "character",
  'left',    'l', 2, "boolean",
  'output',  'o', 2, "character",
  'label',   'c', 2, "character"
))
if ( is.null(opt$image) ) stop("Image file not specified") 
if ( is.null(opt$left) )  opt$left<-TRUE
if ( is.null(opt$output) ) stop("Output file not specified") 

Imagedir<-dirname(opt$output)
if(!file.exists(Imagedir)) dir.create(Imagedir,recursive=TRUE)

Options<-WeatherMap.set.option(NULL)
Options<-WeatherMap.set.option(Options,'land.colour',rgb(100,100,100,255,
                                                       maxColorValue=255))
Options<-WeatherMap.set.option(Options,'sea.colour',rgb(150,150,150,255,
                                                       maxColorValue=255))
Options<-WeatherMap.set.option(Options,'ice.colour',rgb(250,250,250,255,
                                                       maxColorValue=255))
Options<-WeatherMap.set.option(Options,'background.resolution','high')
Options<-WeatherMap.set.option(Options,'wrap.spherical',F)

Options$mslp.base=101325                    # Base value for anomalies
Options$mslp.range=50000                    # Anomaly for max contour
Options$mslp.step=500                       # Smaller -> more contours
#Options$mslp.tpscale=500                    # Smaller -> contours less transparent
Options$mslp.lwd=1
Options$precip.colour=c(0,0.2,0)
Options$label.xp=0.995

unpack.image<-function(image.file) {
  img<-readJPEG(image.file)
  if(!all(dim(img)==c(256,512,3))) {
    stop(sprintf("Invalid image dimensions for %s",image.file))
  }
  if(opt$left) {
    img<-img[,1:256,]
  } else {
    img<-img[,257-512,]
  }
  g<-GSDF()
  g$dimensions[[1]]<-list(type='lat',
                          values=180*(0:255)/255-90)
  g$dimensions[[2]]<-list(type='lon',
                          values=360*(0:255)/255-180)
  result<-list()
  result$air.2m<-g
  result$air.2m$data<-img[,,1]*30-15
  result$prate<-g
  result$prate$data<-(img[,,2]*0.05)**2
  result$prmsl<-g
  result$prmsl$data<-img[,,3]*10000+95000
  return(result)
}


Draw.temperature<-function(temperature,Options,Trange=1) {

  Options.local<-Options
  Options.local$fog.min.transparency<-0.5
  tplus<-temperature
  tplus$data[]<-pmax(0,pmin(Trange,tplus$data))/Trange
  Options.local$fog.colour<-c(1,0,0)
  WeatherMap.draw.fog(tplus,Options.local)
  tminus<-temperature
  tminus$data[]<-tminus$data*-1
  tminus$data[]<-pmax(0,pmin(Trange,tminus$data))/Trange
  Options.local$fog.colour<-c(0,0,1)
  WeatherMap.draw.fog(tminus,Options.local)
}

Draw.pressure<-function(mslp,Options,colour=c(0,0,0)) {

  M<-GSDF.WeatherMap:::WeatherMap.rotate.pole(mslp,Options)
  #M<-GSDF:::GSDF.pad.longitude(M) # Extras for periodic boundary conditions
  lats<-M$dimensions[[GSDF.find.dimension(M,'lat')]]$values
  longs<-M$dimensions[[GSDF.find.dimension(M,'lon')]]$values
    # Need particular data format for contourLines
  maxl<-Options$lon.max+2
  if(lats[2]<lats[1] || longs[2]<longs[1] || max(longs) > maxl ) {
    if(lats[2]<lats[1]) lats<-rev(lats)
    if(longs[2]<longs[1]) longs<-rev(longs)
    longs[longs>maxl]<-longs[longs>maxl]-(maxl*2)
    longs<-sort(longs)
    M2<-M
    M2$dimensions[[GSDF.find.dimension(M,'lat')]]$values<-lats
    M2$dimensions[[GSDF.find.dimension(M,'lon')]]$values<-longs
    M<-GSDF.regrid.2d(M,M2)
  }
  if(GSDF.find.dimension(M,'lat')==1) {
     M2<-M
     M2$dimensions[[1]]<-M$dimensions[[2]]
     M2$dimensions[[2]]<-M$dimensions[[1]]
     M<-GSDF.regrid.2d(M,M2)
   }
  z<-matrix(data=M$data,nrow=length(longs),ncol=length(lats))
  contour.levels<-seq(Options$mslp.base-Options$mslp.range,
                      Options$mslp.base+Options$mslp.range,
                      Options$mslp.step)
  lines<-contourLines(longs,lats,z,
                       levels=contour.levels)
  if(!is.na(lines) && length(lines)>0) {
     for(i in seq(1,length(lines))) {
         tp<-min(1,(abs(lines[[i]]$level-Options$mslp.base)/
                    Options$mslp.tpscale))
         lt<-2
         lwd<-1
         if(lines[[i]]$level<=Options$mslp.base) {
             lt<-1
             lwd<-1
         }
         gp<-gpar(col=rgb(colour[1],colour[2],colour[3],tp),
                             lwd=Options$mslp.lwd*lwd,lty=lt)
         res<-tryCatch({
             grid.xspline(x=unit(lines[[i]]$x,'native'),
                        y=unit(lines[[i]]$y,'native'),
                        shape=1,
                        gp=gp)
             }, warning = function(w) {
                 print(w)
             }, error = function(e) {
                print(e)
             }, finally = {
                # Do nothing
             })
     }
  }
}


    i.data<-unpack.image(opt$image)
    ifile.name<-opt$output

    land<-WeatherMap.get.land(Options)
    
    t2m<-i.data$air.2m
    prmsl.T<-i.data$prmsl
    prate<-i.data$prate
 
     png(ifile.name,
             width=1080*16/9,
             height=1080,
             bg='white',
             pointsize=24,
             type='cairo')

      lon.min<-Options$lon.min
      if(!is.null(Options$vp.lon.min)) lon.min<-Options$vp.lon.min
      lon.max<-Options$lon.max
      if(!is.null(Options$vp.lon.max)) lon.max<-Options$vp.lon.max
      lat.min<-Options$lat.min
      if(!is.null(Options$vp.lat.min)) lat.min<-Options$vp.lat.min
      lat.max<-Options$lat.max
      if(!is.null(Options$vp.lat.max)) lat.max<-Options$vp.lat.max
      base.gp<-gpar(family='Helvetica',font=1,col='black')

# Composite plot in top left
    pushViewport(viewport(x=unit(0.25,'npc'),y=unit(0.75,'npc'),
                 width=unit(0.4944,'npc'),height=unit(0.49,'npc'),
                 gp=base.gp))
      grid.polygon(x=unit(c(0,1,1,0),'npc'),
                   y=unit(c(0,0,1,1),'npc'),
                   gp=gpar(fill=Options$sea.colour))

      pushViewport(dataViewport(c(lon.min,lon.max),c(lat.min,lat.max),
                                extension=0,gp=base.gp))
    
      WeatherMap.draw.land(land,Options)
      Draw.temperature(t2m,Options,Trange=10)
      WeatherMap.draw.precipitation(prate,Options)
      Draw.pressure(prmsl.T,Options,colour=c(0,0,0))
      popViewport()

    popViewport()

  # Pressure only in top right
    pushViewport(viewport(x=unit(0.75,'npc'),y=unit(0.75,'npc'),
                 width=unit(0.4944,'npc'),height=unit(0.49,'npc'),
                 gp=base.gp))
      grid.polygon(x=unit(c(0,1,1,0),'npc'),
                   y=unit(c(0,0,1,1),'npc'),
                   gp=gpar(fill=Options$sea.colour))

      pushViewport(dataViewport(c(lon.min,lon.max),c(lat.min,lat.max),
                                extension=0,gp=base.gp))
    
      WeatherMap.draw.land(land,Options)
     Draw.pressure(prmsl.T,Options,colour=c(0,0,0))
      popViewport()

    popViewport()

  # Temperature only in bottom left
    pushViewport(viewport(x=unit(0.25,'npc'),y=unit(0.25,'npc'),
                 width=unit(0.4944,'npc'),height=unit(0.49,'npc'),
                 gp=base.gp))
      grid.polygon(x=unit(c(0,1,1,0),'npc'),
                   y=unit(c(0,0,1,1),'npc'),
                   gp=gpar(fill=Options$sea.colour))

      pushViewport(dataViewport(c(lon.min,lon.max),c(lat.min,lat.max),
                                extension=0,gp=base.gp))
    
      WeatherMap.draw.land(land,Options)
      Draw.temperature(t2m,Options,Trange=10)
      popViewport()

    popViewport()

  # Precip only in bottom right
    pushViewport(viewport(x=unit(0.75,'npc'),y=unit(0.25,'npc'),
                 width=unit(0.4944,'npc'),height=unit(0.49,'npc'),
                 gp=base.gp))
      grid.polygon(x=unit(c(0,1,1,0),'npc'),
                   y=unit(c(0,0,1,1),'npc'),
                   gp=gpar(fill=Options$sea.colour))

      pushViewport(dataViewport(c(lon.min,lon.max),c(lat.min,lat.max),
                                extension=0,gp=base.gp))
    
      WeatherMap.draw.land(land,Options)
      WeatherMap.draw.precipitation(prate,Options)

      if(!is.null(opt$label)) {
        Options$label<-opt$label
        WeatherMap.draw.label(Options)
      }
      popViewport()

    popViewport()

dev.off()

