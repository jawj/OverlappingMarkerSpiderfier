var gulp = require("gulp");
var coffee = require('gulp-coffee');
var gutil = require('gulp-util');
var closureCompiler = require('gulp-closure-compiler');

gulp.task('default', function() {
  gulp.src('./lib/*.coffee')
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(gulp.dest('.'))
    .pipe(closureCompiler({
      compilerPath: 'bower_components/closure-compiler/compiler.jar',
      fileName: 'oms.min.js',
      compilerFlags: {
        compilation_level: 'ADVANCED_OPTIMIZATIONS',
        externs: [
          'bower_components/google-maps-externs/google_maps_api.js'
        ],
        output_wrapper: '(function(){%output%})();',
        warning_level: 'QUIET'
      }
    }))
    .pipe(gulp.dest('.'))

});