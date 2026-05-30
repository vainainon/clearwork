local Config = CWAdminConfig

local function BuildDashboard(src)
    local roleData = CWAdmin.GetRoleData(src)

    return {
        admin = {
            source = src,
            name = GetPlayerName(src) or 'unknown',
            role = roleData.role,
            role_label = roleData.label,
            role_level = roleData.level
        },

        stats = {
            onlinePlayers = #CWAdmin.GetOnlinePlayers(),
            activeCharacters = CWAdmin.CountActiveCharacters(),
            totalCharacters = CWAdmin.GetTotalCharacters()
        },

        tools = CWAdmin.GetToolStates(src)
    }
end

local function OpenAdminPanel(src)
    if not CWAdmin.IsAdmin(src) then
        print(('[cw-admin] Access denied for %s'):format(src))
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    TriggerClientEvent('cw-admin:client:openPanel', src, BuildDashboard(src))
end

RegisterCommand('cwadmin', function(src)
    if src == 0 then
        print('[cw-admin] /cwadmin can only be used in-game.')
        return
    end

    OpenAdminPanel(src)
end, false)

RegisterCommand('adminchars', function(src)
    if src == 0 then
        return
    end

    OpenAdminPanel(src)
end, false)

RegisterNetEvent('cw-admin:server:openPanel', function()
    OpenAdminPanel(source)
end)

RegisterNetEvent('cw-admin:server:dashboard:load', function()
    local src = source

    if not CWAdmin.IsAdmin(src) then
        CWAdmin.SendError(src, 'Нет доступа.')
        return
    end

    TriggerClientEvent('cw-admin:client:dashboard:receive', src, BuildDashboard(src))
end)