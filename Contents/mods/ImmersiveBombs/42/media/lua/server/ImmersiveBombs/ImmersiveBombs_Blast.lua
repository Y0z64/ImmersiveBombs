--- Applies environmental damage when a bomb or trap explodes.
--- OnThrowableExplode fires from IsoTrap.triggerExplosion, which every thrown
--- bomb and placed trap passes through.

if isClient() then return end

ImmersiveBombs = ImmersiveBombs or {}

local S = nil

local function materialResistance(obj)
    local resist = S.resistance
    local sprite = obj:getSprite()
    if sprite then
        local props = sprite:getProperties()
        if props and props:has("ThumpSound") then
            local sound = props:get("ThumpSound")
            if sound and resist[sound] then
                return resist[sound]
            end
        end
    end
    return resist.default
end

--- Side the object falls towards, away from the blast.
local function breakDirection(obj, originX, originY)
    local props = obj:getProperties()
    local ox, oy = obj:getX(), obj:getY()
    if props and props:has(IsoFlagType.collideN) then
        if originY >= oy then return IsoDirections.N else return IsoDirections.S end
    end
    if originX >= ox then return IsoDirections.W else return IsoDirections.E end
end

--- Brings a registered fence down, leaving broken sprites, debris and scrap.
--- `force` ignores the energy threshold. Returns true if the object was consumed.
--- TODO: Try to find a native function to replace this
local function breakFence(obj, energy, originX, originY, force)
    if not S.fencesAndProps then return false end

    local broken = BrokenFences.getInstance()
    local bent = BentFences and BentFences.getInstance() or nil

    local isBreakable = broken:isBreakableObject(obj)
    local isBendable = bent ~= nil and bent:isBendableFence(obj)
    if not (isBreakable or isBendable) then return false end
    if not force and energy < S.binary.fenceBreakThreshold then return false end

    local dir = breakDirection(obj, originX, originY)

    if isBendable then
        if force or bent:isBentObject(obj) or energy >= S.binary.fenceSmashThreshold then
            bent:smashFence(obj, dir)
        else
            bent:bendFence(obj, dir)
        end
        return true
    end

    -- destroyFence may replace obj and drop it from the square.
    local square = obj:getSquare()
    broken:destroyFence(obj, dir)
    if S.dropScrap and square ~= nil then
        broken:addItems(obj, square)
    end
    return true
end

--- Scrap left by broken furniture. Keyed on the same Material/Material2/
--- Material3 sprite properties IsoObject.addItemsFromProperties() reads.
--- 
--- Deliberately made stingier with no secured drops.
--- We are blowing shit up so we can't expect to have a lot of usable
--- materials afterwards.
local SCRAP = {
    Wood        = { item = "Base.UnusableWood", oneIn = 3 },
    MetalBars   = { item = "Base.MetalBar",     oneIn = 4 },
    MetalPlates = { item = "Base.SheetMetal",   oneIn = 4 },
    MetalPipe   = { item = "Base.MetalPipe",    oneIn = 4 },
    MetalWire   = { item = "Base.Wire",         oneIn = 6 },
    Nails       = { item = "Base.Nails",        oneIn = 4 },
    Screws      = { item = "Base.Screws",       oneIn = 5 },
}

local MATERIAL_KEYS = { "Material", "Material2", "Material3" }

local function dropScrap(props, square)
    for i = 1, #MATERIAL_KEYS do
        local material = props:get(MATERIAL_KEYS[i])
        local scrap = material and SCRAP[material]
        if scrap and ZombRand(scrap.oneIn) == 0 then
            square:AddWorldInventoryItem(scrap.item, ZombRandFloat(0.0, 0.5), ZombRandFloat(0.0, 0.5), 0.0)
        end
    end
end

--- Furniture. The engine gives it no health field at all.
--- Damage field exists but its innadecuate
--- 
--- For now toughness is derived from the PickUpWeight
local function damageFurniture(obj, energy, props, square)
    if not S.furniture then return false end
    if not (props:has("IsMoveAble") or props:has("CanScrap")) then return false end

    local weight = tonumber(props:get("PickUpWeight")) or S.furnitureConf.defaultWeight
    local health = weight * S.healthPerWeight
    if energy * S.damageScale * materialResistance(obj) < health then return false end

    if S.dropScrap then dropScrap(props, square) end
    square:transmitRemoveItemFromSquare(obj)
    return true
end

--- Objects with no health, tracked on IsoObject.damage (0-100).
local function damageBinaryObject(obj, energy, originX, originY)
    if breakFence(obj, energy, originX, originY, false) then return end

    local props = obj:getProperties()
    if props == nil then return end

    local square = obj:getSquare()
    if square == nil then return end

    if damageFurniture(obj, energy, props, square) then return end

    -- Map props - signs, posts, light fixtures - flagged destructible by impact.
    if not S.fencesAndProps then return end
    if not props:has("HitByCar") then return end

    local loss = energy * S.binary.genericDamageScale
    if obj:getDamage() - loss <= 0 then
        square:transmitRemoveItemFromSquare(obj)
        return
    end
    if loss >= 1 then obj:Damage(loss * 10) end
end

--- Do not remove floors
local function isFloor(obj)
    local props = obj:getProperties()
    return props ~= nil and props:has(IsoFlagType.solidfloor)
end

--- Interior floors get the generic burnt sprite; exterior floors don't, so
--- they get the grime decal below instead.
local function scorchFloor(obj)
    local props = obj:getProperties()
    if props:has(IsoFlagType.exterior) then return end

    local sprite = obj:getSprite()
    if sprite and sprite:getName() and sprite:getName():find("_burnt_") then return end

    obj:setSpriteFromName("floors_burnt_01_0")
    obj:transmitUpdatedSpriteToClients()
end

--- haveGrimeWall()/haveGrimeFloor() also match vanilla's ambient room
--- decoration, so check for our own exact sprite name instead.
local function hasAttachedSprite(obj, name)
    local list = obj:getAttachedAnimSprite()
    if list == nil then return false end
    for i = 0, list:size() - 1 do
        local inst = list:get(i)
        local parent = inst and inst:getParentSprite()
        if parent and parent:getName() == name then return true end
    end
    return false
end

local FLOOR_GRIME = {
    "overlay_grime_floor_01_20",
    "overlay_grime_floor_01_21",
    "overlay_grime_floor_01_22",
    "overlay_grime_floor_01_23",
}

local function floorObjectOn(square)
    if square == nil then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj ~= nil and isFloor(obj) then return obj end
    end
    return nil
end

--- Exterior floor closest to the blast, skipping ones already grimed.
local function grimeableFloor(square)
    if square == nil then return nil end
    local obj = floorObjectOn(square)
    if obj == nil then return nil end
    local props = obj:getProperties()
    if not props:has(IsoFlagType.exterior) then return nil end
    local sprite = obj:getSprite()
    if sprite and sprite:getName() and sprite:getName():find("_burnt_") then return nil end
    for i = 1, #FLOOR_GRIME do
        if hasAttachedSprite(obj, FLOOR_GRIME[i]) then return nil end
    end
    return obj
end

local function placeFloorGrimeDecal(obj)
    if obj == nil then return end
    local name = FLOOR_GRIME[ZombRand(#FLOOR_GRIME) + 1]
    obj:addAttachedAnimSpriteByName(name)
    obj:transmitUpdatedSpriteToClients()
end

--- Wall grime is directional: whichever wall (North or West) faces the blast.
local WALL_GRIME_NORTH = "overlay_grime_wall_01_1"
local WALL_GRIME_WEST = "overlay_grime_wall_01_0"

local function scorchWall(square, originX, originY)
    local bNorth = math.abs(square:getY() - originY) >= math.abs(square:getX() - originX)
    local wall = square:getWall(bNorth)
    if wall == nil then return end

    local grimeName = bNorth and WALL_GRIME_NORTH or WALL_GRIME_WEST
    if hasAttachedSprite(wall, grimeName) then return end

    wall:addAttachedAnimSpriteByName(grimeName)
    wall:transmitUpdatedSpriteToClients()
end

--- Scorch/grime stays close to the blast regardless of power - gated on
--- tile distance, not the destruction energy curve.
local function applyStains(square, dist, scorchRadius, originX, originY, snapshot)
    if dist > scorchRadius then return end

    for i = 1, #snapshot do
        local obj = snapshot[i]
        if obj ~= nil and isFloor(obj) then
            scorchFloor(obj)
        end
    end

    scorchWall(square, originX, originY)
end

local function thumpableAllowed(obj)
    if obj:isDoor() then return S.doors end
    if obj:isWindow() then return S.windows end
    return S.playerBuilt
end

local function resolveObject(obj, energy, originX, originY)
    if obj == nil then return end
    if isFloor(obj) then return end

    -- Smashes itself and trips the alarm at zero health.
    if instanceof(obj, "IsoWindow") then
        if S.windows then
            obj:Damage(energy * S.damageScale * materialResistance(obj))
        end
        return
    end

    -- IsoDoor has no Damage(float).
    if instanceof(obj, "IsoDoor") then
        if not S.doors then return end
        if obj:getHealth() <= 0 then return end
        local damage = energy * S.damageScale * materialResistance(obj)
        obj:setHealth(math.max(0, math.floor(obj:getHealth() - damage)))
        if obj:getHealth() <= 0 then
            obj:destroy()
        end
        return
    end

    if instanceof(obj, "IsoThumpable") then
        if not thumpableAllowed(obj) then return end
        if obj:getHealth() <= 0 then return end
        obj:Damage(energy * S.damageScale * materialResistance(obj))
        -- Damage does not destroy on its own.
        if obj:getHealth() <= 0 then
            if not breakFence(obj, energy, originX, originY, true) then
                obj:destroy()
            end
        end
        return
    end

    damageBinaryObject(obj, energy, originX, originY)
end

local function applyToSquare(square, energy, originX, originY, dist, scorchRadius)
    if square == nil then return end
    if NonPvpZone.getNonPvpZone(square:getX(), square:getY()) ~= nil then return end

    -- Snapshot: destroying an object mutates the square's object list.
    local objects = square:getObjects()
    local snapshot = {}
    for i = 0, objects:size() - 1 do
        snapshot[#snapshot + 1] = objects:get(i)
    end

    for i = 1, #snapshot do
        resolveObject(snapshot[i], energy, originX, originY)
    end

    applyStains(square, dist, scorchRadius, originX, originY, snapshot)

    if S.BreakWalls and energy >= S.charThreshold then
        square:Burn()
    end
end

local function onThrowableExplode(trap, square)
    S = ImmersiveBombs.getSettings()
    if not S.enabled then return end
    if trap == nil or square == nil then return end

    local power = trap:getExplosionPower()
    local range = trap:getExplosionRange()
    local baseEnergy

    if power > 0 and range > 0 then
        -- Yield is power * range: a wider charge is a bigger charge.
        baseEnergy = (power * range / S.referenceYield) ^ S.yieldExponent
    else
        if trap:getFireStartingEnergy() <= 0 then return end
        baseEnergy = S.fireFallback.energy
        range = S.fireFallback.range
    end

    baseEnergy = baseEnergy * S.powerScale

    -- Reach stretches the shockwave without changing the yield above.
    local reach = range * S.reachScale
    if reach <= 0 then return end

    local cell = square:getCell()
    local ox, oy, oz = square:getX(), square:getY(), square:getZ()
    local r = math.floor(reach)
    local scorchRadius = math.min(S.scorchRadiusMax, S.scorchRadiusBase + reach * S.scorchRadiusScale)

    -- Nearest grimeable exterior floor to the blast gets the decal.
    local decalObj, decalDist

    for x = ox - r, ox + r do
        for y = oy - r, oy + r do
            local dx, dy = x - ox, y - oy
            local dist = (dx * dx + dy * dy) ^ 0.5
            if dist <= reach then
                local falloff = (1 - dist / reach) ^ S.falloffExponent
                local energy = baseEnergy * falloff
                if energy >= S.minEnergy then
                    local target = cell:getGridSquare(x, y, oz)
                    applyToSquare(target, energy, ox, oy, dist, scorchRadius)
                    if dist <= scorchRadius and (decalDist == nil or dist < decalDist) then
                        local obj = grimeableFloor(target)
                        if obj ~= nil then decalObj, decalDist = obj, dist end
                    end
                end
            end
        end
    end

    placeFloorGrimeDecal(decalObj)
end

Events.OnThrowableExplode.Add(onThrowableExplode)

ImmersiveBombs.onThrowableExplode = onThrowableExplode
