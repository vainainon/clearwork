CW = CW or {}

local function NormalizeCoords(coords)
    if type(coords) ~= 'table' then
        return nil
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    if not x or not y or not z then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
        heading = tonumber(coords.heading) or tonumber(coords.h) or 0.0
    }
end

function CW.SetCharacter(src, character)
    src = tonumber(src)
    local player = src and CW.GetPlayer(src) or nil

    if not player or type(character) ~= 'table' then
        return false
    end

    player.character = character
    return true
end

function CW.ClearCharacter(src)
    src = tonumber(src)
    local player = src and CW.GetPlayer(src) or nil

    if not player then
        return false
    end

    player.character = nil
    return true
end

function CW.GetCharacter(src)
    local player = CW.GetPlayer(src)
    return player and player.character or nil
end

function CW.SaveCharacterPosition(src, coords)
    src = tonumber(src)
    local player = src and CW.GetPlayer(src) or nil
    local position = NormalizeCoords(coords)

    if not player or not player.character or not position then
        return false
    end

    local characterId = tonumber(player.character.id)
    local accountId = tonumber(player.account_id)

    if not characterId or not accountId then
        return false
    end

    MySQL.update.await([[
        UPDATE characters
        SET pos_x = ?, pos_y = ?, pos_z = ?, heading = ?
        WHERE id = ? AND account_id = ?
    ]], {
        position.x,
        position.y,
        position.z,
        position.heading,
        characterId,
        accountId
    })

    player.character.pos_x = position.x
    player.character.pos_y = position.y
    player.character.pos_z = position.z
    player.character.heading = position.heading

    return true
end

RegisterNetEvent('cw-core:server:updateCharacterPosition', function(coords)
    CW.SaveCharacterPosition(source, coords)
end)

RegisterNetEvent('cw-core:server:saveCurrentPosition', function(coords)
    CW.SaveCharacterPosition(source, coords)
end)

exports('SetCharacter', CW.SetCharacter)
exports('ClearCharacter', CW.ClearCharacter)
exports('GetCharacter', CW.GetCharacter)
exports('SaveCharacterPosition', CW.SaveCharacterPosition)
