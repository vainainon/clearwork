(function () {
    'use strict';

    var CELL = 34;
    var lastCharacters = [];
    var currentAdminRole = null;
    var modal = null;
    var modalBody = null;
    var activePayload = null;
    var selectedCatalog = null;
    var selectedAmount = 1;
    var selectedRotated = false;
    var activeCategory = 'all';

    var categoryLabels = {
        all: 'Все',
        food: 'Еда',
        drink: 'Напитки',
        medical: 'Медицина',
        ammo: 'Патроны',
        weapon: 'Оружие',
        clothing: 'Одежда',
        accessory: 'Украшения',
        misc: 'Прочее'
    };

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

    function clampAmount(raw, max) {
        var value = Math.floor(Number(raw) || 1);
        max = Math.floor(Number(max) || 500);
        if (value < 1) value = 1;
        if (value > max) value = max;
        return value;
    }

    function askAmount(item) {
        var stack = Number(item && item.stack ? item.stack : 1) || 1;
        var max = Math.max(1, Math.min(stack, 500));
        var raw = window.prompt('Количество для ' + (item.label || item.name) + ' (1-' + max + '):', String(Math.min(selectedAmount || 1, max)));
        if (raw === null) return null;
        return clampAmount(raw, max);
    }

    function effectiveSize(item) {
        var w = Number(item && item.width ? item.width : 1) || 1;
        var h = Number(item && item.height ? item.height : 1) || 1;
        if (selectedCatalog && item && item.name === selectedCatalog.name && selectedRotated) {
            return { w: h, h: w };
        }
        return { w: w, h: h };
    }

    function injectStyle() {
        if (document.getElementById('cwAdminInventoryStyle')) return;

        var style = document.createElement('style');
        style.id = 'cwAdminInventoryStyle';
        style.textContent = [
            '.inventory-extra-actions { margin-top: 10px; display: grid; grid-template-columns: 1fr; gap: 8px; }',
            '.inventory-extra-actions button { background: #3b210f; }',
            '.inventory-modal-box { width: 1260px; max-width: 94vw; max-height: 84vh; overflow: hidden; }',
            '.inventory-head { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; margin-bottom: 12px; }',
            '.inventory-head h2 { margin: 0; }',
            '.inventory-head-actions { display: grid; grid-template-columns: 140px 140px; gap: 8px; }',
            '.inventory-main-grid { display: grid; grid-template-columns: 245px minmax(430px, 1fr) 320px; gap: 12px; max-height: 64vh; overflow: hidden; }',
            '.inventory-column { min-height: 0; overflow-y: auto; padding-right: 4px; }',
            '.inventory-block { border: 2px solid #3b210f; background: rgba(255,244,205,.55); padding: 10px; margin-bottom: 10px; }',
            '.inventory-block h3 { margin: 0 0 8px; font-size: 20px; }',
            '.inventory-small { font-size: 13px; opacity: .85; }',
            '.admin-equip-list { display: grid; gap: 6px; }',
            '.admin-equip-slot { border: 1px solid rgba(59,33,15,.65); background: rgba(241,223,170,.5); min-height: 54px; padding: 7px; }',
            '.admin-equip-slot.drag-over, .admin-inv-cell.drag-over { outline: 2px solid #8b0000; outline-offset: -2px; }',
            '.slot-title { font-weight: 700; letter-spacing: .05em; text-transform: uppercase; font-size: 12px; }',
            '.empty-slot { font-size: 13px; opacity: .68; margin-top: 5px; font-style: italic; }',
            '.admin-equip-item { margin-top: 5px; border: 1px solid rgba(59,33,15,.45); padding: 5px; background: rgba(59,33,15,.12); }',
            '.admin-container-head { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 8px; }',
            '.admin-inv-grid { position: relative; display: grid; border: 1px solid rgba(59,33,15,.6); background: rgba(0,0,0,.05); }',
            '.admin-inv-cell { width: ' + CELL + 'px; height: ' + CELL + 'px; border-right: 1px solid rgba(59,33,15,.24); border-bottom: 1px solid rgba(59,33,15,.24); box-sizing: border-box; }',
            '.admin-grid-item { position: absolute; box-sizing: border-box; border: 2px solid rgba(59,33,15,.8); background: rgba(59,33,15,.18); padding: 4px; overflow: hidden; pointer-events: none; }',
            '.admin-grid-item .item-name { font-weight: 700; font-size: 12px; line-height: 1.1; }',
            '.admin-grid-item .item-meta { font-size: 11px; opacity: .8; margin-top: 3px; }',
            '.admin-catalog-tabs { display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 8px; }',
            '.admin-catalog-tabs button { padding: 7px 9px; font-size: 12px; }',
            '.admin-catalog-tabs button.active { background: #8b0000; }',
            '.admin-catalog-list { display: grid; gap: 6px; }',
            '.admin-catalog-item { border: 1px solid rgba(59,33,15,.6); background: rgba(241,223,170,.58); padding: 7px; cursor: grab; user-select: none; }',
            '.admin-catalog-item.selected { outline: 2px solid #8b0000; background: rgba(255,244,205,.92); }',
            '.admin-catalog-item:active { cursor: grabbing; }',
            '.admin-catalog-title { display: flex; justify-content: space-between; gap: 8px; font-weight: 700; }',
            '.admin-catalog-desc { margin-top: 4px; font-size: 12px; opacity: .78; }',
            '.admin-catalog-controls { display: grid; gap: 6px; margin-bottom: 8px; }',
            '.admin-catalog-controls input { padding: 8px; font-size: 14px; }',
            '.admin-selected-line { border: 1px solid rgba(59,33,15,.5); padding: 7px; background: rgba(59,33,15,.08); font-size: 13px; }',
            '.inventory-log-table { width: 100%; border-collapse: collapse; font-size: 12px; }',
            '.inventory-log-table th, .inventory-log-table td { border: 1px solid rgba(59,33,15,.45); padding: 5px; vertical-align: top; }',
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
        selectedCatalog = null;
        selectedAmount = 1;
        selectedRotated = false;
    }

    function sortDefinitions(definitions) {
        var list = [];
        Object.keys(definitions || {}).forEach(function (name) {
            var def = definitions[name] || {};
            list.push({
                name: name,
                label: def.label || name,
                description: def.description || '',
                category: def.category || 'misc',
                type: def.type || 'item',
                width: Number(def.width || 1) || 1,
                height: Number(def.height || 1) || 1,
                stack: Number(def.stack || 1) || 1
            });
        });
        list.sort(function (a, b) {
            if (String(a.category) !== String(b.category)) return String(a.category).localeCompare(String(b.category), 'ru');
            return String(a.label).localeCompare(String(b.label), 'ru');
        });
        return list;
    }

    function itemLabel(item) {
        if (!item) return '-';
        return item.label || item.item_name || item.name || '-';
    }

    function getAllDefinitions() {
        if (!activePayload) return [];
        return sortDefinitions(activePayload.definitions || (activePayload.state && activePayload.state.definitions) || {});
    }

    function postAddItem(target) {
        if (!activePayload || !selectedCatalog) return;
        var character = activePayload.character || {};
        var state = activePayload.state || {};
        post('characterInventoryAddItem', {
            characterId: character.id || state.character_id,
            itemName: selectedCatalog.name,
            amount: selectedAmount || 1,
            metadata: '{}',
            reason: 'cw-admin inventory panel',
            target: target || {}
        });
    }

    function parseDragData(event) {
        try {
            var raw = event.dataTransfer.getData('application/json') || event.dataTransfer.getData('text/plain');
            if (!raw) return null;
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    function acceptDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        if (event.currentTarget) event.currentTarget.classList.add('drag-over');
    }

    function leaveDrop(event) {
        if (event.currentTarget) event.currentTarget.classList.remove('drag-over');
    }

    function dropToTarget(event, target) {
        event.preventDefault();
        event.stopPropagation();
        if (event.currentTarget) event.currentTarget.classList.remove('drag-over');

        var data = parseDragData(event);
        if (data && data.itemName) {
            selectedCatalog = data.item;
            selectedAmount = data.amount || 1;
            selectedRotated = data.rotated === true;
        }

        postAddItem(target);
    }

    function renderEquipment(state) {
        var equipment = state.equipment || {};
        var slots = state.equipmentSlots || [];

        if (!slots.length) {
            return '<div class="inventory-small">Слоты экипировки не загружены.</div>';
        }

        return '<div class="admin-equip-list">' + slots.map(function (slot) {
            var item = equipment[slot.id];
            return '<div class="admin-equip-slot" data-slot="' + escapeHtml(slot.id) + '">' +
                '<div class="slot-title">' + escapeHtml(slot.label || slot.id) + '</div>' +
                (item ? '<div class="admin-equip-item"><b>' + escapeHtml(itemLabel(item)) + '</b><br><span class="inventory-small">#' + escapeHtml(item.id) + ' | ' + escapeHtml(item.item_name) + '</span></div>' : '<div class="empty-slot">пусто</div>') +
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

        var containers = state.containers || [];
        if (!containers.length) {
            return '<div class="inventory-block"><h3>Лоты инвентаря</h3><div class="inventory-small">Контейнеры не загружены. Сделай refresh + restart cw-inventory, затем restart cw-admin.</div></div>';
        }

        return containers.map(function (container) {
            var rows = byContainer[container.id] || [];
            var w = Number(container.width || 1) || 1;
            var h = Number(container.height || 1) || 1;
            var html = '<div class="inventory-block"><div class="admin-container-head"><h3>' + escapeHtml(container.label || container.id) + '</h3><span class="inventory-small">' + escapeHtml(w) + 'x' + escapeHtml(h) + '</span></div>';
            html += '<div class="admin-inv-grid" data-container="' + escapeHtml(container.id) + '" style="grid-template-columns: repeat(' + w + ', ' + CELL + 'px); grid-template-rows: repeat(' + h + ', ' + CELL + 'px); width: ' + (w * CELL) + 'px; height: ' + (h * CELL) + 'px;">';

            for (var y = 0; y < h; y++) {
                for (var x = 0; x < w; x++) {
                    html += '<div class="admin-inv-cell" data-container="' + escapeHtml(container.id) + '" data-x="' + x + '" data-y="' + y + '"></div>';
                }
            }

            rows.forEach(function (item) {
                html += '<div class="admin-grid-item" style="left:' + (Number(item.x || 0) * CELL) + 'px; top:' + (Number(item.y || 0) * CELL) + 'px; width:' + (Number(item.width || 1) * CELL) + 'px; height:' + (Number(item.height || 1) * CELL) + 'px;">' +
                    '<div class="item-name">' + escapeHtml(itemLabel(item)) + '</div>' +
                    '<div class="item-meta">' + (Number(item.amount || 1) > 1 ? 'x' + escapeHtml(item.amount) + ' ' : '') + '#' + escapeHtml(item.id) + '</div>' +
                    '</div>';
            });

            html += '</div></div>';
            return html;
        }).join('');
    }

    function renderLogs(logs) {
        logs = logs || [];
        if (!logs.length) {
            return '<div class="inventory-small">Логов пока нет.</div>';
        }

        return '<table class="inventory-log-table"><thead><tr>' +
            '<th>Время</th><th>Действие</th><th>Предмет</th><th>Кол-во</th><th>Откуда</th><th>Куда</th>' +
            '</tr></thead><tbody>' + logs.slice(0, 50).map(function (log) {
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

    function getCategories(definitions) {
        var seen = { all: true };
        var cats = ['all'];
        definitions.forEach(function (item) {
            var cat = item.category || 'misc';
            if (!seen[cat]) {
                seen[cat] = true;
                cats.push(cat);
            }
        });
        return cats;
    }

    function renderCatalog(payload) {
        var definitions = getAllDefinitions();
        var search = document.getElementById('adminCatalogSearch');
        var query = search ? String(search.value || '').toLowerCase() : '';
        var cats = getCategories(definitions);
        var list = definitions.filter(function (item) {
            if (activeCategory !== 'all' && item.category !== activeCategory) return false;
            if (!query) return true;
            return String(item.label + ' ' + item.name + ' ' + item.description).toLowerCase().indexOf(query) !== -1;
        });

        var selectedText = 'Ничего не выбрано';
        if (selectedCatalog) {
            var size = effectiveSize(selectedCatalog);
            selectedText = selectedCatalog.label + ' — ' + selectedCatalog.name + ' | x' + selectedAmount + ' | ' + size.w + 'x' + size.h + (selectedRotated ? ' | повёрнут' : '');
        }

        return '<div class="inventory-block"><h3>Предметы</h3>' +
            '<div class="admin-catalog-controls">' +
                '<input id="adminCatalogSearch" type="text" placeholder="Поиск предмета" value="' + escapeHtml(query) + '">' +
                '<div class="admin-selected-line">' + escapeHtml(selectedText) + '<br><span class="inventory-small">Перетащи предмет в слот. Ctrl при выборе — количество. R — повернуть.</span></div>' +
            '</div>' +
            '<div class="admin-catalog-tabs">' + cats.map(function (cat) {
                return '<button type="button" class="catalog-tab ' + (cat === activeCategory ? 'active' : '') + '" data-category="' + escapeHtml(cat) + '">' + escapeHtml(categoryLabels[cat] || cat) + '</button>';
            }).join('') + '</div>' +
            '<div class="admin-catalog-list">' + list.map(function (item) {
                var size = effectiveSize(item);
                return '<div class="admin-catalog-item' + (selectedCatalog && selectedCatalog.name === item.name ? ' selected' : '') + '" draggable="true" data-item="' + escapeHtml(item.name) + '">' +
                    '<div class="admin-catalog-title"><span>' + escapeHtml(item.label) + '</span><span>' + escapeHtml(size.w) + 'x' + escapeHtml(size.h) + '</span></div>' +
                    '<div class="inventory-small">' + escapeHtml(item.name) + ' | ' + escapeHtml(categoryLabels[item.category] || item.category) + ' | stack ' + escapeHtml(item.stack) + '</div>' +
                    (item.description ? '<div class="admin-catalog-desc">' + escapeHtml(item.description) + '</div>' : '') +
                    '</div>';
            }).join('') + '</div></div>';
    }

    function bindDropTargets() {
        var cells = modalBody.querySelectorAll('.admin-inv-cell');
        Array.prototype.forEach.call(cells, function (cell) {
            cell.addEventListener('dragover', acceptDrop);
            cell.addEventListener('dragleave', leaveDrop);
            cell.addEventListener('drop', function (event) {
                dropToTarget(event, {
                    type: 'container',
                    containerId: cell.dataset.container,
                    x: Number(cell.dataset.x),
                    y: Number(cell.dataset.y),
                    rotated: selectedRotated === true
                });
            });
            cell.addEventListener('click', function () {
                if (!selectedCatalog) return;
                postAddItem({
                    type: 'container',
                    containerId: cell.dataset.container,
                    x: Number(cell.dataset.x),
                    y: Number(cell.dataset.y),
                    rotated: selectedRotated === true
                });
            });
        });

        var slots = modalBody.querySelectorAll('.admin-equip-slot');
        Array.prototype.forEach.call(slots, function (slot) {
            slot.addEventListener('dragover', acceptDrop);
            slot.addEventListener('dragleave', leaveDrop);
            slot.addEventListener('drop', function (event) {
                dropToTarget(event, { type: 'slot', slot: slot.dataset.slot });
            });
            slot.addEventListener('click', function () {
                if (!selectedCatalog) return;
                postAddItem({ type: 'slot', slot: slot.dataset.slot });
            });
        });
    }

    function bindCatalog() {
        var definitions = getAllDefinitions();
        var byName = {};
        definitions.forEach(function (item) { byName[item.name] = item; });

        var search = document.getElementById('adminCatalogSearch');
        if (search) {
            search.addEventListener('input', function () { renderModal(activePayload, true); });
        }

        var tabs = modalBody.querySelectorAll('.catalog-tab');
        Array.prototype.forEach.call(tabs, function (tab) {
            tab.addEventListener('click', function () {
                activeCategory = tab.dataset.category || 'all';
                renderModal(activePayload, true);
            });
        });

        var rows = modalBody.querySelectorAll('.admin-catalog-item');
        Array.prototype.forEach.call(rows, function (row) {
            var item = byName[row.dataset.item];
            if (!item) return;

            row.addEventListener('click', function (event) {
                if (event.ctrlKey) {
                    var amount = askAmount(item);
                    if (amount === null) return;
                    selectedAmount = amount;
                } else {
                    selectedAmount = 1;
                }
                selectedCatalog = item;
                selectedRotated = false;
                renderModal(activePayload, true);
            });

            row.addEventListener('dragstart', function (event) {
                var amount = 1;
                if (!selectedCatalog || selectedCatalog.name !== item.name) {
                    selectedRotated = false;
                }
                if (event.ctrlKey) {
                    var asked = askAmount(item);
                    if (asked === null) {
                        event.preventDefault();
                        return;
                    }
                    amount = asked;
                }
                selectedCatalog = item;
                selectedAmount = amount;
                var payload = {
                    itemName: item.name,
                    amount: amount,
                    rotated: selectedRotated === true,
                    item: item
                };
                event.dataTransfer.setData('application/json', JSON.stringify(payload));
                event.dataTransfer.setData('text/plain', JSON.stringify(payload));
            });
        });
    }

    function renderModal(payload, keepSearch) {
        ensureModal();
        activePayload = payload || activePayload || {};

        var oldSearch = '';
        var search = document.getElementById('adminCatalogSearch');
        if (keepSearch && search) oldSearch = search.value || '';

        var character = activePayload.character || {};
        var state = activePayload.state || {};
        var logs = activePayload.logs || [];
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
            '<div class="inventory-main-grid">' +
                '<div class="inventory-column"><div class="inventory-block"><h3>Экипировка</h3>' + renderEquipment(state) + '</div></div>' +
                '<div class="inventory-column">' + renderContainers(state) + '<div class="inventory-block"><h3>Логи инвентаря</h3>' + renderLogs(logs) + '</div></div>' +
                '<div class="inventory-column">' + renderCatalog(activePayload) + '</div>' +
            '</div>';

        var newSearch = document.getElementById('adminCatalogSearch');
        if (keepSearch && newSearch) newSearch.value = oldSearch;

        document.getElementById('inventoryCloseBtn').addEventListener('click', closeModal);
        document.getElementById('inventoryRefreshBtn').addEventListener('click', function () {
            post('characterInventoryRefresh', { characterId: character.id || state.character_id });
        });

        bindDropTargets();
        bindCatalog();
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

    document.addEventListener('keydown', function (event) {
        if (!activePayload || !selectedCatalog) return;
        if (event.key === 'r' || event.key === 'R' || event.key === 'к' || event.key === 'К') {
            selectedRotated = !selectedRotated;
            renderModal(activePayload, true);
        }
    });

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
            renderModal(data.payload || {}, false);
            return;
        }

        if (data.action === 'ui:close') {
            closeModal();
        }
    });
})();
