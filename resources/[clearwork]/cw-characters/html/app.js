const app = document.getElementById('app');
const characterList = document.getElementById('characterList');
const errorBox = document.getElementById('error');

const views = {
    main: document.getElementById('mainView'),
    characters: document.getElementById('charactersView'),
    create: document.getElementById('createView'),
    rules: document.getElementById('rulesView')
};

const modal = document.getElementById('confirmModal');
const confirmText = document.getElementById('confirmText');
const confirmYes = document.getElementById('confirmYes');
const confirmNo = document.getElementById('confirmNo');

let currentCharacters = [];
let pendingConfirm = null;
let hasSelectedCharacter = false;
let currentCharacterId = null;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
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

function showView(name) {
    Object.keys(views).forEach((key) => {
        if (views[key]) views[key].classList.toggle('hidden', key !== name);
    });

    if (errorBox) errorBox.textContent = '';
}

function openConfirm(text, onConfirm) {
    if (!modal || !confirmText) return;

    confirmText.textContent = text;
    pendingConfirm = onConfirm;
    modal.classList.remove('hidden');
}

function closeConfirm() {
    pendingConfirm = null;
    if (modal) modal.classList.add('hidden');
}

function getAppearanceData() {
    return {
        scale: Number(document.getElementById('scale')?.value || 1),
        skinTone: Number(document.getElementById('skinTone')?.value || 0),
        faceShape: Number(document.getElementById('faceShape')?.value || 0),
        hair: document.getElementById('hair')?.value || 'short',
        beard: document.getElementById('beard')?.value || 'none'
    };
}

function getDeleteStatus(character) {
    if (!character.delete_requested_at) return null;

    const minutes = Number(character.delete_minutes_passed || 0);
    const cancelAvailable = minutes <= 60;
    const hoursLeft = Math.max(0, 12 - Math.floor(minutes / 60));

    return { minutes, cancelAvailable, hoursLeft };
}

function isTruthyFlag(value) {
    if (value === true || value === 1) return true;
    const text = String(value ?? '').toLowerCase();
    return text === '1' || text === 'true' || text === 'yes';
}

function isCurrentCharacter(character) {
    return currentCharacterId !== null && Number(character.id) === Number(currentCharacterId);
}

function isDeadCharacter(character) {
    return isTruthyFlag(character.is_dead);
}

function isRevivedCharacter(character) {
    return isTruthyFlag(character.was_revived) || Boolean(character.revived_at);
}

function renderCharacters() {
    if (!characterList) return;

    characterList.innerHTML = '';

    if (!currentCharacters.length) {
        characterList.innerHTML = `
            <div class="info-card">
                <h3>Персонажей нет</h3>
                <p>Создай первого жителя Лемойна.</p>
            </div>
        `;
        return;
    }

    currentCharacters.forEach((character) => {
        const status = getDeleteStatus(character);
        const ageDays = Number(character.age_days || 0);
        const isCurrent = isCurrentCharacter(character);
        const isDead = isDeadCharacter(character);
        const isRevived = isRevivedCharacter(character);
        const canRequestDelete = isDead || ageDays >= 7;

        const card = document.createElement('div');
        card.className = 'character-card';

        if (isCurrent) card.classList.add('current-character');
        if (isDead) card.classList.add('dead-character');

        let statusHtml = '';

        // Для убитого персонажа не показываем длинное предупреждение: достаточно красной карточки и кнопки "Убит".
        if (isDead) {
            statusHtml = '';
        } else if (isCurrent) {
            statusHtml = `
                <div class="delete-status selected-status">
                    Сейчас ты играешь за этого персонажа.
                </div>
            `;
        } else if (isRevived) {
            statusHtml = `
                <div class="delete-status revived-status">
                    Пермакилл снят администрацией. Персонажа можно возродить.
                </div>
            `;
        } else if (status) {
            statusHtml = `
                <div class="delete-status">
                    Персонаж поставлен на удаление. До удаления примерно: ${status.hoursLeft} ч.
                    ${status.cancelAvailable ? '<br>Удаление можно отменить.' : '<br>Время отмены истекло.'}
                </div>
            `;
        } else if (!canRequestDelete) {
            statusHtml = `
                <div class="delete-status muted">
                    Удаление будет доступно через ${Math.max(0, 7 - ageDays)} дн.
                </div>
            `;
        }

        let actionsHtml = '';

        if (isDead) {
            actionsHtml = `
                <div class="card-actions single-action">
                    <button class="selected-btn" disabled>Убит</button>
                </div>
                <div class="card-actions single-action">
                    <button class="delete-btn">Удалить</button>
                </div>
            `;
        } else if (status) {
            actionsHtml = `
                <div class="card-actions single-action">
                    <button class="cancel-delete-btn">Отменить удаление</button>
                </div>
            `;
        } else if (isCurrent) {
            actionsHtml = `
                <div class="card-actions">
                    <button class="selected-btn" disabled>Выбран</button>
                    <button class="delete-btn" disabled>Удалить</button>
                </div>
            `;
        } else {
            const selectLabel = isRevived ? 'Возродиться' : 'Войти';
            const selectClass = isRevived ? 'select-btn revive-select-btn' : 'select-btn';

            actionsHtml = `
                <div class="card-actions">
                    <button class="${selectClass}">${selectLabel}</button>
                    <button class="delete-btn" ${canRequestDelete ? '' : 'disabled'}>Удалить</button>
                </div>
            `;
        }

        card.innerHTML = `
            <h3>${escapeHtml(character.firstname)} ${escapeHtml(character.lastname)}</h3>
            <p>Возраст: ${escapeHtml(character.age)}</p>
            <p>Пол: ${escapeHtml(character.gender)}</p>
            <p>Наличные: $${escapeHtml(character.cash)}</p>
            ${statusHtml}
            ${actionsHtml}
        `;

        const selectBtn = card.querySelector('.select-btn');
        if (selectBtn) {
            selectBtn.addEventListener('click', () => {
                if (isCurrent || isDead || status) return;
                post('selectCharacter', { id: character.id });
            });
        }

        const deleteBtn = card.querySelector('.delete-btn');
        if (deleteBtn) {
            deleteBtn.addEventListener('click', () => {
                if (deleteBtn.disabled) return;
                if (isCurrent && !isDead) return;

                const deadText = isDead
                    ? `Персонаж ${character.firstname} ${character.lastname} убит. Поставить его на удаление?`
                    : `Поставить персонажа ${character.firstname} ${character.lastname} на удаление? Окончательное удаление произойдёт через 12 часов. Отменить можно только в первый час.`;

                openConfirm(deadText, () => {
                    post('requestDeleteCharacter', { id: character.id });
                });
            });
        }

        const cancelDeleteBtn = card.querySelector('.cancel-delete-btn');
        if (cancelDeleteBtn) {
            cancelDeleteBtn.addEventListener('click', () => {
                if (cancelDeleteBtn.disabled || isCurrent) return;

                openConfirm(`Отменить удаление персонажа ${character.firstname} ${character.lastname}?`, () => {
                    post('cancelDeleteCharacter', { id: character.id });
                });
            });
        }

        characterList.appendChild(card);
    });
}

document.getElementById('showCharactersBtn')?.addEventListener('click', () => {
    renderCharacters();
    showView('characters');
});

document.getElementById('showCreateBtn')?.addEventListener('click', () => showView('create'));
document.getElementById('showRulesBtn')?.addEventListener('click', () => showView('rules'));
document.getElementById('createFromListBtn')?.addEventListener('click', () => showView('create'));

document.querySelectorAll('[data-view]').forEach((button) => {
    button.addEventListener('click', () => showView(button.dataset.view));
});

document.getElementById('closeBtn')?.addEventListener('click', () => post('closeMenu'));

document.getElementById('createBtn')?.addEventListener('click', () => {
    if (errorBox) errorBox.textContent = '';

    post('createCharacter', {
        firstname: document.getElementById('firstname')?.value || '',
        lastname: document.getElementById('lastname')?.value || '',
        age: document.getElementById('age')?.value || 18,
        gender: document.getElementById('gender')?.value || 'male',
        startCity: document.getElementById('startCity')?.value || 'saintdenis',
        skin: getAppearanceData()
    });
});

confirmYes?.addEventListener('click', () => {
    if (pendingConfirm) pendingConfirm();
    closeConfirm();
});

confirmNo?.addEventListener('click', closeConfirm);

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open' || data.action === 'setCharacters') {
        currentCharacters = data.characters || [];
        currentCharacterId = data.currentCharacterId !== undefined && data.currentCharacterId !== null
            ? Number(data.currentCharacterId)
            : null;

        if (currentCharacterId === null) {
            currentCharacters.forEach((character) => {
                if (character.is_current === true || character.is_current === 1 || character.is_current === '1') {
                    currentCharacterId = Number(character.id);
                }
            });
        }

        hasSelectedCharacter = Boolean(data.hasSelectedCharacter || currentCharacterId !== null);
        renderCharacters();

        if (app) app.classList.remove('hidden');
        showView(currentCharacters.length > 0 ? 'characters' : 'main');
    }

    if (data.action === 'close') {
        if (app) app.classList.add('hidden');
        closeConfirm();
    }

    if (data.action === 'setVisible') {
        if (data.visible) {
            if (app) app.classList.remove('hidden');
            renderCharacters();
            showView(currentCharacters.length > 0 ? 'characters' : 'main');
        } else {
            if (app) app.classList.add('hidden');
            closeConfirm();
        }
    }

    if (data.action === 'error') {
        if (errorBox) errorBox.textContent = data.message || 'Ошибка';
    }
});
