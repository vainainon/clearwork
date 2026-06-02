const root = document.getElementById('deathRoot');
const title = document.getElementById('title');
const subtitle = document.getElementById('subtitle');
const text = document.getElementById('text');
const timer = document.getElementById('timer');

const wheel = document.getElementById('wheel');
const rollValue = document.getElementById('rollValue');
const chanceValue = document.getElementById('chanceValue');
const countdownValue = document.getElementById('countdownValue');
const footerLeft = document.getElementById('footerLeft');
const footerRight = document.getElementById('footerRight');

let fakeRollInterval = null;
let finishTimeout = null;
let lastRotation = 0;
let currentMode = 'hidden';

function safeSet(el, value) {
    if (el) el.textContent = value;
}

function safeClassAdd(el, name) {
    if (el) el.classList.add(name);
}

function safeClassRemove(el, ...names) {
    if (el) el.classList.remove(...names);
}

function show() {
    safeClassRemove(root, 'hidden');
}

function hide() {
    safeClassAdd(root, 'hidden');
    safeClassRemove(root, 'countdown-state', 'dead-state', 'safe-state');
    currentMode = 'hidden';
    clearSpinTimers();
}

function clearSpinTimers() {
    if (fakeRollInterval) {
        clearInterval(fakeRollInterval);
        fakeRollInterval = null;
    }

    if (finishTimeout) {
        clearTimeout(finishTimeout);
        finishTimeout = null;
    }
}

function formatTime(seconds) {
    seconds = Math.max(0, Number(seconds) || 0);

    const m = Math.floor(seconds / 60);
    const s = seconds % 60;

    return `${m}:${String(s).padStart(2, '0')}`;
}

function clampChance(value) {
    value = Number(value);

    if (!Number.isFinite(value)) {
        return null;
    }

    value = Math.floor(value);

    if (value < 0) value = 0;
    if (value > 100) value = 100;

    return value;
}

function setChance(chance) {
    chance = clampChance(chance);

    if (chance === null) {
        safeSet(chanceValue, '—');

        if (wheel) {
            wheel.style.setProperty('--death-angle', '0deg');
        }

        return;
    }

    safeSet(chanceValue, `${chance}%`);

    const angle = chance >= 100 ? 360 : chance * 3.6;

    if (wheel) {
        wheel.style.setProperty('--death-angle', `${angle}deg`);
    }

    safeSet(
        footerLeft,
        `Красная зона: 1–${chance}. Зелёная зона: ${chance + 1}–100.`
    );
}

function setMode(mode) {
    currentMode = mode;

    safeClassRemove(root, 'countdown-state', 'dead-state', 'safe-state');

    if (mode === 'countdown') {
        safeClassAdd(root, 'countdown-state');
    }

    if (mode === 'dead') {
        safeClassAdd(root, 'dead-state');
    }

    if (mode === 'safe') {
        safeClassAdd(root, 'safe-state');
    }
}

function prepareRoulette(data) {
    clearSpinTimers();
    show();
    setMode('countdown');

    if (wheel) {
        wheel.classList.remove('spinning');
    }

    safeSet(rollValue, '—');
    safeSet(title, 'Колесо судьбы');
    safeSet(subtitle, 'Салунная рулетка решит, останется ли персонаж в живых.');

    setChance(data.chance);

    const countdown = Number(data.countdown || 5);

    safeSet(countdownValue, countdown);
    safeSet(timer, `До вращения колеса: ${countdown}`);

    safeSet(
        text,
        data.alreadyDead
            ? 'Этот персонаж уже отмечен смертью. Колесо подтвердит приговор.'
            : 'Персонаж ранен. До вращения колеса осталось несколько секунд.'
    );

    safeSet(footerRight, 'Бросок 1–100');
}

function updateCountdown(data) {
    if (currentMode !== 'countdown') return;

    const seconds = Math.max(0, Number(data.seconds) || 0);

    if (data.chance !== undefined && data.chance !== null) {
        setChance(data.chance);
    }

    safeSet(countdownValue, seconds);
    safeSet(timer, seconds > 0 ? `До вращения колеса: ${seconds}` : 'Колесо пошло...');

    if (seconds <= 0) {
        safeSet(title, 'Ставки сделаны');
        safeSet(text, 'Колесо судьбы начинает вращение.');
    }
}

function startSpin(data) {
    clearSpinTimers();
    show();
    setMode('spin');

    setChance(data.chance);

    if (wheel) {
        wheel.classList.add('spinning');
    }

    safeSet(title, 'Ставки сделаны');
    safeSet(subtitle, 'Колесо крутится. Красная зона означает перманентную смерть.');
    safeSet(text, 'Барабан пошёл. Сейчас выпадет число, которое решит судьбу персонажа.');
    safeSet(timer, 'Колесо вращается...');
    safeSet(countdownValue, '0');
    safeSet(footerRight, 'Колесо в движении');

    fakeRollInterval = setInterval(() => {
        const value = Math.floor(Math.random() * 100) + 1;
        safeSet(rollValue, String(value).padStart(2, '0'));
    }, 70);
}

function animateToRoll(data) {
    show();

    const roll = Math.max(1, Math.min(100, Math.floor(Number(data.roll) || 1)));
    const chance = clampChance(data.chance) ?? 0;
    const permanent = data.permanent === true;

    setChance(chance);

    if (currentMode !== 'spin') {
        startSpin({ chance });
    }

    if (!wheel) {
        finishRollInstant(roll, chance, permanent, data.seconds || 300);
        return;
    }

    const anglePerNumber = 3.6;
    const selectedAngle = (roll - 0.5) * anglePerNumber;
    const extraSpins = 7;
    const targetRotation = (360 * extraSpins) - selectedAngle;

    wheel.style.transition = 'none';
    wheel.style.transform = `rotate(${lastRotation % 360}deg)`;

    wheel.offsetHeight;

    wheel.style.transition = 'transform 5.7s cubic-bezier(0.12, 0.72, 0.08, 1)';
    wheel.style.transform = `rotate(${targetRotation}deg)`;

    lastRotation = targetRotation;

    finishTimeout = setTimeout(() => {
        finishRollInstant(roll, chance, permanent, data.seconds || 300);
    }, 5850);
}

function finishRollInstant(roll, chance, permanent, seconds) {
    clearSpinTimers();

    if (wheel) {
        wheel.classList.remove('spinning');
    }

    safeSet(rollValue, String(roll).padStart(2, '0'));

    if (permanent) {
        setMode('dead');

        safeSet(title, 'Перманентная смерть');
        safeSet(subtitle, 'Колесо остановилось в красной зоне.');
        safeSet(text, `Выпал бросок ${roll}. Текущий шанс смерти был ${chance}%. Персонаж погиб навсегда.`);
        safeSet(timer, 'Оживление возможно только через вкладку Персонажи в админ-меню.');
        safeSet(footerRight, 'Приговор исполнен');
    } else {
        setMode('safe');

        safeSet(title, 'Персонаж выжил');
        safeSet(subtitle, 'Колесо миновало красную зону.');
        safeSet(text, `Выпал бросок ${roll}. Текущий шанс смерти был ${chance}%. Персонаж остаётся в нокдауне.`);
        safeSet(timer, `До подъёма: ${formatTime(seconds || 300)}`);
        safeSet(footerRight, 'Выжил');
    }
}

function updateDownedTimer(data) {
    if (currentMode === 'countdown' || currentMode === 'spin') {
        return;
    }

    if (data.permanent) {
        safeSet(timer, 'Персонаж мёртв навсегда.');
        return;
    }

    safeSet(timer, `До подъёма: ${formatTime(data.seconds || 0)}`);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'roulette:start') {
        prepareRoulette({
            chance: data.chance,
            countdown: 5,
            seconds: data.seconds || 300
        });
    }

    if (data.action === 'roulette:prepare') {
        prepareRoulette(data);
    }

    if (data.action === 'roulette:countdownTick') {
        updateCountdown(data);
    }

    if (data.action === 'roulette:spin') {
        startSpin(data);
    }

    if (data.action === 'roulette:result') {
        animateToRoll(data);
    }

    if (data.action === 'downed:tick') {
        updateDownedTimer(data);
    }

    if (data.action === 'downed:hide') {
        hide();
    }
});
