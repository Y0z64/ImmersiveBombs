--- Tunables for ImmersiveBombs.
--- Damage dealt to a tile:
---   (power * range / referenceYield) ^ yieldExponent
---     * (1 - distance / reach) ^ falloffExponent
---     * damageScale * resistance
--- where power and range come from the item's ExplosionPower / ExplosionRange.
---
--- Yield is power * range, not power alone: a wider charge is a bigger charge.
--- Aerosolbomb 70*6=420, PipeBomb 90*7=630 (the reference). Power alone splits
--- them by only 1.29x, too little to both break a security door with a pipe
--- bomb and hold an aerosol at 60% of one.
---
--- damageScale is not free - it is pinned by "pipe bomb breaks 2000 HP at one
--- tile". Once pinned, scale and resistance cancel out and the aerosol's share
--- reduces to (420/630)^yieldExponent / falloff@1tile, so yieldExponent is the
--- only dial that moves it. Steeper falloff pushes it the wrong way.
---
--- The numbers below are the shape of the curve and are not player-facing.
--- What players tweak lives in media/sandbox-options.txt and arrives through
--- ImmersiveBombs.getSettings(), at the bottom of this file.

ImmersiveBombs = ImmersiveBombs or {}

local Config = {

    referenceYield = 630,
    yieldExponent = 2.8,
    damageScale = 4700,

    --- Tiles below this energy are skipped.
    minEnergy = 0.0005,

    --- Used instead of the yield curve by throwables that declare no
    --- ExplosionPower, such as molotovs.
    fireFallback = {
        energy = 0.012,
        range = 1,
    },

    --- Furniture has no health field in the engine - a dresser is a bare
    --- IsoObject. Toughness is derived from PickUpWeight, the vanilla per-tile
    --- carrying weight, so a wardrobe resists far more than a chair and modded
    --- furniture is covered without knowing about it.
    --- The multiplier on that weight is the FurnitureToughness sandbox option:
    --- at 6 a typical 50-weight piece goes at 0-3 tiles from a pipe bomb,
    --- heavier pieces at 0-2, lighter at 0-4.
    furniture = {
        defaultWeight = 50,
    },

    --- Damage multiplier keyed on a tile's ThumpSound property. Lower = tougher.
    --- Material response only - toughness already lives in each object's health.
    --- Glass is high on purpose: a blast wave should take windows out well
    --- beyond the range where it structurally breaks anything.
    resistance = {
        ZombieThumpWindow          = 2.20,
        ZombieThumpWindowExtra     = 2.20,
        ZombieThumpWood            = 1.00,
        ZombieThumpGeneric         = 0.90,
        ZombieThumpChainlinkFence  = 0.85,
        ZombieThumpMetalPoleGate   = 0.80,
        ZombieThumpMetal           = 0.80,
        ZombieThumpGarageDoor      = 0.75,
        default                    = 0.90,
    },

    --- Objects with no health, damaged on IsoObject.damage (0-100).
    --- Thresholds are in energy, so 0-1.
    binary = {
        fenceBreakThreshold = 0.02,
        fenceSmashThreshold = 0.15,
        genericDamageScale  = 150,
    },
}

--- Defaults for every sandbox option, mirroring media/sandbox-options.txt.
--- They are the fallback when the option cannot be read - a mod folder without
--- sandbox-options.txt, or Lua running before the options are registered - so
--- the mod still behaves sanely instead of silently doing nothing.
---
--- CharThreshold is the energy that breaks a 2000 HP security door,
--- 2000 / (4700 * 0.8), so charring reaches exactly as far as a blast that
--- could take an armory door down: a pipe bomb at 0-1 tiles and nothing else.
--- An aerosol tops out at 0.321 energy and never chars directly, but its
--- FireStartingChance of 10 lights fires, and IsoFire calls square:Burn() on
--- its own, so aerosols still char walls the slow way.
local Defaults = {
    Enabled            = true,
    Doors              = true,
    Windows            = true,
    PlayerBuilt        = true,
    Furniture          = false,
    FencesAndProps     = true,
    BreakWalls         = false,
    DropScrap          = true,
    BlastPower         = 100,
    BlastRadius        = 100,
    Falloff            = 4.0,
    FurnitureToughness = 6.0,
    CharThreshold      = 0.53,
}

--- Read straight from the SandboxOptions object rather than from SandboxVars.
--- Both are populated at world load, but only the object is kept current by the
--- in-game admin/debug sandbox editor: its Apply calls getSandboxOptions():set()
--- and never toLua(), so the SandboxVars table goes stale the moment an admin
--- changes anything mid-game.
local function sandboxValue(name)
    local options = getSandboxOptions()
    if options == nil then return Defaults[name] end

    local option = options:getOptionByName("ImmersiveBombs." .. name)
    if option == nil then return Defaults[name] end

    local value = option:getValue()
    if value == nil then return Defaults[name] end
    return value
end

--- The effective settings for one explosion: the curve above, with the player's
--- sandbox choices folded in. Built once per blast, so a mid-game change to the
--- options takes effect on the very next bomb.
function ImmersiveBombs.getSettings()
    return {
        enabled     = sandboxValue("Enabled"),

        doors       = sandboxValue("Doors"),
        windows     = sandboxValue("Windows"),
        playerBuilt = sandboxValue("PlayerBuilt"),
        furniture   = sandboxValue("Furniture"),
        -- One switch for both: fences and street props are the map clutter
        -- vanilla already lets a car flatten, reached through BrokenFences /
        -- BentFences and the HitByCar sprite flag respectively.
        fencesAndProps = sandboxValue("FencesAndProps"),
        BreakWalls   = sandboxValue("BreakWalls"),
        dropScrap   = sandboxValue("DropScrap"),

        -- Blast power multiplies the blast's energy rather than damageScale,
        -- so it reaches every consequence uniformly. Half the destruction here
        -- is decided by comparing energy against a threshold, not by spending
        -- damage against health - fences bend and flatten on energy, street
        -- props take energy-derived damage, walls char above a fixed energy -
        -- and scaling damageScale alone would leave all of those untouched.
        -- At 0 the energy is 0, so nothing anywhere is so much as scratched.
        --
        -- Blast reach stretches how far the shockwave carries. It deliberately
        -- does not feed back into the yield curve, so widening the radius does
        -- not also make the charge stronger.
        powerScale       = sandboxValue("BlastPower") / 100,
        reachScale       = sandboxValue("BlastRadius") / 100,
        falloffExponent  = sandboxValue("Falloff"),
        healthPerWeight  = sandboxValue("FurnitureToughness"),
        charThreshold    = sandboxValue("CharThreshold"),

        damageScale    = Config.damageScale,
        referenceYield = Config.referenceYield,
        yieldExponent  = Config.yieldExponent,
        minEnergy      = Config.minEnergy,
        fireFallback   = Config.fireFallback,
        furnitureConf  = Config.furniture,
        resistance     = Config.resistance,
        binary         = Config.binary,
    }
end

ImmersiveBombs.Config = Config
ImmersiveBombs.SandboxDefaults = Defaults
return Config
