#!/usr/bin/env Rscript

# pix2pix reads composites of two square images - left hand half is source
#  and right hand half is target. Pack the weather images into this format.

# Of course the validation images must be different from the training set
# Training set is 0-399
first.val.image<-400

opd<-sprintf("%s/ML/pix2pix/val/",Sys.getenv('SCRATCH'))
if(!dir.exists(opd)) dir.create(opd,recursive=TRUE)

for(i in seq(first.val.image,first.val.image+99)) {
    cmd<-sprintf("montage %s/ML/training/source/%04d.png %s/ML/training/target/%04d.png -tile 2x1 -geometry 256x256\\!+0+0 %s/%d.jpg\n",
                Sys.getenv('SCRATCH'),i,
                Sys.getenv('SCRATCH'),i,
                opd,i-first.val.image))
    system(cmd)
}
