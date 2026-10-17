-- Pure calculations. No game objects, copied map calibration, or external art.
local M = {}

function M.finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function M.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function M.clock(dayFraction)
    if not M.finite(dayFraction) or dayFraction < 0 or dayFraction > 1 then
        return "--:--"
    end
    local minuteOfDay = math.floor(dayFraction * 1440 + 1e-6) % 1440
    local hour = minuteOfDay // 60
    local displayHour = ((hour + 11) % 12) + 1
    return ("%d:%02d %s"):format(displayHour, minuteOfDay % 60, hour >= 12 and "PM" or "AM")
end

function M.region(tag)
    if type(tag) ~= "string" or tag == "" or tag == "None" then return "Unknown region" end
    local parts = {}
    for word in tag:gmatch("[^.]+") do parts[#parts + 1] = word end
    local last = parts[#parts] or ""
    last = last:gsub("_", " "):gsub("(%u)(%u%l)", "%1 %2"):gsub("(%l)(%u)", "%1 %2")
    return last ~= "" and last or "Unknown region"
end

function M.camera(location, config)
    return {
        X = location.X,
        Y = location.Y,
        Z = math.max(location.Z + config.CameraHeight * 100, config.MinimumCameraAltitude * 100),
    }
end

function M.options(input)
    local c = {}
    local function number(name, fallback, low, high)
        local value = input[name]
        c[name] = M.clamp(M.finite(value) and value or fallback, low, high)
    end
    number("Diameter", 280, 120, 600)
    number("Left", 16, 0, 4000)
    number("Top", 24, 0, 4000)
    number("LargeDiameter", 680, 280, 1200)
    number("MinRange", 60, 20, 1600)
    number("MaxRange", 1600, c.MinRange, 3000)
    number("Range", 300, c.MinRange, c.MaxRange)
    number("CameraHeight", 350, 20, 1000)
    number("MinimumCameraAltitude", 50, -1000, 1000)
    number("Resolution", 512, 128, 1024)
    number("RefreshMs", 750, 250, 5000)
    c.Resolution = math.floor(c.Resolution)
    c.CaptureSource = input.CaptureSource == 2 and 2 or 7
    c.ShowNorth = input.ShowNorth ~= false
    return c
end

return M
