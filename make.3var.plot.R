#!/usr/bin/env Rscript

# Make an image from surface weather data for analysis using
#  machine learning image analysis tools.
# Three variables - one per colour channel.

library(getopt)
library(png)

opt = getopt(matrix(c(
  'output',     'o', 2, "character",  # Output file name
  'year',       'y', 2, "integer",
  'month',      'm', 2, "integer",
  'day',        'd', 2, "integer",
  'hour',       'h', 2, "numeric",
  'resolution', 'r', 2, "numeric",
  'class',      's', 2, "character",  # '20CR', 'CMIP5', 'ERAI', ...
  'version',    'v', 2, "character",  # for 20CR
  'model',      'n', 2, "character",  # for CMIP
  'experiment', 'x', 2, "character",
  'member',     'e', 2, "integer"     # for ensemble datasets
), byrow=TRUE, ncol=4))
if (is.null(opt$output)) stop("Output not specified")
if (is.null(opt$year))   stop("Year not specified")
if (is.null(opt$month))  stop("Month not specified")
if (is.null(opt$day))    stop("Day not specified")
if (is.null(opt$hour))   stop("Hour not specified")
# What data to use (20CR, ERAI, CMIP, ...)
if (is.null(opt$class)) opt$class<-'20CR'
# For 20CR, also need a version
if(opt$class=='20CR') {
  if (is.null(opt$version)) opt$version<-'3.5.1' # 2c
  if (is.null(opt$member))  opt$member<-1
} else {
  stop("Only 20CR currently supported")
}

# Load the data
plot.data<-list()

if(opt$class=='20CR') {
  library(GSDF.TWCR)
  plot.data[['prate']]<-TWCR.get.members.slice.at.hour('prate',
                                                       opt$year,
                                                       opt$month,
                                                       opt$day,
                                                       opt$hour,
                                                       version=opt$version)
  plot.data[['prate']]<-GSDF.select.from.1d(plot.data[['prate']],
                                            'ensemble',
                                            opt$member)
  # Normalise
  w<-which(plot.data[['prate']]$data<0)
  if(length(w)>0) plot.data[['prate']]$data[w]<-0
  plot.data[['prate']]$data[]<-sqrt(plot.data[['prate']]$data)
  plot.data[['prate']]$data[]<-pmax(0,pmin(1,
                          plot.data[['prate']]$data/0.05))
  plot.data[['prmsl']]<-TWCR.get.members.slice.at.hour('prmsl',
                                                       opt$year,
                                                       opt$month,
                                                       opt$day,
                                                       opt$hour,
                                                       version=opt$version)
  plot.data[['prmsl']]<-GSDF.select.from.1d(plot.data[['prmsl']],
                                            'ensemble',
                                            opt$member)
  plot.data[['prmsl']]$data[]<-pmax(0,pmin(1,
                         (plot.data[['prmsl']]$data-95000)/10000))
  plot.data[['air.2m']]<-TWCR.get.members.slice.at.hour('air.2m',
                                                       opt$year,
                                                       opt$month,
                                                       opt$day,
                                                       opt$hour,
                                                       version=opt$version)
  plot.data[['air.2m']]<-GSDF.select.from.1d(plot.data[['air.2m']],
                                            'ensemble',
                                            opt$member)
  t2n<-TWCR.get.slice.at.hour('air.2m',
                               opt$year,
                               opt$month,
                               opt$day,
                               opt$hour,
                               version='3.4.1',
                               type='normal')
  t2n<-GSDF.regrid.2d(t2n,plot.data[['air.2m']]) 
  plot.data[['air.2m']]$data[]<-plot.data[['air.2m']]$data-t2n$data
  plot.data[['air.2m']]$data[]<-pmax(0,pmin(1,
                         (plot.data[['air.2m']]$data+15)/30))
}

# Make the plot (as small as possible)
if(!is.null(opt$resolution)) {
  x.points<-seq(-180,180,opt$resolution)
  y.points<-seq(-90,90,opt$resolution)
  full.y<-matrix(data=rep(y.points,length(x.points)),
                          ncol=length(x.points),byrow=F)
  full.x<-matrix(data=rep(x.points,length(y.points)),
                          ncol=length(x.points),byrow=T)
  image<-array(data=0,dim=c(length(y.points),length(x.points),3))
  # Write temperature to the red channel
  image[,,1]<-GSDF.interpolate.ll(plot.data$air.2m,
                                  as.vector(full.y),
                                  as.vector(full.x))
  # Precip to the green channel
  image[,,2]<-GSDF.interpolate.ll(plot.data$prate,
                                  as.vector(full.y),
                                  as.vector(full.x))
  # Pressure to the blue channel
  image[,,3]<-GSDF.interpolate.ll(plot.data$prmsl,
                                  as.vector(full.y),
                                  as.vector(full.x))
  # Output the result
  writePNG(image,target=opt$output)
} else {
   stop("Native images not yet supported")
}
   
