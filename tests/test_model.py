from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "CirceHUD" / "Scripts"


class CirceTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.model = self.lua.execute((SCRIPTS / "model.lua").read_text())

    def test_all_lua_compiles(self):
        for script in SCRIPTS.glob("*.lua"):
            self.lua.execute("assert(load(...))", script.read_text())

    def test_clock_boundaries_and_invalid_source(self):
        cases = {0: "12:00 AM", 1: "12:01 AM", 719: "11:59 AM", 720: "12:00 PM",
                 721: "12:01 PM", 780: "1:00 PM", 1439: "11:59 PM", 1440: "12:00 AM"}
        for minute, expected in cases.items():
            self.assertEqual(self.model.clock(minute / 1440), expected)
        for value in (None, "bad", -1, 1.1, float("inf"), float("nan")):
            self.assertEqual(self.model.clock(value), "--:--")
        self.assertEqual(self.model.clock(.5), self.model.clock(.5))

    def test_native_region_tags(self):
        self.assertEqual(self.model.region("World.Zones.DeepForest"), "Deep Forest")
        self.assertEqual(self.model.region("Region.NWPlateaus"), "NW Plateaus")
        for tag in (None, "", "None"):
            self.assertEqual(self.model.region(tag), "Unknown region")

    def test_settings_are_bounded(self):
        config = self.model.options(self.lua.table_from({"Resolution": 99999, "RefreshMs": 0,
                                                       "Range": float("nan"), "MinRange": 2000, "MaxRange": -1}))
        self.assertEqual(config.Resolution, 1024)
        self.assertEqual(config.RefreshMs, 250)
        self.assertGreaterEqual(config.MaxRange, config.MinRange)
        self.assertGreaterEqual(config.Range, config.MinRange)

    def test_overhead_camera_never_changes_player_position(self):
        config = self.model.options(self.lua.table())
        location = self.lua.table_from({"X": 125, "Y": -642, "Z": -50000})
        camera = self.model.camera(location, config)
        self.assertEqual((camera.X, camera.Y, camera.Z), (125, -642, 5000))
        self.assertEqual(location.Z, -50000)

    def test_perspective_view_width(self):
        import math
        for height, width in ((35000, 30000), (75000, 160000), (5000, 6000)):
            fov = self.model.fov(height, width)
            self.assertAlmostEqual(2 * height * math.tan(math.radians(fov / 2)), width)
        self.assertEqual(self.model.fov(1, 999999), 150)

    def test_compass_cardinals_and_map_orientation(self):
        import math
        for yaw, bearing in ((-90, 0), (0, 90), (90, 180), (180, 270),
                             (60, 150), (270, 0), (-450, 0), (360, 90)):
            self.assertEqual(self.model.heading(yaw), bearing)
        camera = self.model.mapRotation()
        self.assertEqual(camera.Pitch, -90)
        self.assertEqual(camera.Roll, 0)
        # Camera image-up is -Y (north) and image-right is +X (east).
        yaw = math.radians(camera.Yaw)
        self.assertAlmostEqual(math.cos(yaw), 0)
        self.assertAlmostEqual(math.sin(yaw), -1)
        self.assertAlmostEqual(-math.sin(yaw), 1)
        self.assertAlmostEqual(math.cos(yaw), 0)

    def test_smooth_heading_crosses_north_by_shortest_route(self):
        self.assertEqual(self.model.smoothHeading(359, 1, .5), 0)
        self.assertEqual(self.model.smoothHeading(1, 359, .5), 0)
        self.assertEqual(self.model.smoothHeading(None, 150, .5), 150)
        heading = 350
        for _ in range(12):
            heading = self.model.smoothHeading(heading, 10, .55)
            self.assertTrue(heading >= 350 or heading <= 10)
        self.assertAlmostEqual(heading, 10, places=2)

    def test_heading_uses_camera_then_controller(self):
        lua = self.lua
        lua.globals().modelModule = self.model
        lua.execute('''
package.preload.model=function() return modelModule end
function valid() return true end
camera={IsValid=valid,GetCameraRotation=function() return {Yaw=60} end}
pawn={IsValid=valid,K2_GetActorLocation=function() return {X=0,Y=0,Z=0} end}
controller={IsValid=valid,PlayerCameraManager=camera,
 K2_GetPawn=function() return pawn end,GetControlRotation=function() return {Yaw=-90} end}
package.preload.UEHelpers=function() return {
 GetWorld=function() return {IsValid=valid} end,
 GetPlayerController=function() return controller end} end
''')
        engine = lua.execute((SCRIPTS / "engine.lua").read_text())
        self.assertEqual(engine.player().yaw, 60)
        lua.execute("controller.PlayerCameraManager=nil")
        self.assertEqual(engine.player().yaw, -90)

    def test_main_loop_stationary_hide_and_reload(self):
        lua = self.lua
        lua.globals().modelModule = self.model
        lua.execute('''
package.preload.model=function() return modelModule end
package.preload.settings=function() return {} end
playerAvailable=true; captureCount=0; cameraCount=0; disposed=0; labelCount=0
viewYaw=90; arrowCount=0; yawReads=0
package.preload.engine=function() return {
 yaw=function() yawReads=yawReads+1; return viewYaw end,
 player=function()
  if not playerAvailable then return nil end
  return {world={GetFullName=function() return "TestWorld" end},location={X=0,Y=0,Z=0},yaw=90}
 end,
 hud=function() return {},{} end,
 labels=function() labelCount=labelCount+1; return "Shallows", "12:00 PM" end
} end
package.preload.capture=function() return {new=function()
 cameraCount=cameraCount+1
 return {texture={},valid=function() return true end,
 refresh=function() captureCount=captureCount+1 end,
 dispose=function() disposed=disposed+1 end}
end} end
package.preload.view=function() return {new=function()
 return {valid=function() return true end,visible=function(_,v) shown=v end,
 layout=function() end,update=function(_,r,t) assert(t=="12:00 PM") end,
 heading=function(_,bearing) arrowCount=arrowCount+1; lastHeading=bearing end,
 dispose=function() end}
end} end
Key={F3=1,M=2,ADD=3,SUBTRACT=4};bindings={}
function RegisterKeyBind(key,mods,fn) bindings[key]=fn end
function ExecuteInGameThread(fn) fn() end
function ExecuteWithDelay(ms,fn) if ms==33 then arrowPending=fn else pending=fn end end
function RegisterLoadMapPreHook(fn) pre=fn end
function RegisterLoadMapPostHook(fn) post=fn end
function RegisterHook(_,fn) restart=fn end
function print(_) end
''')
        loader = lua.eval('function(s) assert(load(s,"@CirceHUD/Scripts/main.lua"))() end')
        loader((SCRIPTS / "main.lua").read_text())
        lua.execute("pending(); pending(); pending()")
        self.assertEqual(lua.globals().cameraCount, 1)
        self.assertEqual(lua.globals().captureCount, 3)
        self.assertEqual(lua.globals().labelCount, 3)
        lua.execute("viewYaw=100; for i=1,10 do arrowPending() end")
        self.assertEqual(lua.globals().captureCount, 3)
        self.assertEqual(lua.globals().labelCount, 3)
        self.assertEqual(lua.globals().arrowCount, 11)
        self.assertAlmostEqual(lua.globals().lastHeading, 190, places=2)
        lua.execute("bindings[Key.F3](); pending()")
        self.assertEqual(lua.globals().captureCount, 3)
        self.assertFalse(lua.globals().shown)
        lua.execute("for i=1,10 do arrowPending() end")
        self.assertEqual(lua.globals().yawReads, 10)
        lua.execute("bindings[Key.F3](); pre(); pending()")
        self.assertEqual(lua.globals().disposed, 1)
        lua.execute("post(); pending()")
        self.assertEqual(lua.globals().cameraCount, 2)
        lua.execute("playerAvailable=false; pending()")
        self.assertEqual(lua.globals().disposed, 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
