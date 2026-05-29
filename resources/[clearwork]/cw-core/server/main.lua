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

exports('GetPlayer', function(src)
    return CW.Players[src]
end)

exports('GetAccountId', function(src)
    local player = CW.Players[src]
    return player and player.account_id or nil
end)