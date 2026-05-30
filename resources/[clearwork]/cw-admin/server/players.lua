local Config = CWAdminConfig

CWAdmin.FrozenPlayers = CWAdmin.FrozenPlayers or {}

function CWAdmin.GetOnlinePlayers()
    local players = {}

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)

        if targetSrc then
            local cwPlayer = CWAdmin.GetCWPlayer(targetSrc)
            local roleData = CWAdmin.GetRoleData(targetSrc)

            local ped = GetPlayerPed(targetSrc)

            local coords = {
                x = 0.0,
                y = 0.0,
                z = 0.0,
                heading = 0.0
            }

            if ped and ped ~= 0 then
                local c = GetEntityCoords(ped)

                coords.x = tonumber(c.x) or 0.0
                coords.y = tonumber(c.y) or 0.0
                coords.z = tonumber(c.z) or 0.0
                coords.heading = tonumber(GetEntityHeading(ped)) or 0.0
            end

            local character = nil

            if cwPlayer and cwPlayer.character then
                character = {
                    id = cwPlayer.character.id,
                    firstname = cwPlayer.character.firstname,
                    lastname = cwPlayer.character.lastname,
                    slot = cwPlayer.character.slot
                }
            end

            players[#players + 1] = {
                source = targetSrc,
                name = GetPlayerName(targetSrc) or ('ID ' .. targetSrc),

                account_name = cwPlayer and cwPlayer.name or nil,
                account_id = cwPlayer and cwPlayer.account_id or nil,

                role = roleData.role,
                role_label = roleData.label,
                role_level = roleData.level,
                role_identifier = roleData.identifier,

                character = character,
                ping = GetPlayerPing(targetSrc) or 0,
                frozen = CWAdmin.FrozenPlayers[targetSrc] == true,
                coords = coords
            }
        end
    end

    table.sort(players, function(a, b)
        return tonumber(a.source) < tonumber(b.source)
    end)

    return players
end

local function SendPlayers(src)
    TriggerClientEvent('cw-admin:client:players:receive', src, CWAdmin.GetOnlinePlayers())
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)

    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        heading = tonumber(GetEntityHeading(ped)) or 0.0
    }
end

local function IsTargetProtected(src, target)
    if target == src then
        return false
    end

    local actorRole = CWAdmin.GetAdminRole(src)
    local targetRole = CWAdmin.GetAdminRole(target)

    if targetRole == 'owner' then
        return true
    end

    if CWAdmin.GetRoleLevel(targetRole) >= CWAdmin.GetRoleLevel(actorRole) then
        return true
    end

    return false
end

RegisterNetEvent('cw-admin:server:players:list', function()
    local src = source

    if not CWAdmin.HasPermission(src, Config.Ace.players) then
        CWAdmin.SendError(src, 'Нет доступа к разделу игроков.')
        return
    end

    SendPlayers(src)
end)

RegisterNetEvent('cw-admin:server:players:action', function(action, target, payload)
    local src = source

    action = tostring(action or '')
    target = tonumber(target)
    payload = payload or {}

    if not target or not GetPlayerName(target) then
        CWAdmin.SendError(src, 'Игрок не найден.')
        return
    end

    if IsTargetProtected(src, target) then
        CWAdmin.SendError(src, 'Нельзя применять действие к администратору с равной или более высокой ролью.')
        return
    end

    if action == 'goto' then
        if not CWAdmin.HasPermission(src, Config.Ace.playersTeleport) then
            CWAdmin.SendError(src, 'Нет доступа к телепорту.')
            return
        end

        local coords = GetPlayerCoords(target)

        if not coords then
            CWAdmin.SendError(src, 'Не удалось получить координаты игрока.')
            return
        end

        TriggerClientEvent('cw-admin:client:teleportToCoords', src, coords)

        CWAdmin.AdminLog(src, 'player_goto', {
            target = target
        })

        return
    end

    if action == 'bring' then
        if not CWAdmin.HasPermission(src, Config.Ace.playersTeleport) then
            CWAdmin.SendError(src, 'Нет доступа к телепорту.')
            return
        end

        local coords = GetPlayerCoords(src)

        if not coords then
            CWAdmin.SendError(src, 'Не удалось получить твои координаты.')
            return
        end

        TriggerClientEvent('cw-admin:client:teleportToCoords', target, coords)

        CWAdmin.AdminLog(src, 'player_bring', {
            target = target
        })

        return
    end

    if action == 'freeze' then
        if not CWAdmin.HasPermission(src, Config.Ace.playersFreeze) then
            CWAdmin.SendError(src, 'Нет доступа к freeze.')
            return
        end

        CWAdmin.FrozenPlayers[target] = not CWAdmin.FrozenPlayers[target]

        TriggerClientEvent('cw-admin:client:setFrozen', target, CWAdmin.FrozenPlayers[target])

        CWAdmin.AdminLog(src, 'player_freeze', {
            target = target,
            state = CWAdmin.FrozenPlayers[target]
        })

        SendPlayers(src)
        return
    end

    if action == 'kick' then
        if not CWAdmin.HasPermission(src, Config.Ace.playersKick) then
            CWAdmin.SendError(src, 'Нет доступа к kick.')
            return
        end

        local reason = tostring(payload.reason or 'Kicked by admin')

        CWAdmin.AdminLog(src, 'player_kick', {
            target = target,
            reason = reason
        })

        DropPlayer(target, reason)
        return
    end

    CWAdmin.SendError(src, 'Неизвестное действие.')
end)

AddEventHandler('playerDropped', function()
    local src = source
    CWAdmin.FrozenPlayers[src] = nil
end)