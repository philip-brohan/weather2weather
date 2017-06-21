#!/usr/bin/env Rscript

# Use the ML model repeatedly on its own output - effectivley using it
#  as a free-running GCM.

# Probably this would be much faster if run within tensorflow, rather
#  than restarting TF for each step.

library(getopt)

opt = getopt(matrix(c(
  'start.file',     'i', 2, "character",
  'model.dir',      'm', 2, "character",
  'output.dir',     'o', 2, "character",
  'steps',          's', 2, "integer"
), byrow=TRUE, ncol=4))
if ( is.null(opt$start.file) )  stop("Start.file not specified") 
if ( is.null(opt$output.dir) ) stop("Output directory not specified") 
if ( is.null(opt$model.dir) ) stop("Model not specified") 
if ( is.null(opt$steps) ) opt$steps<-120 # 30 days

if(!file.exists(opt$output.dir)) dir.create(opt$output.dir,recursive=TRUE)

start.file<-opt$start.file
for(step in seq(1,opt$steps)) {

   unlink(sprintf("%s/0.jpg",opt$output.dir))
   file.copy(from=start.file,
             to=sprintf("%s/0.jpg",opt$output.dir))
   unlink(start.file)

# Run the model on that 1 input file in test mode
   cmd<-sprintf("python weather2weather.py --mode test --input_dir=%s --output_dir=%s --checkpoint=%s",
                opt$output.dir,
                opt$output.dir,
                opt$model.dir)
   es<-system(cmd)
   if(es!=0) stop(sprintf("Failed execution of %s",cmd))
   opf<-sprintf("%s/images/0-outputs.png",opt$output.dir)
   if(!file.exists(opf)) stop(sprintf("Model failed at step %d",step))
   file.copy(from=opf,to=sprintf("%s/video.%04d.png",opt$output.dir,step))
   if(step==0) { # Add the initialisation state
     file.copy(from=sprintf("%s/images/0-inputs.png",opt$output.dir),
               to=sprintf("%s/video.0000.png",opt$output.dir))
   }
   # Make the next start file
   start.file<-sprintf("%s/start.jpg",opt$output.dir)
   if(file.exists(start.file)) unlink(start.file)
   cmd<-sprintf("montage %s %s -tile 2x1 -geometry 256x256\\!+0+0 %s\n",
                  opf,opf,start.file)
   es<-system(cmd)
   if(es!=0) stop(sprintf("Failed execution of %s",cmd))
}


