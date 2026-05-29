local function GetCWPlayer(src)
    return exports['cw-core']:GetPlayer(src)
end

RegisterNetEvent('cw-characters:server:getCharacters', function()
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        print(('[cw-characters] Player data not loaded for source %s'):format(src))
        TriggerClientEvent('cw-characters:client:receiveCharacters', src, {})
        return
    end

    local characters = MySQL.query.await([[
        SELECT id, slot, firstname, lastname, gender, age, cash, bank, is_dead, created_at
        FROM characters
        WHERE account_id = ?
        ORDER BY slot ASC
    ]], {
        player.account_id
    })

    TriggerClientEvent('cw-characters:client:receiveCharacters', src, characters or {})
end)

RegisterNetEvent('cw-characters:server:createCharacter', function(data)
    local src = source
    local player = GetCWPlayer(src)

    if not player then
        print(('[cw-characters] Cannot create character, player not loaded: %s'):format(src))
        return
    end

    if type(data) ~= 'table' then return end

    local slot = tonumber(data.slot) or 1
    local firstname = tostring(data.firstname or '')
    local lastname = tostring(data.lastname or '')
    local gender = tostring(data.gender or 'male')
    local age = tonumber(data.age) or 18

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
    ]], {
        player.account_id,
        slot
    })

    if existing then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Этот слот уже занят.')
        return
    end

    local characterId = MySQL.insert.await([[
        INSERT INTO characters
            (account_id, slot, firstname, lastname, gender, age, cash, bank, pos_x, pos_y, pos_z, heading)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.account_id,
        slot,
        firstname,
        lastname,
        gender,
        age,
        15.00,
        0.00,
        -180.0,
        640.0,
        113.0,
        90.0
    })

    print(('[cw-characters] Created character %s for account %s'):format(characterId, player.account_id))

    TriggerClientEvent('cw-characters:client:createSuccess', src, characterId)

    local characters = MySQL.query.await([[
        SELECT id, slot, firstname, lastname, gender, age, cash, bank, is_dead, created_at
        FROM characters
        WHERE account_id = ?
        ORDER BY slot ASC
    ]], {
        player.account_id
    })

    TriggerClientEvent('cw-characters:client:receiveCharacters', src, characters or {})
end)

RegisterNetEvent('cw-characters:server:selectCharacter', function(characterId)
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

    player.character = character

    print(('[cw-characters] Selected character %s %s for %s'):format(
        character.firstname,
        character.lastname,
        player.name
    ))

    TriggerClientEvent('cw-characters:client:characterSelected', src, character)
end)