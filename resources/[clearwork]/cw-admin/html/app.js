function $(id) {
    return document.getElementById(id);
}

var app = $('app');
var closeBtn = $('closeBtn');
var notice = $('notice');

var tabButtons = document.querySelectorAll('.tab-btn');
var tabViews = document.querySelectorAll('.tab-view');

var dashboardAdmin = $('dashboardAdmin');
var dashboardOnline = $('dashboardOnline');
var dashboardActiveCharacters = $('dashboardActiveCharacters');
var dashboardTotalCharacters = $('dashboardTotalCharacters');

var searchInput = $('searchInput');
var searchBtn = $('searchBtn');
var characterList = $('characterList');

var refreshPlayersBtn = $('refreshPlayersBtn');
var playerList = $('playerList');

var managementPlayer = $('managementPlayer');
var managementIdentifier = $('managementIdentifier');
var managementName = $('managementName');
var managementRole = $('managementRole');
var managementSetRoleBtn = $('managementSetRoleBtn');
var managementRefreshBtn = $('managementRefreshBtn');
var adminList = $('adminList');

var modal = $('confirmModal');
var confirmText = $('confirmText');
var confirmYes = $('confirmYes');
var confirmNo = $('confirmNo');

var actionModal = $('actionModal');
var actionModalTitle = $('actionModalTitle');
var actionModalText = $('actionModalText');
var actionReason = $('actionReason');
var actionConfirm = $('actionConfirm');
var actionCancel = $('actionCancel');

var pendingDeleteId = null;
var pendingPlayerAction = null;
var canUseManagement = false;

var LAST_TAB_KEY = 'cw-admin:last-tab';

var RU = {
    charactersNotFound: '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0438 \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u044b.',
    deleteStatus: '\u0423\u0434\u0430\u043b\u0435\u043d\u0438\u0435',
    deleteRequested: '\u041f\u043e\u0441\u0442\u0430\u0432\u043b\u0435\u043d \u043d\u0430 \u0443\u0434\u0430\u043b\u0435\u043d\u0438\u0435',
    active: '\u0410\u043a\u0442\u0438\u0432\u0435\u043d',
    nowPlaying: '\u0421\u0435\u0439\u0447\u0430\u0441 \u0438\u0433\u0440\u0430\u0435\u0442: ',
    selectedNow: '\u0421\u0435\u0439\u0447\u0430\u0441 \u0432\u044b\u0431\u0440\u0430\u043d \u0432 \u0438\u0433\u0440\u0435',
    notSelected: '\u041d\u0435 \u0432\u044b\u0431\u0440\u0430\u043d',
    characterNotSelected: '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436 \u043d\u0435 \u0432\u044b\u0431\u0440\u0430\u043d \u0441\u0435\u0439\u0447\u0430\u0441',
    cannotDeleteActive: '\u041d\u0435\u043b\u044c\u0437\u044f \u0443\u0434\u0430\u043b\u0438\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430, \u043a\u043e\u0442\u043e\u0440\u044b\u0439 \u0441\u0435\u0439\u0447\u0430\u0441 \u0430\u043a\u0442\u0438\u0432\u0435\u043d \u0432 \u0438\u0433\u0440\u0435',
    deleteCharacter: '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430',
    account: '\u0410\u043a\u043a\u0430\u0443\u043d\u0442',
    gender: '\u041f\u043e\u043b',
    age: '\u0412\u043e\u0437\u0440\u0430\u0441\u0442',
    status: '\u0421\u0442\u0430\u0442\u0443\u0441',
    playersNotFound: '\u041e\u043d\u043b\u0430\u0439\u043d-\u0438\u0433\u0440\u043e\u043a\u0438 \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u044b.',
    character: '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436',
    rights: '\u041f\u0440\u0430\u0432\u0430',
    kickPlayer: 'Kick \u0438\u0433\u0440\u043e\u043a\u0430',
    banPlayer: 'Ban \u0438\u0433\u0440\u043e\u043a\u0430',
    playerAction: '\u0414\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u0441 \u0438\u0433\u0440\u043e\u043a\u043e\u043c',
    characterId: '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436 ID ',
    deleted: ' \u0443\u0434\u0430\u043b\u0451\u043d.',
    error: '\u041e\u0448\u0438\u0431\u043a\u0430.',
    done: '\u0413\u043e\u0442\u043e\u0432\u043e.',
    noManagementAccess: '\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430 \u043a \u0443\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u044e.',
    chooseOnlinePlayer: '\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u043e\u043d\u043b\u0430\u0439\u043d-\u0438\u0433\u0440\u043e\u043a\u0430',
    adminsNotFound: '\u0410\u0434\u043c\u0438\u043d\u0438\u0441\u0442\u0440\u0430\u0442\u043e\u0440\u044b \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u044b.',
    role: '\u0420\u043e\u043b\u044c',
    grantedBy: '\u0412\u044b\u0434\u0430\u043b',
    removeRights: '\u0421\u043d\u044f\u0442\u044c \u043f\u0440\u0430\u0432\u0430'
};

var State = {
    activeTab: localStorage.getItem(LAST_TAB_KEY) || 'dashboard',
    characters: [],
    players: [],
    tools: {
        noclip: false,
        godmode: false,
        invisible: false,
        showCoords: false,
        showIds: false
    },
    management: {
        admins: [],
        onlinePlayers: [],
        grantableRoles: []
    }
};

function post(name, data) {
    data = data || {};

    return fetch('https://' + GetParentResourceName() + '/' + name, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    });
}

function escapeHtml(value) {
    return String(value === null || value === undefined ? '' : value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function money(value) {
    var number = Number(value);

    if (isNaN(number)) {
        return escapeHtml(value || '0.00');
    }

    return number.toFixed(2);
}

function getCoords(player) {
    if (!player || !player.coords) {
        return {
            x: 0,
            y: 0,
            z: 0,
            heading: 0
        };
    }

    return {
        x: Number(player.coords.x || 0),
        y: Number(player.coords.y || 0),
        z: Number(player.coords.z || 0),
        heading: Number(player.coords.heading || 0)
    };
}

function setNotice(message, type) {
    if (!notice) {
        return;
    }

    notice.textContent = message || '';
    notice.className = type || '';
}

function getRoleClass(role) {
    if (role === 'owner') {
        return 'role-owner';
    }

    if (role === 'general') {
        return 'role-general';
    }

    if (role === 'admin') {
        return 'role-admin';
    }

    if (role === 'helper') {
        return 'role-helper';
    }

    return 'role-user';
}

function updateManagementTabVisibility(admin) {
    admin = admin || {};

    canUseManagement = admin.role === 'owner' || admin.role === 'general';

    Array.prototype.forEach.call(tabButtons, function (button) {
        if (button.dataset.tab === 'management') {
            button.classList.toggle('hidden', !canUseManagement);
        }
    });
}

function setActiveTab(tab, save) {
    if (!tab) {
        tab = 'dashboard';
    }

    if (tab === 'management' && !canUseManagement) {
        tab = 'dashboard';
        setNotice(RU.noManagementAccess, 'error');
    }

    if (save !== false) {
        localStorage.setItem(LAST_TAB_KEY, tab);
    }

    State.activeTab = tab;

    Array.prototype.forEach.call(tabButtons, function (button) {
        button.classList.toggle('active', button.dataset.tab === tab);
    });

    Array.prototype.forEach.call(tabViews, function (view) {
        view.classList.toggle('active', view.id === 'view-' + tab);
    });

    if (tab !== 'dashboard') {
        setNotice('');
    }

    if (tab === 'dashboard') {
        post('dashboardLoad');
    }

    if (tab === 'characters') {
        searchCharacters();
    }

    if (tab === 'players') {
        loadPlayers();
    }

    if (tab === 'management') {
        loadManagement();
    }
}

function renderDashboard(payload) {
    payload = payload || {};

    var admin = payload.admin || {};
    var stats = payload.stats || {};

    updateManagementTabVisibility(admin);

    if (dashboardAdmin) {
        dashboardAdmin.textContent = admin.name || '-';
    }

    if (dashboardOnline) {
        dashboardOnline.textContent = stats.onlinePlayers || 0;
    }

    if (dashboardActiveCharacters) {
        dashboardActiveCharacters.textContent = stats.activeCharacters || 0;
    }

    if (dashboardTotalCharacters) {
        dashboardTotalCharacters.textContent = stats.totalCharacters || 0;
    }

    if (payload.tools) {
        State.tools = Object.assign({}, State.tools, payload.tools);
        renderTools();
    }
}

function renderTools() {
    var toolButtons = document.querySelectorAll('[data-tool]');

    Array.prototype.forEach.call(toolButtons, function (button) {
        var tool = button.dataset.tool;
        var state = State.tools[tool] === true;

        var labels = {
            noclip: 'Noclip',
            godmode: 'Godmode',
            invisible: 'Invisible',
            showCoords: 'Coords',
            showIds: 'Player IDs'
        };

        button.classList.toggle('active', state);
        button.textContent = (labels[tool] || tool) + ': ' + (state ? 'ON' : 'OFF');
    });
}

function getCharacterStatus(character) {
    if (character.delete_requested_at) {
        return {
            text: RU.deleteStatus,
            className: 'danger',
            description: RU.deleteRequested
        };
    }

    if (character.active_character) {
        return {
            text: RU.active,
            className: 'ok',
            description: character.active_player_name
                ? RU.nowPlaying + character.active_player_name
                : RU.selectedNow
        };
    }

    return {
        text: RU.notSelected,
        className: '',
        description: RU.characterNotSelected
    };
}

function openConfirm(character) {
    pendingDeleteId = character.id;

    if (confirmText) {
        confirmText.textContent = character.firstname + ' ' + character.lastname + ' | ID: ' + character.id;
    }

    if (modal) {
        modal.classList.remove('hidden');
    }
}

function closeConfirm() {
    pendingDeleteId = null;

    if (modal) {
        modal.classList.add('hidden');
    }
}

function openPlayerActionModal(action, player) {
    pendingPlayerAction = {
        action: action,
        target: Number(player.source)
    };

    var actionNames = {
        kick: RU.kickPlayer,
        ban: RU.banPlayer
    };

    if (actionModalTitle) {
        actionModalTitle.textContent = actionNames[action] || RU.playerAction;
    }

    if (actionModalText) {
        actionModalText.textContent = '[' + player.source + '] ' + player.name;
    }

    if (actionReason) {
        actionReason.value = action === 'kick' ? 'Kicked by admin' : '';
        actionReason.focus();
    }

    if (actionModal) {
        actionModal.classList.remove('hidden');
    }
}

function closePlayerActionModal() {
    pendingPlayerAction = null;

    if (actionModal) {
        actionModal.classList.add('hidden');
    }
}

function renderCharacters(characters) {
    State.characters = characters || [];

    if (!characterList) {
        return;
    }

    characterList.innerHTML = '';

    if (!State.characters.length) {
        characterList.innerHTML = '<div class="empty">' + RU.charactersNotFound + '</div>';
        return;
    }

    State.characters.forEach(function (character) {
        var status = getCharacterStatus(character);

        var card = document.createElement('div');
        card.className = 'character-card';

        var deleteDisabled = character.active_character ? 'disabled' : '';
        var deleteTitle = character.active_character ? RU.cannotDeleteActive : RU.deleteCharacter;

        card.innerHTML =
            '<div class="card-main">' +
            '<h3>' + escapeHtml(character.firstname) + ' ' + escapeHtml(character.lastname) + '</h3>' +
            '<span class="status ' + status.className + '" title="' + escapeHtml(status.description) + '">' +
            escapeHtml(status.text) +
            '</span>' +
            '</div>' +

            '<div class="grid">' +
            '<p><b>Character ID:</b> ' + escapeHtml(character.id) + '</p>' +
            '<p><b>Account ID:</b> ' + escapeHtml(character.account_id) + '</p>' +

            '<p><b>' + RU.account + ':</b> ' + escapeHtml(character.account_name || 'unknown') + '</p>' +
            '<p><b>Slot:</b> ' + escapeHtml(character.slot) + '</p>' +

            '<p><b>' + RU.gender + ':</b> ' + escapeHtml(character.gender) + '</p>' +
            '<p><b>' + RU.age + ':</b> ' + escapeHtml(character.age) + '</p>' +

            '<p><b>Cash:</b> $' + money(character.cash) + '</p>' +
            '<p><b>Bank:</b> $' + money(character.bank) + '</p>' +

            '<p><b>License:</b> ' + escapeHtml(character.license || '-') + '</p>' +
            '<p><b>Discord:</b> ' + escapeHtml(character.discord || '-') + '</p>' +

            '<p><b>Created:</b> ' + escapeHtml(character.created_at || '-') + '</p>' +
            '<p><b>' + RU.status + ':</b> ' + escapeHtml(status.description) + '</p>' +
            '</div>' +

            '<button class="delete-btn" type="button" ' + deleteDisabled + ' title="' + escapeHtml(deleteTitle) + '">' +
            RU.deleteCharacter +
            '</button>';

        var deleteBtn = card.querySelector('.delete-btn');

        if (deleteBtn && !character.active_character) {
            deleteBtn.addEventListener('click', function () {
                openConfirm(character);
            });
        }

        characterList.appendChild(card);
    });
}

function renderPlayers(players) {
    State.players = players || [];

    if (!playerList) {
        return;
    }

    playerList.innerHTML = '';

    if (!State.players.length) {
        playerList.innerHTML = '<div class="empty">' + RU.playersNotFound + '</div>';
        return;
    }

    State.players.forEach(function (player) {
        var character = player.character;
        var characterName = character
            ? String((character.firstname || '') + ' ' + (character.lastname || '')).trim()
            : RU.notSelected;

        var coords = getCoords(player);

        var roleLabel = player.role_label || 'User';
        var roleClass = getRoleClass(player.role);

        var card = document.createElement('div');
        card.className = 'player-card';

        card.innerHTML =
            '<div class="card-main">' +
            '<h3>[' + escapeHtml(player.source) + '] ' + escapeHtml(player.name) + '</h3>' +
            '<span class="status ' + (player.frozen ? 'warn' : 'ok') + '">' +
            (player.frozen ? 'Frozen' : 'Online') +
            '</span>' +
            '</div>' +

            '<div class="grid">' +
            '<p><b>Account:</b> ' + escapeHtml(player.account_name || '-') + '</p>' +
            '<p><b>Account ID:</b> ' + escapeHtml(player.account_id || '-') + '</p>' +

            '<p><b>' + RU.character + ':</b> ' + escapeHtml(characterName) + '</p>' +
            '<p><b>Ping:</b> ' + escapeHtml(player.ping) + '</p>' +

            '<p><b>' + RU.rights + ':</b> <span class="' + roleClass + '">' + escapeHtml(roleLabel) + '</span></p>' +
            '<p><b>Identifier:</b> ' + escapeHtml(player.role_identifier || '-') + '</p>' +

            '<p><b>X:</b> ' + coords.x.toFixed(2) + '</p>' +
            '<p><b>Y:</b> ' + coords.y.toFixed(2) + '</p>' +

            '<p><b>Z:</b> ' + coords.z.toFixed(2) + '</p>' +
            '<p><b>H:</b> ' + coords.heading.toFixed(2) + '</p>' +
            '</div>' +

            '<div class="player-actions">' +
            '<button type="button" data-player-action="goto" data-target="' + escapeHtml(player.source) + '">Goto</button>' +
            '<button type="button" data-player-action="bring" data-target="' + escapeHtml(player.source) + '">Bring</button>' +
            '<button type="button" data-player-action="freeze" data-target="' + escapeHtml(player.source) + '">Freeze</button>' +
            '<button type="button" data-player-action="kick" data-target="' + escapeHtml(player.source) + '">Kick</button>' +
            '</div>';

        Array.prototype.forEach.call(card.querySelectorAll('[data-player-action]'), function (button) {
            button.addEventListener('click', function () {
                var action = button.dataset.playerAction;
                var target = Number(button.dataset.target);

                if (action === 'kick' || action === 'ban') {
                    openPlayerActionModal(action, player);
                    return;
                }

                post('playersAction', {
                    action: action,
                    target: target
                });

                setTimeout(loadPlayers, 350);
            });
        });

        playerList.appendChild(card);
    });
}

function renderManagement(payload) {
    payload = payload || {};

    State.management = {
        admins: payload.admins || [],
        onlinePlayers: payload.onlinePlayers || [],
        grantableRoles: payload.grantableRoles || []
    };

    if (managementPlayer) {
        managementPlayer.innerHTML = '<option value="">' + RU.chooseOnlinePlayer + '</option>';

        State.management.onlinePlayers.forEach(function (player) {
            var label = '[' + player.source + '] ' + player.name + ' | ' + (player.role_label || 'User');

            var option = document.createElement('option');
            option.value = String(player.source);
            option.textContent = label;
            option.dataset.identifier = player.role_identifier || '';
            option.dataset.name = player.name || '';

            managementPlayer.appendChild(option);
        });
    }

    if (managementRole) {
        managementRole.innerHTML = '';

        State.management.grantableRoles.forEach(function (role) {
            var option = document.createElement('option');
            option.value = role.role;
            option.textContent = role.label;

            managementRole.appendChild(option);
        });
    }

    if (!adminList) {
        return;
    }

    adminList.innerHTML = '';

    if (!State.management.admins.length) {
        adminList.innerHTML = '<div class="empty">' + RU.adminsNotFound + '</div>';
        return;
    }

    State.management.admins.forEach(function (admin) {
        var roleClass = getRoleClass(admin.role);

        var onlineText = admin.online
            ? 'Online' + (admin.source ? ' | ID: ' + admin.source : '')
            : 'Offline';

        var card = document.createElement('div');
        card.className = 'admin-card';

        card.innerHTML =
            '<div class="card-main">' +
            '<h3>' + escapeHtml(admin.name || admin.online_name || admin.identifier || '-') + '</h3>' +
            '<span class="status ' + (admin.online ? 'ok' : '') + '">' + escapeHtml(onlineText) + '</span>' +
            '</div>' +

            '<div class="grid">' +
            '<p><b>' + RU.role + ':</b> <span class="' + roleClass + '">' + escapeHtml(admin.role_label || admin.role) + '</span></p>' +
            '<p><b>Source:</b> ' + escapeHtml(admin.source || '-') + '</p>' +

            '<p><b>Identifier:</b> ' + escapeHtml(admin.identifier || '-') + '</p>' +
            '<p><b>' + RU.grantedBy + ':</b> ' + escapeHtml(admin.added_by_name || '-') + '</p>' +

            '<p><b>Created:</b> ' + escapeHtml(admin.created_at || '-') + '</p>' +
            '<p><b>Updated:</b> ' + escapeHtml(admin.updated_at || '-') + '</p>' +
            '</div>';

        if (admin.can_remove) {
            card.innerHTML +=
                '<div class="admin-actions">' +
                '<button type="button" data-remove-admin="' + escapeHtml(admin.identifier) + '">' +
                RU.removeRights +
                '</button>' +
                '</div>';
        }

        var removeBtn = card.querySelector('[data-remove-admin]');

        if (removeBtn) {
            removeBtn.addEventListener('click', function () {
                post('managementRemoveRole', {
                    identifier: removeBtn.dataset.removeAdmin
                });

                setTimeout(loadManagement, 500);
            });
        }

        adminList.appendChild(card);
    });
}

function searchCharacters() {
    setNotice('');

    post('charactersSearch', {
        query: searchInput ? searchInput.value : ''
    });
}

function loadPlayers() {
    setNotice('');
    post('playersList');
}

function loadManagement() {
    setNotice('');
    post('managementLoad');
}

if (closeBtn) {
    closeBtn.addEventListener('click', function () {
        post('closeMenu');
    });
}

if (searchBtn) {
    searchBtn.addEventListener('click', searchCharacters);
}

if (searchInput) {
    searchInput.addEventListener('keydown', function (event) {
        if (event.key === 'Enter') {
            searchCharacters();
        }
    });
}

if (refreshPlayersBtn) {
    refreshPlayersBtn.addEventListener('click', loadPlayers);
}

if (managementPlayer) {
    managementPlayer.addEventListener('change', function () {
        var selected = managementPlayer.options[managementPlayer.selectedIndex];

        if (!selected || !selected.value) {
            return;
        }

        if (managementIdentifier) {
            managementIdentifier.value = selected.dataset.identifier || '';
        }

        if (managementName) {
            managementName.value = selected.dataset.name || '';
        }
    });
}

if (managementSetRoleBtn) {
    managementSetRoleBtn.addEventListener('click', function () {
        post('managementSetRole', {
            source: managementPlayer && managementPlayer.value ? Number(managementPlayer.value) : null,
            identifier: managementIdentifier ? managementIdentifier.value : '',
            name: managementName ? managementName.value : '',
            role: managementRole ? managementRole.value : ''
        });

        setTimeout(loadManagement, 500);
    });
}

if (managementRefreshBtn) {
    managementRefreshBtn.addEventListener('click', loadManagement);
}

if (confirmYes) {
    confirmYes.addEventListener('click', function () {
        if (pendingDeleteId) {
            post('charactersDelete', {
                id: pendingDeleteId
            });
        }

        closeConfirm();
    });
}

if (confirmNo) {
    confirmNo.addEventListener('click', closeConfirm);
}

if (actionConfirm) {
    actionConfirm.addEventListener('click', function () {
        if (!pendingPlayerAction) {
            closePlayerActionModal();
            return;
        }

        var reason = actionReason && actionReason.value.trim()
            ? actionReason.value.trim()
            : 'Kicked by admin';

        post('playersAction', {
            action: pendingPlayerAction.action,
            target: pendingPlayerAction.target,
            payload: {
                reason: reason
            }
        });

        closePlayerActionModal();
        setTimeout(loadPlayers, 500);
    });
}

if (actionCancel) {
    actionCancel.addEventListener('click', closePlayerActionModal);
}

Array.prototype.forEach.call(tabButtons, function (button) {
    button.addEventListener('click', function () {
        setActiveTab(button.dataset.tab);
    });
});

Array.prototype.forEach.call(document.querySelectorAll('[data-tool]'), function (button) {
    button.addEventListener('click', function () {
        post('toolsToggle', {
            tool: button.dataset.tool
        });
    });
});

document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') {
        if (actionModal && !actionModal.classList.contains('hidden')) {
            closePlayerActionModal();
            return;
        }

        if (modal && !modal.classList.contains('hidden')) {
            closeConfirm();
            return;
        }

        post('closeMenu');
    }
});

window.addEventListener('message', function (event) {
    var data = event.data || {};

    if (data.action === 'ui:open') {
        if (app) {
            app.classList.remove('hidden');
        }

        setNotice('');
        return;
    }

    if (data.action === 'ui:close') {
        if (app) {
            app.classList.add('hidden');
        }

        closeConfirm();
        closePlayerActionModal();
        return;
    }

    if (data.action === 'panel:open') {
        if (app) {
            app.classList.remove('hidden');
        }

        renderDashboard(data.payload || {});

        var savedTab = localStorage.getItem(LAST_TAB_KEY) || State.activeTab || 'dashboard';

        if (savedTab === 'management' && !canUseManagement) {
            savedTab = 'dashboard';
        }

        setActiveTab(savedTab, false);
        return;
    }

    if (data.action === 'dashboard:set') {
        renderDashboard(data.payload || {});
        return;
    }

    if (data.action === 'characters:set') {
        renderCharacters(data.characters || []);
        return;
    }

    if (data.action === 'characters:deleted') {
        setNotice(RU.characterId + data.id + RU.deleted, 'success');
        return;
    }

    if (data.action === 'players:set') {
        renderPlayers(data.players || []);
        return;
    }

    if (data.action === 'management:set') {
        renderManagement(data.payload || {});
        return;
    }

    if (data.action === 'tools:set') {
        State.tools = Object.assign({}, State.tools, data.tools || {});
        renderTools();
        return;
    }

    if (data.action === 'tools:updateOne') {
        State.tools[data.tool] = data.state === true;
        renderTools();
        return;
    }

    if (data.action === 'error') {
        setNotice(data.message || RU.error, 'error');
        return;
    }

    if (data.action === 'success') {
        setNotice(data.message || RU.done, 'success');
    }
});