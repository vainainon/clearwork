local Config = CWAdminConfig

function CWAdmin.GetActiveCharacters()
    local activeCharacters = {}

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)

        if targetSrc then
            local player = CWAdmin.GetCWPlayer(targetSrc)

            if player and player.character and player.character.id then
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

function CWAdmin.CountActiveCharacters()
    local count = 0
    local activeCharacters = CWAdmin.GetActiveCharacters()

    for _ in pairs(activeCharacters) do
        count = count + 1
    end

    return count
end

function CWAdmin.GetTotalCharacters()
    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM characters')
    end)

    if not ok then
        return 0
    end

    return tonumber(result) or 0
end

local function DecorateCharacters(characters)
    characters = characters or {}

    local activeCharacters = CWAdmin.GetActiveCharacters()

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

function CWAdmin.SearchCharacters(query)
    query = tostring(query or '')

    local limit = tonumber(Config.MaxCharacterSearchResults) or 100
    local characters

    if query == '' then
        characters = MySQL.query.await(([[
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
            LIMIT %s
        ]]):format(limit))
    else
        local like = '%' .. query .. '%'

        characters = MySQL.query.await(([[
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
            LIMIT %s
        ]]):format(limit), {
            like,
            like,
            like,
            like,
            like,
            like,
            like
        })
    end

    return DecorateCharacters(characters or {})
end

RegisterNetEvent('cw-admin:server:characters:search', function(query)
    local src = source

    if not CWAdmin.HasPermission(src, Config.Ace.characters) then
        print(('[cw-admin] Character search denied for %s'):format(src))
        CWAdmin.SendError(src, 'Нет доступа к разделу персонажей.')
        return
    end

    local characters = CWAdmin.SearchCharacters(query)

    print(('[cw-admin] Search "%s" returned %s characters'):format(
        tostring(query or ''),
        #(characters or {})
    ))

    TriggerClientEvent('cw-admin:client:characters:receive', src, characters)
end)

RegisterNetEvent('cw-admin:server:characters:delete', function(characterId)
    local src = source

    if not CWAdmin.HasPermission(src, Config.Ace.charactersDelete) then
        print(('[cw-admin] Character delete denied for %s'):format(src))
        CWAdmin.SendError(src, 'Нет доступа к удалению персонажей.')
        return
    end

    characterId = tonumber(characterId)

    if not characterId then
        CWAdmin.SendError(src, 'Некорректный ID персонажа.')
        return
    end

    local activeCharacters = CWAdmin.GetActiveCharacters()

    if activeCharacters[characterId] then
        CWAdmin.SendError(src, 'Нельзя удалить персонажа, который сейчас активен в игре.')
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
        CWAdmin.SendError(src, 'Персонаж не найден.')
        return
    end

    MySQL.update.await([[
        DELETE FROM characters
        WHERE id = ?
    ]], {
        characterId
    })

    CWAdmin.AdminLog(src, 'character_delete', {
        character_id = character.id,
        firstname = character.firstname,
        lastname = character.lastname,
        account_id = character.account_id
    })

    TriggerClientEvent('cw-admin:client:characters:deleted', src, characterId)
end)