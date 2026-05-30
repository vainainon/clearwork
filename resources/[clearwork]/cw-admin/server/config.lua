CWAdminConfig = CWAdminConfig or {}

CWAdminConfig.Ace = {
    owner = 'clearwork.owner',
    admin = 'clearwork.admin',

    characters = 'clearwork.admin.characters',
    charactersDelete = 'clearwork.admin.characters.delete',

    players = 'clearwork.admin.players',
    playersKick = 'clearwork.admin.players.kick',
    playersTeleport = 'clearwork.admin.players.teleport',
    playersFreeze = 'clearwork.admin.players.freeze',

    tools = 'clearwork.admin.tools',
    noclip = 'clearwork.admin.tools.noclip'
}

CWAdminConfig.Roles = {
    owner = {
        label = 'Owner',
        level = 100,
        order = 1
    },

    general = {
        label = 'General Admin',
        level = 80,
        order = 2
    },

    admin = {
        label = 'Admin',
        level = 60,
        order = 3
    },

    helper = {
        label = 'Helper',
        level = 20,
        order = 4
    },

    user = {
        label = 'User',
        level = 0,
        order = 99
    }
}

CWAdminConfig.RolePermissions = {
    owner = {
        ['*'] = true
    },

    general = {
        ['*'] = true
    },

    admin = {
        ['admin.open'] = true,

        ['dashboard.view'] = true,

        ['characters.search'] = true,
        ['characters.delete'] = true,

        ['players.list'] = true,
        ['players.goto'] = true,
        ['players.bring'] = true,
        ['players.freeze'] = true,
        ['players.kick'] = true,

        ['tools.use'] = true,
        ['tools.noclip'] = true
    },

    helper = {
        ['admin.open'] = true,

        ['dashboard.view'] = true,

        ['characters.search'] = true,

        ['players.list'] = true
    },

    user = {}
}

CWAdminConfig.AceToPermission = {
    [CWAdminConfig.Ace.admin] = 'admin.open',

    [CWAdminConfig.Ace.characters] = 'characters.search',
    [CWAdminConfig.Ace.charactersDelete] = 'characters.delete',

    [CWAdminConfig.Ace.players] = 'players.list',
    [CWAdminConfig.Ace.playersKick] = 'players.kick',
    [CWAdminConfig.Ace.playersTeleport] = 'players.goto',
    [CWAdminConfig.Ace.playersFreeze] = 'players.freeze',

    [CWAdminConfig.Ace.tools] = 'tools.use',
    [CWAdminConfig.Ace.noclip] = 'tools.noclip'
}

CWAdminConfig.GrantableRoles = {
    owner = {
        general = true,
        admin = true,
        helper = true
    },

    general = {
        admin = true,
        helper = true
    },

    admin = {},
    helper = {},
    user = {}
}

CWAdminConfig.MaxCharacterSearchResults = 100
CWAdminConfig.ShowPlayerIdsDistance = 35.0