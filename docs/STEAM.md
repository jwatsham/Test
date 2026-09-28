# Getting Rhythm Chiropractor onto Steam

A checklist, roughly in the order you'll need it. Valve's rules change; confirm details at
https://partner.steamgames.com/doc/home.

## Business setup (start now, it has lead time)

- [ ] Create a Steamworks partner account, complete tax and bank info.
- [ ] Pay the Steam Direct fee (US$100 per game, recoupable after $1,000 gross revenue).
- [ ] Valve requires a waiting period between paying and releasing, and the store page must be
      public ("Coming Soon") for at least 2 weeks before launch. Plan backwards from your date.

## Store page (this is your marketing; do it early)

- [ ] Capsule art in all required sizes (header, small, main, vertical, library). **Hire an
      artist for this.** It's the single most important sales asset, and code art won't cut it.
- [ ] 5+ screenshots, a 30 to 60 second trailer that shows a crack in the first 3 seconds.
- [ ] Short description that sells the joke in one line.
- [ ] Put the page up as early as possible to collect wishlists. Wishlists drive launch visibility.

## Build and export

- [ ] Godot → Editor → Manage Export Templates → download for your Godot version.
- [ ] Project → Export → add **Windows Desktop** and **Linux** presets (Linux covers Steam Deck
      natively, and Windows builds run through Proton as a fallback).
- [ ] Set the app icon, product name and version in the Windows preset.
- [ ] Export to `builds/windows/` and `builds/linux/` (already git-ignored).

## Steam integration (optional for launch, needed for achievements etc.)

- [ ] Add **GodotSteam** (https://godotsteam.com), either the GDExtension from the Asset Library
      or the prebuilt editor.
- [ ] Put `steam_appid.txt` with your App ID next to the executable when testing locally.
- [ ] Easy wins for this game: achievements ("Crack 100 spines", "S rank", "Fix the Banana"),
      Steam Cloud for `user://settings.cfg`, leaderboards per level.

## Upload

- [ ] Install the Steamworks SDK, configure `app_build` / `depot_build` VDF scripts.
- [ ] Upload with SteamPipe (`steamcmd +login ... +run_app_build ...`) or the SteamPipe GUI.
- [ ] Set the build live on a beta branch, test on a clean machine **and a Steam Deck**.
- [ ] Submit the store page and build for Valve review (allow several business days each).

## Steam Deck notes

- Controls already include gamepad A. Verify the UI text is readable at 1280x800.
- Rhythm games are sensitive to Bluetooth audio latency on Deck. The audio offset setting
  (`[` / `]` on the title screen) exists for this, but it should get a proper menu with a
  tap-to-the-beat calibration before release.
