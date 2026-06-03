(function () {
    'use strict';

    function setNotice(message, type) {
        const notice = document.getElementById('notice');

        if (!notice) return;

        notice.textContent = message || '';
        notice.className = type || '';
    }

    function injectStyle() {
        if (document.getElementById('managementUiStyle')) return;

        const style = document.createElement('style');
        style.id = 'managementUiStyle';
        style.textContent = `
            #view-management select[data-cw-management-native-hidden="1"] {
                display: none !important;
            }

            .cw-management-select {
                position: relative;
                width: 100%;
                min-width: 210px;
                font-family: inherit;
                z-index: 20;
            }

            .cw-management-select.open {
                z-index: 2000;
            }

            .cw-management-select-button {
                width: 100%;
                min-height: 48px;
                padding: 0 42px 0 16px;
                border: 2px solid #3b210f;
                background: #f1dfaa;
                color: #2b1608;
                font-family: Georgia, serif;
                font-size: 16px;
                line-height: 1.15;
                text-align: left;
                cursor: pointer;
                position: relative;
                text-transform: none;
                letter-spacing: 0;
                font-weight: normal;
            }

            .cw-management-select-button:hover {
                background: #f1dfaa;
                color: #2b1608;
            }

            .cw-management-select-button::after {
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

            .cw-management-select-button:disabled {
                opacity: .55;
                cursor: not-allowed;
            }

            .cw-management-select-list {
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

            .cw-management-select.open .cw-management-select-list {
                display: block;
            }

            .cw-management-select-option {
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
                text-transform: none;
                letter-spacing: 0;
                font-weight: normal;
            }

            .cw-management-select-option:hover,
            .cw-management-select-option.selected {
                background: #4d3119;
                color: #f3dfaa;
            }

            .cw-management-select-option[disabled] {
                opacity: .55;
                cursor: not-allowed;
            }
        `;

        document.head.appendChild(style);
    }

    function closeAllCustomSelects(except) {
        document.querySelectorAll('.cw-management-select.open').forEach((custom) => {
            if (custom !== except) {
                custom.classList.remove('open');
            }
        });
    }

    function getOptionText(option) {
        return option ? option.textContent.trim() : '';
    }

    function rebuildCustomSelect(select) {
        const custom = select && select._cwManagementSelect;

        if (!custom) return;

        const button = custom.querySelector('.cw-management-select-button');
        const list = custom.querySelector('.cw-management-select-list');

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
            item.className = 'cw-management-select-option';
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
        if (!select) return;

        if (select._cwManagementSelect) {
            rebuildCustomSelect(select);
            return;
        }

        select.dataset.cwManagementNativeHidden = '1';
        select.blur();

        const custom = document.createElement('div');
        custom.className = 'cw-management-select';
        custom.dataset.forSelect = select.id || '';
        custom.innerHTML = `
            <button type="button" class="cw-management-select-button">Выбрать</button>
            <div class="cw-management-select-list"></div>
        `;

        select.insertAdjacentElement('afterend', custom);
        select._cwManagementSelect = custom;

        const button = custom.querySelector('.cw-management-select-button');

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

        if (!button || button.dataset.cwManagementGuardInstalled === '1') return;

        button.dataset.cwManagementGuardInstalled = '1';

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

    function init() {
        injectStyle();
        installCustomSelects();
        installManagementGuard();

        setTimeout(installCustomSelects, 0);
    }

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        if (
            data.action === 'management:set' ||
            data.action === 'players:set' ||
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
        if (event.key === 'Escape') {
            closeAllCustomSelects();
        }
    });

    document.addEventListener('DOMContentLoaded', init);
    setTimeout(init, 500);
})();
