local DOWNED_SECONDS = 300
local ROULETTE_COUNTDOWN_SECONDS = 5

local isDowned = false
local waitingRoll = false
local rollRequested = false
local permanentDead = false

local downedUntil = 0
local rouletteCountdownUntil = 0
local downCoords = nil
local currentChance = nil

local nextPositionSave = 0
local nextUiTick = 0
local nextRagdollTick = 0

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
    if IsEntityDead(ped) then
        return true
    end

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
    if permanentDead then
        return
    end

    isDowned = false
    waitingRoll = false
    rollRequested = false
    currentChance = nil

    SetInvincible(false)
    SafeResurrect(downCoords or GetCurrentCoords(), 200)
    ClearPedTasksImmediately(PlayerPedId())

    ShowUi('downed:hide')
    TriggerServerEvent('cw-death:server:saveDownedPosition', downCoords or GetCurrentCoords())
end

local function BeginKnockdown()
    if isDowned or waitingRoll then
        return
    end

    DisableSpawnManagerAutoSpawn()

    downCoords = GetCurrentCoords()
    isDowned = true
    waitingRoll = true
    rollRequested = false
    permanentDead = false
    currentChance = nil

    downedUntil = 0
    rouletteCountdownUntil = GetGameTimer() + (ROULETTE_COUNTDOWN_SECONDS * 1000)

    nextPositionSave = 0
    nextUiTick = 0
    nextRagdollTick = 0

    SetInvincible(true)
    SafeResurrect(downCoords, 101)

    ShowUi('roulette:prepare', {
        chance = nil,
        countdown = ROULETTE_COUNTDOWN_SECONDS,
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
            local now = GetGameTimer()
            local ped = PlayerPedId()

            DisableAllControlActions(0)
            SetInvincible(true)

            if now >= nextRagdollTick then
                if IsPedDead(ped) then
                    SafeResurrect(downCoords or GetCurrentCoords(), 101)
                    ped = PlayerPedId()
                end

                SetEntityHealth(ped, 101)

                if type(SetPedToRagdoll) == 'function' then
                    SetPedToRagdoll(ped, 1200, 1200, 0, true, true, false)
                end

                nextRagdollTick = now + 1000
            end

            if now >= nextUiTick then
                if waitingRoll then
                    local leftToRoll = math.max(0, math.ceil((rouletteCountdownUntil - now) / 1000))

                    ShowUi('roulette:countdownTick', {
                        chance = currentChance,
                        seconds = leftToRoll
                    })

                    if not rollRequested and leftToRoll <= 0 then
                        rollRequested = true

                        ShowUi('roulette:spin', {
                            chance = currentChance
                        })

                        TriggerServerEvent('cw-death:server:rollRoulette', downCoords or GetCurrentCoords())
                    end
                else
                    local left = permanentDead and 0 or math.max(0, math.ceil((downedUntil - now) / 1000))

                    ShowUi('downed:tick', {
                        seconds = left,
                        permanent = permanentDead
                    })

                    if not permanentDead and downedUntil > 0 and now >= downedUntil then
                        EndKnockdown()
                    end
                end

                nextUiTick = now + 300
            end

            if now >= nextPositionSave then
                TriggerServerEvent('cw-death:server:saveDownedPosition', downCoords or GetCurrentCoords())
                nextPositionSave = now + 15000
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('cw-death:client:roulettePrepared', function(data)
    data = data or {}

    currentChance = tonumber(data.chance) or 0

    local countdown = tonumber(data.countdown) or ROULETTE_COUNTDOWN_SECONDS
    rouletteCountdownUntil = GetGameTimer() + (countdown * 1000)

    ShowUi('roulette:prepare', {
        chance = currentChance,
        countdown = countdown,
        seconds = tonumber(data.seconds) or DOWNED_SECONDS,
        alreadyDead = data.alreadyDead == true
    })
end)

RegisterNetEvent('cw-death:client:rollResult', function(data)
    data = data or {}

    waitingRoll = false
    rollRequested = false
    permanentDead = data.permadeath == true
    currentChance = tonumber(data.chance) or currentChance or 0

    local seconds = tonumber(data.seconds) or DOWNED_SECONDS
    downedUntil = GetGameTimer() + (seconds * 1000)

    ShowUi('roulette:result', {
        chance = currentChance,
        roll = tonumber(data.roll) or 0,
        permanent = permanentDead,
        seconds = seconds,
        alreadyDead = data.alreadyDead == true
    })

    if permanentDead then
        SetInvincible(true)
    end
end)

RegisterNetEvent('cw-death:client:cancelKnockdown', function()
    isDowned = false
    waitingRoll = false
    rollRequested = false
    permanentDead = false
    currentChance = nil

    SetInvincible(false)
    ShowUi('downed:hide')
end)

RegisterNetEvent('cw-death:client:adminRevive', function(coords)
    downCoords = coords or downCoords or GetCurrentCoords()

    isDowned = false
    waitingRoll = false
    rollRequested = false
    permanentDead = false
    currentChance = nil

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