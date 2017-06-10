#! /usr/bin/env ./node_modules/.bin/coffee
# vim: ft=coffee

path      = require 'path'
fs        = require 'fs'
_         = require 'lodash'
log       = require 'simplog'
cluster   = require 'cluster'

worker    = require './worker.coffee'
config    = require './config.coffee'

stillRunning = true
numCpus = require('os').cpus().length

logFilePath = process.env.LOG_FILE_NAME || './proxy.log'
urlLogStream = fs.createWriteStream logFilePath

logUrl = (msg) ->
  urlLogStream.write("#{msg}\n")


process.on 'uncaughtException', (err) ->
    log.error err

process.on 'SIGHUP', () ->
  urlLogStream.end()
  urlLogStream = fs.createWriteStream logFilePath


port = process.env.PORT || 1212

if cluster.isMaster
  shutdownRoutine = () ->
    log.info "starting shutdown"
    urlLogStream.end()
    stillRunning = false
    exitWhenWorkersDone = () ->
      log.info "shutting down proxy"
      process.exit
    cluster.on 'exit', _.after(numCpus, exitWhenWorkersDone)
    _.each cluster.workers, (worker) -> worker.send('shutdown')
    
  process.on(signal, shutdownRoutine) for signal in ['SIGTERM', 'SIGINT']

  hookWorkerShutdown = (worker) ->
    worker.on 'exit', (code, signal) ->
      log.info "worker #{process.pid} exiting"
      log.info "worker #{process.pid} shutting down" unless stillRunning

  log.info "starting proxy on port #{port}"
  log.info "starting #{numCpus} workers"
  hookWorkerShutdown(cluster.fork()) for [1..numCpus]

  # handle worker shutdowns by restarting them if the proxy is supposed to
  # be stillRunning
  cluster.on 'exit', (worker, code, signal) ->
    if stillRunning
      log.info "restarting worker after unexpected stop"
      workerProcess = cluster.fork()
      hookWorkerShutdown workerProcess
  try
    fs.writeFileSync("/tmp/toy_proxy_#{port}.pid", "#{process.pid}")
  catch e
    log.error "failed writing pid file /tmp/toy_roxy_%s.pid\n%s", port, e
else
  worker.start(logUrl, port)
    

