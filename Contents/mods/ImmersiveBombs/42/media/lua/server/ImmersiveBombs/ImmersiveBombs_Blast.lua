--- Applies environmental damage when a bomb or trap explodes.
--- OnThrowableExplode fires from IsoTrap.triggerExplosion, which every thrown
--- bomb and placed trap passes through.

if isClient() then return end

ImmersiveBombs = ImmersiveBombs or {}

local function cfg()
    return ImmersiveBombs.Config
end

local function log(msg)
    if cfg().debug then print("[ImmersiveBombs] " .. tostring(msg)) end
end

local function materialResistance(obj)
    local resist = cfg().resistance
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
local function breakFence(obj, energy, originX, originY, force)
    local C = cfg()
    local broken = BrokenFences.getInstance()
    local bent = BentFences and BentFences.getInstance() or nil

    local isBreakable = broken:isBreakableObject(obj)
    local isBendable = bent ~= nil and bent:isBendableFence(obj)
    if not (isBreakable or isBendable) then return false end
    if not force and energy < C.binary.fenceBreakThreshold then return false end

    local dir = breakDirection(obj, originX, originY)

    if isBendable then
        if force or bent:isBentObject(obj) or energy >= C.binary.fenceSmashThreshold then
            bent:smashFence(obj, dir)
        else
            bent:bendFence(obj, dir)
        end
        return true
    end

    -- destroyFence may replace obj and drop it from the square.
    local square = obj:getSquare()
    broken:destroyFence(obj, dir)
    if square ~= nil then
        broken:addItems(obj, square)
    end
    return true
end

--- Scrap left by broken furniture. Mirrors IsoObject.addItemsFromProperties,
--- which is protected and so unreachable from Lua. Keyed on the same
--- Material/Material2/Material3 sprite properties the engine reads, so modded
--- furniture that declares them drops the right parts.
local SCRAP = {
    Wood        = { item = "Base.UnusableWood", oneIn = 1 },
    MetalBars   = { item = "Base.MetalBar",     oneIn = 2 },
    MetalPlates = { item = "Base.SheetMetal",   oneIn = 2 },
    MetalPipe   = { item = "Base.MetalPipe",    oneIn = 2 },
    MetalWire   = { item = "Base.Wire",         oneIn = 3 },
    Nails       = { item = "Base.Nails",        oneIn = 2 },
    Screws      = { item = "Base.Screws",       oneIn = 2 },
}

local function dropScrap(props, square)
    for _, key in ipairs({ "Material", "Material2", "Material3" }) do
        local material = props:get(key)
        local scrap = material and SCRAP[material]
        if scrap and ZombRand(scrap.oneIn) == 0 then
            square:AddWorldInventoryItem(scrap.item, ZombRandFloat(0.0, 0.5), ZombRandFloat(0.0, 0.5), 0.0)
        end
    end
end

--- Furniture. The engine gives it no health field at all - a dresser is a bare
--- IsoObject whose only durability is IsoObject.damage, the same 0-100 short
--- that AttackObject decrements by 10 a swing and HitByVehicle drives. So we
--- spend blast energy against a toughness derived from PickUpWeight, the
--- vanilla per-tile weight used for carrying furniture around.
---
--- The gate is IsMoveAble / CanScrap: only furniture that could be dismantled
--- or carried is breakable, which is also the scope rule for this mod.
--- HitByCar does not cover furniture - it flags map props like signs and posts.
local function damageFurniture(obj, energy, props, square)
    local C = cfg()
    if not (props:has("IsMoveAble") or props:has("CanScrap")) then return false end

    local weight = tonumber(props:get("PickUpWeight")) or C.furniture.defaultWeight
    local health = weight * C.furniture.healthPerWeight
    if energy * C.damageScale * materialResistance(obj) < health then return false end

    dropScrap(props, square)
    square:transmitRemoveItemFromSquare(obj)
    return true
end

--- Objects with no health, tracked on IsoObject.damage (0-100).
local function damageBinaryObject(obj, energy, originX, originY)
    if breakFence(obj, energy, originX, originY, false) then return end

    local C = cfg()
    local props = obj:getProperties()
    if props == nil then return end

    local square = obj:getSquare()
    if square == nil then return end

    if damageFurniture(obj, energy, props, square) then return end

    -- Map props - signs, posts, light fixtures - flagged destructible by impact.
    if not props:has("HitByCar") then return end

    local newDamage = obj:getDamage() - (energy * C.binary.genericDamageScale)
    if newDamage <= 0 then
        square:transmitRemoveItemFromSquare(obj)
        return
    end
    obj:setDamage(math.floor(newDamage))
end

local function resolveObject(obj, energy, originX, originY)
    if obj == nil then return end

    local damage = energy * cfg().damageScale * materialResistance(obj)

    -- Smashes itself and trips the alarm at zero health.
    if instanceof(obj, "IsoWindow") then
        obj:Damage(damage)
        return
    end

    -- IsoDoor has no Damage(float).
    if instanceof(obj, "IsoDoor") then
        if obj:getHealth() <= 0 then return end
        obj:setHealth(math.max(0, math.floor(obj:getHealth() - damage)))
        if obj:getHealth() <= 0 then
            obj:destroy()
        end
        return
    end

    if instanceof(obj, "IsoThumpable") then
        if obj:getHealth() <= 0 then return end
        obj:Damage(damage)
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

local function applyToSquare(square, energy, originX, originY)
    if square == nil then return end
    if NonPvpZone.getNonPvpZone(square:getX(), square:getY()) ~= nil then
        return
    end

    -- Snapshot: destroying an object mutates the square's object list.
    local objects = square:getObjects()
    local snapshot = {}
    for i = 0, objects:size() - 1 do
        snapshot[#snapshot + 1] = objects:get(i)
    end

    for i = 1, #snapshot do
        resolveObject(snapshot[i], energy, originX, originY)
    end

    -- Burn() chars eligible walls and strips doors, windows and curtains.
    -- It skips sprites the engine considers fire-immune, such as concrete.
    if cfg().char.enabled and energy >= cfg().char.energyThreshold then
        square:Burn()
    end
end

local function onThrowableExplode(trap, square)
    local C = cfg()
    if not C or not C.enabled then return end
    if trap == nil or square == nil then return end

    local power = trap:getExplosionPower()
    local range = trap:getExplosionRange()
    local baseEnergy

    if power > 0 and range > 0 then
        -- Yield is power * range: a wider charge is a bigger charge.
        baseEnergy = (power * range / C.referenceYield) ^ C.yieldExponent
    else
        if trap:getFireStartingEnergy() <= 0 then return end
        baseEnergy = C.fireFallback.energy
        range = C.fireFallback.range
    end

    local cell = square:getCell()
    local ox, oy, oz = square:getX(), square:getY(), square:getZ()
    local r = math.floor(range)

    log(string.format("blast at %d,%d,%d power=%d range=%d energy=%.4f",
        ox, oy, oz, power, range, baseEnergy))

    for x = ox - r, ox + r do
        for y = oy - r, oy + r do
            local dx, dy = x - ox, y - oy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= range then
                local falloff = (1 - dist / range) ^ C.falloffExponent
                local energy = baseEnergy * falloff
                if energy >= C.minEnergy then
                    applyToSquare(cell:getGridSquare(x, y, oz), energy, ox, oy)
                end
            end
        end
    end
end

Events.OnThrowableExplode.Add(onThrowableExplode)

ImmersiveBombs.onThrowableExplode = onThrowableExplode
