local Config = CWAdminConfig

local function CanUseManagement(src)
    local role = CWAdmin.GetAdminRole(src)

    return role == 'owner' or role == 'general'
end

local function GetOnlineOwners()
    local owners = {}

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)

        if src and CWAdmin.GetAdminRole(src) == 'owner' then
            local roleData = CWAdmin.GetRoleData(src)

            owners[#owners + 1] = {
                id = 'owner-' .. tostring(src),
                identifier = roleData.identifier or '-',
                role = 'owner',
                role_label = 'Owner',
                role_level = 100,
                role_order = 1,
                name = GetPlayerName(src) or 'Owner',
                added_by_identifier = 'server.cfg',
                added_by_name = 'server.cfg',
                created_at = 'server.cfg',
                updated_at = 'server.cfg',
                online = true,
                source = src,
                online_name = GetPlayerName(src) or 'Owner',
                can_remove = false,
                can_set_role = false
            }
        end
    end

    return owners
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

local function BuildManagementData(src)
    local owners = GetOnlineOwners()
    local admins = DecorateAdminRows(src, CWAdmin.GetAllAdmins())
    local list = {}

    for _, owner in ipairs(owners) do
        list[#list + 1] = owner
    end

    for _, admin in ipairs(admins) do
        list[#list + 1] = admin
    end

    table.sort(list, function(a, b)
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
        admins = list,
        onlinePlayers = CWAdmin.GetOnlinePlayers()
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

    local identifier = tostring(data.identifier or '')
    local role = tostring(data.role or '')
    local name = tostring(data.name or identifier)

    if identifier == '' and data.source then
        local target = tonumber(data.source)

        if target and GetPlayerName(target) then
            local targetRole = CWAdmin.GetAdminRole(target)

            if targetRole == 'owner' then
                CWAdmin.SendError(src, 'Нельзя менять роль Owner. Owner задаётся только в server.cfg.')
                return
            end

            local roleData = CWAdmin.GetRoleData(target, true)

            identifier = roleData.identifier or ''
            name = GetPlayerName(target) or name
        end
    end

    if identifier == '' then
        CWAdmin.SendError(src, 'Не выбран игрок или identifier.')
        return
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

    local identifier = tostring(data.identifier or '')

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