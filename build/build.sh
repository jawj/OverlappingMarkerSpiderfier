#!/bin/bash

INDIR=../lib/
INPREFIX=oms

OUTDIR=./tmp/
OUTNAME=${INPREFIX}.min.js
OUTFILE=${OUTDIR}${OUTNAME}

TEMPLATE=$(cat template.js)

coffee --output $OUTDIR --compile ${INDIR}${INPREFIX}.coffee

java -jar ~/bin/closure-compiler.jar \
  --compilation_level ADVANCED_OPTIMIZATIONS \
  --js ${OUTDIR}${INPREFIX}.js \
  --externs google_maps_api_v3_5.js \
  --output_wrapper "${TEMPLATE}" \
> $OUTFILE

cp $OUTFILE ../../gh-pages/bin
