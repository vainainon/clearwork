local RolePower = {
    helper = 1,
    admin = 2,
    ['general-admin'] = 3
}

local function GetIdentifier(src, prefix)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return nil
end

local function IsOwner(src)
    return src == 0 or IsPlayerAceAllowed(src, 'clearwork.owner')
end

local function GetAdminBySource(src)
    if IsOwner(src) then
        return {
            role = 'owner',
            power = 4,
            license = 'console/owner',
            name = src == 0 and 'Console' or GetPlayerName(src)
        }
    end

    local license = GetIdentifier(src, 'license:')
    if not license then return nil end

    local admin = MySQL.single.await(
        'SELECT * FROM admin_users WHERE license = ? LIMIT 1',
        { license }
    )

    if not admin then return nil end

    admin.power = RolePower[admin.role] or 0
    return admin
end

local function CanAssign(actor, targetRole)
    if not actor then return false end

    if actor.role == 'owner' then
        return targetRole == 'general-admin' or targetRole == 'admin' or targetRole == 'helper'
    end

    if actor.role == 'general-admin' then
        return targetRole == 'admin' or targetRole == 'helper'
    end

    return false
end

local function LogAdminAction(actor, action, targetLicense, targetName, details)
    MySQL.insert.await([[
        INSERT INTO admin_logs
            (actor_license, actor_name, action, target_license, target_name, details)
        VALUES
            (?, ?, ?, ?, ?, ?)
    ]], {
        actor and actor.license or nil,
        actor and actor.name or nil,
        action,
        targetLicense,
        targetName,
        details
    })
end

RegisterCommand('cw_addadmin', function(src, args)
    local actor = GetAdminBySource(src)

    if not actor then
        print('[cw-admin] Access denied.')
        return
    end

    local role = tostring(args[1] or '')
    local targetId = tonumber(args[2])

    if not RolePower[role] then
        print('[cw-admin] Usage: /cw_addadmin [general-admin/admin/helper] [id]')
        return
    end

    if not targetId or not GetPlayerName(targetId) then
        print('[cw-admin] Player not found.')
        return
    end

    if not CanAssign(actor, role) then
        print('[cw-admin] You cannot assign this role.')
        return
    end

    local license = GetIdentifier(targetId, 'license:')
    local name = GetPlayerName(targetId)

    if not license then
        print('[cw-admin] Target license not found.')
        return
    end

    MySQL.update.await([[
        INSERT INTO admin_users (license, name, role, created_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            role = VALUES(role),
            created_by = VALUES(created_by)
    ]], {
        license,
        name,
        role,
        actor.license
    })

    LogAdminAction(actor, 'add_admin', license, name, json.encode({
        role = role
    }))

    print(('[cw-admin] %s is now %s'):format(name, role))
end, false)

RegisterNetEvent('cw-admin:server:open', function()
    local src = source
    local admin = GetAdminBySource(src)

    if not admin then
        print(('[cw-admin] Access denied for %s'):format(src))
        return
    end

    local players = {}

    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)

        players[#players + 1] = {
            id = playerId,
            name = GetPlayerName(playerId),
            license = GetIdentifier(playerId, 'license:') or 'unknown'
        }
    end

    local admins = MySQL.query.await([[
        SELECT id, license, name, role, created_at
        FROM admin_users
        ORDER BY FIELD(role, 'general-admin', 'admin', 'helper'), created_at DESC
    ]]) or {}

    local logs = MySQL.query.await([[
        SELECT actor_name, action, target_name, details, created_at
        FROM admin_logs
        ORDER BY id DESC
        LIMIT 30
    ]]) or {}

    TriggerClientEvent('cw-admin:client:open', src, {
        self = {
            name = admin.name,
            role = admin.role
        },
        players = players,
        admins = admins,
        logs = logs
    })
end)