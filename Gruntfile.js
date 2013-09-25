module.exports = function(grunt) {
  var pkg, semver, version, verParts, uglify;

  semver = require('semver');
  pkg = grunt.file.readJSON('package.json');

  verParts = pkg.version.split('.');
  version = {
    full: pkg.version,
    major: verParts[0],
    minor: verParts[1],
    patch: verParts[2]
  };
  version.majorMinor = version.major + '.' + version.minor;

  // Project configuration.
  grunt.initConfig({
    pkg: pkg,

    qunit: {
      source: ['test/index.html'],
      minified: ['test/minified.html'],
      minified_api: ['test/minified-api.html']
    },
    karma: {
      options: {
        configFile: 'tests/karma.conf.js'
      },
      dev: {
        configFile: 'tests/karma.conf.js',
        autoWatch: true
      },
      ci: {
        configFile: 'tests/karma.conf.js',
        autoWatch: false
      }
    }
  });

  grunt.loadNpmTasks('grunt-karma');

  // Default task.
  grunt.registerTask('default', ['jshint', 'less', 'build', 'minify', 'dist']);
  // Development watch task
  grunt.registerTask('dev', ['jshint', 'less', 'build', 'qunit:source']);
  grunt.registerTask('test', ['jshint', 'less', 'build', 'minify', 'qunit']);

};
