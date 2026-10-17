local Helpers = require("UEHelpers")
local Model = require("model")
local E = {}

function E.valid(object)
    return object ~= nil and object:IsValid()
end

function E.lookup(path)
    local object = StaticFindObject(path)
    assert(E.valid(object), "Missing reflected object: " .. path)
    return object
end

function E.yaw(controller)
    controller = controller or Helpers.GetPlayerController()
    if not E.valid(controller) then return nil end
    -- The compass tracks where the view faces. A swimming pawn's body can
    -- lag behind the view, so prefer the actual camera, then controller aim.
    local ok, rotation = pcall(function()
        local camera = controller.PlayerCameraManager
        if E.valid(camera) then return camera:GetCameraRotation() end
        return controller:GetControlRotation()
    end)
    if not ok or not rotation or not Model.finite(rotation.Yaw) then
        rotation = controller:GetControlRotation()
    end
    return rotation.Yaw
end

function E.player()
    local world = Helpers.GetWorld()
    local controller = Helpers.GetPlayerController()
    if not E.valid(world) or not E.valid(controller) then return nil end
    local pawn = controller:K2_GetPawn()
    if not E.valid(pawn) then return nil end
    local location = pawn:K2_GetActorLocation()
    return { world = world, pawn = pawn, location = location, yaw = E.yaw(controller) }
end

function E.labels(player)
    local regionOK, region = pcall(function()
        local lib = E.lookup("/Script/Engine.Default__SubsystemBlueprintLibrary")
        local kind = E.lookup("/Script/UWEWorldPopulation2.UWEWorldZoneTrackerSubsystem")
        local tracker = lib:GetWorldSubsystem(player.world, kind)
        if not E.valid(tracker) then return nil end
        return tracker:FindWorldZoneTag(player.location).TagName:ToString()
    end)
    local timeOK, fraction = pcall(function()
        local lib = E.lookup("/Script/UWETimeOfDay.Default__UWETimeOfDayStatics")
        local component = lib:GetTimeOfDayComponent(player.world)
        if not E.valid(component) then return nil end
        return component:GetTimeOfDayFraction()
    end)
    return Model.region(regionOK and region or nil), Model.clock(timeOK and fraction or nil)
end

function E.hud()
    -- Layers is a game-owned canvas. Discover its live widget tree; never take
    -- a root from another mod or create a replacement game HUD.
    for _, screen in ipairs(FindAllOf("WBP_MainScreen_C") or {}) do
        if E.valid(screen) and screen:IsInViewport() then
            local ok, layers = pcall(function() return screen.Layers end)
            if ok and E.valid(layers) then return layers, layers:GetOuter() end
        end
    end
    return nil
end

return E
