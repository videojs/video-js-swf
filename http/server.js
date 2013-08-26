// Super-simple HTTP server using Express for serving
// files out of the directory structure where the program
// is started

var   
  express = require('express'),
  http = require('http'),
  path = require('path'),
  server = express();

server.use(express.bodyParser());
server.use(express.directory(path.resolve('.')));
server.use(express.static(path.resolve('.')));
http.createServer(server).listen(8000);
