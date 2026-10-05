# Desktop development

This checkout lives in `Desktop/PekaBoo-Development`. The downloaded Godot 4.4.1 Windows engine is in `tools/`. Double-click **Launch PekaBoo.cmd** to play. No installation is required.

The desktop menu now has separate Nearby, Online, and Solo pages. The world, models, textures, lighting, shaders, renderer, and graphics quality settings are unchanged. The Android menu is retained. The new boot artwork and animated loading screen share a house-and-peeking-eyes motif.

Press **F1** for controls. Button tooltips show shortcuts without adding labels to the game HUD. **Tab / Shift+Tab** reaches every visible button and field, **Enter** activates buttons, and arrow keys adjust sliders. Focus stays inside the active dialog. Letters and numbers typed into fields do not trigger gameplay shortcuts.

| Action | Key |
| --- | --- |
| Move / look | WASD or arrows / mouse |
| Jump / crouch | Space / C or Ctrl |
| Run | Hold Shift, or toggle R |
| Main / alternate action | E or F / Q |
| Tools / pranks / emotes | T / P / G |
| Tool slots 1–14 | 1–9, 0, -, =, [, ] |
| Pranks | Shift+1–9, or 1–9 while the Pranks panel is open |
| Emotes | 1–8 while the emote wheel is open |
| Wardrobe / settings | F2 / F3 |
| Close panel / release mouse | Escape |
| Return to main menu | F10 |
| Fullscreen | F11 |
| Nearby host / join | H / J |
| Online host / join | O / I |
| Previous / next character | [ / ] in the menu |
| Practise hide / seek | B / V |
| Explore / chill night | X / N |

Tool, prank, and action shortcuts respect button availability and cooldowns. Open dialogs block movement and gameplay actions. Number keys also select dialog buttons; Tab/Enter covers every remaining button, including dynamically created chill activities and lobby/results actions.

## Verification

From this folder in PowerShell:

```powershell
& .\tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --desktop-qa
& .\tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --qa
& .\tools\Godot_v4.4.1-stable_win64_console.exe --path game -- --desktop-qa
```

The last command saves rendered screenshots to `verification/`. Logs and downloaded executables are excluded from Git. Linux uses the same Godot project and keyboard implementation; run a Godot 4.4 Linux engine with `--path game`. Linux was not available on this Windows machine for an OS-specific launch test.

Verified on this checkout:

- Desktop input suite: **89 passed, 0 failed**, both headless and with the actual renderer.
- Existing gameplay suite: **73 passed, 2 failed**. The two failing checks concern catching hiders in hiding spots and the bot checking hiding spots. Both failures also reproduced using the untouched upstream scripts (baseline log: `verification/baseline-bot-qa.log`).
- Visually inspected the new splash, Nearby/Online/Solo menus, and keyboard help. Screenshots are in `verification/`.
- Git whitespace checks passed. All original gameplay assets, import metadata, baked lighting and shaders match the upstream checkout.
- This Windows session exposes a Microsoft virtual display adapter. Godot cannot initialize Vulkan here and automatically uses its Direct3D 12 driver; the full 3D game measured around 2–3 FPS. No renderer or graphics-quality settings were changed to compensate.
- Desktop QA avoids saving the player's settings. No online two-player network session was exercised.

`tools/render_boot_splash.gd` rasterizes the source SVG into the PNG required by Godot's boot screen:

```powershell
& .\tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game --script ..\tools\render_boot_splash.gd
```
