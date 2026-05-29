local SpawnCities = {
    saintdenis = { label = 'Saint Denis', x = 2626.0, y = -1223.0, z = 53.3, heading = 90.0 },
    rhodes = { label = 'Rhodes', x = 1231.0, y = -1298.0, z = 76.9, heading = 135.0 },
    vanhorn = { label = 'Van Horn', x = 2962.0, y = 523.0, z = 45.3, heading = 180.0 },
    annesburg = { label = 'Annesburg', x = 2934.0, y = 1283.0, z = 44.6, heading = 90.0 }
}

local function GetCWPlayer(src)
    return exports['cw-core']:GetPlayer(src)
end

local function GetCharacters(accountId)
    return MySQL.query.await([[
        SELECT id, slot, firstname, lastname, gender, age, cash, bank, skin, is_dead, created_at
        FROM characters
        WHERE account_id = ?
        ORDER BY slot ASC
    ]], { accountId }) or {}
end

RegisterNetEvent('cw-characters:server:getCharacters', function()
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        TriggerClientEvent('cw-characters:client:receiveCharacters', src, {})
        return
    end

    TriggerClientEvent('cw-characters:client:receiveCharacters', src, GetCharacters(player.account_id))
end)

RegisterNetEvent('cw-characters:server:createCharacter', function(data)
    local src = source
    local player = GetCWPlayer(src)

    if not player or type(data) ~= 'table' then return end

    local slot = tonumber(data.slot) or 1
    local firstname = tostring(data.firstname or '')
    local lastname = tostring(data.lastname or '')
    local gender = tostring(data.gender or 'male')
    local age = tonumber(data.age) or 18
    local skin = json.encode(data.skin or {})

    if firstname == '' or lastname == '' then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Имя и фамилия обязательны.')
        return
    end

    if age < 16 or age > 90 then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Возраст должен быть от 16 до 90.')
        return
    end

    local existing = MySQL.single.await([[
        SELECT id FROM characters
        WHERE account_id = ? AND slot = ?
        LIMIT 1
    ]], { player.account_id, slot })

    if existing then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Этот слот уже занят.')
        return
    end

    local characterId = MySQL.insert.await([[
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
        2626.0,
        -1223.0,
        53.3,
        90.0,
        skin
    })

    print(('[cw-characters] Created character %s for account %s'):format(characterId, player.account_id))

    TriggerClientEvent('cw-characters:client:createSuccess', src)
    TriggerClientEvent('cw-characters:client:receiveCharacters', src, GetCharacters(player.account_id))
end)

RegisterNetEvent('cw-characters:server:deleteCharacter', function(characterId)
    local src = source
    local player = GetCWPlayer(src)

    if not player then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    MySQL.update.await([[
        DELETE FROM characters
        WHERE id = ? AND account_id = ?
    ]], {
        characterId,
        player.account_id
    })

    print(('[cw-characters] Deleted character %s for account %s'):format(characterId, player.account_id))

    TriggerClientEvent('cw-characters:client:receiveCharacters', src, GetCharacters(player.account_id))
end)

RegisterNetEvent('cw-characters:server:selectCharacter', function(characterId, spawnCity)
    local src = source
    local player = GetCWPlayer(src)

    if not player then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    local character = MySQL.single.await([[
        SELECT *
        FROM characters
        WHERE id = ? AND account_id = ?
        LIMIT 1
    ]], {
        characterId,
        player.account_id
    })

    if not character then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Персонаж не найден.')
        return
    end

    local city = SpawnCities[spawnCity or '']
    if city then
        character.pos_x = city.x
        character.pos_y = city.y
        character.pos_z = city.z
        character.heading = city.heading
        character.spawn_label = city.label
    end

    player.character = character

    print(('[cw-characters] Selected character %s %s for %s'):format(
        character.firstname,
        character.lastname,
        player.name
    ))

    TriggerClientEvent('cw-characters:client:characterSelected', src, character)
end)

RegisterNetEvent('cw-characters:server:clearSelectedCharacter', function()
    local src = source
    local player = GetCWPlayer(src)

    if not player then return end

    player.character = nil

    print(('[cw-characters] Cleared selected character for %s'):format(player.name))
end)