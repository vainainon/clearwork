const root = document.getElementById('deathRoot');
const spinner = document.getElementById('spinner');
const title = document.getElementById('title');
const text = document.getElementById('text');
const timer = document.getElementById('timer');

function show() {
    root.classList.remove('hidden');
}

function hide() {
    root.classList.add('hidden');
}

function formatTime(seconds) {
    seconds = Math.max(0, Number(seconds) || 0);

    const m = Math.floor(seconds / 60);
    const s = seconds % 60;

    return `${m}:${String(s).padStart(2, '0')}`;
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'roulette:start') {
        show();

        spinner.className = 'spinner';
        title.textContent = 'Рулетка судьбы';
        text.textContent = 'Персонаж в нокдауне. Идёт проверка на перманентную смерть...';
        timer.textContent = `Осталось: ${formatTime(data.seconds || 300)}`;
    }

    if (data.action === 'roulette:result') {
        show();

        spinner.className = data.permanent ? 'spinner dead' : 'spinner stopped';

        if (data.permanent) {
            title.textContent = 'Перманентная смерть';
            text.textContent = `Бросок: ${data.roll}. Шанс смерти: ${data.chance}%. Персонаж погиб навсегда.`;
            timer.textContent = 'Оживление возможно только через админ-меню.';
        } else {
            title.textContent = 'Персонаж выжил';
            text.textContent = `Бросок: ${data.roll}. Шанс смерти: ${data.chance}%. Через 5 минут персонаж сможет встать.`;
            timer.textContent = `Осталось: ${formatTime(data.seconds || 300)}`;
        }
    }

    if (data.action === 'downed:tick') {
        if (data.permanent) {
            timer.textContent = 'Персонаж мёртв навсегда.';
        } else {
            timer.textContent = `Осталось: ${formatTime(data.seconds || 0)}`;
        }
    }

    if (data.action === 'downed:hide') {
        hide();
    }
});