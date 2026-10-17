-- Circe HUD: original standalone live-world minimap.
local Model = require("model")
local Config = Model.options(require("settings"))
local Engine = require("engine")
local Capture = require("capture")
local View = require("view")
local directory = assert(debug.getinfo(1, "S").source:match("^@(.+[/\\])"), "Cannot locate CirceHUD scripts")
local session = { visible = true, large = false, range = Config.Range, queued = false, transition = false }
local lastMessage

local function report(message)
    if message ~= lastMessage then print("[CirceHUD] " .. message .. "\n"); lastMessage = message end
end

local function release()
    if session.view then session.view:dispose() end
    if session.camera then session.camera:dispose() end
    session.view, session.camera, session.worldName, session.reported = nil, nil, nil, nil
end

local function update()
    if session.transition then return end
    if session.skipTicks and session.skipTicks > 0 then session.skipTicks = session.skipTicks - 1; return end
    if session.reset then release(); session.reset = false end
    if not session.visible then
        if session.view and session.view:valid() then session.view:visible(false) end
        return
    end
    local player = Engine.player()
    if not player then release(); return end
    if session.worldName and session.worldName ~= player.world:GetFullName() then release() end
    if session.view and (not session.view:valid() or not session.camera:valid()) then release() end
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
    session.view:update(region, time, player.yaw)
    if not session.reported then
        print(("[CirceHUD] First frame: source=%d, region=%s, time=%s\n"):format(Config.CaptureSource, region, time))
        session.reported = true
    end
    report("Live camera and HUD active; region/time queries completed")
end

local function safelyUpdate()
    local ok, err = pcall(update)
    if not ok then
        release()
        session.skipTicks = 8 -- Back off after failed native API calls.
        report("Waiting after error: " .. tostring(err))
    end
end

local function bind(key, modifiers, callback)
    local ok, err = pcall(function()
        RegisterKeyBind(key, modifiers, function()
            ExecuteInGameThread(function() callback(); safelyUpdate() end)
        end)
    end)
    if not ok then report("Hotkey registration failed: " .. tostring(err)) end
end

bind(Key.H, { ModifierKey.CONTROL }, function() session.visible = not session.visible end)
bind(Key.M, {}, function()
    session.large = not session.large
    session.visible = true
    session.layoutDirty = true
end)
bind(Key.ADD, {}, function() session.range = Model.clamp(session.range / 1.25, Config.MinRange, Config.MaxRange) end)
bind(Key.SUBTRACT, {}, function() session.range = Model.clamp(session.range * 1.25, Config.MinRange, Config.MaxRange) end)

-- Hook callbacks only adjust lifecycle state; all regular object access is
-- scheduled on the game thread. The validity checks also cover missed hooks.
pcall(function()
    RegisterLoadMapPreHook(function() session.transition = true; release() end)
    RegisterLoadMapPostHook(function() session.transition = false; session.reset = true end)
end)
pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        session.transition = false
        session.reset = true
    end)
end)

local function schedule()
    ExecuteWithDelay(Config.RefreshMs, function()
        if session.queued then return end
        session.queued = true
        ExecuteInGameThread(function()
            session.queued = false
            safelyUpdate()
            schedule()
        end)
    end)
end
report("Standalone build 0.1.0-alpha loaded")
schedule()
