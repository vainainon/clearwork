local SpawnCities = {
    saintdenis = {
        label = 'Saint Denis',
        x = 2632.52,
        y = -1312.31,
        z = 51.42,
        heading = 270.0
    },

    rhodes = {
        label = 'Rhodes',
        x = 1230.92,
        y = -1298.34,
        z = 76.90,
        heading = 140.0
    },

    vanhorn = {
        label = 'Van Horn',
        x = 2981.54,
        y = 570.16,
        z = 44.63,
        heading = 80.0
    },

    annesburg = {
        label = 'Annesburg',
        x = 2932.58,
        y = 1350.25,
        z = 44.64,
        heading = 250.0
    }
}

local MAX_CHARACTERS = 3

local function GetCWPlayer(src)
    return exports['cw-core']:GetPlayer(src)
end

local function CleanupDeletedCharacters(accountId)
    MySQL.update.await([[
        DELETE FROM characters
        WHERE account_id = ?
        AND delete_requested_at IS NOT NULL
        AND delete_requested_at <= DATE_SUB(NOW(), INTERVAL 12 HOUR)
    ]], {
        accountId
    })
end

local function GetCharacters(accountId)
    CleanupDeletedCharacters(accountId)

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
            created_at,
            delete_requested_at,
            TIMESTAMPDIFF(DAY, created_at, NOW()) AS age_days,
            TIMESTAMPDIFF(MINUTE, delete_requested_at, NOW()) AS delete_minutes_passed
        FROM characters
        WHERE account_id = ?
        ORDER BY slot ASC
    ]], {
        accountId
    }) or {}
end

local function SendCharacters(src, accountId)
    TriggerClientEvent('cw-characters:client:receiveCharacters', src, GetCharacters(accountId))
end

local function GetFreeSlot(characters)
    local usedSlots = {}

    for _, character in ipairs(characters or {}) do
        local slot = tonumber(character.slot)

        if slot then
            usedSlots[slot] = true
        end
    end

    for slot = 1, MAX_CHARACTERS do
        if not usedSlots[slot] then
            return slot
        end
    end

    return nil
end

RegisterNetEvent('cw-characters:server:getCharacters', function()
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        TriggerClientEvent('cw-characters:client:receiveCharacters', src, {})
        return
    end

    SendCharacters(src, player.account_id)
end)

RegisterNetEvent('cw-characters:server:createCharacter', function(data)
    local src = source
    local player = GetCWPlayer(src)

    if not player or type(data) ~= 'table' then
        return
    end

    local characters = GetCharacters(player.account_id)

    if #characters >= MAX_CHARACTERS then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Максимум 3 персонажа.')
        return
    end

    local slot = GetFreeSlot(characters)

    if not slot then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Нет свободного слота персонажа.')
        return
    end

    local firstname = tostring(data.firstname or '')
    local lastname = tostring(data.lastname or '')
    local gender = tostring(data.gender or 'male')
    local age = tonumber(data.age) or 18
    local skin = json.encode(data.skin or {})
    local cityKey = tostring(data.startCity or 'saintdenis')
    local city = SpawnCities[cityKey] or SpawnCities.saintdenis

    firstname = firstname:gsub('^%s+', ''):gsub('%s+$', '')
    lastname = lastname:gsub('^%s+', ''):gsub('%s+$', '')

    if firstname == '' or lastname == '' then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Имя и фамилия обязательны.')
        return
    end

    if age < 16 or age > 90 then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Возраст должен быть от 16 до 90.')
        return
    end

    local ok, characterId = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO characters
                (account_id, slot, firstname, lastname, gender, age, cash, bank, pos_x, pos_y, pos_z, heading, skin)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            player.account_id,
            slot,
            firstname,
            lastname,
            gender,
            age,
            15.00,
            0.00,
            city.x,
            city.y,
            city.z,
            city.heading,
            skin
        })
    end)

    if not ok then
        print(('[cw-characters] Create character failed for account %s: %s'):format(
            tostring(player.account_id),
            tostring(characterId)
        ))

        TriggerClientEvent('cw-characters:client:createFailed', src, 'Не удалось создать персонажа. Попробуй ещё раз.')
        SendCharacters(src, player.account_id)
        return
    end

    print(('[cw-characters] Created character %s for account %s in slot %s'):format(
        characterId,
        player.account_id,
        slot
    ))

    TriggerClientEvent('cw-characters:client:createSuccess', src)
    SendCharacters(src, player.account_id)
end)

RegisterNetEvent('cw-characters:server:requestDeleteCharacter', function(characterId)
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        return
    end

    characterId = tonumber(characterId)

    if not characterId then
        return
    end

    local character = MySQL.single.await([[
        SELECT
            id,
            firstname,
            lastname,
            created_at,
            delete_requested_at,
            TIMESTAMPDIFF(DAY, created_at, NOW()) AS age_days
        FROM characters
        WHERE id = ?
        AND account_id = ?
        LIMIT 1
    ]], {
        characterId,
        player.account_id
    })

    if not character then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Персонаж не найден.')
        return
    end

    if character.delete_requested_at then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Персонаж уже поставлен на удаление.')
        return
    end

    if tonumber(character.age_days) < 7 then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Персонажа можно удалить только через 7 дней после создания.')
        return
    end

    MySQL.update.await([[
        UPDATE characters
        SET delete_requested_at = NOW()
        WHERE id = ?
        AND account_id = ?
    ]], {
        characterId,
        player.account_id
    })

    print(('[cw-characters] Delete requested for character %s by account %s'):format(
        characterId,
        player.account_id
    ))

    SendCharacters(src, player.account_id)
end)

RegisterNetEvent('cw-characters:server:cancelDeleteCharacter', function(characterId)
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        return
    end

    characterId = tonumber(characterId)

    if not characterId then
        return
    end

    local character = MySQL.single.await([[
        SELECT
            id,
            delete_requested_at,
            TIMESTAMPDIFF(MINUTE, delete_requested_at, NOW()) AS delete_minutes_passed
        FROM characters
        WHERE id = ?
        AND account_id = ?
        LIMIT 1
    ]], {
        characterId,
        player.account_id
    })

    if not character or not character.delete_requested_at then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Удаление не запрошено.')
        return
    end

    if tonumber(character.delete_minutes_passed) > 60 then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Отменить удаление можно только в первый час.')
        return
    end

    MySQL.update.await([[
        UPDATE characters
        SET delete_requested_at = NULL
        WHERE id = ?
        AND account_id = ?
    ]], {
        characterId,
        player.account_id
    })

    print(('[cw-characters] Delete cancelled for character %s by account %s'):format(
        characterId,
        player.account_id
    ))

    SendCharacters(src, player.account_id)
end)

RegisterNetEvent('cw-characters:server:selectCharacter', function(characterId)
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        return
    end

    characterId = tonumber(characterId)

    if not characterId then
        return
    end

    local character = MySQL.single.await([[
        SELECT *
        FROM characters
        WHERE id = ?
        AND account_id = ?
        LIMIT 1
    ]], {
        characterId,
        player.account_id
    })

    if not character then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Персонаж не найден.')
        return
    end

    if character.delete_requested_at then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Персонаж поставлен на удаление.')
        return
    end

    exports['cw-core']:SetCharacter(src, character)

    print(('[cw-characters] Selected character %s %s for %s at %.2f %.2f %.2f'):format(
        character.firstname,
        character.lastname,
        player.name,
        tonumber(character.pos_x) or 0.0,
        tonumber(character.pos_y) or 0.0,
        tonumber(character.pos_z) or 0.0
    ))

    TriggerClientEvent('cw-characters:client:characterSelected', src, character)
end)

RegisterNetEvent('cw-characters:server:clearSelectedCharacter', function()
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        return
    end

    exports['cw-core']:ClearCharacter(src)

    print(('[cw-characters] Cleared selected character for %s'):format(player.name))
end)

RegisterNetEvent('cw-characters:server:openCharacterMenu', function(coords)
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        return
    end

    if player.character and type(coords) == 'table' then
        exports['cw-core']:SaveCharacterPosition(src, coords)

        print(('[cw-characters] Saved position before character switch: %s %.2f %.2f %.2f'):format(
            player.character.id,
            tonumber(coords.x) or 0.0,
            tonumber(coords.y) or 0.0,
            tonumber(coords.z) or 0.0
        ))
    end

    exports['cw-core']:ClearCharacter(src)

    SendCharacters(src, player.account_id)
end)