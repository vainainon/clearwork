local DEFAULT_CHANCE = 15
local ROULETTE_COUNTDOWN_SECONDS = 5
local DOWNED_SECONDS = 300

local activeKnockdowns = {}

local VALID_STATES = {
    roulette = true,
    revive_wait = true,
    switch_wait = true
}

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

local function ClampRemaining(value)
    value = tonumber(value) or DOWNED_SECONDS
    value = math.floor(value)

    if value < 0 then value = 0 end
    if value > DOWNED_SECONDS then value = DOWNED_SECONDS end

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
    EnsureColumn('characters', 'downed_state', '`downed_state` VARCHAR(32) NULL')
    EnsureColumn('characters', 'downed_remaining_seconds', '`downed_remaining_seconds` INT NOT NULL DEFAULT 0')
    EnsureColumn('characters', 'downed_roll', '`downed_roll` INT NULL')
    EnsureColumn('characters', 'downed_chance', '`downed_chance` INT NULL')
    EnsureColumn('characters', 'downed_updated_at', '`downed_updated_at` DATETIME NULL')
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

local function ClearSelectedCharacter(src)
    pcall(function()
        exports['cw-core']:ClearCharacter(src)
    end)

    local player = GetCWPlayer(src)
    if player then
        player.character = nil
    end
end

local function GetCharacterRow(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end

    return MySQL.single.await([[
        SELECT
            id,
            account_id,
            is_dead,
            pos_x,
            pos_y,
            pos_z,
            heading,
            downed_state,
            downed_remaining_seconds,
            downed_roll,
            downed_chance,
            downed_updated_at
        FROM characters
        WHERE id = ?
        LIMIT 1
    ]], { characterId })
end

local function IsCharacterPermadead(characterId)
    local row = GetCharacterRow(characterId)
    return row ~= nil and IsDeadFlag(row.is_dead)
end

local function SetPersistentDownedState(characterId, stateName, remaining, chance, roll, coords)
    characterId = tonumber(characterId)
    if not characterId then return false end

    stateName = tostring(stateName or '')
    if not VALID_STATES[stateName] then return false end

    remaining = ClampRemaining(remaining)
    chance = chance ~= nil and ClampChance(chance) or nil
    roll = roll ~= nil and tonumber(roll) or nil

    if coords then
        coords = NormalizeCoords(coords)

        MySQL.update.await([[
            UPDATE characters
            SET downed_state = ?,
                downed_remaining_seconds = ?,
                downed_chance = ?,
                downed_roll = ?,
                downed_updated_at = NOW(),
                pos_x = ?,
                pos_y = ?,
                pos_z = ?,
                heading = ?
            WHERE id = ?
        ]], {
            stateName,
            remaining,
            chance,
            roll,
            coords.x,
            coords.y,
            coords.z,
            coords.heading,
            characterId
        })
    else
        MySQL.update.await([[
            UPDATE characters
            SET downed_state = ?,
                downed_remaining_seconds = ?,
                downed_chance = ?,
                downed_roll = ?,
                downed_updated_at = NOW()
            WHERE id = ?
        ]], {
            stateName,
            remaining,
            chance,
            roll,
            characterId
        })
    end

    return true
end

local function ClearPersistentDownedState(characterId)
    characterId = tonumber(characterId)
    if not characterId then return false end

    MySQL.update.await([[
        UPDATE characters
        SET downed_state = NULL,
            downed_remaining_seconds = 0,
            downed_chance = NULL,
            downed_roll = NULL,
            downed_updated_at = NULL
        WHERE id = ?
    ]], { characterId })

    return true
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

local function GetCurrentCharacterId(src)
    local player = GetCWPlayer(src)
    if not player or not player.character then return nil, nil end
    return tonumber(player.character.id), player
end

local function BuildCoordsFromRow(row)
    return NormalizeCoords({
        x = row and row.pos_x,
        y = row and row.pos_y,
        z = row and row.pos_z,
        heading = row and row.heading
    })
end

local function IsPlayerDeathLocked(src)
    src = tonumber(src)
    if not src then return false end

    if activeKnockdowns[src] ~= nil then
        return true
    end

    local characterId = GetCurrentCharacterId(src)
    if not characterId then return false end

    local stateName = MySQL.scalar.await(
        'SELECT downed_state FROM characters WHERE id = ? LIMIT 1',
        { characterId }
    )

    return VALID_STATES[tostring(stateName or '')] == true
end

local function IsPlayerPermanentlyDead(src)
    src = tonumber(src)
    if not src then return false end

    local characterId, player = GetCurrentCharacterId(src)
    if not characterId then return false end

    if player and player.character and IsDeadFlag(player.character.is_dead) then return true end
    return IsCharacterPermadead(characterId)
end

local function RestorePersistentState(src)
    local characterId, player = GetCurrentCharacterId(src)
    if not characterId or not player then return end

    local row = GetCharacterRow(characterId)
    if not row then return end

    local stateName = tostring(row.downed_state or '')
    if not VALID_STATES[stateName] then return end

    local permanent = stateName == 'switch_wait' or IsDeadFlag(row.is_dead)
    local seconds = ClampRemaining(row.downed_remaining_seconds)
    local chance = tonumber(row.downed_chance) or (permanent and 100 or GetPermadeathChance())
    local roll = tonumber(row.downed_roll)
    local coords = BuildCoordsFromRow(row)

    activeKnockdowns[src] = {
        characterId = characterId,
        coords = coords,
        chance = chance,
        roll = roll,
        phase = stateName,
        remaining = seconds,
        permanent = permanent,
        rolled = stateName ~= 'roulette'
    }

    if stateName == 'roulette' then
        TriggerClientEvent('cw-death:client:restoreRoulette', src, {
            chance = chance,
            countdown = ROULETTE_COUNTDOWN_SECONDS,
            seconds = DOWNED_SECONDS,
            coords = coords,
            alreadyDead = permanent
        })
        return
    end

    TriggerClientEvent('cw-death:client:restoreDownedState', src, {
        permanent = permanent,
        seconds = seconds,
        chance = chance,
        roll = roll,
        coords = coords
    })
end

CreateThread(function()
    Wait(500)
    EnsureSchema()
    math.randomseed(os.time())
end)

RegisterNetEvent('cw-death:server:requestRestore', function()
    RestorePersistentState(source)
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
        roll = nil,
        phase = 'roulette',
        remaining = DOWNED_SECONDS,
        permanent = alreadyDead,
        rolled = false
    }

    SetPersistentDownedState(characterId, 'roulette', DOWNED_SECONDS, chance, nil, coords)

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
    local wasAlreadyPermanent = state.permanent == true or IsCharacterPermadead(state.characterId)
    local permadeath = roll <= chance

    if wasAlreadyPermanent then
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

    state.chance = chance
    state.roll = roll
    state.permanent = permadeath
    state.phase = permadeath and 'switch_wait' or 'revive_wait'
    state.remaining = DOWNED_SECONDS

    SetPersistentDownedState(state.characterId, state.phase, DOWNED_SECONDS, chance, roll, state.coords)

    TriggerClientEvent('cw-death:client:rollResult', src, {
        chance = chance,
        roll = roll,
        permadeath = permadeath,
        seconds = DOWNED_SECONDS,
        alreadyDead = wasAlreadyPermanent
    })
end)

RegisterNetEvent('cw-death:server:updateDownedState', function(data)
    local src = source
    data = data or {}

    local characterId = GetCurrentCharacterId(src)
    if not characterId then return end

    local stateName = tostring(data.phase or '')
    if not VALID_STATES[stateName] then return end

    local remaining = ClampRemaining(data.seconds)
    local chance = data.chance ~= nil and ClampChance(data.chance) or nil
    local roll = data.roll ~= nil and tonumber(data.roll) or nil
    local coords = data.coords and NormalizeCoords(data.coords) or nil

    local state = activeKnockdowns[src]
    if state and state.characterId == characterId then
        state.phase = stateName
        state.remaining = remaining
        state.chance = chance or state.chance
        state.roll = roll or state.roll
        state.permanent = data.permanent == true or stateName == 'switch_wait'
        if coords then state.coords = coords end
    end

    SetPersistentDownedState(characterId, stateName, remaining, chance, roll, coords)
end)

RegisterNetEvent('cw-death:server:finishKnockdown', function(coords)
    local src = source
    local characterId = GetCurrentCharacterId(src)
    if not characterId then return end

    if IsCharacterPermadead(characterId) then
        TriggerClientEvent('cw-death:client:restoreDownedState', src, {
            permanent = true,
            seconds = 0,
            chance = 100,
            coords = NormalizeCoords(coords)
        })
        return
    end

    coords = NormalizeCoords(coords)
    ClearPersistentDownedState(characterId)
    activeKnockdowns[src] = nil
    SaveCharacterPosition(src, coords)

    TriggerClientEvent('cw-death:client:finishRevive', src, coords)
end)

RegisterNetEvent('cw-death:server:finishPermadeathMenu', function(coords)
    local src = source
    local characterId = GetCurrentCharacterId(src)
    if not characterId then
        activeKnockdowns[src] = nil
        TriggerClientEvent('cw-death:client:finishSwitch', src)
        return
    end

    coords = NormalizeCoords(coords)
    ClearPersistentDownedState(characterId)
    SaveCharacterPosition(src, coords)
    activeKnockdowns[src] = nil
    ClearSelectedCharacter(src)

    TriggerClientEvent('cw-death:client:finishSwitch', src)
end)

RegisterNetEvent('cw-death:server:clearCurrentDownedState', function(coords)
    local src = source
    local characterId = GetCurrentCharacterId(src)
    if not characterId then return end

    ClearPersistentDownedState(characterId)
    activeKnockdowns[src] = nil

    if coords then
        SaveCharacterPosition(src, coords)
    end
end)

RegisterNetEvent('cw-death:server:saveDownedPosition', function(coords)
    SaveCharacterPosition(source, coords)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local state = activeKnockdowns[src]

    if state and state.characterId and state.phase then
        SetPersistentDownedState(
            state.characterId,
            state.phase,
            state.remaining or DOWNED_SECONDS,
            state.chance,
            state.roll,
            state.coords
        )
    end

    activeKnockdowns[src] = nil
end)

exports('GetPermadeathChance', GetPermadeathChance)
exports('SetPermadeathChance', SetPermadeathChance)
exports('IsCharacterPermadead', IsCharacterPermadead)
exports('IsPlayerDeathLocked', IsPlayerDeathLocked)
exports('IsPlayerPermanentlyDead', IsPlayerPermanentlyDead)
