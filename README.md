# PekaBoo 🫣💜

A cosy hide-and-seek game for two, made with Godot 4 for Android — by **RubinBastakoti**.

- **Hide & seek** in a big two-storey house with a garden, hedge maze and shed: hide in spots, turn into furniture, prank each other, and find each other with radar, X-ray and Marco-Polo.
- **Play together** over a phone hotspot or Wi-Fi (one phone hosts, the other joins) — or practise against a bot.
- **Chill mode 🌙**: the house at night with candles, fairy lights, a picnic under the stars, love songs, kissing, hugging, slow dancing, holding hands, sky lanterns, fireworks, sky messages, stargazing, a rooftop deck, a garden swing, pets, cooking together, pillow fights, selfies, rain and snow.
- Anniversary surprise every **2 February**.

## Building

1. Install Godot 4.4 with the Android export templates, the Android SDK and a JDK (the build script expects them in `~/gamedev-tools`).
2. Put the release keystore (`rubinbastakoti-release.keystore`) and `KEYSTORE-README.txt` in this folder (they are not in git).
3. Run `./build.sh` → `build/PekaBoo.apk` (also copied to `~/Downloads/PekaBoo-v1.0.apk`).

The build bakes the house lighting (day and night) on the PC, exports the APK and signs it.

## Credits

Music by Kevin MacLeod (incompetech.com, CC BY 4.0). Sound effects from the BBC Sound Effects archive (personal use) and Kenney (CC0). Furniture, characters and jingles by Kenney (CC0). Textures, sky and props from Poly Haven (CC0). Fonts: Fredoka (SIL OFL), Noto Color Emoji (SIL OFL). Peeking-face emoji from Twemoji (CC BY 4.0).

This is a private, personal project.
