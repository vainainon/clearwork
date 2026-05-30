local Config = CWAdminConfig

CWAdmin.RoleCache = CWAdmin.RoleCache or {}

local function NormalizeRole(role)
    role = tostring(role or 'user'):lower()

    if role == 'general_admin' or role == 'generaladmin' then
        role = 'general'
    end

    if not Config.Roles[role] then
        return 'user'
    end

    if role == 'owner' then
        return 'owner'
    end

    return role
end

local function IsDatabaseRole(role)
    role = NormalizeRole(role)

    return role == 'general' or role == 'admin' or role == 'helper'
end

local function GetRoleInfo(role)
    role = NormalizeRole(role)

    return Config.Roles[role] or Config.Roles.user
end

local function GetIdentifiers(src)
    local identifiers = {}

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        identifiers[#identifiers + 1] = identifier
    end

    return identifiers
end

local function GetPrimaryIdentifier(src)
    local identifiers = GetIdentifiers(src)

    local priorities = {
        'license:',
        'license2:',
        'fivem:',
        'discord:',
        'steam:'
    }

    for _, prefix in ipairs(priorities) do
        for _, identifier in ipairs(identifiers) do
            if identifier:sub(1, #prefix) == prefix then
                return identifier
            end
        end
    end

    return identifiers[1]
end

local function BuildInQuery(values)
    local placeholders = {}

    for i = 1, #values do
        placeholders[#placeholders + 1] = '?'
    end

    return table.concat(placeholders, ', ')
end

function CWAdmin.EnsureAdminUsersTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS admin_users (
            id INT NOT NULL AUTO_INCREMENT,
            identifier VARCHAR(80) NOT NULL,
            role VARCHAR(32) NOT NULL,
            name VARCHAR(64) DEFAULT NULL,
            added_by_identifier VARCHAR(80) DEFAULT NULL,
            added_by_name VARCHAR(64) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (id),
            UNIQUE KEY uniq_identifier (identifier),
            KEY idx_role (role)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    print('[cw-admin] admin_users table checked')
end

function CWAdmin.RoleHasPermission(role, permission)
    role = NormalizeRole(role)

    local permissions = Config.RolePermissions[role] or {}

    if permissions['*'] then
        return true
    end

    return permissions[permission] == true
end

function CWAdmin.GetRoleLevel(role)
    return tonumber(GetRoleInfo(role).level) or 0
end

function CWAdmin.GetRoleLabel(role)
    return GetRoleInfo(role).label or 'User'
end

function CWAdmin.GetAdminRole(src, refresh)
    if src == 0 then
        return 'owner'
    end

    if CWAdmin.IsOwner(src) then
        return 'owner'
    end

    if not refresh and CWAdmin.RoleCache[src] and CWAdmin.RoleCache[src].role then
        return CWAdmin.RoleCache[src].role
    end

    local identifiers = GetIdentifiers(src)

    if #identifiers <= 0 then
        CWAdmin.RoleCache[src] = {
            role = 'user',
            identifier = nil,
            label = CWAdmin.GetRoleLabel('user'),
            level = CWAdmin.GetRoleLevel('user')
        }

        return 'user'
    end

    local query = ('SELECT * FROM admin_users WHERE identifier IN (%s) LIMIT 1'):format(BuildInQuery(identifiers))
    local row = MySQL.single.await(query, identifiers)

    local role = 'user'
    local identifier = GetPrimaryIdentifier(src)
    local name = GetPlayerName(src) or 'unknown'
    local dbId = nil

    if row and row.role then
        local normalized = NormalizeRole(row.role)

        if IsDatabaseRole(normalized) then
            role = normalized
            identifier = row.identifier
            name = row.name or name
            dbId = row.id
        end
    end

    CWAdmin.RoleCache[src] = {
        role = role,
        identifier = identifier,
        name = name,
        db_id = dbId,
        label = CWAdmin.GetRoleLabel(role),
        level = CWAdmin.GetRoleLevel(role)
    }

    return role
end

function CWAdmin.GetRoleData(src, refresh)
    local role = CWAdmin.GetAdminRole(src, refresh)
    local cached = CWAdmin.RoleCache[src] or {}

    return {
        role = role,
        label = CWAdmin.GetRoleLabel(role),
        level = CWAdmin.GetRoleLevel(role),
        identifier = cached.identifier or GetPrimaryIdentifier(src),
        name = cached.name or GetPlayerName(src) or 'unknown'
    }
end

function CWAdmin.GetRoleDataByIdentifiers(identifiers)
    identifiers = identifiers or {}

    if #identifiers <= 0 then
        return {
            role = 'user',
            label = CWAdmin.GetRoleLabel('user'),
            level = CWAdmin.GetRoleLevel('user'),
            identifier = nil
        }
    end

    local query = ('SELECT * FROM admin_users WHERE identifier IN (%s) LIMIT 1'):format(BuildInQuery(identifiers))
    local row = MySQL.single.await(query, identifiers)

    if not row then
        return {
            role = 'user',
            label = CWAdmin.GetRoleLabel('user'),
            level = CWAdmin.GetRoleLevel('user'),
            identifier = identifiers[1]
        }
    end

    local role = NormalizeRole(row.role)

    if not IsDatabaseRole(role) then
        role = 'user'
    end

    return {
        role = role,
        label = CWAdmin.GetRoleLabel(role),
        level = CWAdmin.GetRoleLevel(role),
        identifier = row.identifier,
        name = row.name,
        db_id = row.id
    }
end

function CWAdmin.CanGrantRole(src, targetRole)
    targetRole = NormalizeRole(targetRole)

    if not IsDatabaseRole(targetRole) then
        return false
    end

    local actorRole = CWAdmin.GetAdminRole(src)
    local grantable = Config.GrantableRoles[actorRole] or {}

    return grantable[targetRole] == true
end

function CWAdmin.CanRemoveRole(src, targetRole)
    targetRole = NormalizeRole(targetRole)

    if not IsDatabaseRole(targetRole) then
        return false
    end

    local actorRole = CWAdmin.GetAdminRole(src)

    if actorRole == 'owner' then
        return true
    end

    if actorRole == 'general' then
        return targetRole == 'admin' or targetRole == 'helper'
    end

    return false
end

function CWAdmin.SetAdminRole(src, identifier, role, name)
    identifier = tostring(identifier or '')
    role = NormalizeRole(role)
    name = tostring(name or identifier)

    if identifier == '' then
        return false, 'Пустой identifier.'
    end

    if not IsDatabaseRole(role) then
        return false, 'Эту роль нельзя выдать. Owner назначается только через server.cfg.'
    end

    if not CWAdmin.CanGrantRole(src, role) then
        return false, 'Нет доступа к выдаче этой роли.'
    end

    local actorIdentifier = src == 0 and 'console' or GetPrimaryIdentifier(src)
    local actorName = src == 0 and 'console' or (GetPlayerName(src) or 'unknown')

    MySQL.insert.await([[
        INSERT INTO admin_users
            (identifier, role, name, added_by_identifier, added_by_name)
        VALUES
            (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            role = VALUES(role),
            name = VALUES(name),
            added_by_identifier = VALUES(added_by_identifier),
            added_by_name = VALUES(added_by_name)
    ]], {
        identifier,
        role,
        name,
        actorIdentifier,
        actorName
    })

    CWAdmin.AdminLog(src, 'role_set', {
        identifier = identifier,
        role = role,
        name = name
    })

    for playerId, cached in pairs(CWAdmin.RoleCache) do
        if cached and cached.identifier == identifier then
            CWAdmin.RoleCache[playerId] = nil
        end
    end

    return true, 'Роль выдана.'
end

function CWAdmin.RemoveAdminRole(src, identifier)
    identifier = tostring(identifier or '')

    if identifier == '' then
        return false, 'Пустой identifier.'
    end

    local row = MySQL.single.await([[
        SELECT *
        FROM admin_users
        WHERE identifier = ?
        LIMIT 1
    ]], {
        identifier
    })

    if not row then
        return false, 'Администратор не найден в БД.'
    end

    local targetRole = NormalizeRole(row.role)

    if not CWAdmin.CanRemoveRole(src, targetRole) then
        return false, 'Нет доступа к снятию этой роли.'
    end

    MySQL.update.await([[
        DELETE FROM admin_users
        WHERE identifier = ?
    ]], {
        identifier
    })

    CWAdmin.AdminLog(src, 'role_remove', {
        identifier = identifier,
        old_role = targetRole
    })

    for playerId, cached in pairs(CWAdmin.RoleCache) do
        if cached and cached.identifier == identifier then
            CWAdmin.RoleCache[playerId] = nil
        end
    end

    return true, 'Права сняты.'
end

function CWAdmin.GetAllAdmins()
    local rows = MySQL.query.await([[
        SELECT
            id,
            identifier,
            role,
            name,
            added_by_identifier,
            added_by_name,
            created_at,
            updated_at
        FROM admin_users
    ]]) or {}

    local onlineByIdentifier = {}

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local identifiers = GetIdentifiers(src)

        for _, identifier in ipairs(identifiers) do
            onlineByIdentifier[identifier] = {
                source = src,
                name = GetPlayerName(src) or 'unknown'
            }
        end
    end

    local admins = {}

    for _, row in ipairs(rows) do
        local role = NormalizeRole(row.role)

        if IsDatabaseRole(role) then
            local roleInfo = GetRoleInfo(role)
            local online = onlineByIdentifier[row.identifier]

            admins[#admins + 1] = {
                id = row.id,
                identifier = row.identifier,
                role = role,
                role_label = roleInfo.label,
                role_level = roleInfo.level,
                role_order = roleInfo.order,
                name = row.name,
                added_by_identifier = row.added_by_identifier,
                added_by_name = row.added_by_name,
                created_at = row.created_at,
                updated_at = row.updated_at,
                online = online ~= nil,
                source = online and online.source or nil,
                online_name = online and online.name or nil
            }
        end
    end

    table.sort(admins, function(a, b)
        if a.role_order == b.role_order then
            return tostring(a.name or a.identifier) < tostring(b.name or b.identifier)
        end

        return tonumber(a.role_order) < tonumber(b.role_order)
    end)

    return admins
end

RegisterCommand('cw_setrole', function(src, args)
    local identifier = args[1]
    local role = args[2]
    local name = table.concat(args, ' ', 3)

    if not identifier or not role then
        print('Usage: cw_setrole identifier role name')
        return
    end

    local ok, message = CWAdmin.SetAdminRole(src, identifier, role, name)

    print(('[cw-admin] %s'):format(message))

    if src ~= 0 then
        if ok then
            CWAdmin.SendSuccess(src, message)
        else
            CWAdmin.SendError(src, message)
        end
    end
end, false)

RegisterCommand('cw_removerole', function(src, args)
    local identifier = args[1]

    if not identifier then
        print('Usage: cw_removerole identifier')
        return
    end

    local ok, message = CWAdmin.RemoveAdminRole(src, identifier)

    print(('[cw-admin] %s'):format(message))

    if src ~= 0 then
        if ok then
            CWAdmin.SendSuccess(src, message)
        else
            CWAdmin.SendError(src, message)
        end
    end
end, false)

RegisterCommand('cw_admins', function(src)
    if src ~= 0 and not CWAdmin.HasPermission(src, 'management.view') then
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    local admins = CWAdmin.GetAllAdmins()

    print('[cw-admin] Admin users:')

    for _, admin in ipairs(admins) do
        print(('[cw-admin] %s | %s | %s | online: %s'):format(
            admin.role_label,
            admin.identifier,
            admin.name or '-',
            admin.online and 'yes' or 'no'
        ))
    end
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    CWAdmin.RoleCache[src] = nil
end)

CreateThread(function()
    Wait(500)
    CWAdmin.EnsureAdminUsersTable()
end)