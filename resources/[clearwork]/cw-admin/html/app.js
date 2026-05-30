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
    kickPlayer: 'Kick \u0438\u0433\u0440\u043e\u043a\u0430',
    banPlayer: 'Ban \u0438\u0433\u0440\u043e\u043a\u0430',
    playerAction: '\u0414\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u0441 \u0438\u0433\u0440\u043e\u043a\u043e\u043c',
    characterId: '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436 ID ',
    deleted: ' \u0443\u0434\u0430\u043b\u0451\u043d.',
    error: '\u041e\u0448\u0438\u0431\u043a\u0430.',
    done: '\u0413\u043e\u0442\u043e\u0432\u043e.'
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

function setActiveTab(tab, save) {
    if (!tab) {
        tab = 'dashboard';
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

    setNotice('');

    if (tab === 'dashboard') {
        post('dashboardLoad');
    }

    if (tab === 'characters') {
        searchCharacters();
    }

    if (tab === 'players') {
        loadPlayers();
    }
}

function renderDashboard(payload) {
    payload = payload || {};

    var admin = payload.admin || {};
    var stats = payload.stats || {};

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