# Immersive Bombs

A Project Zomboid mod. Explosions from thrown bombs and placed traps damage the
environment: they break doors, windows, fences, street props and furniture, char
nearby walls, and (soon) leave scorch stains. Vanilla explosions only ever hit
characters — this mod hooks the engine's own trap/explosion event, so it works with
any bomb mod that uses vanilla trap logic, no vanilla files touched.

- Doors, secure doors and garage doors lose durability and break at 0 — weaken one
  with a bomb, then finish it off by hand.
- Furniture toughness scales with weight; destroying a container destroys its contents.
- Windows break at a longer range than it takes to damage most other things.
- Fences and street props (signs, lamps, etc.) break or are destroyed depending on
  blast intensity and proximity.
- Eligible walls char instead of breaking.

Build 42 only (built against 42.20). Doesn't modify any vanilla files, is safe to
add to or remove from an existing save, and should work in multiplayer (the server
needs the mod installed; not yet tested in MP). All settings are configured from
**Sandbox Options → Immersive Bombs**.

Steam Workshop: [Immersive Bombs](https://steamcommunity.com/sharedfiles/filedetails/?id=3802953329)

## Install

**From the Steam Workshop (recommended):** subscribe to the mod above, then enable
it from the in-game mods menu.

**Manual install:** download a release from the
[Releases page](https://github.com/Y0z64/ImmersiveBombs/releases), or clone this
repo, and copy `Contents/mods/ImmersiveBombs` into your Zomboid mods folder:

- Linux: `~/Zomboid/mods/ImmersiveBombs`
- Windows: `%USERPROFILE%\Zomboid\mods\ImmersiveBombs`

Then enable it from the in-game mods menu.

## Running locally / development

This is a pure-Lua mod — there's no build step. To iterate on it in-place, symlink
the repo's mod folder into your Zomboid user data instead of copying it, so edits
show up on the next game load:

```bash
# Linux
ln -s "$(pwd)/Contents/mods/ImmersiveBombs" ~/Zomboid/mods/ImmersiveBombs
```

```powershell
# Windows (run as administrator)
mklink /D "%USERPROFILE%\Zomboid\mods\ImmersiveBombs" "<path-to-repo>\Contents\mods\ImmersiveBombs"
```

Then enable the mod in-game as usual. Game logs land in `~/Zomboid/console.txt`
(Linux) — check there when something misbehaves. Run the game with `-debug` at
least once after touching `sandbox-options.txt` or `Sandbox.json`, since malformed
sandbox files fail loudly under strict JSON parsing but silently otherwise.

## Building from source / packaging a release

There's nothing to compile. To produce a distributable copy:

```bash
cp -r Contents/mods/ImmersiveBombs /path/to/output/ImmersiveBombs
```

The `images/` folder (raw PSD/source assets) and this repo's dev files
(`CLAUDE.md`, `.vscode`, `.idea`) are not part of the mod and should stay out of
anything you package or upload — only `Contents/mods/ImmersiveBombs` is the mod
itself.

## Issues

Found a bug or have feedback? Open an issue on this repo, or leave a comment on
the Workshop page.

## License

See [LICENSE](LICENSE).
