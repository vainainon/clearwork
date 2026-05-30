function $(id) {
    return document.getElementById(id);
}

const app = $('app');
const characterList = $('characterList');
const searchInput = $('searchInput');
const searchBtn = $('searchBtn');
const closeBtn = $('closeBtn');
const errorBox = $('error');
const modal = $('confirmModal');
const confirmText = $('confirmText');
const confirmYes = $('confirmYes');
const confirmNo = $('confirmNo');

let pendingDeleteId = null;

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

function setError(message) {
    if (errorBox) {
        errorBox.textContent = message || '';
    }
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
    if (!characterList) {
        return;
    }

    characterList.innerHTML = '';

    if (!characters.length) {
        characterList.innerHTML = `
            <div class="empty">
                Персонажи не найдены.
            </div>
        `;
        return;
    }

    characters.forEach((character) => {
        const status = getCharacterStatus(character);

        const card = document.createElement('div');
        card.className = 'character-card';

        const deleteDisabled = character.active_character ? 'disabled' : '';
        const deleteTitle = character.active_character
            ? 'Нельзя удалить персонажа, который сейчас активен в игре'
            : 'Удалить персонажа';

        card.innerHTML = `
            <div class="char-main">
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

function searchCharacters() {
    setError('');

    post('searchCharacters', {
        query: searchInput ? searchInput.value : ''
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

if (closeBtn) {
    closeBtn.addEventListener('click', () => {
        post('closeMenu');
    });
}

if (confirmYes) {
    confirmYes.addEventListener('click', () => {
        if (pendingDeleteId) {
            post('deleteCharacter', {
                id: pendingDeleteId
            });
        }

        closeConfirm();
    });
}

if (confirmNo) {
    confirmNo.addEventListener('click', () => {
        closeConfirm();
    });
}

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('closeMenu');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        if (app) {
            app.classList.remove('hidden');
        }

        setError('');
        return;
    }

    if (data.action === 'close') {
        if (app) {
            app.classList.add('hidden');
        }

        closeConfirm();
        return;
    }

    if (data.action === 'characters') {
        renderCharacters(data.characters || []);
        return;
    }

    if (data.action === 'deleted') {
        setError(`Персонаж ID ${data.id} удалён.`);
        return;
    }

    if (data.action === 'error') {
        setError(data.message || 'Ошибка');
    }
});