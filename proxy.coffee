#! /usr/bin/env coffee
# vim: ft=coffee

httpProxy = require "http-proxy"
http      = require 'http'
https     = require 'https'
path      = require 'path'
net       = require 'net'
fs        = require 'fs'
_         = require 'lodash'
url       = require 'url'
log       = require 'simplog'


DO_NOT_BLOCK = "NO_BLOCK"
BLOCK = "BLOCK"
urlBlocks = [
  (url) ->
    if url.indexOf("ads2") is -1
      return DO_NOT_BLOCK
    else
      return BLOCK
]
  
shouldIProxy = (url) ->
  doNotProxy = false
  _.forEach urlBlocks, (value, index, collection) ->
    doNotProxy = value(req.url) is BLOCK
    # if we ge one hit that says 'do not proxy' we're done
    false if doNotProxy
  return not doNotProxy



proxy = httpProxy.createProxyServer()
proxy.on 'error', (error, req, res) ->
  log.error "error while requesting #{req.url.split('?')[0]} -> #{error}"
server = http.createServer (req, res) ->
  doNotProxy = false
  _.forEach urlBlocks, (value, index, collection) ->
    doNotProxy = value(req.url) is BLOCK
    # if we ge one hit that says 'do not proxy' we're done
    false if doNotProxy

  if doNotProxy
    log.info "skipping blocked url: #{req.url}"
    res.writeHead "200"
    res.end ""
  else
    log.info "requesting #{req.url.split('?')[0]}"
    proxy.web(req, res, { target: req.url })

# handle an secure connection request, we're just hooking the
# client up to the thing that they've requested
server.on 'connect', (req, clientSocket, head) ->
  log.info "secure connection to: #{req.url}"
  # URL is in the form 'hostname:port'
  parts = req.url.split(':', 2)
  # open a TCP connection to the remote host
  destServerConnection = net.connect parts[1], parts[0], () ->
    # respond to the client that the connection was made
    clientSocket.write("HTTP/1.1 200 OK\r\n\r\n")
    # create a tunnel between the two hosts
    clientSocket.pipe(destServerConnection)
    destServerConnection.pipe(clientSocket)

server.listen(1212)
