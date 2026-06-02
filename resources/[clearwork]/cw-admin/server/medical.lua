local Config = CWAdminConfig

local function ClampChance(value)
    value = tonumber(value) or 15
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

local function GetServerCoords(src)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped)
    }
end

local function SaveCharacterPosition(src, coords)
    if not coords then return end

    pcall(function()
        exports['cw-core']:SaveCharacterPosition(src, coords)
    end)
end

local function FindOnlineSourceByCharacterId(characterId)
    characterId = tonumber(characterId)

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local player = CWAdmin.GetCWPlayer(src)

        if player and player.character and tonumber(player.character.id) == characterId then
            return src, player
        end
    end

    return nil, nil
end

CreateThread(function()
    Wait(500)
    EnsureSchema()
end)

RegisterNetEvent('cw-admin:server:medical:getSettings', function()
    local src = source

    if not CWAdmin.HasPermission(src, Config.Ace.characters) then
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    TriggerClientEvent('cw-admin:client:medical:settings', src, {
        permadeathChance = GetPermadeathChance()
    })
end)

RegisterNetEvent('cw-admin:server:medical:setPermadeathChance', function(value)
    local src = source

    if not CWAdmin.HasPermission(src, Config.Ace.characters) then
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    local chance = SetPermadeathChance(value)

    CWAdmin.AdminLog(src, 'set_permadeath_chance', 'chance=' .. chance)
    CWAdmin.SendSuccess(src, 'Шанс перманентной смерти установлен: ' .. chance .. '%')

    TriggerClientEvent('cw-admin:client:medical:settings', src, {
        permadeathChance = chance
    })
end)

RegisterNetEvent('cw-admin:server:medical:revivePlayer', function(target)
    local src = source
    target = tonumber(target)

    if not CWAdmin.HasPermission(src, Config.Ace.players) then
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    if not target or GetPlayerName(target) == nil then
        CWAdmin.SendError(src, 'Игрок не найден.')
        return
    end

    local player = CWAdmin.GetCWPlayer(target)

    if not player or not player.character then
        CWAdmin.SendError(src, 'У игрока не выбран персонаж.')
        return
    end

    local characterId = tonumber(player.character.id)
    local row = MySQL.single.await(
        'SELECT id, is_dead FROM characters WHERE id = ? LIMIT 1',
        { characterId }
    )

    if row and tonumber(row.is_dead) == 1 then
        CWAdmin.SendError(src, 'У персонажа перма-килл. Сначала оживи его во вкладке Персонажи.')
        return
    end

    local coords = GetServerCoords(target)

    TriggerClientEvent('cw-death:client:adminRevive', target, coords)
    SaveCharacterPosition(target, coords)

    CWAdmin.AdminLog(src, 'revive_player', 'target=' .. target .. ', character=' .. characterId)
    CWAdmin.SendSuccess(src, 'Игрок возрождён на том же персонаже и в том же месте.')
end)

RegisterNetEvent('cw-admin:server:medical:reviveCharacter', function(characterId)
    local src = source
    characterId = tonumber(characterId)

    if not CWAdmin.HasPermission(src, Config.Ace.characters) then
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    if not characterId then
        CWAdmin.SendError(src, 'Персонаж не найден.')
        return
    end

    local affected = MySQL.update.await(
        'UPDATE characters SET is_dead = 0 WHERE id = ?',
        { characterId }
    )

    if not affected or affected < 1 then
        CWAdmin.SendError(src, 'Персонаж не найден.')
        return
    end

    local onlineSrc, onlinePlayer = FindOnlineSourceByCharacterId(characterId)

    if onlineSrc and onlinePlayer and onlinePlayer.character then
        onlinePlayer.character.is_dead = 0
        TriggerClientEvent('cw-death:client:adminRevive', onlineSrc, GetServerCoords(onlineSrc))
    end

    CWAdmin.AdminLog(src, 'revive_character', 'character=' .. characterId)
    CWAdmin.SendSuccess(src, 'Персонаж оживлён. Теперь его можно выбрать или возродить игрока.')
end)