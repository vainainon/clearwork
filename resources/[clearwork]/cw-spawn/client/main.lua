local function GetSpawnCoords(character)
    return {
        x = tonumber(character.pos_x) or 1230.92,
        y = tonumber(character.pos_y) or -1298.34,
        z = tonumber(character.pos_z) or 76.90,
        heading = tonumber(character.heading) or 140.0
    }
end

local function SpawnAtCharacterPosition(character)
    if type(character) ~= 'table' then return end

    local spawn = GetSpawnCoords(character)

    DoScreenFadeOut(500)
    Wait(800)

    exports.spawnmanager:spawnPlayer({
        x = spawn.x,
        y = spawn.y,
        z = spawn.z,
        heading = spawn.heading,
        model = `mp_male`,
        skipFade = true
    }, function()
        local ped = PlayerPedId()

        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        SetEntityAlpha(ped, 255, false)
        SetEntityCollision(ped, true, true)
        ClearPedTasksImmediately(ped)

        Wait(1000)
        DoScreenFadeIn(800)

        TriggerEvent('cw-spawn:client:spawnFinished')

        print(('[cw-spawn] Spawned with spawnmanager at %.2f %.2f %.2f heading %.2f'):format(
            spawn.x,
            spawn.y,
            spawn.z,
            spawn.heading
        ))
    end)
end

RegisterNetEvent('cw-spawn:client:spawnCharacter', function(character)
    SpawnAtCharacterPosition(character)
end)