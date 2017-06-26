# Make a batch of source/target images for training a 3-day ML forecast
#  on the 20CR2c data

library(lubridate)

count<-0
source.dir<-sprintf("%s/weather2weather/data_as_images/source.3days",Sys.getenv('SCRATCH'))
if(!file.exists(source.dir)) dir.create(source.dir,recursive=TRUE)
target.dir<-sprintf("%s/weather2weather/data_as_images/target.3days",Sys.getenv('SCRATCH'))
if(!file.exists(target.dir)) dir.create(target.dir,recursive=TRUE)

# These are the years I happened to have downloaded the data for
#  using individual ensemble members so it should not matter
#  which years are used.
for(year in c(2004,1996,1988,1980,1972,1964,1956,
              1948,1940,1932,1924,1916,1908,1900)) {

  c.date<-lubridate::ymd_hms(sprintf("%04d-01-01:00:00:00",year))
  while(year(c.date)==year) {
         sink('multistart.step.slm')
          cat('#!/bin/ksh -l\n')
          cat('#SBATCH --output=/scratch/hadpb/slurm_output/W2W-%j.out\n')
          cat('#SBATCH --qos=normal\n')
          cat('#SBATCH --ntasks=1\n')
          cat('#SBATCH --ntasks-per-core=2\n')
          cat('#SBATCH --time=20\n')
             while(TRUE) {
                cat(sprintf("./make.3var.plot.R --year=%d --month=%d --day=%d --hour=%d --resolution=2 --output=%s/%04d.png\n",
                            year(c.date),month(c.date),day(c.date),
                            hour(c.date),source.dir,count))
                c.date<-c.date+lubridate::days(3)
                cat(sprintf("./make.3var.plot.R --year=%d --month=%d --day=%d --hour=%d --resolution=2 --output=%s/%04d.png\n",
                            year(c.date),month(c.date),day(c.date),
                            hour(c.date),target.dir,count))
                c.date<-c.date+lubridate::days(5)
                count<-count+1
                if(count%%10==99 || year(c.date)!=year) break
              }
         
          sink()
          system('sbatch multistart.step.slm')
          unlink('multistart.step.slm')
   }
  
}
