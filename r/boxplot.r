file <- commandArgs(trailingOnly=T)[1]
print( file )
t <- read.table(
        file, 
        sep="\t",
        header=T,
        fill=T
        )

base <- sub( "(^[^.]+).*", "\\1", file )
image <- paste( base, "png", sep="." )
png( image )

p <- list(
        boxwex = 0.1,
        ylab   = "Times, s"
        )
boxplot( t, pars=p )
