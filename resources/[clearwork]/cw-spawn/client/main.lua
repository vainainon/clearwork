local defaultSpawn = {
    x = 1230.92,
    y = -1298.15,
    z = 76.9,
    heading = 180.0
}

local function DisableSpawnManagerAutoSpawn()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function()
            exports.spawnmanager:setAutoSpawn(false)
        end)
    end
end

local function GetSpawnCoords(character)
    return {
        x = tonumber(character and character.pos_x) or defaultSpawn.x,
        y = tonumber(character and character.pos_y) or defaultSpawn.y,
        z = tonumber(character and character.pos_z) or defaultSpawn.z,
        heading = tonumber(character and character.pos_heading) or defaultSpawn.heading
    }
end

local function SafeSetCoords(coords)
    local ped = PlayerPedId()

    if type(NetworkResurrectLocalPlayer) == 'function' then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.heading or 0.0, true, false)
        Wait(100)
    elseif type(ResurrectPed) == 'function' then
        ResurrectPed(ped)
        Wait(100)
    end

    ped = PlayerPedId()

    if type(SetEntityCoordsNoOffset) == 'function' then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    else
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    end

    SetEntityHeading(ped, coords.heading or 0.0)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, 200)

    if type(ResetEntityAlpha) == 'function' then
        ResetEntityAlpha(ped)
    else
        SetEntityAlpha(ped, 255, false)
    end
end

CreateThread(function()
    Wait(1000)
    DisableSpawnManagerAutoSpawn()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DisableSpawnManagerAutoSpawn()
    end
end)

RegisterNetEvent('cw-spawn:client:spawnCharacter', function(character)
    DisableSpawnManagerAutoSpawn()

    local coords = GetSpawnCoords(character)

    DoScreenFadeOut(300)
    Wait(350)

    SafeSetCoords(coords)

    Wait(250)
    DoScreenFadeIn(500)

    TriggerEvent('cw-spawn:client:spawnFinished', character)
end)

RegisterNetEvent('cw-spawn:client:respawnHere', function(coords)
    DisableSpawnManagerAutoSpawn()

    local ped = PlayerPedId()
    local current = coords or {
        x = GetEntityCoords(ped).x,
        y = GetEntityCoords(ped).y,
        z = GetEntityCoords(ped).z,
        heading = GetEntityHeading(ped)
    }

    SafeSetCoords(current)
end)

exports('RespawnCurrentPedAt', function(coords)
    SafeSetCoords(coords)
end)