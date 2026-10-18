"""Count native calls made by the real runtime; these are not FPS benchmarks."""
from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "CirceHUD/Scripts"


def runtime(scripts=SCRIPTS, diagnostics=False):
    scripts = Path(scripts).resolve()
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests/runtime_stub.lua").read_text(encoding="utf-8"))
    pointer = (scripts.parent / "Assets/pointer.png.lua").resolve()
    lua.globals().checkAsset = lambda p: Path(p).resolve() == pointer and pointer.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    lua.globals().scriptPath = scripts.as_posix()
    lua.globals().diagnostics = diagnostics
    lua.execute('''
package.path=scriptPath.."/?.lua"; package.cpath=""
require("settings").Diagnostics=diagnostics
assert(loadfile(scriptPath.."/main.lua"))()
''')
    return lua


class PerformanceTests(unittest.TestCase):
    def test_stationary_runtime_avoids_fast_searches_and_redundant_draws(self):
        lua = runtime()
        lua.execute("step(230)")
        g = lua.globals()
        self.assertEqual(g.captures, 10)
        self.assertEqual(g.controllerSearches, 10)
        self.assertEqual(g.headingUpdates, 1)
        self.assertEqual(g.pixelReads, 0)
        self.assertEqual(g.timers, 1)
        self.assertTrue(g.labelValues["Deep Forest"])
        self.assertTrue(g.labelValues["12:00 PM"])
        self.assertFalse(any("error" in line for line in g.messages.values()))

    def test_turning_remains_responsive_without_extra_search_or_capture(self):
        lua = runtime()
        lua.execute("step(); viewYaw=100; step(10)")
        g = lua.globals()
        self.assertEqual(g.controllerSearches, 1)
        self.assertEqual(g.captures, 1)
        self.assertGreater(g.headingUpdates, 1)
        self.assertLess(abs(g.lastHeading - 190), 0.1)

    def test_dead_controller_is_skipped_and_reacquired_on_slow_tick(self):
        lua = runtime()
        lua.execute('''
step()
local old=controller
old.IsValid=function() return false end
step(22)
assert(controllerSearches==1 and captures==1 and headingUpdates==1)
controller={}
for key,value in pairs(old) do controller[key]=value end
controller.IsValid=function() return true end
viewYaw=120; step(); step(10)
assert(controllerSearches==2 and captures==2 and headingUpdates>1)
for _,line in ipairs(messages) do assert(not line:find("error"), line) end
''')

    def test_diagnostic_pixel_reads_require_opt_in_and_run_once_per_camera(self):
        lua = runtime(diagnostics=True)
        lua.execute("step(230)")
        self.assertEqual(lua.globals().pixelReads, 3)
        lua.execute("step(230)")
        self.assertEqual(lua.globals().pixelReads, 3)

    def test_hidden_map_stops_searches_captures_and_arrow_writes(self):
        lua = runtime()
        lua.execute('''
step(); press(Key.F3); step()
local searches,frames,writes=controllerSearches,captures,headingUpdates
step(230)
assert(controllerSearches==searches and captures==frames and headingUpdates==writes)
pre(); step(); post(); step(23)
assert(cameras==1)
press(Key.F3); step(); assert(cameras==2 and rootWidget.visibility==3)
''')

    def test_heading_threshold_wraps_and_accumulates_small_movements(self):
        lua = runtime()
        lua.execute('''
local View=require("view")
local angles={}
local view=setmetatable({marker={SetRenderTransformAngle=function(self,angle)
 angles[#angles+1]=angle
end}}, View)
view:heading(359.98); view:heading(0.02); view:heading(0.06)
assert(#angles==1)
view:heading(0.10); assert(#angles==2)
view:heading(0.10); assert(#angles==2)
view:heading(90); assert(#angles==3)
''')


if __name__ == "__main__":
    unittest.main(verbosity=2)
