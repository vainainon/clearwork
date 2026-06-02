local Config = CWAdminConfig

local function Trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function CanUseManagement(src)
    local role = CWAdmin.GetAdminRole(src)
    return role == 'owner' or role == 'general'
end

local function GetPlayerIdentifierList(src)
    local identifiers = {}

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        identifiers[#identifiers + 1] = identifier
    end

    return identifiers
end

local function IdentifierEquals(a, b)
    return tostring(a or ''):lower() == tostring(b or ''):lower()
end

local function PlayerHasIdentifier(src, identifier)
    identifier = tostring(identifier or '')
    if identifier == '' then
        return false
    end

    for _, playerIdentifier in ipairs(GetPlayerIdentifierList(src)) do
        if IdentifierEquals(playerIdentifier, identifier) then
            return true
        end
    end

    return false
end

local function IsOnlineOwnerIdentifier(identifier)
    identifier = tostring(identifier or '')
    if identifier == '' then
        return false
    end

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)

        if targetSrc and CWAdmin.GetAdminRole(targetSrc) == 'owner' then
            if PlayerHasIdentifier(targetSrc, identifier) then
                return true
            end

            local roleData = CWAdmin.GetRoleData(targetSrc)
            if roleData and IdentifierEquals(roleData.identifier, identifier) then
                return true
            end
        end
    end

    return false
end

local function DecorateAdminRows(src, admins)
    admins = admins or {}

    for _, admin in ipairs(admins) do
        admin.can_remove = CWAdmin.CanRemoveRole(src, admin.role) == true
        admin.can_set_role = CWAdmin.CanGrantRole(src, admin.role) == true
    end

    return admins
end

local function GetGrantableRoles(src)
    local role = CWAdmin.GetAdminRole(src)
    local grantable = Config.GrantableRoles[role] or {}
    local result = {}

    for roleName, enabled in pairs(grantable) do
        if enabled and Config.Roles[roleName] then
            result[#result + 1] = {
                role = roleName,
                label = Config.Roles[roleName].label,
                order = Config.Roles[roleName].order
            }
        end
    end

    table.sort(result, function(a, b)
        return tonumber(a.order) < tonumber(b.order)
    end)

    return result
end

local function GetManagementOnlinePlayers()
    local players = CWAdmin.GetOnlinePlayers()
    local result = {}

    for _, player in ipairs(players or {}) do
        local role = player.role or CWAdmin.GetAdminRole(player.source)

        -- Owner не показываем в выдаче прав: он задаётся только через server.cfg.
        if role ~= 'owner' then
            result[#result + 1] = player
        end
    end

    return result
end

local function BuildManagementData(src)
    -- Важно: Owner больше не добавляется в список админов как псевдо-строка server.cfg.
    -- В UI остаются только реальные строки из admin_users.
    local admins = DecorateAdminRows(src, CWAdmin.GetAllAdmins())

    table.sort(admins, function(a, b)
        local orderA = tonumber(a.role_order) or 99
        local orderB = tonumber(b.role_order) or 99

        if orderA == orderB then
            return tostring(a.name or a.identifier) < tostring(b.name or b.identifier)
        end

        return orderA < orderB
    end)

    return {
        actor = CWAdmin.GetRoleData(src),
        grantableRoles = GetGrantableRoles(src),
        admins = admins,
        onlinePlayers = GetManagementOnlinePlayers()
    }
end

RegisterNetEvent('cw-admin:server:management:list', function()
    local src = source

    if not CanUseManagement(src) then
        CWAdmin.SendError(src, 'Нет доступа к управлению.')
        return
    end

    TriggerClientEvent('cw-admin:client:management:receive', src, BuildManagementData(src))
end)

RegisterNetEvent('cw-admin:server:management:setRole', function(data)
    local src = source

    if not CanUseManagement(src) then
        CWAdmin.SendError(src, 'Нет доступа к управлению.')
        return
    end

    data = data or {}
    local target = tonumber(data.source)
    local identifier = Trim(data.identifier)
    local role = Trim(data.role)
    local name = Trim(data.name)

    if role == '' then
        CWAdmin.SendError(src, 'Не выбрана роль.')
        return
    end

    if target and GetPlayerName(target) then
        local targetRole = CWAdmin.GetAdminRole(target, true)
        if targetRole == 'owner' then
            CWAdmin.SendError(src, 'Нельзя менять роль Owner. Owner задаётся только в server.cfg.')
            return
        end

        local roleData = CWAdmin.GetRoleData(target, true)
        identifier = roleData.identifier or identifier
        name = GetPlayerName(target) or name
    end

    if identifier == '' then
        CWAdmin.SendError(src, 'Не выбран игрок или identifier.')
        return
    end

    if IsOnlineOwnerIdentifier(identifier) then
        CWAdmin.SendError(src, 'Нельзя выдавать БД-роль Owner-у. Owner задаётся только в server.cfg.')
        return
    end

    if name == '' then
        name = identifier
    end

    local ok, message = CWAdmin.SetAdminRole(src, identifier, role, name)
    if ok then
        CWAdmin.SendSuccess(src, message)
        TriggerClientEvent('cw-admin:client:management:receive', src, BuildManagementData(src))
    else
        CWAdmin.SendError(src, message)
    end
end)

RegisterNetEvent('cw-admin:server:management:removeRole', function(data)
    local src = source

    if not CanUseManagement(src) then
        CWAdmin.SendError(src, 'Нет доступа к управлению.')
        return
    end

    data = data or {}
    local identifier = Trim(data.identifier)

    if identifier == '' then
        CWAdmin.SendError(src, 'Пустой identifier.')
        return
    end

    local ok, message = CWAdmin.RemoveAdminRole(src, identifier)
    if ok then
        CWAdmin.SendSuccess(src, message)
        TriggerClientEvent('cw-admin:client:management:receive', src, BuildManagementData(src))
    else
        CWAdmin.SendError(src, message)
    end
end)
