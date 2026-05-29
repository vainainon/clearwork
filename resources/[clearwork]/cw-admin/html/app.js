const app = document.getElementById('app');
const adminInfo = document.getElementById('adminInfo');

const playersTab = document.getElementById('playersTab');
const adminsTab = document.getElementById('adminsTab');
const logsTab = document.getElementById('logsTab');

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    });
}

function switchTab(name) {
    playersTab.classList.toggle('hidden', name !== 'players');
    adminsTab.classList.toggle('hidden', name !== 'admins');
    logsTab.classList.toggle('hidden', name !== 'logs');
}

function renderPlayers(players) {
    if (!players.length) {
        playersTab.innerHTML = '<div class="card">Игроков нет.</div>';
        return;
    }

    playersTab.innerHTML = players.map((player) => `
        <div class="card">
            <h3>${player.name}</h3>
            <p>ID: ${player.id}</p>
            <p>${player.license}</p>
        </div>
    `).join('');
}

function renderAdmins(admins) {
    if (!admins.length) {
        adminsTab.innerHTML = '<div class="card">Админов в БД пока нет.</div>';
        return;
    }

    adminsTab.innerHTML = admins.map((admin) => `
        <div class="card">
            <h3>${admin.name || 'Unknown'}</h3>
            <p>Роль: ${admin.role}</p>
            <p>${admin.license}</p>
            <p>Добавлен: ${admin.created_at}</p>
        </div>
    `).join('');
}

function renderLogs(logs) {
    if (!logs.length) {
        logsTab.innerHTML = '<div class="card">Логов пока нет.</div>';
        return;
    }

    logsTab.innerHTML = logs.map((log) => `
        <div class="card">
            <h3>${log.action}</h3>
            <p>Кто: ${log.actor_name || 'unknown'}</p>
            <p>Цель: ${log.target_name || '-'}</p>
            <p>Время: ${log.created_at}</p>
        </div>
    `).join('');
}

document.querySelectorAll('[data-tab]').forEach((button) => {
    button.addEventListener('click', () => {
        switchTab(button.dataset.tab);
    });
});

document.getElementById('closeBtn').addEventListener('click', () => {
    post('close');
});

document.getElementById('refreshBtn').addEventListener('click', () => {
    post('refresh');
});

window.addEventListener('message', (event) => {
    const payload = event.data;

    if (payload.action === 'open') {
        const data = payload.data;

        adminInfo.textContent = `${data.self.name} / ${data.self.role}`;

        renderPlayers(data.players || []);
        renderAdmins(data.admins || []);
        renderLogs(data.logs || []);

        switchTab('players');
        app.classList.remove('hidden');
    }

    if (payload.action === 'close') {
        app.classList.add('hidden');
    }
});