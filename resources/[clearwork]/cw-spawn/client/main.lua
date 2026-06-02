local skySpawn = {
    x = 0.0,
    y = 0.0,
    z = 2000.0,
    heading = 0.0,
    model = 'mp_male'
}

local defaultSpawn = {
    x = 2632.52,
    y = -1312.31,
    z = 51.42,
    heading = 270.0,
    model = 'mp_male'
}

local hiddenSpawnReady = false

local function DisableSpawnManagerAutoSpawn()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function()
            exports.spawnmanager:setAutoSpawn(false)
        end)
    end
end

local function GetCharacterModel(character)
    local gender = tostring(character and character.gender or ''):lower()

    if gender == 'female' or gender == 'f' or gender == 'woman' or gender == 'женщина' then
        return 'mp_female'
    end

    return 'mp_male'
end

local function GetSpawnCoords(character)
    return {
        x = tonumber(character and character.pos_x) or defaultSpawn.x,
        y = tonumber(character and character.pos_y) or defaultSpawn.y,
        z = tonumber(character and character.pos_z) or defaultSpawn.z,
        heading = tonumber(character and character.heading) or defaultSpawn.heading,
        model = GetCharacterModel(character)
    }
end

local function SpawnWithSpawnManager(spawn)
    if GetResourceState('spawnmanager') ~= 'started' then
        return false
    end

    local ok, err = pcall(function()
        exports.spawnmanager:spawnPlayer({
            x = spawn.x,
            y = spawn.y,
            z = spawn.z,
            heading = spawn.heading or 0.0,
            model = spawn.model or 'mp_male',
            skipFade = true
        })
    end)

    if not ok then
        print(('[cw-spawn] spawnmanager spawn failed: %s'):format(tostring(err)))
        return false
    end

    return true
end

local function SafeSetCoords(coords)
    local ped = PlayerPedId()

    if type(NetworkResurrectLocalPlayer) == 'function' then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.heading or 0.0, true, false)
        Wait(150)
    elseif type(ResurrectPed) == 'function' and ped and ped ~= 0 then
        ResurrectPed(ped)
        Wait(150)
    end

    ped = PlayerPedId()

    if not ped or ped == 0 then
        return false
    end

    if type(SetEntityCoordsNoOffset) == 'function' then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    else
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    end

    SetEntityHeading(ped, coords.heading or 0.0)
    return true
end

local function SetPedHidden(state)
    local ped = PlayerPedId()

    if not ped or ped == 0 then
        return
    end

    FreezeEntityPosition(ped, state)
    SetEntityVisible(ped, not state, false)
    SetEntityCollision(ped, not state, not state)

    if state then
        SetEntityAlpha(ped, 0, false)
        ClearPedTasksImmediately(ped)
    else
        if type(ResetEntityAlpha) == 'function' then
            ResetEntityAlpha(ped)
        else
            SetEntityAlpha(ped, 255, false)
        end
    end
end

local function FinalizePed(coords, visible, health)
    local ped = PlayerPedId()

    if not ped or ped == 0 then
        return false
    end

    if coords then
        SafeSetCoords(coords)
        ped = PlayerPedId()
    end

    SetEntityHeading(ped, coords and coords.heading or GetEntityHeading(ped))
    FreezeEntityPosition(ped, not visible)
    SetEntityVisible(ped, visible, false)
    SetEntityCollision(ped, visible, visible)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, health or 200)

    if visible then
        if type(ResetEntityAlpha) == 'function' then
            ResetEntityAlpha(ped)
        else
            SetEntityAlpha(ped, 255, false)
        end
    else
        SetEntityAlpha(ped, 0, false)
    end

    return true
end

local function EnsureHiddenSpawn(forceSky)
    DisableSpawnManagerAutoSpawn()

    if not forceSky and hiddenSpawnReady then
        SetPedHidden(true)
        return
    end

    DoScreenFadeOut(0)

    local spawned = SpawnWithSpawnManager(skySpawn)

    if spawned then
        Wait(900)
        FinalizePed(skySpawn, false, 200)
    else
        SafeSetCoords(skySpawn)
        FinalizePed(skySpawn, false, 200)
    end

    hiddenSpawnReady = true
end

CreateThread(function()
    Wait(1000)
    DisableSpawnManagerAutoSpawn()

    -- На входе создаём настоящий ped через spawnmanager, но прячем его в skybox.
    -- Это убирает состояние "камера без персонажа".
    EnsureHiddenSpawn(true)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DisableSpawnManagerAutoSpawn()
    end
end)

RegisterNetEvent('cw-spawn:client:prepareCharacterMenu', function(forceSky)
    EnsureHiddenSpawn(forceSky == true)
end)

RegisterNetEvent('cw-spawn:client:spawnCharacter', function(character)
    DisableSpawnManagerAutoSpawn()

    local coords = GetSpawnCoords(character)

    DoScreenFadeOut(300)
    Wait(350)

    local spawned = SpawnWithSpawnManager(coords)

    if spawned then
        Wait(1000)
        FinalizePed(coords, true, 200)
    else
        SafeSetCoords(coords)
        FinalizePed(coords, true, 200)
    end

    hiddenSpawnReady = false

    Wait(250)
    DoScreenFadeIn(500)

    TriggerEvent('cw-spawn:client:spawnFinished', character)

    print(('[cw-spawn] Spawned character at %.2f %.2f %.2f heading %.2f'):format(
        coords.x,
        coords.y,
        coords.z,
        coords.heading
    ))
end)

RegisterNetEvent('cw-spawn:client:respawnHere', function(coords)
    DisableSpawnManagerAutoSpawn()

    local ped = PlayerPedId()
    local currentCoords = GetEntityCoords(ped)

    local current = coords or {
        x = currentCoords.x,
        y = currentCoords.y,
        z = currentCoords.z,
        heading = GetEntityHeading(ped),
        model = 'mp_male'
    }

    local spawned = SpawnWithSpawnManager(current)

    if spawned then
        Wait(700)
    else
        SafeSetCoords(current)
    end

    FinalizePed(current, true, 200)
end)

exports('RespawnCurrentPedAt', function(coords)
    TriggerEvent('cw-spawn:client:respawnHere', coords)
end)
