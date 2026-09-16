--- Tunables for ImmersiveBombs.
--- Damage dealt to a tile:
---   (power * range / referenceYield) ^ yieldExponent
---     * (1 - distance / range) ^ falloffExponent
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

ImmersiveBombs = ImmersiveBombs or {}

local Config = {

    enabled = true,
    debug = false,

    referenceYield = 630,
    yieldExponent = 2.8,
    damageScale = 4700,
    falloffExponent = 4.0,

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
    --- healthPerWeight sets where furniture sits between the two extremes: at 6
    --- a typical 50-weight piece goes at 0-3 tiles from a pipe bomb, heavier
    --- pieces at 0-2, lighter at 0-4.
    furniture = {
        defaultWeight = 50,
        healthPerWeight = 6,
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

    --- Swaps eligible wall sprites for their charred, leap-through versions.
    --- One-way, and also strips doors/windows/curtains from the square.
    --- Set to the energy that breaks a 2000 HP security door, 2000 / (4700 *
    --- 0.8), so charring reaches exactly as far as a blast that could take an
    --- armory door down - a pipe bomb at 0-1 tiles and nothing else.
    --- An aerosol tops out at 0.321 energy and never chars directly, but its
    --- FireStartingChance of 10 lights fires, and IsoFire calls square:Burn()
    --- on its own, so aerosols still char walls the slow way.
    char = {
        enabled = true,
        energyThreshold = 0.53,
    },
}

ImmersiveBombs.Config = Config
return Config
