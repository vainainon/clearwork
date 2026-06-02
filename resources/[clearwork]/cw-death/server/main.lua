local DEFAULT_CHANCE = 15

local function ClampChance(value)
    value = tonumber(value) or DEFAULT_CHANCE
    value = math.floor(value)

    if value < 0 then value = 0 end
    if value > 100 then value = 100 end

    return value
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

    MySQL.query.await([[
        ALTER TABLE characters
        ADD COLUMN IF NOT EXISTS is_dead TINYINT(1) NOT NULL DEFAULT 0;
    ]])
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

    if ok then
        return player
    end

    return nil
end

local function SaveCharacterPosition(src, coords)
    if not coords then return end

    pcall(function()
        exports['cw-core']:SaveCharacterPosition(src, {
            x = tonumber(coords.x),
            y = tonumber(coords.y),
            z = tonumber(coords.z),
            heading = tonumber(coords.heading) or 0.0
        })
    end)
end

local function SetCharacterPermadead(src, characterId, coords)
    MySQL.update.await([[
        UPDATE characters
        SET is_dead = 1,
            pos_x = ?,
            pos_y = ?,
            pos_z = ?,
            pos_heading = ?
        WHERE id = ?
    ]], {
        tonumber(coords.x),
        tonumber(coords.y),
        tonumber(coords.z),
        tonumber(coords.heading) or 0.0,
        tonumber(characterId)
    })

    local player = GetCWPlayer(src)
    if player and player.character then
        player.character.is_dead = 1
        player.character.pos_x = tonumber(coords.x)
        player.character.pos_y = tonumber(coords.y)
        player.character.pos_z = tonumber(coords.z)
        player.character.pos_heading = tonumber(coords.heading) or 0.0
    end
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
        TriggerClientEvent('cw-death:client:cancelKnockdown', src)
        return
    end

    coords = coords or {}
    coords.x = tonumber(coords.x) or 0.0
    coords.y = tonumber(coords.y) or 0.0
    coords.z = tonumber(coords.z) or 0.0
    coords.heading = tonumber(coords.heading) or 0.0

    SaveCharacterPosition(src, coords)

    local characterId = tonumber(player.character.id)
    local alreadyDead = tonumber(player.character.is_dead) == 1

    if alreadyDead then
        TriggerClientEvent('cw-death:client:rollResult', src, {
            chance = 100,
            roll = 1,
            permadeath = true,
            seconds = 300,
            alreadyDead = true
        })

        return
    end

    local chance = GetPermadeathChance()
    local roll = math.random(1, 100)
    local permadeath = roll <= chance

    if permadeath then
        SetCharacterPermadead(src, characterId, coords)
    end

    TriggerClientEvent('cw-death:client:rollResult', src, {
        chance = chance,
        roll = roll,
        permadeath = permadeath,
        seconds = 300
    })
end)

RegisterNetEvent('cw-death:server:saveDownedPosition', function(coords)
    SaveCharacterPosition(source, coords)
end)

exports('GetPermadeathChance', GetPermadeathChance)
exports('SetPermadeathChance', SetPermadeathChance)