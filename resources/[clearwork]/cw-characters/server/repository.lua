CWCharacters = CWCharacters or {}
local Config = CWCharactersConfig

local function Trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function GetCurrentCharacterId(player)
    if type(player) ~= 'table' or type(player.character) ~= 'table' then
        return nil
    end

    return tonumber(player.character.id)
end

function CWCharacters.GetCWPlayer(src)
    local ok, player = pcall(function()
        return exports['cw-core']:GetPlayer(src)
    end)

    if ok and player then
        return player
    end

    pcall(function()
        player = exports['cw-core']:LoadOrCreateAccount(src)
    end)

    return player
end

function CWCharacters.CleanupDeletedCharacters(accountId)
    MySQL.update.await(([[
        DELETE FROM characters
        WHERE account_id = ?
          AND delete_requested_at IS NOT NULL
          AND delete_requested_at <= DATE_SUB(NOW(), INTERVAL %s HOUR)
    ]]):format(tonumber(Config.DeleteFinalizeHours) or 12), { accountId })
end

function CWCharacters.GetCharacters(accountId)
    CWCharacters.CleanupDeletedCharacters(accountId)

    return MySQL.query.await([[
        SELECT
            id,
            slot,
            firstname,
            lastname,
            gender,
            age,
            cash,
            bank,
            skin,
            is_dead,
            revived_at,
            created_at,
            delete_requested_at,
            TIMESTAMPDIFF(DAY, created_at, NOW()) AS age_days,
            TIMESTAMPDIFF(MINUTE, delete_requested_at, NOW()) AS delete_minutes_passed
        FROM characters
        WHERE account_id = ?
        ORDER BY slot ASC
    ]], { accountId }) or {}
end

function CWCharacters.SendCharacters(src, playerOrAccountId)
    local accountId = playerOrAccountId
    local currentCharacterId = nil

    if type(playerOrAccountId) == 'table' then
        accountId = playerOrAccountId.account_id
        currentCharacterId = GetCurrentCharacterId(playerOrAccountId)
    else
        local player = CWCharacters.GetCWPlayer(src)
        currentCharacterId = GetCurrentCharacterId(player)
    end

    if not accountId then
        TriggerClientEvent('cw-characters:client:receiveCharacters', src, {}, nil)
        return
    end

    local characters = CWCharacters.GetCharacters(accountId)

    for _, character in ipairs(characters) do
        character.is_current = currentCharacterId ~= nil and tonumber(character.id) == currentCharacterId
        character.active_character = character.is_current
        character.is_dead = tonumber(character.is_dead) or 0
        character.was_revived = character.revived_at ~= nil
    end

    TriggerClientEvent('cw-characters:client:receiveCharacters', src, characters, currentCharacterId)
end

function CWCharacters.GetFreeSlot(characters)
    local usedSlots = {}

    for _, character in ipairs(characters or {}) do
        local slot = tonumber(character.slot)
        if slot then
            usedSlots[slot] = true
        end
    end

    for slot = 1, tonumber(Config.MaxCharacters) or 3 do
        if not usedSlots[slot] then
            return slot
        end
    end

    return nil
end

function CWCharacters.NormalizeCreateData(data)
    data = data or {}

    local firstname = Trim(data.firstname)
    local lastname = Trim(data.lastname)
    local age = tonumber(data.age) or 18
    local gender = tostring(data.gender or 'male')
    local cityKey = tostring(data.startCity or 'saintdenis')
    local city = Config.SpawnCities[cityKey] or Config.SpawnCities.saintdenis

    return {
        firstname = firstname,
        lastname = lastname,
        age = age,
        gender = gender,
        city = city,
        skin = json.encode(data.skin or {})
    }
end
