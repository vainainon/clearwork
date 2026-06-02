local DEFAULT_CHANCE = 15
local ROULETTE_COUNTDOWN_SECONDS = 5
local DOWNED_SECONDS = 300

local activeKnockdowns = {}

local function IsDeadFlag(value)
    if value == true then return true end
    if value == 1 then return true end

    if type(value) == 'string' then
        local normalized = value:lower()
        return normalized == '1' or normalized == 'true' or normalized == 'yes'
    end

    return tonumber(value) == 1
end

local function ClampChance(value)
    value = tonumber(value) or DEFAULT_CHANCE
    value = math.floor(value)

    if value < 0 then value = 0 end
    if value > 100 then value = 100 end

    return value
end

local function NormalizeCoords(coords)
    coords = coords or {}

    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        heading = tonumber(coords.heading) or tonumber(coords.h) or 0.0
    }
end

local function EnsureColumn(tableName, columnName, definition)
    local exists = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
    ]], { tableName, columnName })

    if tonumber(exists) == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, definition))
    end
end

local function EnsureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS cw_settings (
            `key` VARCHAR(64) NOT NULL,
            `value` LONGTEXT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        INSERT IGNORE INTO cw_settings (`key`, `value`)
        VALUES ('permadeath_chance', '15');
    ]])

    EnsureColumn('characters', 'is_dead', '`is_dead` TINYINT(1) NOT NULL DEFAULT 0')
    EnsureColumn('characters', 'revived_at', '`revived_at` DATETIME NULL')
end

local function GetPermadeathChance()
    local value = MySQL.scalar.await(
        'SELECT `value` FROM cw_settings WHERE `key` = ? LIMIT 1',
        { 'permadeath_chance' }
    )

    return ClampChance(value)
end

local function SetPermadeathChance(value)
    local chance = ClampChance(value)

    MySQL.update.await([[
        INSERT INTO cw_settings (`key`, `value`)
        VALUES ('permadeath_chance', ?)
        ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
    ]], { tostring(chance) })

    return chance
end

local function GetCWPlayer(src)
    local ok, player = pcall(function()
        return exports['cw-core']:GetPlayer(src)
    end)

    if ok then return player end
    return nil
end

local function SaveCharacterPosition(src, coords)
    coords = NormalizeCoords(coords)

    pcall(function()
        exports['cw-core']:SaveCharacterPosition(src, coords)
    end)
end

local function IsCharacterPermadead(characterId)
    characterId = tonumber(characterId)
    if not characterId then return false end

    local value = MySQL.scalar.await(
        'SELECT is_dead FROM characters WHERE id = ? LIMIT 1',
        { characterId }
    )

    return IsDeadFlag(value)
end

local function IsPlayerDeathLocked(src)
    src = tonumber(src)
    if not src then return false end

    -- Этот экспорт используется меню персонажей как блок переключения.
    -- Блокировать надо только активный нокдаун/рулетку, а не уже случившийся пермакилл.
    return activeKnockdowns[src] ~= nil
end

local function IsPlayerPermanentlyDead(src)
    src = tonumber(src)
    if not src then return false end

    local player = GetCWPlayer(src)
    if not player or not player.character then return false end

    if IsDeadFlag(player.character.is_dead) then return true end

    local characterId = tonumber(player.character.id)
    if not characterId then return false end

    return IsCharacterPermadead(characterId)
end

local function SetCharacterPermadead(src, characterId, coords)
    coords = NormalizeCoords(coords)
    characterId = tonumber(characterId)
    if not characterId then return false end

    local affected = MySQL.update.await([[
        UPDATE characters
        SET is_dead = 1,
            revived_at = NULL,
            pos_x = ?,
            pos_y = ?,
            pos_z = ?,
            heading = ?
        WHERE id = ?
    ]], { coords.x, coords.y, coords.z, coords.heading, characterId })

    local player = GetCWPlayer(src)
    if player and player.character and tonumber(player.character.id) == characterId then
        player.character.is_dead = 1
        player.character.revived_at = nil
        player.character.pos_x = coords.x
        player.character.pos_y = coords.y
        player.character.pos_z = coords.z
        player.character.heading = coords.heading
    end

    return affected and affected > 0
end

CreateThread(function()
    Wait(500)
    EnsureSchema()
    math.randomseed(os.time())
end)

RegisterNetEvent('cw-death:server:knockdown', function(coords)
    local src = source
    local player = GetCWPlayer(src)

    if not player or not player.character then
        activeKnockdowns[src] = nil
        TriggerClientEvent('cw-death:client:cancelKnockdown', src)
        return
    end

    coords = NormalizeCoords(coords)
    SaveCharacterPosition(src, coords)

    local characterId = tonumber(player.character.id)
    if not characterId then
        activeKnockdowns[src] = nil
        TriggerClientEvent('cw-death:client:cancelKnockdown', src)
        return
    end

    local alreadyDead = IsDeadFlag(player.character.is_dead) or IsCharacterPermadead(characterId)
    local chance = alreadyDead and 100 or GetPermadeathChance()

    activeKnockdowns[src] = {
        characterId = characterId,
        coords = coords,
        chance = chance,
        alreadyDead = alreadyDead,
        rolled = false
    }

    TriggerClientEvent('cw-death:client:roulettePrepared', src, {
        chance = chance,
        countdown = ROULETTE_COUNTDOWN_SECONDS,
        seconds = DOWNED_SECONDS,
        alreadyDead = alreadyDead
    })
end)

RegisterNetEvent('cw-death:server:rollRoulette', function(coords)
    local src = source
    local state = activeKnockdowns[src]
    if not state or state.rolled then return end

    local player = GetCWPlayer(src)
    if not player or not player.character then
        activeKnockdowns[src] = nil
        TriggerClientEvent('cw-death:client:cancelKnockdown', src)
        return
    end

    state.rolled = true

    if coords then
        state.coords = NormalizeCoords(coords)
        SaveCharacterPosition(src, state.coords)
    end

    local chance = ClampChance(state.chance)
    local roll = math.random(1, 100)
    local permadeath = roll <= chance

    if state.alreadyDead or IsCharacterPermadead(state.characterId) then
        chance = 100
        roll = 1
        permadeath = true
    end

    local ok, err = pcall(function()
        if permadeath then
            local saved = SetCharacterPermadead(src, state.characterId, state.coords)
            if not saved then error('database update returned 0 affected rows') end
        end
    end)

    if not ok then
        print(('[cw-death] Failed to set permadeath for character %s: %s'):format(
            tostring(state.characterId),
            tostring(err)
        ))
        permadeath = false
    end

    TriggerClientEvent('cw-death:client:rollResult', src, {
        chance = chance,
        roll = roll,
        permadeath = permadeath,
        seconds = DOWNED_SECONDS,
        alreadyDead = state.alreadyDead == true
    })

    activeKnockdowns[src] = nil
end)

RegisterNetEvent('cw-death:server:saveDownedPosition', function(coords)
    SaveCharacterPosition(source, coords)
end)

AddEventHandler('playerDropped', function()
    activeKnockdowns[source] = nil
end)

exports('GetPermadeathChance', GetPermadeathChance)
exports('SetPermadeathChance', SetPermadeathChance)
exports('IsCharacterPermadead', IsCharacterPermadead)
exports('IsPlayerDeathLocked', IsPlayerDeathLocked)
exports('IsPlayerPermanentlyDead', IsPlayerPermanentlyDead)
