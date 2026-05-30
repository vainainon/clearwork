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
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    });
}

function showView(name) {
    Object.keys(views).forEach((key) => {
        views[key].classList.toggle('hidden', key !== name);
    });

    errorBox.textContent = '';
}

function openConfirm(text, onConfirm) {
    confirmText.textContent = text;
    pendingConfirm = onConfirm;
    modal.classList.remove('hidden');
}

function closeConfirm() {
    pendingConfirm = null;
    modal.classList.add('hidden');
}

function getAppearanceData() {
    return {
        scale: Number(document.getElementById('scale').value),
        skinTone: Number(document.getElementById('skinTone').value),
        faceShape: Number(document.getElementById('faceShape').value),
        hair: document.getElementById('hair').value,
        beard: document.getElementById('beard').value
    };
}

function getDeleteStatus(character) {
    if (!character.delete_requested_at) {
        return null;
    }

    const minutes = Number(character.delete_minutes_passed || 0);
    const cancelAvailable = minutes <= 60;
    const hoursLeft = Math.max(0, 12 - Math.floor(minutes / 60));

    return {
        minutes,
        cancelAvailable,
        hoursLeft
    };
}

function isCurrentCharacter(character) {
    return currentCharacterId !== null && Number(character.id) === Number(currentCharacterId);
}

function renderCharacters() {
    characterList.innerHTML = '';

    if (!currentCharacters.length) {
        characterList.innerHTML = `
            <div class="character-card">
                <h3>Персонажей нет</h3>
                <p>Создай первого жителя Лемойна.</p>
            </div>
        `;
        return;
    }

    currentCharacters.forEach((character) => {
        const status = getDeleteStatus(character);
        const ageDays = Number(character.age_days || 0);
        const canRequestDelete = ageDays >= 7 && !status;
        const isCurrent = isCurrentCharacter(character);

        const card = document.createElement('div');
        card.className = isCurrent ? 'character-card current-character' : 'character-card';

        let statusHtml = '';

        if (isCurrent) {
            statusHtml = `
                <div class="delete-status selected-status">
                    Сейчас ты играешь за этого персонажа.
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

        card.innerHTML = `
            <h3>${character.firstname} ${character.lastname}</h3>
            <p>Возраст: ${character.age}</p>
            <p>Пол: ${character.gender}</p>
            <p>Наличные: $${character.cash}</p>
            ${statusHtml}
            <div class="card-actions">
                <button class="select-btn ${isCurrent ? 'selected-btn' : ''}" ${status || isCurrent ? 'disabled' : ''}>
                    ${isCurrent ? 'Выбран' : 'Войти'}
                </button>
                ${status
                ? `<button class="cancel-delete-btn" ${isCurrent ? 'disabled' : ''}>Отменить</button>`
                : `<button class="delete-btn" ${!canRequestDelete || isCurrent ? 'disabled' : ''}>Удалить</button>`
            }
            </div>
        `;

        const selectBtn = card.querySelector('.select-btn');

        if (selectBtn) {
            selectBtn.addEventListener('click', () => {
                if (isCurrent) {
                    return;
                }

                post('selectCharacter', {
                    id: character.id
                });
            });
        }

        const deleteBtn = card.querySelector('.delete-btn');

        if (deleteBtn) {
            deleteBtn.addEventListener('click', () => {
                if (isCurrent) {
                    return;
                }

                openConfirm(
                    `Поставить персонажа ${character.firstname} ${character.lastname} на удаление? Окончательное удаление произойдёт через 12 часов. Отменить можно только в первый час.`,
                    () => {
                        post('requestDeleteCharacter', {
                            id: character.id
                        });
                    }
                );
            });
        }

        const cancelDeleteBtn = card.querySelector('.cancel-delete-btn');

        if (cancelDeleteBtn) {
            cancelDeleteBtn.addEventListener('click', () => {
                if (isCurrent) {
                    return;
                }

                openConfirm(
                    `Отменить удаление персонажа ${character.firstname} ${character.lastname}?`,
                    () => {
                        post('cancelDeleteCharacter', {
                            id: character.id
                        });
                    }
                );
            });
        }

        characterList.appendChild(card);
    });
}

document.getElementById('showCharactersBtn').addEventListener('click', () => {
    renderCharacters();
    showView('characters');
});

document.getElementById('showCreateBtn').addEventListener('click', () => {
    showView('create');
});

document.getElementById('showRulesBtn').addEventListener('click', () => {
    showView('rules');
});

document.getElementById('createFromListBtn').addEventListener('click', () => {
    showView('create');
});

document.querySelectorAll('[data-view]').forEach((button) => {
    button.addEventListener('click', () => {
        showView(button.dataset.view);
    });
});

document.getElementById('closeBtn').addEventListener('click', () => {
    post('closeMenu');
});

document.getElementById('createBtn').addEventListener('click', () => {
    errorBox.textContent = '';

    post('createCharacter', {
        firstname: document.getElementById('firstname').value,
        lastname: document.getElementById('lastname').value,
        age: document.getElementById('age').value,
        gender: document.getElementById('gender').value,
        startCity: document.getElementById('startCity').value,
        skin: getAppearanceData()
    });
});

confirmYes.addEventListener('click', () => {
    if (pendingConfirm) {
        pendingConfirm();
    }

    closeConfirm();
});

confirmNo.addEventListener('click', () => {
    closeConfirm();
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
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
        app.classList.remove('hidden');

        if (currentCharacters.length > 0) {
            showView('characters');
        } else {
            showView('main');
        }
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
        closeConfirm();
    }

    if (data.action === 'error') {
        errorBox.textContent = data.message || 'Ошибка';
    }
});
