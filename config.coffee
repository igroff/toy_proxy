# vim: set ft=coffee
fs    = require 'fs'
path  = require 'path'
_     = require 'lodash'

CONF_ROOT='.'
BLOCK_CONFIG_FILE=path.join(CONF_ROOT, 'block.conf')

loadBlockList = () ->
  if fs.existsSync(BLOCK_CONFIG_FILE)
    data = fs.readFileSync(BLOCK_CONFIG_FILE, encoding: 'utf8')
    _.map _.compact(data.split('\n')), (value) ->
      # cuz we're friendly we'll allow you to enter expressions as you would
      # a expression literal in Javascript, or as you would a string value 
      # in the constructor of RegExp
      # so if you've /*/'d it we'll take those off
      value = value[1...-1] if value[0...1] is "/" and value[-1..] is "/"
      new RegExp(value)
    
module.exports.blockExpressions = loadBlockList() || []
