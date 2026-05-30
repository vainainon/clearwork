function $(id) {
    return document.getElementById(id);
}

const app = $('app');
const closeBtn = $('closeBtn');
const notice = $('notice');

const tabButtons = document.querySelectorAll('.tab-btn');
const tabViews = document.querySelectorAll('.tab-view');

const dashboardAdmin = $('dashboardAdmin');
const dashboardOnline = $('dashboardOnline');
const dashboardActiveCharacters = $('dashboardActiveCharacters');
const dashboardTotalCharacters = $('dashboardTotalCharacters');

const searchInput = $('searchInput');
const searchBtn = $('searchBtn');
const characterList = $('characterList');

const refreshPlayersBtn = $('refreshPlayersBtn');
const playerList = $('playerList');

const modal = $('confirmModal');
const confirmText = $('confirmText');
const confirmYes = $('confirmYes');
const confirmNo = $('confirmNo');

let pendingDeleteId = null;

const State = {
    activeTab: 'dashboard',
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

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    });
}

function escapeHtml(value) {
    return String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
}

function money(value) {
    const number = Number(value);

    if (Number.isNaN(number)) {
        return escapeHtml(value ?? '0.00');
    }

    return number.toFixed(2);
}

function setNotice(message, type = 'error') {
    if (!notice) {
        return;
    }

    notice.textContent = message || '';
    notice.className = type;
}

function setActiveTab(tab) {
    State.activeTab = tab;

    tabButtons.forEach((button) => {
        button.classList.toggle('active', button.dataset.tab === tab);
    });

    tabViews.forEach((view) => {
        view.classList.toggle('active', view.id === `view-${tab}`);
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
    const admin = payload.admin || {};
    const stats = payload.stats || {};

    if (dashboardAdmin) {
        dashboardAdmin.textContent = admin.name || '-';
    }

    if (dashboardOnline) {
        dashboardOnline.textContent = stats.onlinePlayers ?? 0;
    }

    if (dashboardActiveCharacters) {
        dashboardActiveCharacters.textContent = stats.activeCharacters ?? 0;
    }

    if (dashboardTotalCharacters) {
        dashboardTotalCharacters.textContent = stats.totalCharacters ?? 0;
    }

    if (payload.tools) {
        State.tools = {
            ...State.tools,
            ...payload.tools
        };

        renderTools();
    }
}

function renderTools() {
    const toolButtons = document.querySelectorAll('[data-tool]');

    toolButtons.forEach((button) => {
        const tool = button.dataset.tool;
        const state = State.tools[tool] === true;

        const labels = {
            noclip: 'Noclip',
            godmode: 'Godmode',
            invisible: 'Invisible',
            showCoords: 'Coords',
            showIds: 'Player IDs'
        };

        button.classList.toggle('active', state);
        button.textContent = `${labels[tool] || tool}: ${state ? 'ON' : 'OFF'}`;
    });
}

function getCharacterStatus(character) {
    if (character.delete_requested_at) {
        return {
            text: 'Удаление',
            className: 'danger',
            description: 'Поставлен на удаление'
        };
    }

    if (character.active_character) {
        return {
            text: 'Активен',
            className: 'ok',
            description: character.active_player_name
                ? `Сейчас играет: ${character.active_player_name}`
                : 'Сейчас выбран в игре'
        };
    }

    return {
        text: 'Не выбран',
        className: '',
        description: 'Персонаж не выбран сейчас'
    };
}

function openConfirm(character) {
    pendingDeleteId = character.id;

    if (confirmText) {
        confirmText.textContent = `${character.firstname} ${character.lastname} | ID: ${character.id}`;
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

function renderCharacters(characters) {
    State.characters = characters || [];

    if (!characterList) {
        return;
    }

    characterList.innerHTML = '';

    if (!State.characters.length) {
        characterList.innerHTML = `
            <div class="empty">
                Персонажи не найдены.
            </div>
        `;
        return;
    }

    State.characters.forEach((character) => {
        const status = getCharacterStatus(character);

        const card = document.createElement('div');
        card.className = 'character-card';

        const deleteDisabled = character.active_character ? 'disabled' : '';
        const deleteTitle = character.active_character
            ? 'Нельзя удалить персонажа, который сейчас активен в игре'
            : 'Удалить персонажа';

        card.innerHTML = `
            <div class="card-main">
                <h3>${escapeHtml(character.firstname)} ${escapeHtml(character.lastname)}</h3>
                <span class="status ${status.className}" title="${escapeHtml(status.description)}">
                    ${escapeHtml(status.text)}
                </span>
            </div>

            <div class="grid">
                <p><b>Character ID:</b> ${escapeHtml(character.id)}</p>
                <p><b>Account ID:</b> ${escapeHtml(character.account_id)}</p>

                <p><b>Аккаунт:</b> ${escapeHtml(character.account_name || 'unknown')}</p>
                <p><b>Slot:</b> ${escapeHtml(character.slot)}</p>

                <p><b>Пол:</b> ${escapeHtml(character.gender)}</p>
                <p><b>Возраст:</b> ${escapeHtml(character.age)}</p>

                <p><b>Cash:</b> $${money(character.cash)}</p>
                <p><b>Bank:</b> $${money(character.bank)}</p>

                <p><b>License:</b> ${escapeHtml(character.license || '-')}</p>
                <p><b>Discord:</b> ${escapeHtml(character.discord || '-')}</p>

                <p><b>Created:</b> ${escapeHtml(character.created_at || '-')}</p>
                <p><b>Статус:</b> ${escapeHtml(status.description)}</p>
            </div>

            <button
                class="delete-btn"
                type="button"
                ${deleteDisabled}
                title="${escapeHtml(deleteTitle)}"
            >
                Удалить персонажа
            </button>
        `;

        const deleteBtn = card.querySelector('.delete-btn');

        if (deleteBtn && !character.active_character) {
            deleteBtn.addEventListener('click', () => {
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
        playerList.innerHTML = `
            <div class="empty">
                Онлайн-игроки не найдены.
            </div>
        `;
        return;
    }

    State.players.forEach((player) => {
        const character = player.character;
        const characterName = character
            ? `${character.firstname || ''} ${character.lastname || ''}`.trim()
            : 'Не выбран';

        const card = document.createElement('div');
        card.className = 'player-card';

        card.innerHTML = `
            <div class="card-main">
                <h3>[${escapeHtml(player.source)}] ${escapeHtml(player.name)}</h3>
                <span class="status ${player.frozen ? 'warn' : 'ok'}">
                    ${player.frozen ? 'Frozen' : 'Online'}
                </span>
            </div>

            <div class="grid">
                <p><b>Account:</b> ${escapeHtml(player.account_name || '-')}</p>
                <p><b>Account ID:</b> ${escapeHtml(player.account_id || '-')}</p>

                <p><b>Персонаж:</b> ${escapeHtml(characterName)}</p>
                <p><b>Ping:</b> ${escapeHtml(player.ping)}</p>

                <p><b>X:</b> ${Number(player.coords?.x || 0).toFixed(2)}</p>
                <p><b>Y:</b> ${Number(player.coords?.y || 0).toFixed(2)}</p>

                <p><b>Z:</b> ${Number(player.coords?.z || 0).toFixed(2)}</p>
                <p><b>H:</b> ${Number(player.coords?.heading || 0).toFixed(2)}</p>
            </div>

            <div class="player-actions">
                <button type="button" data-player-action="goto" data-target="${escapeHtml(player.source)}">Goto</button>
                <button type="button" data-player-action="bring" data-target="${escapeHtml(player.source)}">Bring</button>
                <button type="button" data-player-action="freeze" data-target="${escapeHtml(player.source)}">Freeze</button>
                <button type="button" data-player-action="kick" data-target="${escapeHtml(player.source)}">Kick</button>
            </div>
        `;

        card.querySelectorAll('[data-player-action]').forEach((button) => {
            button.addEventListener('click', () => {
                const action = button.dataset.playerAction;
                const target = Number(button.dataset.target);

                if (action === 'kick') {
                    const reason = prompt('Причина kick:', 'Kicked by admin') || 'Kicked by admin';

                    post('playersAction', {
                        action,
                        target,
                        payload: {
                            reason
                        }
                    });

                    return;
                }

                post('playersAction', {
                    action,
                    target
                });
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
    closeBtn.addEventListener('click', () => {
        post('closeMenu');
    });
}

if (searchBtn) {
    searchBtn.addEventListener('click', searchCharacters);
}

if (searchInput) {
    searchInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            searchCharacters();
        }
    });
}

if (refreshPlayersBtn) {
    refreshPlayersBtn.addEventListener('click', loadPlayers);
}

if (confirmYes) {
    confirmYes.addEventListener('click', () => {
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

tabButtons.forEach((button) => {
    button.addEventListener('click', () => {
        setActiveTab(button.dataset.tab);
    });
});

document.querySelectorAll('[data-tool]').forEach((button) => {
    button.addEventListener('click', () => {
        post('toolsToggle', {
            tool: button.dataset.tool
        });
    });
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('closeMenu');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

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
        return;
    }

    if (data.action === 'panel:open') {
        if (app) {
            app.classList.remove('hidden');
        }

        renderDashboard(data.payload || {});
        setActiveTab('dashboard');
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
        setNotice(`Персонаж ID ${data.id} удалён.`, 'success');
        return;
    }

    if (data.action === 'players:set') {
        renderPlayers(data.players || []);
        return;
    }

    if (data.action === 'tools:set') {
        State.tools = {
            ...State.tools,
            ...(data.tools || {})
        };

        renderTools();
        return;
    }

    if (data.action === 'tools:updateOne') {
        State.tools[data.tool] = data.state === true;
        renderTools();
        return;
    }

    if (data.action === 'error') {
        setNotice(data.message || 'Ошибка.', 'error');
        return;
    }

    if (data.action === 'success') {
        setNotice(data.message || 'Готово.', 'success');
    }
});