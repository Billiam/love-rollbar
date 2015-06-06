local Rollbar = require('love-rollbar')
local config = require('config')

function love.load()
  --configure rollbar
  Rollbar.access_token = config.rollbar_api_key
  Rollbar.environment = 'development'
  Rollbar.app_version = '0.0.0'

  local foo = {}
  x=foo.bar.baz
end

local old_error = love.errhand
function love.errhand(message)
  Rollbar.error(message)
  old_error(message)
end
