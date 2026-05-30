local ToolStates = {
    noclip = false,
    godmode = false,
    invisible = false,
    showCoords = false,
    showIds = false
}

local NoclipSpeed = 1.2
local FastNoclipSpeed = 5.0
local SlowNoclipSpeed = 0.35

local Controls = {
    forward = 0x8FD015D8,
    back = 0xD27782E3,
    left = 0x7065027D,
    right = 0xB4E465B4,
    sprint = 0x8FFC75D6,
    jump = 0xD9D0E1C0,
    crouch = 0xDB096B85
}

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))

    return vector3(
        -math.sin(z) * num,
        math.cos(z) * num,
        math.sin(x)
    )
end

local function DrawScreenText(text, x, y, scale)
    SetTextScale(scale or 0.35, scale or 0.35)
    SetTextColor(255, 255, 255, 220)
    SetTextCentre(true)

    local str = CreateVarString(10, 'LITERAL_STRING', text)
    DisplayText(str, x, y)
end

local function DrawWorldText(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawScreenText(text, 0.0, 0.0, 0.28)
    ClearDrawOrigin()
end

local function ApplyNoclipState(state)
    local ped = PlayerPedId()

    FreezeEntityPosition(ped, state)
    SetEntityCollision(ped, not state, not state)

    if state then
        SetEntityInvincible(ped, true)
    elseif not ToolStates.godmode then
        SetEntityInvincible(ped, false)
    end
end

local function ApplyGodmodeState(state)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, state or ToolStates.noclip)
end

local function ApplyInvisibleState(state)
    local ped = PlayerPedId()

    SetEntityVisible(ped, not state, false)
    SetEntityAlpha(ped, state and 90 or 255, false)
end

local function SetToolState(tool, state)
    state = state == true
    ToolStates[tool] = state

    if tool == 'noclip' then
        ApplyNoclipState(state)
    elseif tool == 'godmode' then
        ApplyGodmodeState(state)
    elseif tool == 'invisible' then
        ApplyInvisibleState(state)
    end

    SendNUIMessage({
        action = 'tools:updateOne',
        tool = tool,
        state = state
    })
end

RegisterNetEvent('cw-admin:client:tools:setState', function(tool, state)
    SetToolState(tool, state)
end)

RegisterNetEvent('cw-admin:client:tools:states', function(states)
    states = states or {}

    for tool, state in pairs(states) do
        ToolStates[tool] = state == true
    end

    SendNUIMessage({
        action = 'tools:set',
        tools = ToolStates
    })
end)

RegisterNetEvent('cw-admin:client:teleportToCoords', function(coords)
    if type(coords) ~= 'table' then
        return
    end

    local ped = PlayerPedId()

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    SetEntityCoordsNoOffset(
        ped,
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        tonumber(coords.z) or 0.0,
        false,
        false,
        false
    )

    if coords.heading then
        SetEntityHeading(ped, tonumber(coords.heading) or 0.0)
    end
end)

RegisterNetEvent('cw-admin:client:setFrozen', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state == true)
end)

CreateThread(function()
    while true do
        if ToolStates.noclip then
            Wait(0)

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local camRot = GetGameplayCamRot(2)
            local forward = RotationToDirection(camRot)
            local right = vector3(forward.y, -forward.x, 0.0)

            local speed = NoclipSpeed

            if IsControlPressed(0, Controls.sprint) then
                speed = FastNoclipSpeed
            end

            if IsControlPressed(0, Controls.crouch) then
                speed = SlowNoclipSpeed
            end

            local newCoords = coords

            if IsControlPressed(0, Controls.forward) then
                newCoords = newCoords + forward * speed
            end

            if IsControlPressed(0, Controls.back) then
                newCoords = newCoords - forward * speed
            end

            if IsControlPressed(0, Controls.right) then
                newCoords = newCoords + right * speed
            end

            if IsControlPressed(0, Controls.left) then
                newCoords = newCoords - right * speed
            end

            if IsControlPressed(0, Controls.jump) then
                newCoords = newCoords + vector3(0.0, 0.0, speed)
            end

            SetEntityCoordsNoOffset(ped, newCoords.x, newCoords.y, newCoords.z, true, true, true)
            SetEntityHeading(ped, camRot.z)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if ToolStates.showCoords then
            Wait(0)

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            DrawScreenText(
                ('X: %.2f | Y: %.2f | Z: %.2f | H: %.2f'):format(coords.x, coords.y, coords.z, heading),
                0.5,
                0.92,
                0.32
            )
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if ToolStates.showIds then
            Wait(0)

            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)

            for _, player in ipairs(GetActivePlayers()) do
                local targetPed = GetPlayerPed(player)

                if targetPed and targetPed ~= 0 then
                    local targetCoords = GetEntityCoords(targetPed)
                    local distance = #(myCoords - targetCoords)

                    if distance <= 35.0 then
                        local serverId = GetPlayerServerId(player)
                        local name = GetPlayerName(player) or 'unknown'

                        DrawWorldText(
                            vector3(targetCoords.x, targetCoords.y, targetCoords.z + 1.15),
                            ('[%s] %s'):format(serverId, name)
                        )
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local ped = PlayerPedId()

    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
end)