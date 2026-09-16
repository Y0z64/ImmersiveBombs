# ImmersiveBombs — Project Zomboid Mod

Explosions (thrown bombs + placed traps) damage the environment: break doors, windows
and furniture, and leave scorch stains on walls and floors.

## Sources of truth (strict priority — never invert)

Per [Getting started with modding § Sources of truth](https://pzwiki.net/wiki/Getting_started_with_modding):
game files > API docs > wiki/Discords > external docs > forums > **LLMs, last**.
Never assert from memory; verify in the source before deciding.

- Decompiled Java: `/home/yair/Downloads/ZomboidDecompiler/bin/output/source/`
- Vanilla Lua + scripts: `/home/yair/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/media/`
- [JavaDocs](https://projectzomboid.com/modding/) · [LuaDocs](https://demiurgequantified.github.io/ProjectZomboidLuaDocs/) · [wiki](https://pzwiki.net/wiki/Modding)
- pzwiki 403s normal fetchers: `curl -A "Mozilla/5.0 ..." "https://pzwiki.net/wiki/PAGE?action=raw"`

## Environment

- **Build 42**. Game at `.../common/ProjectZomboid/projectzomboid/` (note nested dir).
- User data `~/Zomboid`; logs `~/Zomboid/console.txt`.
- Game runs **Kahlua (Lua 5.1)** — no external libs, no 5.2+ syntax. System `lua` 5.4 is
  for `luac -p` syntax checks only.
- **B42 only.** Mod lives at `Contents/mods/ImmersiveBombs/42/` with its own `mod.info`.
  B42 reads only `common/` and `<version>/` (`ZomboidFileSystem.getAllModFoldersAux`), so a
  root `media/` or `mod.info` is ignored entirely. Lua namespaced under a mod-named subfolder.
- Testing: `~/Zomboid/mods/ImmersiveBombs` is symlinked to the repo's mod folder.

## Design

Pure Lua, no Java modloader. `IsoTrap.triggerExplosion()` fires
`LuaEventManager.triggerEvent("OnThrowableExplode", trap, square)` (`IsoTrap.java:419`,
registered `LuaEventManager.java:817`). Every thrown bomb and placed trap funnels through it —
`IsoMolotovCocktail.Explode()` builds an `IsoTrap` and calls the same method. Vanilla's
`drawCircleExplosion` only hits characters, so our work is purely additive.

**Scope rule: never destroy map walls, and never touch floors at all.** Only things that
could be dismantled or broken by hand come down — doors, windows, fences, furniture,
player-built structures — and even a pipe bomb should need very high power at very close
range to do it. Calibrate that way.

Removing a floor leaves an impassable black void, so `resolveObject` drops anything flagged
`solidfloor` before any other test — 139 vanilla floor tiles (carpets, plank floors, metal
catwalks) carry `IsMoveAble`/`CanScrap` and would otherwise go down the furniture path at a
`PickUpWeight` of 10. Charring is fine: `BurnWalls` swaps interior floors for
`floors_burnt_01_0`, a real sprite.

The one legitimate thing we do to walls is **char** them: `IsoGridSquare.Burn()` runs the
engine's `BurnWalls`, swapping eligible sprites for `walls_burnt_01_*` — the charred versions
you can leap through like a window — and fires `OnGridBurnt`. Eligibility is the engine's call,
not ours: `BurnWalls` skips any sprite whose `firerequirement` is at or above
`FIRE_IMMUNE_THRESHOLD` (800000), so timber chars and concrete doesn't. It is one-way and also
strips doors/windows/curtains from the square, so keep it behind a high energy threshold.

Reuse the engine's own damage systems rather than a hand-written material table, so modded
content is covered for free:

- **`IHasHealth`** (`IsoDoor`, `IsoThumpable`, `IsoTree`, `IsoBarricade`) — health *is* the
  hardness metric, assigned from tile data. Doors: 100 fence gate / 500 weak wooden /
  800 strong wooden / **2000 `forceLocked`** (`IsoDoor.java:794-808`). Windows 50.
- **`IsoObject.damage`** — generic 0-100 short for healthless objects (`isDestroyed()` is
  `damage <= 0`), driven by `AttackObject()`, `HitByVehicle()` and `Damage(float)`. Map props
  like signs are gated by the **`HitByCar`** sprite property.
- **Furniture has no health field at all** — a dresser is a bare `IsoObject`. Gate on
  `IsMoveAble`/`CanScrap` (= "could be dismantled") and derive toughness from `PickUpWeight`.
  Scrap comes from `Material`/`Material2`/`Material3`; `addItemsFromProperties()` is
  `protected` so its table is mirrored in Lua. The `ISMoveableSpriteProps` Lua framework is
  about player pickup, not destruction — its `canBreak` means "botched dismantle".
- **`BrokenFences` / `BentFences`** — tile lists populated *from Lua*
  (`media/lua/server/Items/BrokenFences.lua`), so modded fences register themselves.
- **`ThumpSound`** sprite property — the engine's per-tile material tag, used as resistance.

## API traps (all cost a bug already)

- **`IsoDoor` has no `Damage(float)`** — use `getHealth`/`setHealth(int)`/`destroy()`.
- `IsoThumpable.Damage()` does **not** self-destroy; `IsoWindow.Damage()` does (and trips the alarm).
- `destroyFence` replaces an `IsoThumpable` with a fresh `IsoObject` and drops **no** loot —
  capture the square *first*, call `addItems` separately.
- **Instance fields are unreadable from Lua since B42.15.** Public getters only. This rules out
  `BentFences.ThumpData.bendStage` → use `isBentObject()`.
- **Kahlua passes every Lua number as a `Double`.** `int` params coerce (`setHealth`), `short`
  ones do **not**, and `math.floor` cannot help — it returns a Double too. So
  `IsoObject.setDamage(short)` is unreachable from Lua; go through `IsoObject.Damage(float)`,
  which casts internally as `damage -= (short)(amount * 0.1)`.
- `__classmetatables` hooks only fire when a method is called *from Lua*. Use events, not hooks.
- Explosions resolve server-side; world mutation belongs in `media/lua/server/`.

## Settings

Gameplay knobs are **sandbox options**, never `PZAPI.ModOptions`. The wiki is explicit
([ModOptions](https://pzwiki.net/wiki/ModOptions)): mod options are client-local and global
across saves, so anything that mutates the world desyncs MP and belongs in sandbox options.
Ours give a dedicated "Immersive Bombs" page in the Sandbox Options screen, the server
settings editor, and the in-game admin/debug sandbox editor.

- `media/sandbox-options.txt` — read from `getVersionDir()/media/`, then `getCommonDir()/media/`
  (`CustomSandboxOptions.java:31-38`). `option ImmersiveBombs.Foo` → `SandboxVars.ImmersiveBombs.Foo`.
- Names/tooltips: `Sandbox_<translation>` and `Sandbox_<translation>_tooltip`; the page title is
  `Sandbox_<page>`. Mod file: `media/lua/shared/Translate/EN/Sandbox.json` (B42 uses JSON).

Sandbox-options traps:

- **`readFile` concatenates lines with no separator** (`CustomSandboxOptions.java:62-64`), and
  `ScriptParser.stripComments` only understands `/* */`. A `//` comment therefore eats the rest
  of the file. Every entry needs its own trailing comma, including the last before a `}` —
  `readBlock` returns on `}` without flushing a pending value.
- **`double`/`integer` render as text entry boxes**, not sliders; `min`/`max` are required or
  `parse` returns null and the option is dropped silently.
- **Read through `getSandboxOptions():getOptionByName()`, not `SandboxVars`.** The admin/debug
  editor's Apply calls `getSandboxOptions():set()` and never `toLua()`
  (`ISServerSandboxOptionsUI.lua:739`), so the `SandboxVars` table goes stale on a mid-game edit.
- `Translator.getText` runs `String.formatted` on the result, so a literal `%` in an option
  name throws (caught, but logged). Avoid it.

## Current state

- `media/sandbox-options.txt` — 16 player-facing options
- `media/lua/shared/Translate/EN/Sandbox.json` — their names and tooltips
- `media/lua/shared/ImmersiveBombs/ImmersiveBombs_Config.lua` — curve shape, calibration notes,
  and `ImmersiveBombs.getSettings()`, which folds the sandbox choices in once per blast
- `media/lua/server/ImmersiveBombs/ImmersiveBombs_Blast.lua` — `OnThrowableExplode` handler

Defaults: doors, windows, fences, player-built structures and street props **on**; furniture
and wall charring **off**. `BlastPower` scales the blast's *energy*, not `damageScale`, because
fences, props and charring are decided by comparing energy against a threshold and would
otherwise ignore it.

Done: durability damage + breaking doors, windows, fences, player-built structures;
charring eligible walls via `IsoGridSquare.Burn()`; sandbox options for all of it.
Not started: scorch stains/overlays (the `ScorchMarks` option is reserved and currently inert),
container contents damage.

Not yet play-tested; calibration is derived from engine health values.
