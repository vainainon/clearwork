const app = document.getElementById('app');
const characterList = document.getElementById('characterList');
const errorBox = document.getElementById('error');

let currentCharacters = [];

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    });
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
        const card = document.createElement('div');
        card.className = 'character-card';

        card.innerHTML = `
            <h3>${character.firstname} ${character.lastname}</h3>
            <p>Возраст: ${character.age}</p>
            <p>Пол: ${character.gender}</p>
            <p>Наличные: $${character.cash}</p>
            <button>Войти</button>
        `;

        card.querySelector('button').addEventListener('click', () => {
            post('selectCharacter', {
                id: character.id
            });
        });

        characterList.appendChild(card);
    });
}

document.getElementById('createBtn').addEventListener('click', () => {
    errorBox.textContent = '';

    post('createCharacter', {
        slot: currentCharacters.length + 1,
        firstname: document.getElementById('firstname').value,
        lastname: document.getElementById('lastname').value,
        age: document.getElementById('age').value,
        gender: document.getElementById('gender').value
    });
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        currentCharacters = data.characters || [];
        renderCharacters();
        app.classList.remove('hidden');
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
    }

    if (data.action === 'error') {
        errorBox.textContent = data.message || 'Ошибка';
    }
});