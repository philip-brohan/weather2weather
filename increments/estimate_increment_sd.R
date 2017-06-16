#!/usr/bin/env Rscript

# Calculate the (spatial variation of) the standard deviation of all the pressure increments (6-hr) changes
#  in the training dataset.

library(jpeg)


get.pressure.increment<-function(image.file) {
  img<-readJPEG(image.file)
  if(!all(dim(img)==c(256,512,3))) {
    stop(sprintf("Invalid image dimensions for %s",image.file))
  }
  prmsl.inc<-img[,257:512,3]-img[,1:256,3]*10000
  return(prmsl.inc)
}

incs<-array(dim=c(256,256,399))
for(i in seq(1,399)) {
  image.file<-sprintf("%s/weather2weather/p2p_format_images_for_training/%d.jpg",
                      Sys.getenv('SCRATCH'),i)
  incs[,,i]<-get.pressure.increment(image.file)
}
# Standard deviation over cases
incs<-apply(incs,c(1,2),sd)
saveRDS(incs,'increment.sd.Rdata')
