'use strict';

const gulp = require('gulp');
const sass = require('gulp-sass');
const replace = require('gulp-replace');

gulp.task('default', () => gulp
    .src('*.sass')
    .pipe(sass({includePaths: ['node_modules']}).on('error', sass.logError))
    .pipe(replace('.markdown-body', 'body'))
    .pipe(gulp.dest('../../MacDown/Resources/Styles/'))
);
