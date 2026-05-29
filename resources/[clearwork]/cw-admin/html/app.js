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

function setError(message) {
    if (errorBox) {
        errorBox.textContent = message || '';
    }
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
            <div class="empty">Персонажи не найдены.</div>
        `;
        return;
    }

    characters.forEach((character) => {
        const card = document.createElement('div');
        card.className = 'character-card';

        const deletedStatus = character.delete_requested_at
            ? `<span class="status danger">Поставлен на удаление</span>`
            : `<span class="status ok">Активен</span>`;

        card.innerHTML = `
            <div class="char-main">
                <h3>${character.firstname} ${character.lastname}</h3>
                ${deletedStatus}
            </div>

            <div class="grid">
                <p><b>Character ID:</b> ${character.id}</p>
                <p><b>Account ID:</b> ${character.account_id}</p>
                <p><b>Аккаунт:</b> ${character.account_name || 'unknown'}</p>
                <p><b>Slot:</b> ${character.slot}</p>
                <p><b>Пол:</b> ${character.gender}</p>
                <p><b>Возраст:</b> ${character.age}</p>
                <p><b>Cash:</b> $${character.cash}</p>
                <p><b>Bank:</b> $${character.bank}</p>
                <p><b>License:</b> ${character.license || '-'}</p>
                <p><b>Discord:</b> ${character.discord || '-'}</p>
                <p><b>Created:</b> ${character.created_at || '-'}</p>
            </div>

            <button class="delete-btn">Удалить персонажа</button>
        `;

        const deleteBtn = card.querySelector('.delete-btn');

        if (deleteBtn) {
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