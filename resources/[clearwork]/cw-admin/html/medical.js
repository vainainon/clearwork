(function () {
    'use strict';

    function resourcePost(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify(data || {})
        });
    }

    function isTruthyFlag(value) {
        if (value === true || value === 1) return true;

        const text = String(value ?? '').toLowerCase();
        return text === '1' || text === 'true' || text === 'yes';
    }

    function setNotice(message, type) {
        const notice = document.getElementById('notice');
        if (!notice) return;

        notice.textContent = message || '';
        notice.className = type || '';
    }

    function injectStyle() {
        if (document.getElementById('medicalAdminStyle')) return;

        const style = document.createElement('style');
        style.id = 'medicalAdminStyle';
        style.textContent = `
            .medical-admin-panel {
                margin: 12px 0 16px;
                padding: 14px;
                border: 1px solid rgba(255,255,255,.12);
                border-radius: 12px;
                background: rgba(255,255,255,.045);
            }

            .medical-admin-panel h3 {
                margin: 0 0 10px;
            }

            .medical-row {
                display: flex;
                gap: 10px;
                align-items: center;
                flex-wrap: wrap;
            }

            .medical-row input[type="number"] {
                width: 84px;
            }

            .medical-row input[type="range"] {
                width: 220px;
            }

            .medical-note {
                margin-top: 8px;
                opacity: .75;
                font-size: 12px;
            }

            .medical-revive-btn {
                background: rgba(50, 180, 90, .18) !important;
                border-color: rgba(50, 180, 90, .45) !important;
            }

            .medical-revive-btn:disabled {
                opacity: .55 !important;
                cursor: not-allowed !important;
            }

            .medical-dead-mark {
                display: inline-block;
                margin-top: 8px;
                padding: 4px 8px;
                border-radius: 999px;
                color: #ffd1d1;
                background: rgba(170, 20, 20, .25);
                border: 1px solid rgba(255, 80, 80, .25);
                font-size: 12px;
            }

            select[data-cw-native-hidden="1"] {
                display: none !important;
            }

            .cw-custom-select {
                position: relative;
                width: 100%;
                min-width: 210px;
                font-family: inherit;
                z-index: 20;
            }

            .cw-custom-select.open {
                z-index: 2000;
            }

            .cw-custom-select-button {
                width: 100%;
                min-height: 48px;
                padding: 0 42px 0 16px;
                border: 2px solid #3b210f;
                background: rgba(255, 244, 205, .58);
                color: #2b1608;
                font-family: Georgia, serif;
                font-size: 16px;
                line-height: 1.15;
                text-align: left;
                cursor: pointer;
                position: relative;
            }

            .cw-custom-select-button::after {
                content: '';
                position: absolute;
                right: 14px;
                top: 50%;
                width: 0;
                height: 0;
                margin-top: -2px;
                border-left: 6px solid transparent;
                border-right: 6px solid transparent;
                border-top: 7px solid #3b210f;
            }

            .cw-custom-select-button:disabled {
                opacity: .55;
                cursor: not-allowed;
            }

            .cw-custom-select-list {
                display: none;
                position: absolute;
                left: 0;
                right: 0;
                top: calc(100% + 4px);
                max-height: 220px;
                overflow-y: auto;
                border: 2px solid #3b210f;
                background: #ead396;
                box-shadow: 0 16px 30px rgba(0, 0, 0, .45);
                padding: 4px;
            }

            .cw-custom-select.open .cw-custom-select-list {
                display: block;
            }

            .cw-custom-select-option {
                display: block;
                width: 100%;
                padding: 10px 12px;
                border: 0;
                background: transparent;
                color: #2b1608;
                font-family: Georgia, serif;
                font-size: 15px;
                text-align: left;
                cursor: pointer;
            }

            .cw-custom-select-option:hover,
            .cw-custom-select-option.selected {
                background: #4d3119;
                color: #f3dfaa;
            }

            .cw-custom-select-option[disabled] {
                opacity: .55;
                cursor: not-allowed;
            }
        `;

        document.head.appendChild(style);
    }

    function getState() {
        if (window.State) return window.State;

        try {
            if (State) return State;
        } catch (_) {}

        return null;
    }

    function getPlayerFromState(source) {
        const state = getState();
        if (!state || !Array.isArray(state.players)) return null;

        return state.players.find((player) => Number(player.source) === Number(source)) || null;
    }

    function injectCharacterSettingsPanel() {
        const view = document.getElementById('view-characters');
        if (!view || document.getElementById('medicalSettingsPanel')) return;

        const searchRow = view.querySelector('.search-row');
        const panel = document.createElement('div');

        panel.id = 'medicalSettingsPanel';
        panel.className = 'medical-admin-panel';
        panel.innerHTML = `
            <h3>Перманентная смерть</h3>
            <div class="medical-row">
                <label>Шанс смерти:</label>
                <input id="medicalChanceRange" type="range" min="0" max="100" step="1" value="15" />
                <input id="medicalChanceInput" type="number" min="0" max="100" step="1" value="15" />
                <span>%</span>
                <button id="medicalChanceSave" type="button">Сохранить</button>
                <button id="medicalChanceRefresh" type="button">Обновить</button>
            </div>
            <div id="medicalChanceStatus" class="medical-note">
                Настройка применяется к новой рулетке при нокдауне.
            </div>
        `;

        if (searchRow) {
            view.insertBefore(panel, searchRow);
        } else {
            view.prepend(panel);
        }

        const range = document.getElementById('medicalChanceRange');
        const input = document.getElementById('medicalChanceInput');
        const save = document.getElementById('medicalChanceSave');
        const refresh = document.getElementById('medicalChanceRefresh');

        function syncFromRange() {
            if (input && range) input.value = range.value;
        }

        function syncFromInput() {
            if (!input || !range) return;

            let value = Number(input.value) || 0;
            value = Math.max(0, Math.min(100, Math.floor(value)));

            input.value = value;
            range.value = value;
        }

        if (range) range.addEventListener('input', syncFromRange);
        if (input) input.addEventListener('input', syncFromInput);

        if (save) {
            save.addEventListener('click', () => {
                syncFromInput();
                resourcePost('medicalSetPermadeathChance', {
                    chance: Number(input ? input.value : 15)
                });
            });
        }

        if (refresh) {
            refresh.addEventListener('click', () => resourcePost('medicalGetSettings'));
        }

        resourcePost('medicalGetSettings');
    }

    function addReviveButtonsToPlayers() {
        const list = document.getElementById('playerList');
        if (!list) return;

        const cards = list.querySelectorAll('.player-card');

        cards.forEach((card) => {
            if (card.querySelector('[data-medical-revive-player]')) return;

            const title = card.querySelector('h3');
            const actions = card.querySelector('.player-actions');

            if (!title || !actions) return;

            const match = title.textContent.match(/^\[(\d+)\]/);
            if (!match) return;

            const source = Number(match[1]);
            const player = getPlayerFromState(source);
            const isPermadead = isTruthyFlag(player?.character?.is_dead);

            const button = document.createElement('button');
            button.textContent = isPermadead ? 'Пермакилл' : 'Возродить';
            button.className = 'medical-revive-btn';
            button.dataset.medicalRevivePlayer = String(source);
            button.disabled = isPermadead;
            button.title = isPermadead
                ? 'Нельзя возродить через Игроки. Сначала сними пермакилл во вкладке Персонажи.'
                : 'Возродить игрока на текущем персонаже и текущем месте.';

            button.addEventListener('click', () => {
                if (button.disabled) return;

                resourcePost('medicalRevivePlayer', {
                    source
                });
            });

            actions.appendChild(button);
        });
    }

    function addReviveButtonsToCharacters() {
        const state = getState();
        const list = document.getElementById('characterList');

        if (!state || !Array.isArray(state.characters) || !list) return;

        const cards = list.querySelectorAll('.character-card');

        cards.forEach((card, index) => {
            const character = state.characters[index];
            if (!character) return;

            const isDead = isTruthyFlag(character.is_dead);

            if (isDead && !card.querySelector('.medical-dead-mark')) {
                const mark = document.createElement('div');
                mark.className = 'medical-dead-mark';
                mark.textContent = 'Перма-килл';
                card.appendChild(mark);
            }

            if (!isDead || card.querySelector('[data-medical-revive-character]')) return;

            const actions = card.querySelector('.character-actions') || card;
            const button = document.createElement('button');

            button.textContent = 'Снять пермакилл / оживить';
            button.className = 'medical-revive-btn';
            button.dataset.medicalReviveCharacter = String(character.id);
            button.title = 'Снимает is_dead у персонажа. Если игрок онлайн на этом персонаже — возрождает его на месте.';

            button.addEventListener('click', () => {
                resourcePost('medicalReviveCharacter', {
                    id: character.id
                });

                setTimeout(() => {
                    const search = document.getElementById('searchBtn');
                    if (search) search.click();
                }, 700);
            });

            actions.appendChild(button);
        });
    }

    function closeAllCustomSelects(except) {
        document.querySelectorAll('.cw-custom-select.open').forEach((custom) => {
            if (custom !== except) custom.classList.remove('open');
        });
    }

    function getOptionText(option) {
        return option ? option.textContent.trim() : '';
    }

    function rebuildCustomSelect(select) {
        const custom = select._cwCustomSelect;
        if (!custom) return;

        const button = custom.querySelector('.cw-custom-select-button');
        const list = custom.querySelector('.cw-custom-select-list');

        if (!button || !list) return;

        const options = Array.from(select.options || []);
        const selectedOption = options.find((option) => option.value === select.value) || options[0] || null;
        const selectedText = getOptionText(selectedOption) || 'Выбрать';

        button.textContent = selectedText;
        button.disabled = select.disabled || options.length <= 0;
        list.innerHTML = '';

        options.forEach((option) => {
            const item = document.createElement('button');
            item.type = 'button';
            item.className = 'cw-custom-select-option';
            item.textContent = getOptionText(option) || option.value || '-';
            item.disabled = option.disabled;

            if (option.value === select.value) {
                item.classList.add('selected');
            }

            item.addEventListener('click', () => {
                if (item.disabled) return;

                select.value = option.value;
                select.dispatchEvent(new Event('change', { bubbles: true }));
                closeAllCustomSelects();
                rebuildCustomSelect(select);
            });

            list.appendChild(item);
        });
    }

    function createCustomSelect(select) {
        if (!select || select._cwCustomSelect) {
            if (select && select._cwCustomSelect) rebuildCustomSelect(select);
            return;
        }

        select.dataset.cwNativeHidden = '1';
        select.blur();

        const custom = document.createElement('div');
        custom.className = 'cw-custom-select';
        custom.dataset.forSelect = select.id || '';
        custom.innerHTML = `
            <button class="cw-custom-select-button" type="button">Выбрать</button>
            <div class="cw-custom-select-list"></div>
        `;

        select.insertAdjacentElement('afterend', custom);
        select._cwCustomSelect = custom;

        const button = custom.querySelector('.cw-custom-select-button');

        button.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();

            if (button.disabled) return;

            const willOpen = !custom.classList.contains('open');
            closeAllCustomSelects(custom);
            custom.classList.toggle('open', willOpen);
        });

        select.addEventListener('change', () => rebuildCustomSelect(select));

        new MutationObserver(() => rebuildCustomSelect(select)).observe(select, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['disabled', 'selected', 'value']
        });

        rebuildCustomSelect(select);
    }

    function installCustomSelects() {
        createCustomSelect(document.getElementById('managementPlayer'));
        createCustomSelect(document.getElementById('managementRole'));
    }

    function installManagementGuard() {
        const button = document.getElementById('managementSetRoleBtn');
        if (!button || button.dataset.cwGuardInstalled === '1') return;

        button.dataset.cwGuardInstalled = '1';

        button.addEventListener('click', (event) => {
            const playerSelect = document.getElementById('managementPlayer');
            const identifierInput = document.getElementById('managementIdentifier');
            const roleSelect = document.getElementById('managementRole');

            const source = playerSelect && playerSelect.value ? Number(playerSelect.value) : null;
            const identifier = identifierInput ? identifierInput.value.trim() : '';
            const role = roleSelect ? roleSelect.value : '';

            if (!source && !identifier) {
                event.preventDefault();
                event.stopImmediatePropagation();
                setNotice('Выбери онлайн-игрока или укажи identifier.', 'error');
                return false;
            }

            if (!role) {
                event.preventDefault();
                event.stopImmediatePropagation();
                setNotice('Выбери роль.', 'error');
                return false;
            }

            closeAllCustomSelects();
            return true;
        }, true);
    }

    function watchLists() {
        const playerList = document.getElementById('playerList');
        const characterList = document.getElementById('characterList');

        if (playerList && !playerList.dataset.medicalWatch) {
            playerList.dataset.medicalWatch = '1';

            new MutationObserver(() => setTimeout(addReviveButtonsToPlayers, 0)).observe(playerList, {
                childList: true,
                subtree: true
            });
        }

        if (characterList && !characterList.dataset.medicalWatch) {
            characterList.dataset.medicalWatch = '1';

            new MutationObserver(() => setTimeout(addReviveButtonsToCharacters, 0)).observe(characterList, {
                childList: true,
                subtree: true
            });
        }
    }

    function applySettings(payload) {
        payload = payload || {};

        const value = Number(payload.permadeathChance);
        const chance = Number.isFinite(value) ? value : 15;

        const range = document.getElementById('medicalChanceRange');
        const input = document.getElementById('medicalChanceInput');
        const status = document.getElementById('medicalChanceStatus');

        if (range) range.value = chance;
        if (input) input.value = chance;
        if (status) status.textContent = `Текущий шанс перманентной смерти: ${chance}%.`;
    }

    function init() {
        injectStyle();
        injectCharacterSettingsPanel();
        watchLists();
        installCustomSelects();
        installManagementGuard();

        setTimeout(addReviveButtonsToPlayers, 0);
        setTimeout(addReviveButtonsToCharacters, 0);
        setTimeout(installCustomSelects, 0);
    }

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        if (data.action === 'medical:settings') {
            applySettings(data.payload);
        }

        if (
            data.action === 'characters:set' ||
            data.action === 'players:set' ||
            data.action === 'management:set' ||
            data.action === 'setVisible' ||
            data.action === 'open' ||
            data.action === 'panel:open'
        ) {
            setTimeout(init, 50);
        }

        if (data.action === 'ui:close') {
            closeAllCustomSelects();
        }
    });

    document.addEventListener('click', () => closeAllCustomSelects());
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') closeAllCustomSelects();
    });

    document.addEventListener('DOMContentLoaded', init);
    setTimeout(init, 500);
})();
