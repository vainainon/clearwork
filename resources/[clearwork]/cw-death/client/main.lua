local DOWNED_SECONDS = 300
local ROULETTE_COUNTDOWN_SECONDS = 5
local RESULT_ANIMATION_SECONDS = 6

local isDowned = false
local waitingRoll = false
local rollRequested = false
local permanentDead = false
local actionReady = false
local actionMode = nil
local activePhase = nil

local downedUntil = 0
local countdownUntil = 0
local resultTimerStartsAt = 0
local downCoords = nil
local currentChance = nil
local currentRoll = nil

local nextUiTick = 0
local nextRagdollTick = 0
local nextPositionSave = 0
local nextStateSave = 0

local function DisableSpawnManagerAutoSpawn()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function()
            exports.spawnmanager:setAutoSpawn(false)
        end)
    end
end

local function GetCurrentCoords()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return { x = 0.0, y = 0.0, z = 0.0, heading = 0.0 }
    end

    local coords = GetEntityCoords(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped)
    }
end

local function NormalizeCoords(coords)
    coords = coords or GetCurrentCoords()

    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        heading = tonumber(coords.heading) or tonumber(coords.h) or 0.0
    }
end

local function ShowUi(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

local function SetInvincible(state)
    if type(SetPlayerInvincible) == 'function' then
        SetPlayerInvincible(PlayerId(), state)
    end
end

local function SetActionFocus(state)
    SetNuiFocus(state == true, state == true)
    SetNuiFocusKeepInput(false)
end

local function IsPedDead(ped)
    if not ped or ped == 0 then return false end
    if IsEntityDead(ped) then return true end
    if type(IsPedFatallyInjured) == 'function' and IsPedFatallyInjured(ped) then return true end
    return false
end

local function IsSwitchBlocked()
    return activePhase ~= nil or isDowned or waitingRoll or permanentDead
end

local function ResetDeathState(hideUi)
    isDowned = false
    waitingRoll = false
    rollRequested = false
    permanentDead = false
    actionReady = false
    actionMode = nil
    activePhase = nil

    currentChance = nil
    currentRoll = nil
    downedUntil = 0
    countdownUntil = 0
    resultTimerStartsAt = 0

    SetActionFocus(false)
    SetInvincible(false)

    if hideUi ~= false then
        ShowUi('downed:hide')
    end
end

local function PrepareDownedPed(coords)
    coords = NormalizeCoords(coords)
    downCoords = coords

    DisableSpawnManagerAutoSpawn()
    TriggerEvent('cw-spawn:client:respawnHere', coords)
    SetInvincible(true)

    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        SetEntityHealth(ped, 101)
        ClearPedTasksImmediately(ped)
    end
end

local function SaveDownedState(force)
    if not activePhase then return end
    if waitingRoll then return end

    local now = GetGameTimer()
    if not force and now < nextStateSave then return end

    local remaining = 0
    if downedUntil > 0 then
        remaining = math.max(0, math.ceil((downedUntil - now) / 1000))
    end

    TriggerServerEvent('cw-death:server:updateDownedState', {
        phase = activePhase,
        seconds = remaining,
        permanent = permanentDead,
        chance = currentChance,
        roll = currentRoll,
        coords = downCoords or GetCurrentCoords()
    })

    nextStateSave = now + 60000
end

local function SetActionReady(state)
    if actionReady == state then return end

    actionReady = state == true
    SetActionFocus(actionReady)

    ShowUi('downed:actionState', {
        available = actionReady,
        mode = actionMode,
        permanent = permanentDead
    })

    if actionReady then
        SaveDownedState(true)
    end
end

local function BeginKnockdown()
    if IsSwitchBlocked() then return end

    downCoords = GetCurrentCoords()
    isDowned = true
    waitingRoll = true
    rollRequested = false
    permanentDead = false
    actionReady = false
    actionMode = nil
    activePhase = 'roulette'
    currentChance = nil
    currentRoll = nil

    countdownUntil = GetGameTimer() + (ROULETTE_COUNTDOWN_SECONDS * 1000)
    downedUntil = 0
    resultTimerStartsAt = 0
    nextUiTick = 0
    nextRagdollTick = 0
    nextPositionSave = 0
    nextStateSave = 0

    SetActionFocus(false)
    PrepareDownedPed(downCoords)

    ShowUi('roulette:prepare', {
        chance = nil,
        countdown = ROULETTE_COUNTDOWN_SECONDS,
        seconds = DOWNED_SECONDS
    })

    TriggerServerEvent('cw-death:server:knockdown', downCoords)
end

local function RestoreRoulette(data)
    data = data or {}

    downCoords = NormalizeCoords(data.coords)
    isDowned = true
    waitingRoll = true
    rollRequested = false
    permanentDead = data.permanent == true
    actionReady = false
    actionMode = nil
    activePhase = 'roulette'
    currentChance = tonumber(data.chance) or 0
    currentRoll = nil

    local countdown = tonumber(data.countdown) or ROULETTE_COUNTDOWN_SECONDS
    countdownUntil = GetGameTimer() + (countdown * 1000)
    downedUntil = 0
    resultTimerStartsAt = 0
    nextUiTick = 0
    nextRagdollTick = 0
    nextPositionSave = 0
    nextStateSave = 0

    SetActionFocus(false)
    PrepareDownedPed(downCoords)

    ShowUi('roulette:prepare', {
        chance = currentChance,
        countdown = countdown,
        seconds = tonumber(data.seconds) or DOWNED_SECONDS,
        alreadyDead = data.alreadyDead == true
    })
end

local function RestoreDownedState(data)
    data = data or {}

    local seconds = math.max(0, tonumber(data.seconds) or DOWNED_SECONDS)
    local permanent = data.permanent == true

    downCoords = NormalizeCoords(data.coords)
    isDowned = true
    waitingRoll = false
    rollRequested = false
    permanentDead = permanent
    activePhase = permanent and 'switch_wait' or 'revive_wait'
    actionMode = permanent and 'switch' or 'revive'
    currentChance = tonumber(data.chance) or currentChance or 0
    currentRoll = tonumber(data.roll) or currentRoll
    resultTimerStartsAt = 0
    downedUntil = GetGameTimer() + (seconds * 1000)

    nextUiTick = 0
    nextRagdollTick = 0
    nextPositionSave = 0
    nextStateSave = 0

    PrepareDownedPed(downCoords)
    SetActionFocus(false)

    ShowUi('downed:state', {
        permanent = permanent,
        seconds = seconds,
        chance = currentChance,
        roll = currentRoll,
        actionAvailable = seconds <= 0
    })

    actionReady = false
    SetActionReady(seconds <= 0)
end

local function FinishLocalRevive(coords)
    coords = NormalizeCoords(coords or downCoords or GetCurrentCoords())

    ResetDeathState(true)
    TriggerEvent('cw-spawn:client:respawnHere', coords)
    ClearPedTasksImmediately(PlayerPedId())
end

local function FinishLocalSwitch()
    ResetDeathState(true)
    TriggerEvent('cw-characters:client:forceOpenMenu')
end

CreateThread(function()
    DisableSpawnManagerAutoSpawn()
    SetActionFocus(false)
    ShowUi('downed:hide')

    while true do
        Wait(250)

        if not IsSwitchBlocked() then
            local ped = PlayerPedId()
            if ped and ped ~= 0 and DoesEntityExist(ped) and IsPedDead(ped) then
                BeginKnockdown()
            end
        end
    end
end)

CreateThread(function()
    while true do
        if IsSwitchBlocked() then
            local now = GetGameTimer()
            local ped = PlayerPedId()

            SetInvincible(true)

            if now >= nextRagdollTick then
                if ped and ped ~= 0 then
                    SetEntityHealth(ped, 101)
                    if type(SetPedToRagdoll) == 'function' then
                        SetPedToRagdoll(ped, 1200, 1200, 0, true, true, false)
                    end
                end

                nextRagdollTick = now + 1000
            end

            if now >= nextUiTick then
                if waitingRoll then
                    local leftToRoll = math.max(0, math.ceil((countdownUntil - now) / 1000))

                    ShowUi('roulette:countdownTick', {
                        chance = currentChance,
                        seconds = leftToRoll
                    })

                    if not rollRequested and leftToRoll <= 0 then
                        rollRequested = true
                        ShowUi('roulette:spin', { chance = currentChance })
                        TriggerServerEvent('cw-death:server:rollRoulette', downCoords or GetCurrentCoords())
                    end
                elseif activePhase == 'revive_wait' or activePhase == 'switch_wait' then
                    local left = 0

                    if resultTimerStartsAt > 0 and now < resultTimerStartsAt then
                        left = DOWNED_SECONDS
                    elseif downedUntil > 0 then
                        left = math.max(0, math.ceil((downedUntil - now) / 1000))
                    end

                    ShowUi('downed:tick', {
                        seconds = left,
                        permanent = permanentDead,
                        actionAvailable = left <= 0,
                        mode = actionMode
                    })

                    if left <= 0 then
                        SetActionReady(true)
                    end
                end

                nextUiTick = now + 300
            end

            if now >= nextPositionSave then
                downCoords = downCoords or GetCurrentCoords()
                TriggerServerEvent('cw-death:server:saveDownedPosition', downCoords)
                nextPositionSave = now + 15000
            end

            SaveDownedState(false)
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
    countdownUntil = GetGameTimer() + (countdown * 1000)

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
    activePhase = permanentDead and 'switch_wait' or 'revive_wait'
    actionMode = permanentDead and 'switch' or 'revive'
    actionReady = false

    currentChance = tonumber(data.chance) or currentChance or 0
    currentRoll = tonumber(data.roll) or 0

    local seconds = tonumber(data.seconds) or DOWNED_SECONDS
    resultTimerStartsAt = GetGameTimer() + (RESULT_ANIMATION_SECONDS * 1000)
    downedUntil = resultTimerStartsAt + (seconds * 1000)
    nextStateSave = GetGameTimer() + 60000

    SetActionFocus(false)

    ShowUi('roulette:result', {
        chance = currentChance,
        roll = currentRoll,
        permanent = permanentDead,
        seconds = seconds,
        alreadyDead = data.alreadyDead == true
    })
end)

RegisterNetEvent('cw-death:client:restoreRoulette', function(data)
    RestoreRoulette(data or {})
end)

RegisterNetEvent('cw-death:client:restoreDownedState', function(data)
    RestoreDownedState(data or {})
end)

RegisterNetEvent('cw-death:client:finishRevive', function(coords)
    FinishLocalRevive(coords)
end)

RegisterNetEvent('cw-death:client:finishSwitch', function()
    FinishLocalSwitch()
end)

RegisterNetEvent('cw-death:client:cancelKnockdown', function()
    ResetDeathState(true)
end)

RegisterNetEvent('cw-death:client:adminRevive', function(coords)
    FinishLocalRevive(coords or downCoords or GetCurrentCoords())
    TriggerServerEvent('cw-death:server:clearCurrentDownedState', coords or downCoords or GetCurrentCoords())
end)

-- Старый event оставлен для совместимости, но больше не гасит состояние смерти.
-- Раньше из-за него /chars мог закрыть HTML и фактически поднять убитого персонажа.
RegisterNetEvent('cw-death:client:characterMenuOpened', function()
end)

RegisterNUICallback('deathAction', function(_, cb)
    if not actionReady then
        cb({ ok = false })
        return
    end

    actionReady = false
    SetActionFocus(false)

    if actionMode == 'revive' and not permanentDead then
        TriggerServerEvent('cw-death:server:finishKnockdown', downCoords or GetCurrentCoords())
        cb({ ok = true })
        return
    end

    if actionMode == 'switch' and permanentDead then
        TriggerServerEvent('cw-death:server:finishPermadeathMenu', downCoords or GetCurrentCoords())
        cb({ ok = true })
        return
    end

    cb({ ok = false })
end)

AddEventHandler('cw-spawn:client:spawnFinished', function()
    ResetDeathState(true)

    SetTimeout(1200, function()
        TriggerServerEvent('cw-death:server:requestRestore')
    end)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DisableSpawnManagerAutoSpawn()
        SetActionFocus(false)
        ShowUi('downed:hide')

        SetTimeout(2000, function()
            TriggerServerEvent('cw-death:server:requestRestore')
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SaveDownedState(true)
    SetActionFocus(false)
    SetInvincible(false)
    ShowUi('downed:hide')
end)

exports('IsSwitchBlocked', IsSwitchBlocked)
