-- Test doubles only: this does not validate native rendering or frame time.

context="startup"; messages={}; bindings={}; widgets={}; reflected={}
captures=0; cameras=0; timers=0; headingUpdates=0; imported={}
controllerSearches=0; pixelReads=0; viewYaw=60
playerAvailable=true; nativeLabels=true; labelValues={}
function print(message) messages[#messages+1]=tostring(message) end
function game() assert(context=="game", "Native work outside game loop") end
function valid() return true end
function noop() game() end
function object(fields) fields=fields or {}; fields.IsValid=valid; return fields end
function CreateInvalidObject() return {IsValid=function() return false end} end
function FText(value) game(); return value end
local function slot()
 return object({SetAnchors=noop,SetAlignment=noop,SetPosition=noop,SetSize=noop,SetZOrder=noop})
end
local function widget(kind)
 local w=object({Font={},Brush={OutlineSettings={}},kind=kind})
 for _,name in ipairs({"SetJustification","SetFont","SetColorAndOpacity","SetShadowOffset",
  "SetShadowColorAndOpacity","SetBrushResourceObject","SetBrushFromTexture",
  "SetRenderTransformPivot","SetBrush","RemoveFromParent"}) do w[name]=noop end
 function w:SetVisibility(value) game(); self.visibility=value end
 function w:SetText(value) game(); self.text=value; labelValues[value]=true end
 function w:SetRenderTransformAngle(value) game(); headingUpdates=headingUpdates+1; lastHeading=value end
 function w:AddChildToCanvas(child) game(); return slot() end
 widgets[#widgets+1]=w
 return w
end
world=object({GetFullName=function() return "CleanWorld" end})
local cameraManager=object({GetCameraRotation=function() game(); return {Yaw=viewYaw} end})
local pawn=object({K2_GetActorLocation=function() game(); return {X=125,Y=-642,Z=-5000} end})
controller=object({PlayerCameraManager=cameraManager,IsPlayerController=valid,
 K2_GetPawn=function() game(); return pawn end,
 GetWorld=function() game(); return world end,
 GetControlRotation=function() game(); return {Yaw=-90} end})
host=object({AddChildToCanvas=function(self,child) game(); rootWidget=child; return slot() end,
 GetOuter=function() game(); return object() end})
screen=object({Layers=host,IsInViewport=valid})
function FindAllOf(kind)
 game()
 if kind=="PlayerController" or kind=="Controller" then
  controllerSearches=controllerSearches+1; return playerAvailable and {controller} or {}
 end
 assert(kind=="WBP_MainScreen_C", "Unexpected class dependency: "..kind)
 return {screen}
end
function FindFirstOf(kind)
 game(); assert(kind=="GameInstance"); return CreateInvalidObject()
end
function world:SpawnActor(kind,location,rotation)
 game(); assert(kind.path=="/Script/Engine.SceneCapture2D"); cameras=cameras+1
 local component=object({PostProcessSettings={},SetVisibility=noop,Activate=noop,
  SetShowFlagSettings=noop,K2_SetWorldLocation=noop,K2_SetWorldRotation=noop,
  K2_GetComponentLocation=function() return location end,
  K2_GetComponentRotation=function() return rotation end,
  CaptureScene=function() game(); captures=captures+1 end})
 return object({SetReplicates=noop,SetActorEnableCollision=noop,K2_DestroyActor=noop,
  GetComponentByClass=function(self,kind)
   assert(kind.path=="/Script/Engine.SceneCaptureComponent2D"); return component
  end})
end
local rendering=object({
 CreateRenderTarget2D=function() game(); return object() end,
 ImportFileAsTexture2D=function(self,world,path)
  game(); assert(checkAsset(path), "Asset not in extracted ZIP: "..path)
  imported[#imported+1]=path; return object()
 end,
 ReadRenderTargetPixel=function() game(); pixelReads=pixelReads+1; return {R=10,G=20,B=30,A=255} end})
local subsystem=object({GetWorldSubsystem=function()
 game(); if not nativeLabels then return CreateInvalidObject() end
 return object({FindWorldZoneTag=function() return {TagName={ToString=function() return "World.Zones.DeepForest" end}} end})
end})
local time=object({GetTimeOfDayComponent=function()
 game(); if not nativeLabels then return CreateInvalidObject() end
 return object({GetTimeOfDayFraction=function() return .5 end})
end})
local known={
 ["/Script/Engine.SceneCapture2D"]=true,
 ["/Script/Engine.SceneCaptureComponent2D"]=true,
 ["/Script/Engine.Default__KismetRenderingLibrary"]=rendering,
 ["/Script/Engine.Default__SubsystemBlueprintLibrary"]=subsystem,
 ["/Script/UWEWorldPopulation2.UWEWorldZoneTrackerSubsystem"]=true,
 ["/Script/UWETimeOfDay.Default__UWETimeOfDayStatics"]=time,
 ["/Script/UMG.CanvasPanel"]=true,["/Script/UMG.Image"]=true,["/Script/UMG.TextBlock"]=true}
function StaticFindObject(path)
 game(); reflected[path]=true
 assert(known[path], "Unexpected reflected dependency: "..path)
 return known[path]==true and object({path=path}) or known[path]
end
function StaticConstructObject(kind,outer) game(); return widget(kind.path) end
Key={F3=1,M=2,ADD=3,SUBTRACT=4}
function RegisterKeyBind(key,modifiers,fn) bindings[key]=fn end
function RegisterLoadMapPreHook(fn) pre=fn end
function RegisterLoadMapPostHook(fn) post=fn end
function RegisterHook(path,fn) assert(path=="/Script/Engine.PlayerController:ClientRestart"); restart=fn end
function LoopInGameThreadWithDelay(ms,fn)
 assert(context=="startup" and ms==33); timers=timers+1; timer=fn
end
function step(count)
 context="game"; for i=1,count or 1 do timer() end; context="idle"
end
function press(key) context="key"; bindings[key](); context="idle" end

-- Match the controller discovery/GetWorld call structure in standard UEHelpers.
package.preload.UEHelpers=function()
 local helpers={}
 function helpers.GetPlayerController()
  for _,candidate in ipairs(FindAllOf("PlayerController") or FindAllOf("Controller") or {}) do
   if candidate:IsValid() and candidate:IsPlayerController() then return candidate end
  end
  return CreateInvalidObject()
 end
 function helpers.GetWorld()
  local player=helpers.GetPlayerController()
  if player:IsValid() then return player:GetWorld() end
  return CreateInvalidObject()
 end
 return helpers
end
