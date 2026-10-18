Circe's Circular Minimap - Region and Clock
Version 0.1.5-alpha

A smooth circular minimap with region names and a 12-hour in-game clock.
Press F3 to show or hide it.

REQUIREMENTS
Subnautica 2 for Windows and a compatible UE4SS installation with UEHelpers
and LoopInGameThreadWithDelay support.
Tested locally on Windows/Steam, including repeated F3 toggles and Quick Stack
working afterward. Other storefronts and multiplayer are untested.

VORTEX
Install the Subnautica 2 game-support extension and UE4SS first.
Install this ZIP, enable it and deploy. It should be classified as
"UE4SS (Lua scripts)" and create ue4ss/Mods/CirceHUD/Scripts/main.lua.
Disable any other minimap to avoid overlapping displays and shortcut conflicts.

MANUAL INSTALL
Save and close the game. Extract the CirceHUD folder into:
<game>/Subnautica2/Binaries/Win64/ue4ss/Mods/
The resulting file must be Mods/CirceHUD/Scripts/main.lua.
The included enabled.txt activates the mod. Do not replace your shared mods.txt.
If it already contains an explicit "CirceHUD : 0", change that entry to 1.

CONTROLS
F3: show/hide the map, region label and clock
M: enlarge/restore the local map
Numpad + / -: zoom in/out

SETTINGS
Edit CirceHUD/Scripts/settings.lua while the game is closed.
Settings include size, position, range, capture frequency and arrow smoothing.
Back up your customized settings before updating, since an update replaces them.

LIMITATIONS
This is a live overhead view of nearby loaded geometry, not a full world atlas.
Buildings and cave ceilings can obscure geometry beneath them.
Unknown region may appear above water or where the game supplies no zone tag.
Vortex archive routing is checked against extension 1.5.1; complete live
Vortex install/update/uninstall testing remains pending.

UNINSTALL
Save and close the game. In Vortex, disable/remove CirceHUD and deploy.
For a manual install, remove only Mods/CirceHUD. If you added a CirceHUD line
to mods.txt manually, remove that line or set it to 0.

LICENSE
MIT license: see LICENSE.txt.
Source: https://github.com/MissViciousCirce/circe-hud
Unofficial fan mod, not affiliated with Unknown Worlds.
