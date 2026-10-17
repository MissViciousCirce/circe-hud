-- Circe HUD: distances are metres; UI sizes are Slate units.
return {
    Diameter = 280,
    Left = 16,
    Top = 24,
    LargeDiameter = 680,
    Range = 300,
    MinRange = 60,
    MaxRange = 1600,
    CameraHeight = 350,
    MinimumCameraAltitude = 50,
    Resolution = 512,
    RefreshMs = 750,
    ArrowRefreshMs = 33,
    ArrowSmoothing = 0.55,
    -- Grading affects this map camera only. False restores the 0.1.2 colors.
    DarkWater = true,
    MapContrast = 1.35,
    -- 3 = scene color with depth in alpha. The RGBA8 target clamps geometry
    -- depth to opaque alpha, so Slate cannot discard otherwise visible terrain.
    CaptureSource = 3,
    ShowNorth = true,
}
