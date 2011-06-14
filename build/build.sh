#!/bin/bash

INDIR=../lib/
INPREFIX=oms

OUTDIR=./tmp/
OUTNAME=${INPREFIX}.min.js
OUTFILE=${OUTDIR}${OUTNAME}

coffee --output $OUTDIR --compile ${INDIR}${INPREFIX}.coffee

echo '/* Built:' $(date) '*/' > $OUTFILE
cat template.js >> $OUTFILE

java -jar ~/bin/closure-compiler.jar \
  --compilation_level ADVANCED_OPTIMIZATIONS \
  --js ${OUTDIR}${INPREFIX}.js \
  --externs google_maps_api_v3_5.js \
  --output_wrapper '(function(){%output%}).call(this);' \
>> $OUTFILE

cp $OUTFILE ../../gh-pages/bin
