set INDIR=..\lib\
set INPREFIX=oms

set OUTDIR=.\tmp\
set OUTNAME=%INPREFIX%.min.js
set OUTFILE=%OUTDIR%%OUTNAME%

call coffee --output %OUTDIR% --map --compile %INDIR%%INPREFIX%.coffee

@set JARPATH=c:\Dev\closure-compiler\compiler.jar

java -jar "%JARPATH%" ^
  --compilation_level ADVANCED_OPTIMIZATIONS ^
  --js "%OUTDIR%%INPREFIX%.js" ^
  --externs google_maps_api_v3_20.js SlidingMarker.annotations.js MarkerWithGhost.annotations.js ^
  --output_wrapper ;(function(){%%output%%}).call(this); ^
  > "%OUTFILE%"

echo /* %date% %time% */ >> "%OUTFILE%"

rem cp $OUTFILE ../../gh-pages/bin
rem cp ${OUTDIR}${INPREFIX}.js ../../gh-pages/bin