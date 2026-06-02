(function () {
    'use strict';

    var lastCharacters = [];
    var currentAdminRole = null;
    var modal = null;
    var modalBody = null;
    var activePayload = null;

    function post(name, data) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        });
    }

    function escapeHtml(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function canUseInventory() {
        return currentAdminRole === 'owner' || currentAdminRole === 'general' || currentAdminRole === 'admin';
    }

    function characterName(character) {
        character = character || {};
        return String((character.firstname || '') + ' ' + (character.lastname || '')).trim() || ('Character #' + character.id);
    }

    function injectStyle() {
        if (document.getElementById('cwAdminInventoryStyle')) return;

        var style = document.createElement('style');
        style.id = 'cwAdminInventoryStyle';
        style.textContent = [
            '.inventory-extra-actions { margin-top: 10px; display: grid; grid-template-columns: 1fr; gap: 8px; }',
            '.inventory-extra-actions button { background: #3b210f; }',
            '.inventory-modal-box { width: 960px; max-width: 92vw; max-height: 82vh; overflow-y: auto; }',
            '.inventory-head { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; margin-bottom: 14px; }',
            '.inventory-head h2 { margin: 0; }',
            '.inventory-head-actions { display: grid; grid-template-columns: 150px 150px; gap: 8px; }',
            '.inventory-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }',
            '.inventory-block { border: 2px solid #3b210f; background: rgba(255,244,205,.52); padding: 12px; margin-bottom: 12px; }',
            '.inventory-block h3 { margin: 0 0 8px; font-size: 20px; }',
            '.inventory-small { font-size: 13px; opacity: .85; }',
            '.inventory-items-list { display: grid; gap: 6px; }',
            '.inventory-item-row { border: 1px solid rgba(59,33,15,.45); padding: 7px; background: rgba(241,223,170,.55); }',
            '.inventory-form { display: grid; grid-template-columns: 1.4fr 90px; gap: 8px; }',
            '.inventory-form textarea { grid-column: 1 / 3; min-height: 70px; resize: vertical; }',
            '.inventory-form input, .inventory-form select, .inventory-form textarea { font-size: 14px; padding: 9px; }',
            '.inventory-form button { grid-column: 1 / 3; }',
            '.inventory-log-table { width: 100%; border-collapse: collapse; font-size: 13px; }',
            '.inventory-log-table th, .inventory-log-table td { border: 1px solid rgba(59,33,15,.45); padding: 6px; vertical-align: top; }',
            '.inventory-log-table th { background: rgba(59,33,15,.12); }'
        ].join('\n');
        document.head.appendChild(style);
    }

    function ensureModal() {
        if (modal) return;

        injectStyle();

        modal = document.createElement('div');
        modal.id = 'inventoryModal';
        modal.className = 'modal hidden';
        modal.innerHTML = '<div class="modal-box inventory-modal-box"><div id="inventoryModalBody"></div></div>';

        var panel = document.querySelector('.panel') || document.body;
        panel.appendChild(modal);
        modalBody = document.getElementById('inventoryModalBody');

        modal.addEventListener('click', function (event) {
            if (event.target === modal) {
                closeModal();
            }
        });
    }

    function closeModal() {
        if (modal) modal.classList.add('hidden');
        activePayload = null;
    }

    function sortDefinitions(definitions) {
        var list = [];
        Object.keys(definitions || {}).forEach(function (name) {
            var def = definitions[name] || {};
            list.push({ name: name, label: def.label || name, type: def.type || 'item' });
        });
        list.sort(function (a, b) {
            return String(a.label).localeCompare(String(b.label), 'ru');
        });
        return list;
    }

    function itemLabel(item) {
        if (!item) return '-';
        return item.label || item.item_name || item.name || '-';
    }

    function renderEquipment(state) {
        var equipment = state.equipment || {};
        var slots = state.equipmentSlots || [];

        if (!slots.length) {
            return '<div class="inventory-small">Слоты экипировки не загружены.</div>';
        }

        return '<div class="inventory-items-list">' + slots.map(function (slot) {
            var item = equipment[slot.id];
            return '<div class="inventory-item-row"><b>' + escapeHtml(slot.label || slot.id) + '</b><br>' +
                (item ? escapeHtml(itemLabel(item)) + ' <span class="inventory-small">#' + escapeHtml(item.id) + '</span>' : '<span class="inventory-small">пусто</span>') +
                '</div>';
        }).join('') + '</div>';
    }

    function renderContainers(state) {
        var items = state.items || [];
        var byContainer = {};

        items.forEach(function (item) {
            if (!item.container_id || item.equip_slot) return;
            byContainer[item.container_id] = byContainer[item.container_id] || [];
            byContainer[item.container_id].push(item);
        });

        return (state.containers || []).map(function (container) {
            var rows = byContainer[container.id] || [];
            var html = '<div class="inventory-block"><h3>' + escapeHtml(container.label || container.id) +
                ' <span class="inventory-small">' + escapeHtml(container.width) + 'x' + escapeHtml(container.height) + '</span></h3>';

            if (!rows.length) {
                html += '<div class="inventory-small">Пусто.</div>';
            } else {
                html += '<div class="inventory-items-list">' + rows.map(function (item) {
                    return '<div class="inventory-item-row"><b>' + escapeHtml(itemLabel(item)) + '</b> x' + escapeHtml(item.amount || 1) +
                        '<br><span class="inventory-small">#' + escapeHtml(item.id) + ' | ' + escapeHtml(item.item_name) +
                        ' | ' + escapeHtml(item.width) + 'x' + escapeHtml(item.height) +
                        ' | x:' + escapeHtml(item.x) + ' y:' + escapeHtml(item.y) + '</span></div>';
                }).join('') + '</div>';
            }

            return html + '</div>';
        }).join('');
    }

    function renderLogs(logs) {
        logs = logs || [];
        if (!logs.length) {
            return '<div class="inventory-small">Логов пока нет.</div>';
        }

        return '<table class="inventory-log-table"><thead><tr>' +
            '<th>Время</th><th>Действие</th><th>Предмет</th><th>Кол-во</th><th>Откуда</th><th>Куда</th>' +
            '</tr></thead><tbody>' + logs.slice(0, 80).map(function (log) {
                return '<tr>' +
                    '<td>' + escapeHtml(log.created_at || '-') + '</td>' +
                    '<td>' + escapeHtml(log.action || '-') + '</td>' +
                    '<td>' + escapeHtml(log.item_name || '-') + '</td>' +
                    '<td>' + escapeHtml(log.amount || '-') + '</td>' +
                    '<td>' + escapeHtml(log.from_container || log.from_slot || '-') + '</td>' +
                    '<td>' + escapeHtml(log.to_container || log.to_slot || '-') + '</td>' +
                    '</tr>';
            }).join('') + '</tbody></table>';
    }

    function renderAddForm(payload) {
        var definitions = sortDefinitions(payload.definitions || (payload.state && payload.state.definitions) || {});
        var options = definitions.map(function (item) {
            return '<option value="' + escapeHtml(item.name) + '">' + escapeHtml(item.label) + ' — ' + escapeHtml(item.name) + '</option>';
        }).join('');

        return '<div class="inventory-block"><h3>Выдать предмет</h3>' +
            '<div class="inventory-form">' +
            '<select id="inventoryItemName"><option value="">Выбрать предмет</option>' + options + '</select>' +
            '<input id="inventoryItemAmount" type="number" min="1" max="500" value="1">' +
            '<textarea id="inventoryItemMetadata" placeholder="Metadata JSON, можно оставить пустым"></textarea>' +
            '<input id="inventoryItemReason" type="text" placeholder="Причина / комментарий" value="cw-admin">' +
            '<button id="inventoryAddItemBtn" type="button">Выдать предмет</button>' +
            '</div></div>';
    }

    function renderModal(payload) {
        ensureModal();
        activePayload = payload || {};

        var character = payload.character || {};
        var state = payload.state || {};
        var logs = payload.logs || [];
        var title = characterName(character);
        var itemCount = (state.items || []).length;

        modalBody.innerHTML =
            '<div class="inventory-head">' +
                '<div><h2>Инвентарь: ' + escapeHtml(title) + '</h2>' +
                '<div class="inventory-small">Character ID: ' + escapeHtml(character.id || state.character_id || '-') +
                ' | Account ID: ' + escapeHtml(character.account_id || '-') +
                ' | Revision: ' + escapeHtml(state.revision || 0) +
                ' | Предметов: ' + escapeHtml(itemCount) + '</div></div>' +
                '<div class="inventory-head-actions">' +
                    '<button id="inventoryRefreshBtn" type="button">Обновить</button>' +
                    '<button id="inventoryCloseBtn" type="button">Закрыть</button>' +
                '</div>' +
            '</div>' +
            renderAddForm(payload) +
            '<div class="inventory-layout">' +
                '<div>' +
                    '<div class="inventory-block"><h3>Экипировка</h3>' + renderEquipment(state) + '</div>' +
                    renderContainers(state) +
                '</div>' +
                '<div><div class="inventory-block"><h3>Логи инвентаря</h3>' + renderLogs(logs) + '</div></div>' +
            '</div>';

        document.getElementById('inventoryCloseBtn').addEventListener('click', closeModal);
        document.getElementById('inventoryRefreshBtn').addEventListener('click', function () {
            post('characterInventoryRefresh', { characterId: character.id || state.character_id });
        });
        document.getElementById('inventoryAddItemBtn').addEventListener('click', function () {
            var itemName = document.getElementById('inventoryItemName').value;
            var amount = document.getElementById('inventoryItemAmount').value;
            var metadata = document.getElementById('inventoryItemMetadata').value;
            var reason = document.getElementById('inventoryItemReason').value;

            post('characterInventoryAddItem', {
                characterId: character.id || state.character_id,
                itemName: itemName,
                amount: amount,
                metadata: metadata,
                reason: reason
            });
        });

        modal.classList.remove('hidden');
    }

    function decorateCharacterCards(characters) {
        characters = characters || lastCharacters || [];
        if (!canUseInventory()) return;

        var cards = document.querySelectorAll('#characterList .character-card');
        Array.prototype.forEach.call(cards, function (card, index) {
            if (card.dataset.inventoryPatched === '1') return;
            var character = characters[index];
            if (!character || !character.id) return;

            card.dataset.inventoryPatched = '1';

            var wrap = document.createElement('div');
            wrap.className = 'inventory-extra-actions';

            var btn = document.createElement('button');
            btn.type = 'button';
            btn.textContent = 'Инвентарь';
            btn.addEventListener('click', function () {
                post('characterInventoryOpen', { characterId: character.id });
            });

            wrap.appendChild(btn);
            card.appendChild(wrap);
        });
    }

    if (typeof window.renderCharacters === 'function') {
        var originalRenderCharacters = window.renderCharacters;
        window.renderCharacters = function (characters) {
            lastCharacters = characters || [];
            originalRenderCharacters(characters);
            setTimeout(function () { decorateCharacterCards(lastCharacters); }, 0);
        };
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};

        if ((data.action === 'panel:open' || data.action === 'dashboard:set') && data.payload && data.payload.admin) {
            currentAdminRole = data.payload.admin.role || null;
            setTimeout(function () { decorateCharacterCards(lastCharacters); }, 0);
        }

        if (data.action === 'characters:set') {
            lastCharacters = data.characters || [];
            setTimeout(function () { decorateCharacterCards(lastCharacters); }, 30);
            return;
        }

        if (data.action === 'inventory:receive') {
            renderModal(data.payload || {});
            return;
        }

        if (data.action === 'ui:close') {
            closeModal();
        }
    });
})();
