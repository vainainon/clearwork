CW = {}
CW.Players = {}

local function GetIdentifier(src, prefix)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return nil
end

local function LoadOrCreateAccount(src)
    local license = GetIdentifier(src, 'license:')

    if not license then
        DropPlayer(src, 'License identifier not found.')
        return nil
    end

    local steam = GetIdentifier(src, 'steam:')
    local discord = GetIdentifier(src, 'discord:')
    local fivem = GetIdentifier(src, 'fivem:')
    local name = GetPlayerName(src)

    local account = MySQL.single.await(
        'SELECT * FROM accounts WHERE license = ? LIMIT 1',
        { license }
    )

    if not account then
        local insertId = MySQL.insert.await([[
            INSERT INTO accounts (license, steam, discord, fivem, name)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            license,
            steam,
            discord,
            fivem,
            name
        })

        account = MySQL.single.await(
            'SELECT * FROM accounts WHERE id = ? LIMIT 1',
            { insertId }
        )

        print(('[cw-core] Created account %s for %s'):format(insertId, name))
    else
        MySQL.update.await([[
            UPDATE accounts
            SET steam = ?, discord = ?, fivem = ?, name = ?
            WHERE id = ?
        ]], {
            steam,
            discord,
            fivem,
            name,
            account.id
        })

        print(('[cw-core] Loaded account %s for %s'):format(account.id, name))
    end

    CW.Players[src] = {
        source = src,
        account_id = account.id,
        license = license,
        steam = steam,
        discord = discord,
        fivem = fivem,
        name = name,
        character = nil
    }

    return CW.Players[src]
end

local function SaveCharacterPosition(src, coords)
    local player = CW.Players[src]

    if not player or not player.character then
        print(('[cw-core] Cannot save position, no selected character for source %s'):format(src))
        return false
    end

    if type(coords) ~= 'table' then
        return false
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    local heading = tonumber(coords.heading)

    if not x or not y or not z then
        return false
    end

    heading = heading or 0.0

    MySQL.update.await([[
        UPDATE characters
        SET pos_x = ?, pos_y = ?, pos_z = ?, heading = ?
        WHERE id = ? AND account_id = ?
    ]], {
        x,
        y,
        z,
        heading,
        player.character.id,
        player.account_id
    })

    player.character.pos_x = x
    player.character.pos_y = y
    player.character.pos_z = z
    player.character.heading = heading

    print(('[cw-core] Saved position for character %s: %.2f %.2f %.2f'):format(
        player.character.id,
        x,
        y,
        z
    ))

    return true
end

AddEventHandler('playerJoining', function()
    local src = source

    CreateThread(function()
        Wait(1000)
        LoadOrCreateAccount(src)
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source

    if CW.Players[src] then
        print(('[cw-core] Player dropped: %s | reason: %s'):format(CW.Players[src].name, reason))
        CW.Players[src] = nil
    end
end)

RegisterNetEvent('cw-core:server:updateCharacterPosition', function(coords)
    SaveCharacterPosition(source, coords)
end)

RegisterNetEvent('cw-core:server:saveCurrentPosition', function(coords)
    SaveCharacterPosition(source, coords)
end)

exports('GetPlayer', function(src)
    return CW.Players[src]
end)

exports('GetAccountId', function(src)
    local player = CW.Players[src]
    return player and player.account_id or nil
end)

exports('SetCharacter', function(src, character)
    if not CW.Players[src] then
        return false
    end

    CW.Players[src].character = character
    return true
end)

exports('ClearCharacter', function(src)
    if not CW.Players[src] then
        return false
    end

    CW.Players[src].character = nil
    return true
end)

exports('SaveCharacterPosition', function(src, coords)
    return SaveCharacterPosition(src, coords)
end)