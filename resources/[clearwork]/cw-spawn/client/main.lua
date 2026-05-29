local function SpawnAtCharacterPosition(character)
    local ped = PlayerPedId()

    local x = tonumber(character.pos_x) or -180.0
    local y = tonumber(character.pos_y) or 640.0
    local z = tonumber(character.pos_z) or 113.0
    local heading = tonumber(character.heading) or 90.0

    DoScreenFadeOut(500)
    Wait(800)

    RequestCollisionAtCoord(x, y, z)

    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, heading)

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)

    Wait(1000)
    DoScreenFadeIn(800)

    print(('[cw-spawn] Spawned character at %.2f %.2f %.2f'):format(x, y, z))
end

RegisterNetEvent('cw-spawn:client:spawnCharacter', function(character)
    if type(character) ~= 'table' then return end
    SpawnAtCharacterPosition(character)
end)