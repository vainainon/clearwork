local function FindGroundZ(x, y, z)
    local testHeights = {
        z + 50.0,
        z + 25.0,
        z + 10.0,
        z + 5.0,
        z,
        z - 5.0,
        z - 15.0
    }

    for _, height in ipairs(testHeights) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)

        if found then
            return groundZ + 1.0
        end

        Wait(50)
    end

    return z + 1.0
end

local function SpawnAtCharacterPosition(character)
    local ped = PlayerPedId()

    local x = tonumber(character.pos_x) or 1230.92
    local y = tonumber(character.pos_y) or -1298.34
    local z = tonumber(character.pos_z) or 76.90
    local heading = tonumber(character.heading) or 140.0

    DoScreenFadeOut(500)
    Wait(800)

    FreezeEntityPosition(ped, true)

    RequestCollisionAtCoord(x, y, z)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(100)
    end

    local safeZ = FindGroundZ(x, y, z)

    SetEntityCoordsNoOffset(ped, x, y, safeZ, false, false, false)
    SetEntityHeading(ped, heading)

    Wait(500)

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)

    Wait(500)
    DoScreenFadeIn(800)

    print(('[cw-spawn] Spawned character at %.2f %.2f %.2f'):format(x, y, safeZ))
end

RegisterNetEvent('cw-spawn:client:spawnCharacter', function(character)
    if type(character) ~= 'table' then return end
    SpawnAtCharacterPosition(character)
end)