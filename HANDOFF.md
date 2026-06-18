# Sushi Shift Handoff

Last updated: 2026-06-18

## Project

This folder contains the Godot MVP cooking game `Sushi Shift`.

- Project root: `/home/ralf/prj/exploration/godot-cooking-game`
- Engine used: Godot `4.6.3.stable.official.7d41c59c4`
- Main scene: `scenes/Main.tscn`
- Main implementation: `scripts/main.gd`
- Export presets: `export_presets.cfg`
- MVP plan: `mvp-plan.md`
- Asset inventory: `asset-inventory.md`

The game is a small sushi-counter cooking MVP built around the Quaternius Sushi Restaurant Kit. The player picks up ingredients, assembles/cuts where needed, serves matching orders, and plays a 3 minute shift.

## Core Gameplay State

Current mechanics:

- Main menu, pause menu, restart/game-over flow.
- 3 minute timed shift.
- Orders spawn and time out.
- Recipes:
  - Onigiri: Rice -> Assemble -> Serve
  - Salmon Nigiri: Rice + Salmon -> Assemble -> Serve
  - Cucumber Roll: Rice + Nori + sliced cucumber -> Assemble -> Serve
- Stations:
  - Rice, Salmon, Nori, Cucumber
  - Cut
  - Assemble
  - Serve Here
- In-game guide panel explains the current recipe and next action.
- Order cards include short recipe hints.
- Player cannot walk through the prep row, serving bar, walls, appliances, plants, and dining area.
- Held item is positioned in front of the player, not behind.
- Player walking/idle/processing animations loop.
- Music and SFX are integrated.

## Assets

Primary 3D pack:

- `assets/quaternius-sushi-restaurant-kit/Sushi Restaurant Kit - May 2023`
- Style: low-poly, cute, warm, stylized Japanese sushi restaurant.
- Main visible scene: counter kitchen, shoji wall background, rabbits as guests, panda chef/player, sushi food props, appliances, lanterns, decorative plants.

Generated/added audio:

- `assets/audio/sushi_shift_theme.mp3`
- `assets/audio/sfx_pickup.mp3`
- `assets/audio/sfx_chop.mp3`
- `assets/audio/sfx_assemble.mp3`
- `assets/audio/sfx_serve_success.mp3`
- `assets/audio/sfx_error.mp3`
- `assets/audio/sfx_drop.mp3`
- `assets/audio/README.md`

Audio was generated with ElevenLabs using the globally configured API key available through `~/.profile` at the time of generation. Do not print or commit secrets.

## Important Implementation Notes

Key constants and layout:

- `scripts/main.gd`
- `PREP_ROW_Z := -1.65`
- Walk bounds:
  - `WALK_MIN_X := -6.65`
  - `WALK_MAX_X := 6.65`
  - `WALK_MIN_Z := -2.55`
  - `WALK_MAX_Z := 0.28`
- Player radius: `PLAYER_RADIUS := 0.32`
- Hold socket is on the front of `PlayerVisual`.
- Station labels use normal depth testing now, so they behave like scene labels instead of rendering through the player.

Recent object-placement fixes:

- Prep row moved forward to separate furniture from back-wall appliances.
- Fridge moved/scaled to `Vector3(-6.55, 0, -3.58)`, scale `0.60`.
- Can fridge moved/scaled to `Vector3(4.20, 0, -3.32)`, scale `0.55`.
- Oven moved/scaled to `Vector3(5.95, 0, -3.43)`, scale `0.72`.
- Bamboo and plant moved to side/front decorative positions instead of inside appliance footprints.
- Matching collision blockers were updated in `_build_global_collision_blockers()`.

Object overlap audit:

- `tests/object_overlap_audit.gd`
- Reports X/Z footprints for major stations, appliances, decor, and props.
- Fails on disallowed appliance/station, appliance/appliance, appliance/decor, and appliance/small-prop overlaps.
- Can save `screenshots/object_overlap_audit.png` with red markers when run with rendering.
- Current report ends with `BAD_OVERLAPS none`.

## Tests And Audits

Useful commands from project root:

```bash
godot --headless --path . -s res://tests/smoke_test.gd
godot --headless --path . -s res://tests/playthrough_test.gd
godot --headless --path . -s res://tests/gameplay_polish_audit.gd
godot --headless --path . -s res://tests/collision_audit.gd
godot --headless --path . -s res://tests/object_overlap_audit.gd
godot --headless --path . -- --asset-load-audit
xvfb-run -a -s '-screen 0 1280x720x24' godot --path . -s res://tests/layout_audit.gd
xvfb-run -a -s '-screen 0 1280x720x24' godot --path . -s res://tests/capture_screenshot.gd
xvfb-run -a -s '-screen 0 1280x720x24' godot --path . -s res://tests/capture_ui_screenshots.gd
xvfb-run -a -s '-screen 0 1280x720x24' godot --path . -s res://tests/capture_held_screenshot.gd
```

Last known validation status:

- Smoke test: passed.
- Playthrough test: passed.
- Gameplay polish audit: passed.
- Collision audit: passed.
- Object overlap audit: passed, `BAD_OVERLAPS none`.
- Layout audit: passed, no size outliers and no UI/world overlap.
- Asset audit: passed, `loaded=75 fallbacks=0 audio=true`.
- Exported Windows exe under Wine: passed asset audit.

Godot sometimes prints cleanup warnings like `ObjectDB instances leaked at exit` after tests. They have not been test failures; check process exit code and the pass line.

## Screenshots

Current useful screenshots:

- `screenshots/gameplay.png`
- `screenshots/held_item.png`
- `screenshots/menu.png`
- `screenshots/pause.png`
- `screenshots/game_over.png`
- `screenshots/object_overlap_audit.png`
- `screenshots/windows_wine_menu.png`

`windows_wine_menu.png` was captured from the Windows `.exe` running under Wine in an Xvfb virtual display.

Capture command used:

```bash
xvfb-run -a -s '-screen 0 1280x720x24' bash -lc 'set -m; WINEPREFIX=/srv/wine-prefixes/sushi-shift WINEDEBUG=-all wine64 builds/windows/SushiShift.exe > /tmp/sushi-wine.log 2>&1 & app_pid=$!; sleep 10; import -window root screenshots/windows_wine_menu.png; kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true; cat /tmp/sushi-wine.log'
```

## Builds

Windows:

- Zip: `builds/windows/SushiShift-Windows.zip`
- Exe: `builds/windows/SushiShift.exe`
- Exported pack for audit: `builds/windows/SushiShift-Windows.pck`
- Public upload: `https://exploration.nbg1.your-objectstorage.com/SushiShift-Windows.zip`
- Tailscale static URL while server is running: `http://100.98.187.105:8766/SushiShift-Windows.zip`
- SHA256:
  - `SushiShift-Windows.zip`: `55d07804ce04932b622aaf3688b14b9337302f478baf0c5ef862e2b8a29077d7`
  - `SushiShift.exe`: `92668459c2834b19fc60b6e46fafc3d8063cef71f146970a00ed717f4e84d80d`

macOS:

- Latest zip: `builds/macos/SushiShift-macOS-polish-768f6424.zip`
- Tailscale static URL while server is running: `http://100.98.187.105:8765/SushiShift-macOS-polish-768f6424.zip`
- SHA256:
  - `SushiShift-macOS-polish-768f6424.zip`: `768f64248109b5df5a30878c9001ac9bed102432318b4a827f17e3c755b5f5b6`

Linux:

- Binary: `builds/linux/SushiShift.x86_64`

Export commands:

```bash
godot --headless --path . --export-release Linux builds/linux/SushiShift.x86_64
godot --headless --path . --export-release macOS builds/macos/SushiShift-macOS.zip
godot --headless --path . --export-release Windows builds/windows/SushiShift.exe
python3 -m zipfile -c builds/windows/SushiShift-Windows.zip builds/windows/SushiShift.exe
```

Validate exported Windows pack/exe:

```bash
godot --headless --path . --export-pack Windows builds/windows/SushiShift-Windows.pck
godot --headless --main-pack builds/windows/SushiShift-Windows.pck -- --asset-load-audit
WINEPREFIX=/srv/wine-prefixes/sushi-shift WINEDEBUG=-all wine64 builds/windows/SushiShift.exe --headless -- --asset-load-audit
```

## Serving And Sharing

Current Tailscale IP used:

- `100.98.187.105`
- Host: `ralfs-ubuntu`

Static file servers that may be running:

```bash
# macOS build folder
cd /home/ralf/prj/exploration/godot-cooking-game/builds/macos
python3 -m http.server 8765 --bind 0.0.0.0

# Windows build folder
cd /home/ralf/prj/exploration/godot-cooking-game/builds/windows
python3 -m http.server 8766 --bind 0.0.0.0
```

Check servers:

```bash
ss -ltnp | rg ':8765|:8766'
curl -I http://100.98.187.105:8766/SushiShift-Windows.zip
```

FilesFly sharing:

```bash
ff check
ff upload /home/ralf/prj/exploration/godot-cooking-game/builds/windows/SushiShift-Windows.zip -o SushiShift-Windows.zip
```

Last FilesFly URL:

```text
https://exploration.nbg1.your-objectstorage.com/SushiShift-Windows.zip
```

Do not print `~/.config/filesfly/filesfly.json`; it contains secret config.

## Wine Setup

Wine was installed to validate Windows builds.

Install choice:

- Minimal Ubuntu package: `wine64`
- Installed with `--no-install-recommends`.
- Apt archive cache redirected to `/srv/apt-cache/archives` during install and then cleaned.

Storage:

- HDD mount: `/srv`, 1.8 TB.
- Wine prefix: `/srv/wine-prefixes/sushi-shift`, about `1.2G`.
- Apt cache after cleanup: `/srv/apt-cache`, about `12K`.

Useful command:

```bash
WINEPREFIX=/srv/wine-prefixes/sushi-shift WINEDEBUG=-all wine64 builds/windows/SushiShift.exe --headless -- --asset-load-audit
```

In headless/Xvfb Wine runs, audio may fall back to dummy output. That is expected on this host and does not mean the Windows artifact lacks audio.

## Known Limitations

- The game is an MVP, not a deep cooking sim.
- Recipes and interactions are intentionally simple.
- Windows was validated through Wine, not on a real Windows desktop.
- Wine screenshot confirms the Windows exe renders the main menu.
- The Windows build is not code signed, so Windows may show a SmartScreen warning.
- macOS build is not notarized; `xattr -dr com.apple.quarantine` may be needed after download.
- The project folder is not a git repository as of the last check.

## Next Good Steps

- Add a proper settings screen for volume and controls.
- Add controller support.
- Add more recipes and a recipe book panel.
- Add visual order delivery feedback above guests.
- Add a short tutorial first order with forced Onigiri.
- Add actual Windows desktop validation if a Windows machine is available.
- Consider signing/notarization only if distributing beyond local testing.
