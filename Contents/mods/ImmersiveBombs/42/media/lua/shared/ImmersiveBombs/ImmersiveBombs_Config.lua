--- Tunables for ImmersiveBombs.
--- Damage dealt to a tile:
---   (power * range / referenceYield) ^ yieldExponent
---     * (1 - distance / reach) ^ falloffExponent
---     * damageScale * resistance
--- where power and range come from the item's ExplosionPower / ExplosionRange.
---
--- Yield is power * range: a wider charge is a bigger charge.
ImmersiveBombs = ImmersiveBombs or {}

local Config = {

    referenceYield = 630,
    yieldExponent = 2.8,
    damageScale = 4700,

    --- Tiles below this energy are skipped.
    --- TODO: This could be tweaked for performance pourposes to prevent checking a lot of tiles
    minEnergy = 0.0005,

    --- Used instead of the yield curve by throwables that declare no
    --- ExplosionPower, such as molotovs.
    fireFallback = {
        energy = 0.012,
        range = 1,
    },

    --- Furniture toughness is derived from PickUpWeight. At 50 units an object
    --- will break around 0-3 tiles from a pipebomb
    --- TODO: Modded furniture that weights exactly 0.0 (wrong or no PickUpWeight attr)
    --- should defaul to this pickup value to prevent making wrongly configured
    --- objects unncesarily brittle.
    furniture = {
        defaultWeight = 50,
    },

    --- Damage multiplier keyed on a tile's ThumpSound property. Lower = tougher.
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
    --- TODO: This should tune to all HitByCar objects and not only fences
    --- (lamposts, signs, etc)
    binary = {
        fenceBreakThreshold = 0.02,
        fenceSmashThreshold = 0.15,
        genericDamageScale  = 150,
    },

    --- Scorch/grime radius in tiles: base + reach * scale, capped at max, so
    --- it stays close to the blast regardless of how powerful the charge is.
    scorchRadiusBase = 1,
    scorchRadiusScale = 0.1,
    scorchRadiusMax = 3,
}

--- Defaults for every sandbox option.
---
--- CharThreshold is the energy that breaks a 2000 HP security door,
--- 2000 / (4700 * 0.8), so charring reaches exactly as far as a blast that
--- could take an armory door down: a pipe bomb at 0-1 tiles and nothing else.
local Defaults = {
    Enabled            = true,
    Doors              = true,
    Windows            = true,
    PlayerBuilt        = true,
    Furniture          = true,
    FencesAndProps     = true,
    BreakWalls         = true,
    DropScrap          = true,
    BlastPower         = 100,
    BlastRadius        = 100,
    Falloff            = 4.0,
    FurnitureToughness = 6.0,
    CharThreshold      = 0.53,
}

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
--- options updates.
--- TODO: Might not be optimal, measure and remove if not needed, currently only
--- useful for debug
function ImmersiveBombs.getSettings()
    return {
        enabled     = sandboxValue("Enabled"),

        doors       = sandboxValue("Doors"),
        windows     = sandboxValue("Windows"),
        playerBuilt = sandboxValue("PlayerBuilt"),
        furniture   = sandboxValue("Furniture"),
        --TODO: Change scope to include HitByCar items
        fencesAndProps = sandboxValue("FencesAndProps"),
        BreakWalls   = sandboxValue("BreakWalls"),
        dropScrap   = sandboxValue("DropScrap"),

        -- Blast reach stretches how far the shockwave carries. It does
        -- not feed back into the yield curve, so widening the radius does
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
        scorchRadiusBase  = Config.scorchRadiusBase,
        scorchRadiusScale = Config.scorchRadiusScale,
        scorchRadiusMax   = Config.scorchRadiusMax,
        fireFallback   = Config.fireFallback,
        furnitureConf  = Config.furniture,
        resistance     = Config.resistance,
        binary         = Config.binary,
    }
end

ImmersiveBombs.Config = Config
ImmersiveBombs.SandboxDefaults = Defaults
return Config
