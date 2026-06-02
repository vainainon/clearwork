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

function show() {
    root.classList.remove('hidden');
}

function hide() {
    root.classList.add('hidden');
    root.classList.remove('countdown-state', 'dead-state', 'safe-state');
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
        chanceValue.textContent = '—';
        wheel.style.setProperty('--death-angle', '0deg');
        return;
    }

    chanceValue.textContent = `${chance}%`;

    const angle = chance >= 100 ? 360 : chance * 3.6;
    wheel.style.setProperty('--death-angle', `${angle}deg`);

    footerLeft.textContent = `Красная зона: 1–${chance}. Зелёная зона: ${chance + 1}–100.`;
}

function setMode(mode) {
    currentMode = mode;

    root.classList.remove('countdown-state', 'dead-state', 'safe-state');

    if (mode === 'countdown') {
        root.classList.add('countdown-state');
    }

    if (mode === 'dead') {
        root.classList.add('dead-state');
    }

    if (mode === 'safe') {
        root.classList.add('safe-state');
    }
}

function prepareRoulette(data) {
    clearSpinTimers();
    show();
    setMode('countdown');

    wheel.classList.remove('spinning');
    rollValue.textContent = '—';

    title.textContent = 'Колесо судьбы';
    subtitle.textContent = 'Салунная рулетка решит, останется ли персонаж в живых.';

    setChance(data.chance);

    const countdown = Number(data.countdown || data.seconds || 5);

    countdownValue.textContent = countdown;
    timer.textContent = `До вращения колеса: ${countdown}`;
    text.textContent = data.alreadyDead
        ? 'Этот персонаж уже отмечен смертью. Колесо подтвердит приговор.'
        : 'Персонаж ранен. До вращения колеса осталось несколько секунд.';

    footerRight.textContent = 'Бросок 1–100';
}

function updateCountdown(data) {
    if (currentMode !== 'countdown') return;

    const seconds = Math.max(0, Number(data.seconds) || 0);

    if (data.chance !== undefined && data.chance !== null) {
        setChance(data.chance);
    }

    countdownValue.textContent = seconds;
    timer.textContent = seconds > 0
        ? `До вращения колеса: ${seconds}`
        : 'Колесо пошло...';

    if (seconds <= 0) {
        title.textContent = 'Ставки сделаны';
        text.textContent = 'Колесо судьбы начинает вращение.';
    }
}

function startSpin(data) {
    clearSpinTimers();
    show();
    setMode('spin');

    setChance(data.chance);

    wheel.classList.add('spinning');

    title.textContent = 'Ставки сделаны';
    subtitle.textContent = 'Колесо крутится. Красная зона означает перманентную смерть.';
    text.textContent = 'Барабан пошёл. Сейчас выпадет число, которое решит судьбу персонажа.';
    timer.textContent = 'Колесо вращается...';
    countdownValue.textContent = '0';
    footerRight.textContent = 'Колесо в движении';

    fakeRollInterval = setInterval(() => {
        const value = Math.floor(Math.random() * 100) + 1;
        rollValue.textContent = String(value).padStart(2, '0');
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
        clearSpinTimers();

        wheel.classList.remove('spinning');
        rollValue.textContent = String(roll).padStart(2, '0');

        if (permanent) {
            setMode('dead');

            title.textContent = 'Перманентная смерть';
            subtitle.textContent = 'Колесо остановилось в красной зоне.';
            text.textContent = `Выпал бросок ${roll}. Текущий шанс смерти был ${chance}%. Персонаж погиб навсегда.`;
            timer.textContent = 'Оживление возможно только через вкладку Персонажи в админ-меню.';
            footerRight.textContent = 'Приговор исполнен';
        } else {
            setMode('safe');

            title.textContent = 'Персонаж выжил';
            subtitle.textContent = 'Колесо миновало красную зону.';
            text.textContent = `Выпал бросок ${roll}. Текущий шанс смерти был ${chance}%. Персонаж остаётся в нокдауне.`;
            timer.textContent = `До подъёма: ${formatTime(data.seconds || 300)}`;
            footerRight.textContent = 'Выжил';
        }
    }, 5850);
}

function updateDownedTimer(data) {
    if (currentMode === 'countdown' || currentMode === 'spin') {
        return;
    }

    if (data.permanent) {
        timer.textContent = 'Персонаж мёртв навсегда.';
        return;
    }

    timer.textContent = `До подъёма: ${formatTime(data.seconds || 0)}`;
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

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