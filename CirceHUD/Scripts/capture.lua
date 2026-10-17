-- One local, non-replicated camera. Only this camera's rendering flags change.
local E = require("engine")
local Model = require("model")
local Capture = {}
Capture.__index = Capture

function Capture.new(player, config)
    local self = setmetatable({}, Capture)
    local success, problem = pcall(function()
        self.actor = player.world:SpawnActor(E.lookup("/Script/Engine.SceneCapture2D"),
            Model.camera(player.location, config), { Pitch = -90, Yaw = 0, Roll = 0 })
        assert(E.valid(self.actor), "Could not create the overhead camera")
        self.actor:SetReplicates(false)
        self.actor:SetActorEnableCollision(false)
        self.component = self.actor:GetComponentByClass(E.lookup("/Script/Engine.SceneCaptureComponent2D"))
        assert(E.valid(self.component), "Camera has no capture component")
        local c = self.component
        c.bCaptureEveryFrame = false
        c.bCaptureOnMovement = false
        c.bAlwaysPersistRenderingState = false
        c.ProjectionType = 1 -- Orthographic: no perspective distortion.
        c.CaptureSource = config.CaptureSource
        c.OrthoWidth = config.Range * 100
        c.LODDistanceFactor = 2
        c.PostProcessBlendWeight = 0
        c:SetShowFlagSettings({
            { ShowFlagName = "Fog", Enabled = false },
            { ShowFlagName = "VolumetricFog", Enabled = false },
            { ShowFlagName = "Atmosphere", Enabled = false },
            { ShowFlagName = "Translucency", Enabled = false },
            { ShowFlagName = "SingleLayerWater", Enabled = false },
            { ShowFlagName = "DynamicShadows", Enabled = false },
            { ShowFlagName = "Particles", Enabled = false },
        })
        local rendering = E.lookup("/Script/Engine.Default__KismetRenderingLibrary")
        self.texture = rendering:CreateRenderTarget2D(player.world, config.Resolution, config.Resolution,
            2, { R = 0.018, G = 0.055, B = 0.070, A = 1 }, false, false)
        assert(E.valid(self.texture), "Could not create the map render target")
        c.TextureTarget = self.texture
    end)
    if not success then self:dispose(); error(problem) end
    return self
end

function Capture:valid()
    return E.valid(self.actor) and E.valid(self.component) and E.valid(self.texture)
end

function Capture:refresh(player, config, range)
    self.component.OrthoWidth = range * 100
    self.actor:K2_SetActorLocation(Model.camera(player.location, config), false, {}, true)
    self.component:CaptureScene()
end

function Capture:dispose()
    if E.valid(self.actor) then pcall(function() self.actor:K2_DestroyActor() end) end
    self.actor, self.component, self.texture = nil, nil, nil
end

return Capture
