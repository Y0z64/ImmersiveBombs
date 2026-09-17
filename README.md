# Immersive Bombs

## Breakdown secured doors and walls
Explosions now damage the world around them:
Damage or break doors, secure doors and garages.
Break windows and furniture around explosions
Scorch floors, walls and leave marks on the world

## How it works
The explosion intensity is calculated with both the explosion power and the range of the bomb with a steep distance falloff.

### Different objects are damaged in different ways:
- Doors, Garege doors and Secure doors: Have their durability reduced and break at 0. Meaning that you can weaken a door with a bomb and then finish it off with melee atacks.

- Furniture: Furniture toughness is calculated by the object's weight. Very heavy objects will be difficult to destroy even with a powerful bomb while small objects like chairs will blow up easy. Destroying a container also destroys the contents.

- Windows: Windows break at a very far distance of the explosion center and don't require a very powerful bomb to break.

- Fences and other props: Explosions will either break or completely destroy fences and other damageable objects (signs, lamps, etc.) depending on the explosion intensity and proximity.

### Default bomb behaviour:
- Aerosol bombs damage a secure door for around 60% of its health but cannot destroy walls or most furniture.

- Pipe bombs breakdown secure doors and destroy walls at point blank.

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
(Linux), check there when something misbehaves. Run the game with `-debug` at
least once after touching `sandbox-options.txt` or `Sandbox.json`, since malformed
sandbox files fail loudly under strict JSON parsing but silently otherwise.

## Issues

Found a bug or have feedback? Open an issue on this repo, or leave a comment on
the Workshop page.

## License

See [LICENSE](LICENSE).
