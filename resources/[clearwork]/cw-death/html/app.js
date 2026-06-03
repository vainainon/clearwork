const root = document.getElementById('deathRoot');
const title = document.getElementById('title');
const subtitle = document.getElementById('subtitle');
const text = document.getElementById('text');
const timer = document.getElementById('timer');
const wheel = document.getElementById('wheel');
const rollValue = document.getElementById('rollValue');
const chanceValue = document.getElementById('chanceValue');
const countdownValue = document.getElementById('countdownValue');
const countdownLabel = document.getElementById('countdownLabel');
const footerLeft = document.getElementById('footerLeft');
const footerRight = document.getElementById('footerRight');
const actionButton = document.getElementById('actionButton');

let fakeRollInterval = null;
let finishTimeout = null;
let lastRotation = 0;
let currentMode = 'hidden';
let currentActionMode = null;

function safeSet(el, value) {
    if (el) el.textContent = value;
}

function safeClassAdd(el, name) {
    if (el) el.classList.add(name);
}

function safeClassRemove(el, ...names) {
    if (el) el.classList.remove(...names);
}

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
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

function show() {
    safeClassRemove(root, 'hidden');
}

function hide() {
    safeClassAdd(root, 'hidden');
    safeClassRemove(root, 'countdown-state', 'spin-state', 'dead-state', 'safe-state', 'ready-state');
    safeClassAdd(actionButton, 'hidden');
    if (actionButton) actionButton.disabled = true;
    currentMode = 'hidden';
    currentActionMode = null;
    clearSpinTimers();
}

function formatTime(seconds) {
    seconds = Math.max(0, Number(seconds) || 0);
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${String(s).padStart(2, '0')}`;
}

function clampChance(value) {
    value = Number(value);
    if (!Number.isFinite(value)) return null;

    value = Math.floor(value);
    if (value < 0) value = 0;
    if (value > 100) value = 100;
    return value;
}

function setChance(chance) {
    chance = clampChance(chance);

    if (chance === null) {
        safeSet(chanceValue, '—');
        if (wheel) wheel.style.setProperty('--death-angle', '0deg');
        safeSet(footerLeft, 'Красная зона — перманентная смерть.');
        return;
    }

    safeSet(chanceValue, `${chance}%`);

    const angle = chance >= 100 ? 360 : chance * 3.6;
    if (wheel) wheel.style.setProperty('--death-angle', `${angle}deg`);

    if (chance >= 100) {
        safeSet(footerLeft, 'Красная зона: 1–100. Зелёной зоны нет.');
    } else if (chance <= 0) {
        safeSet(footerLeft, 'Красной зоны нет. Зелёная зона: 1–100.');
    } else {
        safeSet(footerLeft, `Красная зона: 1–${chance}. Зелёная зона: ${chance + 1}–100.`);
    }
}

function setMode(mode) {
    currentMode = mode;
    safeClassRemove(root, 'countdown-state', 'spin-state', 'dead-state', 'safe-state', 'ready-state');

    if (mode === 'countdown') safeClassAdd(root, 'countdown-state');
    if (mode === 'spin') safeClassAdd(root, 'spin-state');
    if (mode === 'dead') safeClassAdd(root, 'dead-state');
    if (mode === 'safe') safeClassAdd(root, 'safe-state');
}

function configureAction(mode, available) {
    currentActionMode = mode || currentActionMode;

    if (!actionButton || !currentActionMode) return;

    const isSwitch = currentActionMode === 'switch';
    actionButton.textContent = isSwitch ? 'Сменить персонажа' : 'Подняться';
    safeClassRemove(actionButton, 'hidden');
    actionButton.disabled = !available;

    if (available) {
        safeClassAdd(root, 'ready-state');
        safeSet(timer, isSwitch ? 'Теперь можно сменить персонажа.' : 'Теперь можно подняться.');
    } else {
        safeClassRemove(root, 'ready-state');
    }
}

function prepareRoulette(data) {
    clearSpinTimers();
    show();
    setMode('countdown');

    if (wheel) {
        wheel.classList.remove('spinning');
    }

    safeClassAdd(actionButton, 'hidden');
    if (actionButton) actionButton.disabled = true;

    safeSet(rollValue, '—');
    safeSet(title, 'Колесо судьбы');
    safeSet(subtitle, 'Салунная рулетка решит, останется ли персонаж в живых.');
    setChance(data.chance);

    const countdown = Number(data.countdown || 5);
    safeSet(countdownLabel, 'До рулетки');
    safeSet(countdownValue, countdown);
    safeSet(timer, `До вращения колеса: ${countdown}`);
    safeSet(text, data.alreadyDead
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

    safeSet(countdownLabel, 'До рулетки');
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

    safeClassAdd(actionButton, 'hidden');
    if (actionButton) actionButton.disabled = true;

    safeSet(title, 'Ставки сделаны');
    safeSet(subtitle, 'Колесо крутится. Красная зона означает перманентную смерть.');
    safeSet(text, 'Барабан пошёл. Сейчас выпадет число, которое решит судьбу персонажа.');
    safeSet(timer, 'Колесо вращается...');
    safeSet(countdownLabel, 'До рулетки');
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
    showDownedState({ permanent, seconds, chance, roll, actionAvailable: false });
}

function showDownedState(data) {
    const permanent = data.permanent === true;
    const seconds = Math.max(0, Number(data.seconds) || 0);
    const roll = data.roll !== undefined && data.roll !== null ? Number(data.roll) : null;
    const chance = clampChance(data.chance) ?? 0;

    show();
    setChance(chance);
    setMode(permanent ? 'dead' : 'safe');

    currentActionMode = permanent ? 'switch' : 'revive';

    if (roll !== null && Number.isFinite(roll)) {
        safeSet(rollValue, String(roll).padStart(2, '0'));
    }

    if (permanent) {
        safeSet(title, 'Перманентная смерть');
        safeSet(subtitle, 'Колесо остановилось в красной зоне.');
        safeSet(text, roll !== null
            ? `Выпал бросок ${roll}. Текущий шанс смерти был ${chance}%. Персонаж погиб навсегда.`
            : 'Персонаж погиб навсегда.'
        );
        safeSet(footerRight, 'Приговор исполнен');
        safeSet(countdownLabel, 'До смены');
    } else {
        safeSet(title, 'Персонаж выжил');
        safeSet(subtitle, 'Колесо миновало красную зону.');
        safeSet(text, roll !== null
            ? `Выпал бросок ${roll}. Текущий шанс смерти был ${chance}%. Персонаж остаётся в нокдауне.`
            : 'Персонаж остаётся в нокдауне.'
        );
        safeSet(footerRight, 'Выжил');
        safeSet(countdownLabel, 'До подъёма');
    }

    safeSet(countdownValue, formatTime(seconds));
    safeSet(timer, permanent
        ? `До смены персонажа: ${formatTime(seconds)}`
        : `До подъёма: ${formatTime(seconds)}`
    );

    configureAction(currentActionMode, data.actionAvailable === true || seconds <= 0);
}

function updateDownedTimer(data) {
    if (currentMode === 'countdown' || currentMode === 'spin') return;

    const seconds = Math.max(0, Number(data.seconds) || 0);
    const permanent = data.permanent === true;

    safeSet(countdownLabel, permanent ? 'До смены' : 'До подъёма');
    safeSet(countdownValue, formatTime(seconds));
    safeSet(timer, permanent
        ? `До смены персонажа: ${formatTime(seconds)}`
        : `До подъёма: ${formatTime(seconds)}`
    );

    configureAction(data.mode || (permanent ? 'switch' : 'revive'), data.actionAvailable === true || seconds <= 0);
}

actionButton?.addEventListener('click', () => {
    if (actionButton.disabled || !currentActionMode) return;
    actionButton.disabled = true;
    post('deathAction', { mode: currentActionMode });
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'roulette:start') {
        prepareRoulette({ chance: data.chance, countdown: 5, seconds: data.seconds || 300 });
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

    if (data.action === 'downed:state') {
        showDownedState(data);
    }

    if (data.action === 'downed:tick') {
        updateDownedTimer(data);
    }

    if (data.action === 'downed:actionState') {
        configureAction(data.mode, data.available === true);
    }

    if (data.action === 'downed:hide') {
        hide();
    }
});
