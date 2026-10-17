-- Circe HUD: original standalone live-world minimap.
local Model = require("model")
local Config = Model.options(require("settings"))
local Engine = require("engine")
local Capture = require("capture")
local View = require("view")
local directory = assert(debug.getinfo(1, "S").source:match("^@(.+[/\\])"), "Cannot locate CirceHUD scripts")
local session = { visible = true, large = false, range = Config.Range, transition = false }
-- Key callbacks run on UE4SS's event thread. Publish only plain Lua commands;
-- never dispatch native callbacks or touch widget wrappers from that thread.
local commands, written, consumed = {}, 0, 0
local lastMessage

local function report(message)
    if message ~= lastMessage then print("[CirceHUD] " .. message .. "\n"); lastMessage = message end
end

local function release()
    local view, camera = session.view, session.camera
    session.view, session.camera, session.worldName, session.reported = nil, nil, nil, nil
    session.bearing = nil
    session.arrowError = nil
    -- Cleanup must not throw out of the recovery path and kill the update loop.
    if view then pcall(function() view:dispose() end) end
    if camera then pcall(function() camera:dispose() end) end
end

local function update()
    if session.reset then release(); session.reset = false end
    if session.transition then return end
    if not session.visible then
        if session.view and session.view:valid() then session.view:visible(false) end
        return
    end
    if session.skipTicks and session.skipTicks > 0 then session.skipTicks = session.skipTicks - 1; return end
    local player = Engine.player()
    if not player then release(); return end
    if session.worldName and session.worldName ~= player.world:GetFullName() then release() end
    if session.view and (not session.view:valid() or not session.camera or not session.camera:valid()) then release() end
    if not session.view then
        local host, outer = Engine.hud()
        if not host then report("Waiting for the game HUD"); return end
        session.worldName = player.world:GetFullName()
        session.camera = Capture.new(player, Config)
        session.view = View.new(host, outer, player.world, session.camera.texture, Config, directory)
        session.layoutDirty = true
    end
    session.view:visible(true)
    if session.layoutDirty then session.view:layout(Config, session.large); session.layoutDirty = false end
    session.camera:refresh(player, Config, session.range)
    local region, time = Engine.labels(player)
    session.view:update(region, time)
    if not session.bearing then
        session.bearing = Model.heading(player.yaw)
        session.view:heading(session.bearing)
    end
    if not session.reported then
        print(("[CirceHUD] First frame: source=%d, region=%s, time=%s, viewYaw=%.1f, bearing=%.1f\n")
            :format(session.camera.source or Config.CaptureSource, region, time, player.yaw, Model.heading(player.yaw)))
        session.reported = true
    end
    report("Live camera and HUD active; region/time queries completed")
end

local function updateArrow()
    if session.transition or session.reset or not session.visible or not session.view then return end
    if not session.view:valid() then return end
    local yaw = Engine.yaw()
    if not Model.finite(yaw) then return end
    session.bearing = Model.smoothHeading(session.bearing, Model.heading(yaw), Config.ArrowSmoothing)
    session.view:heading(session.bearing)
end

local function safelyUpdate()
    local ok, err = pcall(update)
    if not ok then
        release()
        session.skipTicks = 8 -- Back off after failed native API calls.
        report("Waiting after error: " .. tostring(err))
    end
end

local function bind(key, command)
    local ok, err = pcall(function()
        RegisterKeyBind(key, {}, function()
            local nextIndex = written + 1
            commands[nextIndex] = command
            written = nextIndex
        end)
    end)
    if not ok then report("Hotkey registration failed: " .. tostring(err)) end
end

bind(Key.F3, "toggle")
bind(Key.M, "enlarge")
bind(Key.ADD, "zoomIn")
bind(Key.SUBTRACT, "zoomOut")

local function drainCommands()
    local limit = written
    if consumed == limit then return false end
    while consumed < limit do
        consumed = consumed + 1
        local command = commands[consumed]
        commands[consumed] = nil
        if command == "toggle" then
            session.visible = not session.visible
        elseif command == "enlarge" then
            session.large = not session.large
            session.visible = true
            session.layoutDirty = true
        elseif command == "zoomIn" then
            session.range = Model.clamp(session.range / 1.25, Config.MinRange, Config.MaxRange)
        elseif command == "zoomOut" then
            session.range = Model.clamp(session.range * 1.25, Config.MinRange, Config.MaxRange)
        end
    end
    session.skipTicks = 0 -- An explicit show request may retry immediately.
    print(("[CirceHUD] Controls applied through #%d; HUD %s\n"):format(consumed, session.visible and "shown" or "hidden"))
    return true
end

-- Hooks only adjust lifecycle state. Native cleanup happens in the same loop
-- as rendering, including when the HUD is hidden during a map transition.
pcall(function()
    RegisterLoadMapPreHook(function() session.transition = true; session.reset = true end)
    RegisterLoadMapPostHook(function() session.transition = false; session.reset = true end)
end)
pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        session.transition = false
        session.reset = true
    end)
end)

local elapsed = Config.RefreshMs
local function tick()
    local changed = drainCommands()
    elapsed = elapsed + Config.ArrowRefreshMs
    if changed or session.reset or elapsed >= Config.RefreshMs then
        elapsed = 0
        safelyUpdate()
    end
    local ok, err = pcall(updateArrow)
    if not ok then
        -- Rebuild on the next terrain tick instead of retaining broken widgets.
        session.reset = true
        report("Rebuilding HUD after arrow error: " .. tostring(err))
    end
end

report("Standalone build 0.1.4-alpha loaded")
-- One persistent native timer; no recurring asynchronous callback creation or
-- key-driven ExecuteInGameThread calls that can race the UE4SS Lua registry.
if type(LoopInGameThreadWithDelay) == "function" then
    LoopInGameThreadWithDelay(Config.ArrowRefreshMs, function()
        local ok, err = pcall(tick)
        if not ok then
            release()
            session.skipTicks = 8
            report("Recovered update error: " .. tostring(err))
        end
    end)
    report("Single game-thread update loop ready; F3 toggles HUD")
else
    report("This UE4SS build is missing LoopInGameThreadWithDelay; update UE4SS for Subnautica 2")
end
