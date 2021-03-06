love-rollbar
============
[![Error Tracking](https://d26gfdfi90p7cf.cloudfront.net/rollbar-badge.144534.o.png)](https://rollbar.com)

This is a library for [LÖVE](http://love2d.org) which can be used to
report errors and stacktraces to [Rollbar](http://rollbar.com)
via a background thread.

Note that errors (such as syntax errors) which prevent your code from being
loaded will not trigger Rollbar notifications.

A Rollbar demo can be found here: https://rollbar.com/demo/demo/

Installation
============
Copy `love-rollbar.lua`, `json.lua` and the `luajit-request` directory to a location in your project (such as a `vendor` directory).

Luajit-request requires curl. For windows, DLL binaries are available here: https://github.com/LPGhatguy/luajit-request/releases/tag/v2.1.0

These need to be placed next to your `love.exe` during development, and next to your fused exe when you distribute your game
( see [Game Distribution](https://love2d.org/wiki/Game_Distribution) )

Rollbar Setup
-------------

Create an account at [Rollbar.com](http://rollbar.com), or create a new project if you have an account already.
In your project settings, locate your project access tokens, and find your post_client_token. This is an api token with limited permissions.

You will need to pass this token to the Rollbar library (see below), and you will need to distribute this token with your game.

Optionally, set up all your notification channels (hipchat/pivotal/trello/whatever) in Rollbar.

Usage
=====

### Rollbar.error(message, options)
Send an error message and traceback to Rollbar.
##### Parameters
* `message`: (**string**) An arbitrary error message
* `options`: (**table**) A table of options with the following keys (optional)
  * `level`: (**string**) [_default=error_] The error level to report. <br> May be one of `critical`, `error`, `warning`, `info`, `debug` (optional)
  * `data` : (**table**) Any extra data to pass to Rollbar for your error. (optional)

### Rollbar.debug(message, options)
### Rollbar.info(message, options)
### Rollbar.warning(message, options)
### Rollbar.critical(message, options)

Same as Rollbar.error, but using the relevant error level.

Example
=======
```lua
local Rollbar = require('vendor.love-rollbar')

function love.load()
  -- configure Rollbar
  Rollbar.access_token = 'your-api-token'
  -- optional, but helpful to distinguish between deployed code and testing code
  Rollbar.environment = 'development'
  -- optional, your game/app's version
  Rollbar.app_version = '0.0.0'

  Rollbar.error('informative message', {level = "debug"})
end

-- Submit errors to rollbar, and then
-- proceed with the normal LÖVE error behavior
local old_error = love.errhand
function love.errhand(message)
  Rollbar.error(message)
  old_error(message)
end
```
