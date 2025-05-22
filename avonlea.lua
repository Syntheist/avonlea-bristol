-- Avonlea
-- the Lake of Shining Waters,
-- and the hills of stillness,
-- as A. Shirley once saw them,
-- held in this quiet box.
-- tracks the sky above
-- Prince Edward Island,
-- and brings its present
-- gently into view.

-- parameters
local show_params = false
local show_params_time = 0
local show_params_duration = 1.0 -- Display duration (seconds)

local util = require "util"
engine.name = "Avonlea" -- engine

-- Encoder assignments - easily changeable
local WIND_ENCODER = 1  -- Wind control (default: E1)
local DEPTH_ENCODER = 2 -- Depth control (default: E2)
local GLINT_ENCODER = 3 -- Glint control (default: E3)

-- Include modules
local avonlea = include("lib/avonlea_engine") -- Sound engine
local moon_calc = include("lib/moon_calculator")
local visual = include("lib/avonlea_visual")
local weather = include("lib/weather")

-- Check if file exists, create if not
local function check_file_exists(file)
  local f = io.open(file, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

-- Location information for Green Gables area
local LATITUDE = 46.49300   -- Latitude (North)
local LONGITUDE = -63.38729 -- Longitude (West)
local ELEVATION = 4         -- Elevation (m)
local VIEW_AZIMUTH = 180    -- View direction (180=South)
local FOV = 120             -- Field of view (degrees)

-- Moon drawing settings
local MOON_SIZE = 6    -- Moon diameter (pixels) - reduced size
local current_date = { -- Initial date/time
  year = 2024,
  month = 5,
  day = 20,
  hour = 22,
  minute = 0,
  second = 0,
  time_zone = -3 -- ADT (Atlantic Daylight Time)
}

-- Moon information
local moon = {
  phase = 0,        -- Moon phase (0-1)
  azimuth = 0,      -- Azimuth angle
  altitude = 0,     -- Altitude
  x = 0,            -- X coordinate on screen
  y = 0,            -- Y coordinate on screen
  visible = false,  -- Visible on screen
  shape_data = nil, -- Moon shape data
  size = MOON_SIZE  -- Moon size (for visual module)
}

-- Control flag to prevent multiple moon updates during preset changes
local updating_preset = false

-- Weather state display
local weather_state_display = {
  visible = false,
  text = "",
  show_time = 0,
  duration = 1.0  -- 1 second display
}

-- Get and set current time
function set_current_time()
  -- Get current time using standard Lua functions
  local current_timestamp = os.time()
  
  -- Apply timezone offset (ADT = UTC-3)
  local offset = current_date.time_zone * 3600
  local adjusted_timestamp = current_timestamp + offset
  
  -- Get date components
  local date_table = os.date("*t", adjusted_timestamp)
  
  -- Debug time info
  local time_str = os.date("%Y-%m-%d %H:%M:%S", adjusted_timestamp)
  print("Current system time: " .. time_str)
  print(string.format("Time components: %04d-%02d-%02d %02d:%02d:%02d", 
    date_table.year, date_table.month, date_table.day, 
    date_table.hour, date_table.min, date_table.sec))
  
  -- Update current_date structure
  current_date.year = date_table.year
  current_date.month = date_table.month
  current_date.day = date_table.day
  current_date.hour = date_table.hour
  current_date.minute = date_table.min
  
  -- Update parameters (this will trigger update_moon_data via param actions)
  updating_preset = true
  params:set("year", date_table.year)
  params:set("month", date_table.month)
  params:set("day", date_table.day)
  params:set("hour", date_table.hour)
  params:set("minute", date_table.min)
  updating_preset = false
  
  -- Update moon data once after all parameters are set
  update_moon_data()
end

-- Calculate moon position and phase
function update_moon_data()
  -- Calculate Julian date
  local jd = moon_calc.calculate_julian_date(
    current_date.year,
    current_date.month,
    current_date.day,
    current_date.hour,
    current_date.minute,
    0
  )

  -- Calculate moon phase
  moon.phase = moon_calc.calculate_moon_phase(jd)

  -- Use simplified position calculation for consistent visibility
  local position = moon_calc.calculate_simplified_position(jd, current_date.month, current_date.hour)
  moon.azimuth = position.azimuth
  moon.altitude = position.altitude

  -- Calculate screen position
  local screen_pos = moon_calc.calculate_screen_position(
    moon.azimuth,
    moon.altitude,
    VIEW_AZIMUTH,
    FOV,
    128,          -- Screen width
    64,           -- Screen height
    MOON_SIZE / 2 -- Pass radius
  )

  moon.x = screen_pos.x
  moon.y = screen_pos.y
  moon.visible = screen_pos.visible -- Always show if in view

  -- Generate moon shape data
  moon.shape_data = moon_calc.generate_moon_shape(moon.phase, MOON_SIZE)

  -- Automatically map moon data to sound parameters (always enabled)
  -- Map moon data to depth parameter (range 0.3-0.8)
  local moon_depth = util.linlin(0, 1, 0.3, 0.8, moon.phase)
  params:set("depth", moon_depth)

  -- Map moon altitude to spatial parameter (range 0.2-0.8)
  local moon_glint = util.linlin(0, 90, 0.2, 0.8, math.max(0, moon.altitude))
  params:set("glint", moon_glint)

  -- Display debug information
  local date_str = string.format("%04d-%02d-%02d %02d:%02d",
    current_date.year,
    current_date.month,
    current_date.day,
    current_date.hour,
    current_date.minute)
  print("=== Moon update at " .. date_str .. " ===")
  print(string.format("Location: Lat=%.5f, Long=%.5f, View=%d°", LATITUDE, LONGITUDE, VIEW_AZIMUTH))
  print(string.format("Julian Date: %.5f", jd))
  print(string.format("Moon phase: %.2f", moon.phase))
  print(string.format("Moon position: Azimuth=%.2f°, Altitude=%.2f°", moon.azimuth, moon.altitude))
  print(string.format("Screen position: X=%.2f, Y=%.2f", moon.x, moon.y))
  print(string.format("Moon visible: %s", moon.visible and "YES" or "NO"))

  -- Display moon parameter mapping information
  local moon_depth = util.linlin(0, 1, 0.3, 0.8, moon.phase)
  local moon_glint = util.linlin(0, 90, 0.2, 0.8, math.max(0, moon.altitude))
  print(string.format("Mapped to synth params - Depth: %.2f, Glint: %.2f", moon_depth, moon_glint))
end

function init()
  -- Initialize sound engine
  avonlea.add_params()
  avonlea.init()

  -- Add wind parameter (connect with engine's wind parameter)
  params:add_separator("Visual Parameters")

  -- Add date and time settings
  params:add_separator("Moon Settings")

  params:add_number("year", "Year", 2020, 2030, current_date.year)
  params:set_action("year", function(x)
    if not updating_preset then
      current_date.year = x; update_moon_data()
    end
  end)

  params:add_number("month", "Month", 1, 12, current_date.month)
  params:set_action("month", function(x)
    if not updating_preset then
      current_date.month = x; update_moon_data()
    end
  end)

  params:add_number("day", "Day", 1, 31, current_date.day)
  params:set_action("day", function(x)
    if not updating_preset then
      current_date.day = x; update_moon_data()
    end
  end)

  params:add_number("hour", "Hour", 0, 23, current_date.hour)
  params:set_action("hour", function(x)
    if not updating_preset then
      current_date.hour = x; update_moon_data()
    end
  end)

  params:add_number("minute", "Minute", 0, 59, current_date.minute)
  params:set_action("minute", function(x)
    if not updating_preset then
      current_date.minute = x; update_moon_data()
    end
  end)

  -- Time sync button
  params:add_trigger("use_current_time", "Use Current Time")
  params:set_action("use_current_time", function() set_current_time() end)

  -- Initialize moon data
  update_moon_data()

  -- Moon info display
  params:add_option("show_moon_info", "Show Moon Info", { "No", "Yes" }, 2)

  -- Initialize visual module
  visual.init(moon, params)

  -- Initialize weather module
  weather.init()

  -- Connect visual module and sound engine
  avonlea.connect_visual(visual)

  -- Initialize engine commands
  clock.run(function()
    -- Wait for complete engine initialization
    clock.sleep(0.5) -- Increased delay for weather system

    -- Initialize wind parameter
    engine.wind(params:get("wind"))
    print("Wind parameter initialized with: " .. params:get("wind"))

    -- Initialize other sound parameters
    engine.depth(params:get("depth"))
    engine.glint(params:get("glint"))
    engine.gain(params:get("gain"))
    
    -- Now update weather (after engine is ready)
    avonlea.update_weather()
  end)

  -- Set up redraw clock
  redraw_clock = clock.run(function()
    while true do
      clock.sleep(1 / 15)
      redraw()
    end
  end)

  -- Set up weather update clock (check every 5 minutes)
  weather_clock = clock.run(function()
    while true do
      clock.sleep(300) -- 5 minutes
      local old_state = weather.get_effective_state()
      weather.update()
      local new_state = weather.get_effective_state()
      
      -- Update sound if weather changed
      if old_state ~= new_state then
        avonlea.update_weather()
        print("Weather changed: " .. old_state .. " -> " .. new_state)
      end
    end
  end)

  -- Display information on screen
  screen.clear()
  screen.move(10, 30)
  screen.text("Avonlea - Green Gables")
  screen.move(10, 40)
  screen.text("Loading...")
  screen.update()

  -- Display debug information
  print("=== Avonlea Engine Initialized ===")
  print(string.format("Moon phase: %.2f", moon.phase))
  print(string.format("Moon position: Azimuth=%.2f, Altitude=%.2f", moon.azimuth, moon.altitude))
  print(string.format("Sound parameters - Depth: %.2f, Glint: %.2f, Wind: %.2f",
    params:get("depth"), params:get("glint"), params:get("wind")))
  print("===================================")
end

-- Encoder control update
function enc(n, d)
  -- Map encoders to parameters using the assignment variables
  if n == WIND_ENCODER then
    params:delta("wind", d * 0.2)
    print(string.format("E1 Wind: %.3f", params:get("wind")))
    -- Reset parameter display timer
    show_params_time = util.time()
    show_params = true
  elseif n == DEPTH_ENCODER then
    params:delta("depth", d * 0.2)
    print(string.format("E2 Depth: %.3f", params:get("depth")))
    -- Reset parameter display timer
    show_params_time = util.time()
    show_params = true
  elseif n == GLINT_ENCODER then
    params:delta("glint", d * 0.2)
    print(string.format("E3 Glint: %.3f", params:get("glint")))
    -- Reset parameter display timer
    show_params_time = util.time()
    show_params = true
  end
end

-- Key handler
function key(n, z)
  if n == 2 and z == 1 then
    -- K2 cycles through weather states (Auto -> Clear -> Cloudy -> Rainy -> Snowy)
    local new_weather_state = weather.cycle_manual_weather()
    print("Weather mode: " .. new_weather_state)
    
    -- Update sound engine with new weather
    avonlea.update_weather()
    
    -- Show weather state display
    weather_state_display.text = weather.get_display_state()
    weather_state_display.visible = true
    weather_state_display.show_time = util.time()
    
  elseif n == 3 and z == 1 then
    -- K3 refreshes current time and weather
    set_current_time()
    weather.force_update()
    -- Update sound when real weather changes
    avonlea.update_weather()
    print("Time and weather updated")
  end
end

-- Use visual module's redraw function
function redraw()
  -- Update visual module with current weather state
  local current_weather_state = weather.get_effective_state()
  visual.set_weather_state(current_weather_state)
  
  visual.redraw()

  -- Display parameter information (only when encoders are used)
  local current_time = util.time()

  -- Check parameter display end time
  if show_params and current_time - show_params_time > show_params_duration then
    show_params = false
  end

  if show_params then
    screen.level(15)
    screen.move(5, 10)
    screen.text(string.format("D:%.1f G:%.1f W:%.1f",
      params:get("depth") * 10,
      params:get("glint") * 10,
      params:get("wind") * 10))
  end
  
  -- Display weather state (temporarily, same height as params)
  if weather_state_display.visible then
    local current_time = util.time()
    if current_time - weather_state_display.show_time > weather_state_display.duration then
      weather_state_display.visible = false
    else
      screen.level(15)
      local text_width = screen.text_extents(weather_state_display.text)
      screen.move(128 - text_width - 5, 10)  -- Right aligned with margin
      screen.text(weather_state_display.text)
    end
  end

  screen.update()
end

-- Cleanup function
function cleanup()
  if redraw_clock then clock.cancel(redraw_clock) end
  if weather_clock then clock.cancel(weather_clock) end
  engine.free() -- Synthesizer cleanup
  print("Avonlea engine cleaned up")
end
