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
- Mod is hybrid B41/B42: `Contents/mods/ImmersiveBombs/` and `.../42/`, each with its own
  `mod.info`. Keep both trees identical (`diff -r`). Lua namespaced under a mod-named subfolder.

## Design

Pure Lua, no Java modloader. `IsoTrap.triggerExplosion()` fires
`LuaEventManager.triggerEvent("OnThrowableExplode", trap, square)` (`IsoTrap.java:419`,
registered `LuaEventManager.java:817`). Every thrown bomb and placed trap funnels through it —
`IsoMolotovCocktail.Explode()` builds an `IsoTrap` and calls the same method. Vanilla's
`drawCircleExplosion` only hits characters, so our work is purely additive.

**Scope rule: never destroy map walls.** Only things that could be dismantled or broken by
hand come down — doors, windows, fences, furniture, player-built structures — and even a pipe
bomb should need very high power at very close range to do it. Calibrate that way.

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
- Kahlua won't coerce floats into `int`/`short` params — floor before `setHealth`/`setDamage`.
- `__classmetatables` hooks only fire when a method is called *from Lua*. Use events, not hooks.
- Explosions resolve server-side; world mutation belongs in `media/lua/server/`.

## Current state

- `media/lua/shared/ImmersiveBombs/ImmersiveBombs_Config.lua` — tunables + calibration notes
- `media/lua/server/ImmersiveBombs/ImmersiveBombs_Blast.lua` — `OnThrowableExplode` handler

Done: durability damage + breaking doors, windows, fences, player-built structures;
charring eligible walls via `IsoGridSquare.Burn()`.
Not started: scorch stains/overlays, container contents damage.

Not yet play-tested; calibration is derived from engine health values.
