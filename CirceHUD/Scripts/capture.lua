-- One local, non-replicated camera. Only this camera's rendering flags change.
local E = require("engine")
local Model = require("model")
local Capture = {}
Capture.__index = Capture

function Capture.new(player, config)
    local self = setmetatable({}, Capture)
    local success, problem = pcall(function()
        self.actor = player.world:SpawnActor(E.lookup("/Script/Engine.SceneCapture2D"),
            Model.camera(player.location, config), Model.mapRotation())
        assert(E.valid(self.actor), "Could not create the overhead camera")
        self.actor:SetReplicates(false)
        self.actor:SetActorEnableCollision(false)
        self.component = self.actor:GetComponentByClass(E.lookup("/Script/Engine.SceneCaptureComponent2D"))
        assert(E.valid(self.component), "Camera has no capture component")
        local c = self.component
        c.bCaptureEveryFrame = false
        c.bCaptureOnMovement = false
        c.bAlwaysPersistRenderingState = true
        c.ProjectionType = 0 -- Perspective avoids orthographic clipping-plane defaults.
        c.PrimitiveRenderMode = 1 -- RenderScenePrimitives, not an empty show-only list.
        c.MaxViewDistanceOverride = -1
        c.bEnableClipPlane = false
        c.bUseCustomProjectionMatrix = false
        c:SetVisibility(true, false)
        c:Activate(true)
        c.CaptureSource = config.CaptureSource
        c.OrthoWidth = config.Range * 100
        c.LODDistanceFactor = 2
        c.PostProcessBlendWeight = 0
        c:SetShowFlagSettings({
            { ShowFlagName = "Lighting", Enabled = false },
            { ShowFlagName = "Fog", Enabled = false },
            { ShowFlagName = "VolumetricFog", Enabled = false },
            { ShowFlagName = "Atmosphere", Enabled = false },
            { ShowFlagName = "Translucency", Enabled = false },
            { ShowFlagName = "SingleLayerWater", Enabled = false },
            { ShowFlagName = "DynamicShadows", Enabled = false },
            { ShowFlagName = "Particles", Enabled = false },
            { ShowFlagName = "PostProcessMaterial", Enabled = false },
        })
        self.source = config.CaptureSource
        if config.DarkWater then
            -- SceneColor bypasses color grading. FinalColor is required to
            -- apply this local grade; the game camera is never modified.
            local graded, reason = pcall(function()
                local p = c.PostProcessSettings
                local function override(name, value)
                    p["bOverride_" .. name] = true
                    p[name] = value
                end
                override("ColorContrast", { X = config.MapContrast, Y = config.MapContrast, Z = config.MapContrast, W = 1 })
                override("ColorOffset", { X = -0.018, Y = -0.040, Z = -0.075, W = 0 })
                override("ColorGain", { X = 1.12, Y = 1.06, Z = 1.0, W = 1 })
                override("AutoExposureMethod", 2) -- Manual: water must not brighten through adaptation.
                override("AutoExposureApplyPhysicalCameraExposure", false)
                override("AutoExposureBias", 0)
                override("BloomIntensity", 0)
                override("VignetteIntensity", 0)
                override("MotionBlurAmount", 0)
                c.PostProcessSettings = p
            end)
            if graded then
                c.PostProcessBlendWeight = 1
                self.source = 2 -- FinalColorLDR includes grading and tone mapping.
                print("[CirceHUD] Dark-water color grade active on map camera\n")
            else
                c.PostProcessBlendWeight = 0
                print("[CirceHUD] Color grade unavailable; original capture retained: " .. tostring(reason) .. "\n")
            end
        end
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
    self.component.CaptureSource = self.source
    local position = Model.camera(player.location, config)
    self.component.FOVAngle = Model.fov(position.Z - player.location.Z, range * 100)
    -- Set the component's world transform explicitly; actor spawn rotation alone
    -- does not establish which way a component with a relative transform faces.
    self.component:K2_SetWorldLocation(position, false, {}, true)
    self.component:K2_SetWorldRotation(Model.mapRotation(), false, {}, true)
    self.component:CaptureScene()
    self.frames = (self.frames or 0) + 1
    if self.frames == 6 then
        self.sampledSource = self.source
        local ok, result = pcall(function()
            local p = self.component:K2_GetComponentLocation()
            local r = self.component:K2_GetComponentRotation()
            print(("[CirceHUD] Camera XYZ=%.1f,%.1f,%.1f rotation=%.1f,%.1f,%.1f FOV=%.1f projection=%d\n")
                :format(p.X,p.Y,p.Z,r.Pitch,r.Yaw,r.Roll,self.component.FOVAngle,self.component.ProjectionType))
            local library = E.lookup("/Script/Engine.Default__KismetRenderingLibrary")
            local values = {}
            for _, factor in ipairs({0.25, 0.5, 0.75}) do
                local pos = math.floor(config.Resolution * factor)
                local pixel = library:ReadRenderTargetPixel(player.world, self.texture, pos, pos)
                values[#values + 1] = ("%d,%d,%d,%d"):format(pixel.R, pixel.G, pixel.B, pixel.A)
            end
            return table.concat(values, " | ")
        end)
        print(("[CirceHUD] Capture source=%d sample RGBA: %s\n"):format(self.source, tostring(result)))
    end
end

function Capture:dispose()
    if E.valid(self.actor) then pcall(function() self.actor:K2_DestroyActor() end) end
    self.actor, self.component, self.texture = nil, nil, nil
end

return Capture
