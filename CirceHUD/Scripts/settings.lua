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
    -- Unreal ESceneCaptureSource: 7 = unlit BaseColor (deferred rendering),
    -- 2 = FinalColorLDR. Change to 2 if this game's renderer cannot show BaseColor.
    CaptureSource = 7,
    ShowNorth = true,
}
