CW = CW or {}
CW.Players = CW.Players or {}

local function GetIdentifier(src, prefix)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return nil
end

local function LoadOrCreateAccount(src)
    src = tonumber(src)
    if not src then
        return nil
    end

    local license = GetIdentifier(src, 'license:') or GetIdentifier(src, 'license2:')
    if not license then
        DropPlayer(src, 'License identifier not found.')
        return nil
    end

    local steam = GetIdentifier(src, 'steam:')
    local discord = GetIdentifier(src, 'discord:')
    local fivem = GetIdentifier(src, 'fivem:')
    local name = GetPlayerName(src) or ('ID ' .. tostring(src))

    local account = MySQL.single.await('SELECT * FROM accounts WHERE license = ? LIMIT 1', { license })

    if not account then
        local insertId = MySQL.insert.await([[
            INSERT INTO accounts (license, steam, discord, fivem, name)
            VALUES (?, ?, ?, ?, ?)
        ]], { license, steam, discord, fivem, name })

        account = MySQL.single.await('SELECT * FROM accounts WHERE id = ? LIMIT 1', { insertId })
        print(('[cw-core] Created account %s for %s'):format(tostring(insertId), name))
    else
        MySQL.update.await([[
            UPDATE accounts
            SET steam = ?, discord = ?, fivem = ?, name = ?
            WHERE id = ?
        ]], { steam, discord, fivem, name, account.id })

        print(('[cw-core] Loaded account %s for %s'):format(tostring(account.id), name))
    end

    CW.Players[src] = {
        source = src,
        account_id = tonumber(account.id),
        license = license,
        steam = steam,
        discord = discord,
        fivem = fivem,
        name = name,
        character = CW.Players[src] and CW.Players[src].character or nil
    }

    return CW.Players[src]
end

function CW.LoadOrCreateAccount(src)
    return LoadOrCreateAccount(src)
end

function CW.GetPlayer(src)
    return CW.Players[tonumber(src)]
end

function CW.GetAccountId(src)
    local player = CW.GetPlayer(src)
    return player and player.account_id or nil
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
    local player = CW.Players[src]

    if player then
        print(('[cw-core] Player dropped: %s | reason: %s'):format(player.name or src, tostring(reason)))
        CW.Players[src] = nil
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    CreateThread(function()
        Wait(1500)
        for _, playerId in ipairs(GetPlayers()) do
            LoadOrCreateAccount(tonumber(playerId))
        end
    end)
end)

exports('LoadOrCreateAccount', CW.LoadOrCreateAccount)
exports('GetPlayer', CW.GetPlayer)
exports('GetAccountId', CW.GetAccountId)
