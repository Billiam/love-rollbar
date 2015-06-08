local foreground, current_folder, work_channel, response_channel = unpack({...})

if foreground == false then
  require('love.filesystem')
  local request = require(current_folder .. 'luajit-request')

  local post_request = function(url, data)
    return request.send(url, {
      method = "POST",
      data = data 
    })
  end

  while true do
    local data = work_channel:demand()
    if data and type(data) == 'table' then
      local url, json = unpack(data)
      if url and json then
        local response = post_request(url, json)
        if response then
          if response.code == '200' then
            response_channel:push({'done', url, json, response.body})
          else
            print('Error posting to rollbar')
            print('Code: ' .. response.code)
            print(response.body)
          end
        else
          print('Could not submit rollbar data')
        end
      end
    end
  end
else
  --thread boilerplate
  local work_channel = love.thread.getChannel('updater_work')
  local response_channel = love.thread.getChannel('updater_response')
  local thread_path = foreground:gsub("%.", "/") .. ".lua"

  local current_folder = thread_path:gsub('(%.?)[^%.]+%.lua$', '%1')
  if current_folder ~= '' then
    current_folder = current_folder .. '.'
  end

  local thread

  local init_thread = function()
    if not thread then
      thread = love.thread.newThread(thread_path)
      thread:start(false, current_folder, work_channel, response_channel)
    end
  end

  local json = require(current_folder .. 'json')

  local Rollbar = {}

  -- Get a version string for Love reporting
  local framework = function()
    return string.format("LOVE %s.%s.%s under %s", love._version_major, love._version_minor, love._version_revision, love._os)
  end

  local SEVERITY = {
    critical = true,
    error = true,
    warning = true,
    info = true,
    debug = true,
  }

  local ERROR_TYPES = {
    ['attempt to .+ %(a .+ value%)'] = 'Type error',
    ['attempt to .+ a .+ value'] = 'Type error',
    ['expected %(to close'] = 'Expected to close',
    ['unfinished string near'] = 'Unfinished string',
    ['expected near'] = 'Expected near',
    ['=\' expected near'] = '= Expected near',
    ['unexpected symbol near'] = 'Unexpected near',
  }

  -- parse an error message to create an error type
  local error_type = function(message)
    if type(message) == 'string' then
      for match,e_type in pairs(ERROR_TYPES) do
        if string.find(message, match) then
          return e_type
        end
      end
    end

    return 'Unknown'
  end

  -- fetch a specific line from a file, and surrounding lines
  local read_lines = function(file, number, context)
    if not love.filesystem.isFile(file) then
      return
    end

    context = context or 0

    local pre = {}
    local post = {}
    local current

    local cur = 1
    for line in love.filesystem.lines(file) do
      local offset = number - cur
      if offset < -context then
        break;
      end

      if math.abs(offset) <= context then
        --trim line code
        line = line:match "^%s*(.-)%s*$"

        if offset == 0 then
          current = line
        elseif offset > -context and offset < 0 then
          table.insert(post, line)
        elseif offset < context and offset > 0 then
          table.insert(pre, line)
        end
      end

      cur = cur + 1
    end

    return current, pre, post
  end

  local get_stack = function()
    local stack = {}
    local depth = 1
    while true do
      local state = debug.getinfo(depth)
      if state then
        table.insert(stack, state)
      else
        break
      end

      depth = depth + 1
    end
    return stack
  end

  local frame_locals = function(level)
    local index = 1
    local variables = {}

    while true do
      local name, value = debug.getlocal(level, index)
      if not name then break end
      if type(value) == 'function' then
        value = tostring(value)
      end
      variables[name] = value

      index = index + 1
    end

    return variables
  end
  
  local parse_stack = function(stack, truncate)
    truncate = truncate or 1

    local frames = {}

    for i=#stack,truncate,-1 do
      local data = stack[i]
      local frame = {}
      frame.filename = data.source
      
      if data.currentline > 0 then
        frame.lineno = data.currentline
      end
      
      frame.method = data.name or data.short_src

      if data.what == 'Lua' and data.source:sub(1,1) == '@' then
        frame.filename = '/app/' .. data.source
        local current, pre, post = read_lines(data.source:sub(2), data.currentline)
        frame.locals = frame_locals(i + 1)

        if current then
          frame.code = current
        end

        --not currently used by rollbar
        if pre or post then
          frame.context = {}

          if pre then
            frame.context.pre = pre
          end

          if post then
            frame.context.post = post
          end 
        end
      end

      table.insert(frames, frame)
    end
    return frames
  end

  local parse_severity = function(level)
    return SEVERITY[level] and level or nil
  end

  local submit_to_rollbar = function(data)
    init_thread()

    local encoded = json.encode(data)
    work_channel:push({'https://api.rollbar.com/api/1/item/', encoded})
  end

  local generate_request = function(message, options)
    options = options or {}

    local result = {
      access_token = Rollbar.access_token,
      data = {
        environment = Rollbar.environment or 'Production',
        body = {
          trace = {
            frames = {},
            exception = {}
          }
        },
        level = "error",
        timestamp = os.time(),
        code_version = Rollbar.app_version,
        platform = 'client',
        language = 'lua',
        framework = framework(),
        server = {
          root = "/app"
        },
        notifier = {
          name = "love-rollbar",
          version = "0.0.0"
        }
      }
    }

    if options.data and type(options.data) == 'table' then
      result.data.custom = options.data
    end

    local exception = result.data.body.trace.exception

    result.data.level = parse_severity(options.level)

    exception.message = message
    exception.class = error_type(message)
    local stack = get_stack()
    result.data.body.trace.frames = parse_stack(stack, 6)

    return result
  end

  local rollbar_call = function(notification_type, message, options)
    if not Rollbar.access_token then
      print('Rollbar access token has not been set')
      return
    end

    options = options or {}
    options.level = options.level or notification_type

    local result = generate_request(message, options)
    submit_to_rollbar(result)
  end

  for notification_type in pairs(SEVERITY) do
    Rollbar[notification_type] = function(message, options)
      rollbar_call(notification_type, message, options)
    end
  end

  return Rollbar
end