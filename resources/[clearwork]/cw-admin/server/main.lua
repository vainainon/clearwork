local function IsAdmin(src)
    return IsPlayerAceAllowed(src, 'clearwork.admin')
end

local function SendError(src, message)
    TriggerClientEvent('cw-admin:client:error', src, message)
end

local function GetActiveCharacters()
    local activeCharacters = {}

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)

        if targetSrc then
            local ok, player = pcall(function()
                return exports['cw-core']:GetPlayer(targetSrc)
            end)

            if ok and player and player.character and player.character.id then
                local characterId = tonumber(player.character.id)

                if characterId then
                    activeCharacters[characterId] = {
                        source = targetSrc,
                        player_name = player.name or GetPlayerName(targetSrc) or ('ID ' .. targetSrc),
                        account_id = tonumber(player.account_id)
                    }
                end
            end
        end
    end

    return activeCharacters
end

local function DecorateCharacters(characters)
    characters = characters or {}

    local activeCharacters = GetActiveCharacters()

    for _, character in ipairs(characters) do
        local characterId = tonumber(character.id)
        local activeData = characterId and activeCharacters[characterId] or nil

        character.active_character = activeData ~= nil

        if activeData then
            character.active_source = activeData.source
            character.active_player_name = activeData.player_name
        else
            character.active_source = nil
            character.active_player_name = nil
        end
    end

    return characters
end

RegisterNetEvent('cw-admin:server:searchCharacters', function(query)
    local src = source

    if not IsAdmin(src) then
        print(('[cw-admin] Access denied for %s'):format(src))
        SendError(src, 'Нет доступа.')
        return
    end

    query = tostring(query or '')

    local characters

    if query == '' then
        characters = MySQL.query.await([[
            SELECT
                c.id,
                c.account_id,
                c.slot,
                c.firstname,
                c.lastname,
                c.gender,
                c.age,
                c.cash,
                c.bank,
                c.is_dead,
                c.created_at,
                c.delete_requested_at,
                a.name AS account_name,
                a.license,
                a.discord,
                a.steam
            FROM characters c
            LEFT JOIN accounts a ON a.id = c.account_id
            ORDER BY c.created_at DESC
            LIMIT 100
        ]])
    else
        local like = '%' .. query .. '%'

        characters = MySQL.query.await([[
            SELECT
                c.id,
                c.account_id,
                c.slot,
                c.firstname,
                c.lastname,
                c.gender,
                c.age,
                c.cash,
                c.bank,
                c.is_dead,
                c.created_at,
                c.delete_requested_at,
                a.name AS account_name,
                a.license,
                a.discord,
                a.steam
            FROM characters c
            LEFT JOIN accounts a ON a.id = c.account_id
            WHERE
                c.firstname LIKE ?
                OR c.lastname LIKE ?
                OR CONCAT(c.firstname, ' ', c.lastname) LIKE ?
                OR a.name LIKE ?
                OR a.license LIKE ?
                OR a.discord LIKE ?
                OR a.steam LIKE ?
            ORDER BY c.created_at DESC
            LIMIT 100
        ]], {
            like,
            like,
            like,
            like,
            like,
            like,
            like
        })
    end

    characters = DecorateCharacters(characters)

    print(('[cw-admin] Search "%s" returned %s characters'):format(query, #(characters or {})))

    TriggerClientEvent('cw-admin:client:receiveCharacters', src, characters or {})
end)

RegisterNetEvent('cw-admin:server:deleteCharacter', function(characterId)
    local src = source

    if not IsAdmin(src) then
        print(('[cw-admin] Delete denied for %s'):format(src))
        SendError(src, 'Нет доступа.')
        return
    end

    characterId = tonumber(characterId)

    if not characterId then
        SendError(src, 'Некорректный ID персонажа.')
        return
    end

    local activeCharacters = GetActiveCharacters()

    if activeCharacters[characterId] then
        SendError(src, 'Нельзя удалить персонажа, который сейчас активен в игре.')
        return
    end

    local character = MySQL.single.await([[
        SELECT id, firstname, lastname, account_id
        FROM characters
        WHERE id = ?
        LIMIT 1
    ]], {
        characterId
    })

    if not character then
        SendError(src, 'Персонаж не найден.')
        return
    end

    MySQL.update.await([[
        DELETE FROM characters
        WHERE id = ?
    ]], {
        characterId
    })

    print(('[cw-admin] Admin %s deleted character %s %s [%s]'):format(
        GetPlayerName(src),
        character.firstname,
        character.lastname,
        character.id
    ))

    TriggerClientEvent('cw-admin:client:deletedCharacter', src, characterId)
end)