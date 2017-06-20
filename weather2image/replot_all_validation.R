#!/usr/bin/env Rscript

library(getopt)

opt = getopt(matrix(c(
  'input.dir',      'i', 2, "character",
  'output.dir',     'o', 2, "character"
), byrow=TRUE, ncol=4))
if ( is.null(opt$input.dir) )  stop("Input directory not specified") 
if ( is.null(opt$output.dir) ) stop("Output directory not specified") 

if(!file.exists(opt$output.dir)) dir.create(opt$output.dir,recursive=TRUE)
sink(sprintf("%s/index.html",opt$output.dir))
cat("<html><body><table cellspacing=10 border=1>\n")
for(case in seq(0,99)) {
  of<-sprintf("%s/%04d.png",opt$output.dir,case)
  cmd<-sprintf("./weather2image/replot.p2p.image.panels.comparison.R --forecast=%s/%d-outputs.png --input=%s/%d-inputs.png --target=%s/%d-targets.png --output=%s",
               opt$input.dir,case,
               opt$input.dir,case,
               opt$input.dir,case,
               of)
  system(cmd)
  if(!file.exists(of)) stop(sprintf("Creation failed for %s",of))
  cat(sprintf("<tr><td>%d</td><td><img src=%s></td></tr>",case,of))
}
cat("</table></body></html>\n")
sink()


