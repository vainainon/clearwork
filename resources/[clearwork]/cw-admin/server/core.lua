CWAdmin = CWAdmin or {}

local Config = CWAdminConfig or {}

function CWAdmin.IsAdmin(src)
    if src == 0 then
        return true
    end

    return IsPlayerAceAllowed(src, Config.Ace.admin)
end

function CWAdmin.HasPermission(src, ace)
    if src == 0 then
        return true
    end

    if Config.Ace and Config.Ace.admin and IsPlayerAceAllowed(src, Config.Ace.admin) then
        return true
    end

    if ace and IsPlayerAceAllowed(src, ace) then
        return true
    end

    return false
end

function CWAdmin.SendError(src, message)
    TriggerClientEvent('cw-admin:client:error', src, tostring(message or 'Ошибка.'))
end

function CWAdmin.SendSuccess(src, message)
    TriggerClientEvent('cw-admin:client:success', src, tostring(message or 'Готово.'))
end

function CWAdmin.GetCWPlayer(src)
    local ok, player = pcall(function()
        return exports['cw-core']:GetPlayer(src)
    end)

    if not ok then
        print(('[cw-admin] cw-core:GetPlayer failed for %s'):format(tostring(src)))
        return nil
    end

    return player
end

function CWAdmin.AdminLog(src, action, data)
    local name = GetPlayerName(src) or 'console'

    print(('[cw-admin] %s | %s | %s'):format(
        tostring(name),
        tostring(action),
        data and json.encode(data) or '{}'
    ))
end