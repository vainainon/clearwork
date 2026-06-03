local Config = CWCharactersConfig

local function IsDeadFlag(value)
    if CWCharacters and CWCharacters.IsDeadFlag then
        return CWCharacters.IsDeadFlag(value)
    end

    if value == true then return true end
    if value == 1 then return true end

    if type(value) == 'string' then
        local normalized = value:lower()
        return normalized == '1' or normalized == 'true' or normalized == 'yes'
    end

    return tonumber(value) == 1
end

local function IsDeathSwitchLocked(src)
    if GetResourceState('cw-death') ~= 'started' then return false end

    local ok, locked = pcall(function()
        return exports['cw-death']:IsPlayerDeathLocked(src)
    end)

    return ok and locked == true
end


local function GetAliveDownedCharacterId(accountId)
    if not accountId then return nil end
    if GetResourceState('cw-death') ~= 'started' then return nil end

    local ok, row = pcall(function()
        return MySQL.single.await([[
            SELECT id
            FROM characters
            WHERE account_id = ?
              AND (is_dead = 0 OR is_dead IS NULL)
              AND downed_state IN ('roulette', 'revive_wait')
            LIMIT 1
        ]], { accountId })
    end)

    if not ok then return nil end
    return row and tonumber(row.id) or nil
end

local function SendOpenBlocked(src)
    TriggerClientEvent(
        'cw-characters:client:openFailed',
        src,
        'Смена персонажа недоступна: текущий персонаж ранен или ждёт исход смерти.'
    )
end

RegisterNetEvent('cw-characters:server:getCharacters', function()
    local src = source
    local player = CWCharacters.GetCWPlayer(src)

    if not player then
        TriggerClientEvent('cw-characters:client:accountNotReady', src)
        return
    end

    CWCharacters.SendCharacters(src, player)
end)

RegisterNetEvent('cw-characters:server:openCharacterMenu', function(coords)
    local src = source
    local player = CWCharacters.GetCWPlayer(src)

    if not player then
        TriggerClientEvent('cw-characters:client:accountNotReady', src)
        return
    end

    -- Блокируем весь активный процесс смерти: рулетка, ожидание подъёма и ожидание смены персонажа.
    -- После финального таймера cw-death сам откроет меню персонажей через отдельную кнопку.
    if player.character and IsDeathSwitchLocked(src) then
        SendOpenBlocked(src)
        return
    end

    if player.character and type(coords) == 'table' then
        exports['cw-core']:SaveCharacterPosition(src, coords)
    end

    CWCharacters.SendCharacters(src, player)
end)

RegisterNetEvent('cw-characters:server:createCharacter', function(data)
    local src = source
    local player = CWCharacters.GetCWPlayer(src)
    if not player or type(data) ~= 'table' then return end

    local characters = CWCharacters.GetCharacters(player.account_id)

    if #characters >= (tonumber(Config.MaxCharacters) or 3) then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Максимум 3 персонажа.')
        return
    end

    local slot = CWCharacters.GetFreeSlot(characters)
    if not slot then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Нет свободного слота персонажа.')
        return
    end

    local normalized = CWCharacters.NormalizeCreateData(data)

    if normalized.firstname == '' or normalized.lastname == '' then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Имя и фамилия обязательны.')
        return
    end

    if normalized.age < 16 or normalized.age > 90 then
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Возраст должен быть от 16 до 90.')
        return
    end

    local ok, characterId = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO characters
                (account_id, slot, firstname, lastname, gender, age, cash, bank, pos_x, pos_y, pos_z, heading, skin, is_dead, revived_at)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL)
        ]], {
            player.account_id,
            slot,
            normalized.firstname,
            normalized.lastname,
            normalized.gender,
            normalized.age,
            15.00,
            0.00,
            normalized.city.x,
            normalized.city.y,
            normalized.city.z,
            normalized.city.heading,
            normalized.skin
        })
    end)

    if not ok then
        print(('[cw-characters] Create character failed for account %s: %s'):format(
            tostring(player.account_id),
            tostring(characterId)
        ))
        TriggerClientEvent('cw-characters:client:createFailed', src, 'Не удалось создать персонажа. Попробуй ещё раз.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    print(('[cw-characters] Created character %s for account %s in slot %s'):format(
        tostring(characterId),
        tostring(player.account_id),
        tostring(slot)
    ))

    TriggerClientEvent('cw-characters:client:createSuccess', src)
    CWCharacters.SendCharacters(src, player)
end)

RegisterNetEvent('cw-characters:server:requestDeleteCharacter', function(characterId)
    local src = source
    local player = CWCharacters.GetCWPlayer(src)
    if not player then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    local character = MySQL.single.await([[
        SELECT
            id,
            firstname,
            lastname,
            created_at,
            delete_requested_at,
            is_dead,
            TIMESTAMPDIFF(DAY, created_at, NOW()) AS age_days
        FROM characters
        WHERE id = ? AND account_id = ?
        LIMIT 1
    ]], { characterId, player.account_id })

    if not character then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Персонаж не найден.')
        return
    end

    local isDead = IsDeadFlag(character.is_dead)
    local isCurrent = player.character and tonumber(player.character.id) == characterId

    if isCurrent and not isDead then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Нельзя поставить на удаление персонажа, за которого ты сейчас играешь.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    if character.delete_requested_at then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Персонаж уже поставлен на удаление.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    if not isDead and tonumber(character.age_days or 0) < (tonumber(Config.DeleteAllowedAfterDays) or 7) then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Персонажа можно удалить только через 7 дней после создания.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    MySQL.update.await(
        'UPDATE characters SET delete_requested_at = NOW() WHERE id = ? AND account_id = ?',
        { characterId, player.account_id }
    )

    if isCurrent and isDead then
        exports['cw-core']:ClearCharacter(src)
        player.character = nil
    end

    print(('[cw-characters] Delete requested for character %s by account %s'):format(
        tostring(characterId),
        tostring(player.account_id)
    ))

    CWCharacters.SendCharacters(src, player)
end)

RegisterNetEvent('cw-characters:server:cancelDeleteCharacter', function(characterId)
    local src = source
    local player = CWCharacters.GetCWPlayer(src)
    if not player then return end

    characterId = tonumber(characterId)
    if not characterId then return end

    local character = MySQL.single.await([[
        SELECT
            id,
            delete_requested_at,
            TIMESTAMPDIFF(MINUTE, delete_requested_at, NOW()) AS delete_minutes_passed
        FROM characters
        WHERE id = ? AND account_id = ?
        LIMIT 1
    ]], { characterId, player.account_id })

    if not character or not character.delete_requested_at then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Удаление не запрошено.')
        return
    end

    if tonumber(character.delete_minutes_passed or 0) > (tonumber(Config.DeleteCancelMinutes) or 60) then
        TriggerClientEvent('cw-characters:client:deleteFailed', src, 'Отменить удаление можно только в первый час.')
        return
    end

    MySQL.update.await(
        'UPDATE characters SET delete_requested_at = NULL WHERE id = ? AND account_id = ?',
        { characterId, player.account_id }
    )

    print(('[cw-characters] Delete cancelled for character %s by account %s'):format(
        tostring(characterId),
        tostring(player.account_id)
    ))

    CWCharacters.SendCharacters(src, player)
end)

RegisterNetEvent('cw-characters:server:selectCharacter', function(payload)
    local src = source
    local player = CWCharacters.GetCWPlayer(src)
    if not player then return end

    local characterId = nil
    local currentPosition = nil

    if type(payload) == 'table' then
        characterId = tonumber(payload.id)
        currentPosition = payload.currentPosition
    else
        characterId = tonumber(payload)
    end

    if not characterId then return end

    local downedCharacterId = GetAliveDownedCharacterId(player.account_id)
    if downedCharacterId and downedCharacterId ~= characterId then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'У тебя есть раненый персонаж. Сначала вернись на него и дождись исхода нокдауна.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    -- Во время активного процесса смерти переключаться нельзя.
    -- Если выпал пермакилл, меню откроется только после пятиминутного таймера через кнопку cw-death.
    if player.character and IsDeathSwitchLocked(src) then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Смена персонажа недоступна: текущий персонаж ранен или ждёт исход смерти.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    local character = MySQL.single.await(
        'SELECT * FROM characters WHERE id = ? AND account_id = ? LIMIT 1',
        { characterId, player.account_id }
    )

    if not character then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Персонаж не найден.')
        return
    end

    local selectedIsDead = IsDeadFlag(character.is_dead)
    character.is_dead = selectedIsDead and 1 or 0

    -- Проверка мёртвого персонажа должна быть раньше проверки "это уже текущий".
    -- Иначе текущий убитый персонаж визуально выглядит как выбранный и его можно снова открыть.
    if selectedIsDead then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Персонаж убит. Его нельзя выбрать, пока администрация не снимет пермакилл.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    if character.delete_requested_at then
        TriggerClientEvent('cw-characters:client:selectFailed', src, 'Персонаж ожидает удаления.')
        CWCharacters.SendCharacters(src, player)
        return
    end

    if player.character and tonumber(player.character.id) == characterId then
        CWCharacters.SendCharacters(src, player)
        return
    end

    if player.character and type(currentPosition) == 'table' then
        exports['cw-core']:SaveCharacterPosition(src, currentPosition)
    end

    if character.revived_at ~= nil then
        MySQL.update.await(
            'UPDATE characters SET revived_at = NULL WHERE id = ? AND account_id = ?',
            { characterId, player.account_id }
        )
        character.revived_at = nil
        character.was_revived = false
    end

    exports['cw-core']:SetCharacter(src, character)

    print(('[cw-characters] Selected character %s %s for %s at %.2f %.2f %.2f'):format(
        tostring(character.firstname),
        tostring(character.lastname),
        tostring(player.name),
        tonumber(character.pos_x) or 0.0,
        tonumber(character.pos_y) or 0.0,
        tonumber(character.pos_z) or 0.0
    ))

    TriggerClientEvent('cw-characters:client:characterSelected', src, character)
end)

RegisterNetEvent('cw-characters:server:clearSelectedCharacter', function()
    local src = source
    local player = CWCharacters.GetCWPlayer(src)
    if not player then return end

    exports['cw-core']:ClearCharacter(src)
    print(('[cw-characters] Cleared selected character for %s'):format(tostring(player.name)))
end)
