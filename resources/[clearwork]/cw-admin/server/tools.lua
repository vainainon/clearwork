local Config = CWAdminConfig

CWAdmin.ToolStates = CWAdmin.ToolStates or {}

local AllowedTools = {
    noclip = Config.Ace.noclip,
    godmode = Config.Ace.tools,
    invisible = Config.Ace.tools,
    showCoords = Config.Ace.tools,
    showIds = Config.Ace.tools
}

function CWAdmin.GetToolStates(src)
    CWAdmin.ToolStates[src] = CWAdmin.ToolStates[src] or {
        noclip = false,
        godmode = false,
        invisible = false,
        showCoords = false,
        showIds = false
    }

    return CWAdmin.ToolStates[src]
end

RegisterNetEvent('cw-admin:server:tools:toggle', function(tool)
    local src = source

    tool = tostring(tool or '')

    local ace = AllowedTools[tool]

    if not ace then
        CWAdmin.SendError(src, 'Неизвестный инструмент.')
        return
    end

    if not CWAdmin.HasPermission(src, ace) then
        CWAdmin.SendError(src, 'Нет доступа к этому инструменту.')
        return
    end

    local states = CWAdmin.GetToolStates(src)
    states[tool] = not states[tool]

    TriggerClientEvent('cw-admin:client:tools:setState', src, tool, states[tool])
    TriggerClientEvent('cw-admin:client:tools:states', src, states)

    CWAdmin.AdminLog(src, 'tool_toggle', {
        tool = tool,
        state = states[tool]
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    CWAdmin.ToolStates[src] = nil
end)