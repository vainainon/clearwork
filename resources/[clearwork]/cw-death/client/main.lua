local DOWNED_SECONDS = 300

local isDowned = false
local waitingRoll = false
local permanentDead = false
local downedUntil = 0
local downCoords = nil
local nextPositionSave = 0

local function DisableSpawnManagerAutoSpawn()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function()
            exports.spawnmanager:setAutoSpawn(false)
        end)
    end
end

local function GetCurrentCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped)
    }
end

local function SafeResurrect(coords, health)
    coords = coords or GetCurrentCoords()

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
    SetEntityHealth(ped, health or 200)

    if type(ResetEntityAlpha) == 'function' then
        ResetEntityAlpha(ped)
    end
end

local function IsPedDead(ped)
    if IsEntityDead(ped) then return true end

    if type(IsPedFatallyInjured) == 'function' and IsPedFatallyInjured(ped) then
        return true
    end

    return false
end

local function SetInvincible(state)
    if type(SetPlayerInvincible) == 'function' then
        SetPlayerInvincible(PlayerId(), state)
    end
end

local function ShowUi(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

local function EndKnockdown()
    if permanentDead then return end

    isDowned = false
    waitingRoll = false

    SetInvincible(false)
    SafeResurrect(downCoords or GetCurrentCoords(), 200)
    ClearPedTasksImmediately(PlayerPedId())

    ShowUi('downed:hide')
    TriggerServerEvent('cw-death:server:saveDownedPosition', downCoords or GetCurrentCoords())
end

local function BeginKnockdown()
    if isDowned or waitingRoll then return end

    DisableSpawnManagerAutoSpawn()

    downCoords = GetCurrentCoords()
    isDowned = true
    waitingRoll = true
    permanentDead = false
    downedUntil = GetGameTimer() + (DOWNED_SECONDS * 1000)
    nextPositionSave = 0

    SetInvincible(true)
    SafeResurrect(downCoords, 101)

    ShowUi('roulette:start', {
        seconds = DOWNED_SECONDS
    })

    TriggerServerEvent('cw-death:server:knockdown', downCoords)
end

CreateThread(function()
    DisableSpawnManagerAutoSpawn()

    while true do
        Wait(250)

        if not isDowned and not waitingRoll then
            local ped = PlayerPedId()

            if DoesEntityExist(ped) and IsPedDead(ped) then
                BeginKnockdown()
            end
        end
    end
end)

CreateThread(function()
    while true do
        if isDowned then
            local ped = PlayerPedId()
            local now = GetGameTimer()

            DisableAllControlActions(0)
            SetInvincible(true)

            if IsPedDead(ped) then
                SafeResurrect(downCoords or GetCurrentCoords(), 101)
                ped = PlayerPedId()
            end

            SetEntityHealth(ped, 101)

            if type(SetPedToRagdoll) == 'function' then
                SetPedToRagdoll(ped, 1000, 1000, 0, true, true, false)
            end

            local left = math.max(0, math.ceil((downedUntil - now) / 1000))

            ShowUi('downed:tick', {
                seconds = left,
                permanent = permanentDead
            })

            if now >= nextPositionSave then
                TriggerServerEvent('cw-death:server:saveDownedPosition', downCoords or GetCurrentCoords())
                nextPositionSave = now + 15000
            end

            if not permanentDead and not waitingRoll and now >= downedUntil then
                EndKnockdown()
            end

            Wait(500)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('cw-death:client:rollResult', function(data)
    data = data or {}

    waitingRoll = false
    permanentDead = data.permadeath == true

    if data.seconds then
        downedUntil = GetGameTimer() + (tonumber(data.seconds) * 1000)
    end

    ShowUi('roulette:result', {
        chance = tonumber(data.chance) or 0,
        roll = tonumber(data.roll) or 0,
        permanent = permanentDead,
        seconds = math.max(0, math.ceil((downedUntil - GetGameTimer()) / 1000))
    })

    if permanentDead then
        SetInvincible(true)
    end
end)

RegisterNetEvent('cw-death:client:cancelKnockdown', function()
    isDowned = false
    waitingRoll = false
    permanentDead = false

    SetInvincible(false)
    ShowUi('downed:hide')
end)

RegisterNetEvent('cw-death:client:adminRevive', function(coords)
    downCoords = coords or downCoords or GetCurrentCoords()

    isDowned = false
    waitingRoll = false
    permanentDead = false

    SetInvincible(false)
    SafeResurrect(downCoords, 200)
    ClearPedTasksImmediately(PlayerPedId())

    ShowUi('downed:hide')
    TriggerServerEvent('cw-death:server:saveDownedPosition', downCoords)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DisableSpawnManagerAutoSpawn()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetInvincible(false)
    ShowUi('downed:hide')
end)