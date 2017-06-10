#! /usr/bin/env ./node_modules/.bin/coffee
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
cluster   = require 'cluster'

config    = require './config.coffee'

start = (port) ->
  shouldIProxy = (url) ->
    doNotProxy = false
    _.forEach config.blockExpressions, (value, index, collection) ->
      doNotProxy = value.test(url)
      # if we ge one hit that says 'do not proxy' we're done
      false if doNotProxy
    return not doNotProxy

  proxy = httpProxy.createProxyServer()

  proxy.on 'error', (error, req, res) ->
    log.error "error while requesting #{req.url.split('?')[0]} -> #{error}"

  server = http.createServer (req, res) ->
    if shouldIProxy(req.url)
      log.info "#{req.method} #{req.url}"
      cluster.worker.send({type:'url', 'url':req.url})
      proxy.web(req, res, { target: req.url })
    else
      log.info "skipping blocked url: #{req.url}"
      res.writeHead "200"
      res.end ""

  # handle an secure connection request, we're just hooking the
  # client up to the thing that they've requested
  server.on 'connect', (req, clientSocket, head) ->
    return if not shouldIProxy(req.url)
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

  log.info "starting proxy worker on port #{port} with pid #{process.pid}"
  server.listen(port)

module.exports.start = start
