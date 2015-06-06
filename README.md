love-rollbar
============
This is a library for [LÖVE](http://love2d.org) which can be used to
report errors and stacktraces to [Rollbar](http://rollbar.com) 
via a background thread.

Note that errors (such as syntax errors) which prevent your code from being
loaded will not trigger rollbar notifications.

A rollbar demo can be found here: https://rollbar.com/demo/demo/

Installation
============
Copy `love-rollbar.lua`, `json.lua` and the `luajit-request` directory to a location in your project (such as a `vendor` directory).

Luajit-request requires curl. For windows, DLL binaries are available here: https://github.com/LPGhatguy/luajit-request/releases/tag/v2.1.0

These need to be placed next to your `love.exe` during development, and next to your fused exe when you distribute your game 
( see [Game Distribution](https://github.com/LPGhatguy/luajit-request/releases/tag/v2.1.0) )

Rollbar Setup
-------------

Create an account at [Rollbar.com](http://rollbar.com), or create a new project if you have an account already. 
In your project settings, locate your project access tokens, and find your post_client_token. This is an api token with limited permissions.

You will need to pass this token to the rollbar library (see below), and you will need to distribute this token with your game.

Optionally, set up all your notification channels (hipchat/pivotal/trello/whatever) in Rollbar.

Usage
=====

```lua
local Rollbar = require('vendor.love-rollbar')

function love.load()
  -- configure rollbar
  Rollbar.access_token = 'you-api-token'
  -- optional, but helpful to distinguish between deployed code and testing code
  Rollbar.environment = 'development'
  -- optional, your game/app's version
  Rollbar.app_version = '0.0.0'
end

-- Submit errors to rollbar, and then
-- proceed with the normal LÖVE error behavior
local old_error = love.errhand
function love.errhand(message)
  Rollbar.error(message)
  old_error(message)
end
```
