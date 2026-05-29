local function IsAdmin(src)
    return IsPlayerAceAllowed(src, 'clearwork.admin')
end

local function SendError(src, message)
    TriggerClientEvent('cw-admin:client:error', src, message)
end

RegisterNetEvent('cw-admin:server:searchCharacters', function(query)
    local src = source

    if not IsAdmin(src) then
        print(('[cw-admin] Access denied for %s'):format(src))
        SendError(src, 'Нет доступа.')
        return
    end

    query = tostring(query or '')
    local like = '%' .. query .. '%'

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

    local character = MySQL.single.await([[
        SELECT id, firstname, lastname, account_id
        FROM characters
        WHERE id = ?
        LIMIT 1
    ]], { characterId })

    if not character then
        SendError(src, 'Персонаж не найден.')
        return
    end

    MySQL.update.await([[
        DELETE FROM characters
        WHERE id = ?
    ]], { characterId })

    print(('[cw-admin] Admin %s deleted character %s %s [%s]'):format(
        GetPlayerName(src),
        character.firstname,
        character.lastname,
        character.id
    ))

    TriggerClientEvent('cw-admin:client:deletedCharacter', src, characterId)
end)