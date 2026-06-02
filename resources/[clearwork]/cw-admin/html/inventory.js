(function () {
    'use strict';

    var DEBUG = true;
    var CELL = 34;

    var lastCharacters = [];
    var currentAdminRole = null;
    var modal = null;
    var modalBody = null;
    var activePayload = null;
    var activeState = null;
    var activeCharacterId = null;
    var selectedCatalog = null;
    var selectedAmount = 1;
    var selectedRotated = false;
    var activeCategory = 'all';
    var customDrag = null;
    var dragGhost = null;
    var dragOverElement = null;
    var suppressNextCatalogClick = false;

    var categoryLabels = {
        all: 'Все',
        accessory: 'Украшения',
        ammo: 'Патроны',
        clothing: 'Одежда',
        drink: 'Напитки',
        food: 'Еда',
        medical: 'Медицина',
        weapon: 'Оружие',
        misc: 'Прочее'
    };

    var defaultEquipmentSlots = [
        { id: 'hat', label: 'Головной убор' },
        { id: 'coat', label: 'Верхняя одежда' },
        { id: 'shirt', label: 'Рубаха' },
        { id: 'pants', label: 'Штаны' },
        { id: 'boots', label: 'Обувь' },
        { id: 'vest', label: 'Разгрузка' },
        { id: 'holster_left', label: 'Кобура Л' },
        { id: 'holster_right', label: 'Кобура П' },
        { id: 'back_long_1', label: 'Двуручное 1' },
        { id: 'back_long_2', label: 'Двуручное 2' },
        { id: 'accessory_1', label: 'Украшение 1' },
        { id: 'accessory_2', label: 'Украшение 2' }
    ];

    var defaultContainers = [
        { id: 'pockets', label: 'Карманы', width: 4, height: 2, order: 10, fallback: true },
        { id: 'belt', label: 'Пояс', width: 3, height: 1, order: 20, fallback: true }
    ];

    function debug() {
        if (!DEBUG || !window.console || !console.log) return;
        var args = Array.prototype.slice.call(arguments);
        args.unshift('[cw-admin:inventory:nui:debug]');
        console.log.apply(console, args);
    }

    function warn() {
        if (!window.console || !console.warn) return;
        var args = Array.prototype.slice.call(arguments);
        args.unshift('[cw-admin:inventory:nui:warn]');
        console.warn.apply(console, args);
    }

    function post(name, data) {
        debug('post', name, data || {});
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(function (err) {
            warn('post failed', name, err);
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

    function normalizeNumber(value) {
        var n = Number(value);
        return Number.isFinite(n) ? n : null;
    }

    function canUseInventory() {
        return currentAdminRole === 'owner' || currentAdminRole === 'general' || currentAdminRole === 'admin';
    }

    function countMap(value) {
        if (!value || typeof value !== 'object') return 0;
        var count = 0;
        Object.keys(value).forEach(function () { count++; });
        return count;
    }

    function resolveCharacterId() {
        var payload = activePayload || {};
        var state = activeState || payload.state || {};
        var character = payload.character || {};

        var candidates = [
            activeCharacterId,
            payload.characterId,
            payload.character_id,
            character.id,
            character.character_id,
            state.character_id,
            state.characterId
        ];

        for (var i = 0; i < candidates.length; i++) {
            var id = normalizeNumber(candidates[i]);
            if (id && id > 0) return id;
        }

        if (modalBody && modalBody.dataset && modalBody.dataset.characterId) {
            var fromDataset = normalizeNumber(modalBody.dataset.characterId);
            if (fromDataset && fromDataset > 0) return fromDataset;
        }

        return null;
    }

    function characterName(character) {
        character = character || {};
        return String((character.firstname || '') + ' ' + (character.lastname || '')).trim() || ('Character #' + (resolveCharacterId() || '-'));
    }

    function cloneList(list) {
        return (list || []).map(function (item) {
            var out = {};
            Object.keys(item || {}).forEach(function (key) { out[key] = item[key]; });
            return out;
        });
    }

    function normalizeState(payload) {
        payload = payload || {};
        var raw = payload.state || {};
        var state = {};
        Object.keys(raw).forEach(function (key) { state[key] = raw[key]; });

        if (!Array.isArray(state.items)) state.items = [];
        if (!state.equipment || typeof state.equipment !== 'object') state.equipment = {};

        if (!Array.isArray(state.containers) || state.containers.length === 0) {
            state.containers = cloneList(defaultContainers);
            state._containersFallback = true;
        }

        if (!Array.isArray(state.equipmentSlots) || state.equipmentSlots.length === 0) {
            state.equipmentSlots = cloneList(defaultEquipmentSlots);
            state._equipmentFallback = true;
        }

        if (!state.definitions || typeof state.definitions !== 'object') {
            state.definitions = payload.definitions || {};
        }

        return state;
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
            '.inventory-modal-box { width: 1160px; max-width: 94vw; max-height: 84vh; overflow: hidden; }',
            '.inventory-head { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; margin-bottom: 12px; }',
            '.inventory-head h2 { margin: 0; }',
            '.inventory-head-actions { display: grid; grid-template-columns: 140px 140px; gap: 8px; }',
            '.inventory-debug-line { border: 1px solid rgba(139,0,0,.45); background: rgba(139,0,0,.08); padding: 6px; margin: 8px 0 10px; font-size: 12px; }',
            '.inventory-main-grid { display: grid; grid-template-columns: 240px minmax(430px, 1fr) 315px; gap: 12px; max-height: 64vh; overflow: hidden; }',
            '.inventory-column { min-height: 0; overflow-y: auto; padding-right: 4px; }',
            '.inventory-block { border: 2px solid #3b210f; background: rgba(255,244,205,.55); padding: 10px; margin-bottom: 10px; }',
            '.inventory-block h3 { margin: 0 0 8px; font-size: 20px; }',
            '.inventory-small { font-size: 13px; opacity: .85; }',
            '.admin-equip-list { display: grid; gap: 6px; }',
            '.admin-equip-slot { border: 1px solid rgba(59,33,15,.65); background: rgba(241,223,170,.5); min-height: 52px; padding: 7px; }',
            '.admin-equip-slot.drag-over, .admin-inv-cell.drag-over { outline: 2px solid #8b0000; outline-offset: -2px; }',
            '.slot-title { font-weight: 700; letter-spacing: .05em; text-transform: uppercase; font-size: 12px; }',
            '.empty-slot { font-size: 13px; opacity: .68; margin-top: 5px; font-style: italic; }',
            '.admin-equip-item { margin-top: 5px; border: 1px solid rgba(59,33,15,.45); padding: 5px; background: rgba(59,33,15,.12); }',
            '.admin-container-head { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 8px; }',
            '.admin-inv-grid { position: relative; display: grid; border: 1px solid rgba(59,33,15,.6); background: rgba(0,0,0,.05); width: max-content; }',
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
            '.admin-catalog-drag-ghost { position: fixed; z-index: 999999; pointer-events: none; border: 2px solid rgba(59,33,15,.9); background: rgba(241,223,170,.96); color: #2b180c; padding: 7px 10px; min-width: 150px; box-shadow: 0 4px 12px rgba(0,0,0,.35); font-weight: 700; }',
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
            if (event.target === modal) closeModal();
        });
    }

    function closeModal() {
        if (modal) modal.classList.add('hidden');
        activePayload = null;
        activeState = null;
        activeCharacterId = null;
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
        return item.label || item.item_label || item.item_name || item.name || '-';
    }

    function getAllDefinitions() {
        if (!activePayload) return [];
        return sortDefinitions(activePayload.definitions || (activeState && activeState.definitions) || {});
    }

    function postAddItem(target) {
        if (!activePayload || !selectedCatalog) {
            warn('postAddItem skipped: no payload or no selected item', activePayload, selectedCatalog);
            return;
        }

        var characterId = resolveCharacterId();
        target = target || {};
        if (characterId) {
            target.characterId = characterId;
            target.character_id = characterId;
        }

        var payload = {
            characterId: characterId,
            character_id: characterId,
            itemName: selectedCatalog.name,
            amount: selectedAmount || 1,
            metadata: '{}',
            reason: 'cw-admin inventory panel drag/drop',
            target: target
        };

        debug('add item payload', payload);
        post('characterInventoryAddItem', payload);
    }

    function parseDragData(event) {
        try {
            var raw = event.dataTransfer.getData('application/json') || event.dataTransfer.getData('text/plain');
            if (!raw) return null;
            return JSON.parse(raw);
        } catch (e) {
            warn('bad drag data', e);
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

    function closestElement(element, selector) {
        while (element && element !== document) {
            if (element.matches && element.matches(selector)) return element;
            element = element.parentNode;
        }
        return null;
    }

    function clearDragOverElement() {
        if (dragOverElement && dragOverElement.classList) {
            dragOverElement.classList.remove('drag-over');
        }
        dragOverElement = null;
    }

    function setDragOverElement(element) {
        if (dragOverElement === element) return;
        clearDragOverElement();
        dragOverElement = element || null;
        if (dragOverElement && dragOverElement.classList) {
            dragOverElement.classList.add('drag-over');
        }
    }

    function destroyDragGhost() {
        if (dragGhost && dragGhost.parentNode) {
            dragGhost.parentNode.removeChild(dragGhost);
        }
        dragGhost = null;
        clearDragOverElement();
    }

    function updateDragGhost(x, y) {
        if (!customDrag || !customDrag.dragging) return;

        if (!dragGhost) {
            dragGhost = document.createElement('div');
            dragGhost.className = 'admin-catalog-drag-ghost';
            dragGhost.textContent = (customDrag.item.label || customDrag.item.name) + ' x' + customDrag.amount;
            document.body.appendChild(dragGhost);
        }

        dragGhost.style.left = (x + 12) + 'px';
        dragGhost.style.top = (y + 12) + 'px';

        var under = document.elementFromPoint(x, y);
        var cell = closestElement(under, '.admin-inv-cell');
        var slot = closestElement(under, '.admin-equip-slot');
        setDragOverElement(cell || slot || null);
    }

    function startCatalogMouseDrag(event, item) {
        if (!event || event.button !== 0) return;
        if (closestElement(event.target, 'input, textarea, select, button')) return;

        var amount = 1;
        if (event.ctrlKey) {
            var asked = askAmount(item);
            if (asked === null) return;
            amount = asked;
        }

        var keepRotated = selectedCatalog && selectedCatalog.name === item.name && selectedRotated === true;

        customDrag = {
            item: item,
            amount: amount,
            rotated: keepRotated,
            startX: event.clientX,
            startY: event.clientY,
            dragging: false
        };
    }

    function finishCatalogMouseDrag(event) {
        if (!customDrag) return false;

        var drag = customDrag;
        customDrag = null;

        if (!drag.dragging) {
            destroyDragGhost();
            return false;
        }

        if (event && event.preventDefault) event.preventDefault();
        if (event && event.stopPropagation) event.stopPropagation();
        suppressNextCatalogClick = true;

        selectedCatalog = drag.item;
        selectedAmount = drag.amount;
        selectedRotated = drag.rotated === true;

        var x = event && typeof event.clientX === 'number' ? event.clientX : drag.startX;
        var y = event && typeof event.clientY === 'number' ? event.clientY : drag.startY;
        var under = document.elementFromPoint(x, y);
        var cell = closestElement(under, '.admin-inv-cell');
        var slot = closestElement(under, '.admin-equip-slot');

        debug('custom drag finish', {
            itemName: drag.item && drag.item.name,
            amount: drag.amount,
            rotated: drag.rotated,
            hasCell: !!cell,
            hasSlot: !!slot,
            underClass: under && under.className
        });

        destroyDragGhost();

        if (cell) {
            postAddItem({
                type: 'container',
                containerId: cell.dataset.container,
                container_id: cell.dataset.container,
                x: Number(cell.dataset.x),
                y: Number(cell.dataset.y),
                rotated: selectedRotated === true
            });
            return true;
        }

        if (slot) {
            postAddItem({ type: 'slot', slot: slot.dataset.slot });
            return true;
        }

        debug('custom drag cancelled: no valid target');
        return true;
    }

    function dropToTarget(event, target) {
        event.preventDefault();
        event.stopPropagation();
        if (event.currentTarget) event.currentTarget.classList.remove('drag-over');

        var data = parseDragData(event);
        debug('drop target', target, 'dragData', data);

        if (data && data.itemName) {
            selectedCatalog = data.item || findDefinition(data.itemName);
            selectedAmount = data.amount || 1;
            selectedRotated = data.rotated === true;
        }

        postAddItem(target);
    }

    function findDefinition(name) {
        var list = getAllDefinitions();
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === name) return list[i];
        }
        return null;
    }

    function renderEquipment(state) {
        var equipment = state.equipment || {};
        var slots = state.equipmentSlots || state.equipment_slots || [];

        return '<div class="admin-equip-list">' + slots.map(function (slot) {
            var slotId = slot.id || slot.slot;
            var item = equipment[slotId] || null;
            return '' +
                '<div class="admin-equip-slot" data-slot="' + escapeHtml(slotId) + '">' +
                    '<div class="slot-title">' + escapeHtml(slot.label || slotId) + '</div>' +
                    (item
                        ? '<div class="admin-equip-item"><b>' + escapeHtml(itemLabel(item)) + '</b><br>#' + escapeHtml(item.id) + ' | ' + escapeHtml(item.item_name) + '</div>'
                        : '<div class="empty-slot">пусто</div>') +
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

        return containers.map(function (container) {
            var rows = byContainer[container.id] || [];
            var w = Number(container.width || 1) || 1;
            var h = Number(container.height || 1) || 1;
            var html = '' +
                '<div class="inventory-block">' +
                    '<div class="admin-container-head">' +
                        '<h3>' + escapeHtml(container.label || container.id) + '</h3>' +
                        '<b>' + escapeHtml(w) + 'x' + escapeHtml(h) + '</b>' +
                    '</div>' +
                    '<div class="admin-inv-grid" style="grid-template-columns: repeat(' + w + ', ' + CELL + 'px); grid-template-rows: repeat(' + h + ', ' + CELL + 'px);">';

            for (var y = 0; y < h; y++) {
                for (var x = 0; x < w; x++) {
                    html += '<div class="admin-inv-cell" data-container="' + escapeHtml(container.id) + '" data-x="' + x + '" data-y="' + y + '"></div>';
                }
            }

            rows.forEach(function (item) {
                var itemW = Number(item.width || item.w || 1) || 1;
                var itemH = Number(item.height || item.h || 1) || 1;
                if (item.rotated === true || item.rotated === 1) {
                    var tmp = itemW;
                    itemW = itemH;
                    itemH = tmp;
                }

                html += '' +
                    '<div class="admin-grid-item" style="left:' + ((Number(item.x) || 0) * CELL) + 'px; top:' + ((Number(item.y) || 0) * CELL) + 'px; width:' + (itemW * CELL) + 'px; height:' + (itemH * CELL) + 'px;">' +
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

        return '' +
            '<table class="inventory-log-table">' +
                '<thead><tr><th>Время</th><th>Действие</th><th>Предмет</th><th>Кол-во</th><th>Откуда</th><th>Куда</th></tr></thead>' +
                '<tbody>' + logs.slice(0, 50).map(function (log) {
                    return '' +
                        '<tr>' +
                            '<td>' + escapeHtml(log.created_at || '-') + '</td>' +
                            '<td>' + escapeHtml(log.action || '-') + '</td>' +
                            '<td>' + escapeHtml(log.item_name || '-') + '</td>' +
                            '<td>' + escapeHtml(log.amount || '-') + '</td>' +
                            '<td>' + escapeHtml(log.from_container || log.from_slot || '-') + '</td>' +
                            '<td>' + escapeHtml(log.to_container || log.to_slot || '-') + '</td>' +
                        '</tr>';
                }).join('') + '</tbody>' +
            '</table>';
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

    function renderCatalog() {
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

        return '' +
            '<h3>Предметы</h3>' +
            '<div class="admin-catalog-controls">' +
                '<input id="adminCatalogSearch" type="text" placeholder="Поиск предмета">' +
                '<div class="admin-selected-line">' + escapeHtml(selectedText) + '<br>Перетащи предмет в слот. Ctrl при выборе — количество. R — повернуть.</div>' +
            '</div>' +
            '<div class="admin-catalog-tabs">' + cats.map(function (cat) {
                return '<button type="button" class="catalog-tab' + (activeCategory === cat ? ' active' : '') + '" data-category="' + escapeHtml(cat) + '">' + escapeHtml(categoryLabels[cat] || cat) + '</button>';
            }).join('') + '</div>' +
            '<div class="admin-catalog-list">' + list.map(function (item) {
                var size = effectiveSize(item);
                var selectedClass = selectedCatalog && selectedCatalog.name === item.name ? ' selected' : '';
                return '' +
                    '<div class="admin-catalog-item' + selectedClass + '" draggable="false" data-item="' + escapeHtml(item.name) + '">' +
                        '<div class="admin-catalog-title"><span>' + escapeHtml(item.label) + '</span><span>' + escapeHtml(size.w) + 'x' + escapeHtml(size.h) + '</span></div>' +
                        '<div class="inventory-small">' + escapeHtml(item.name) + ' | ' + escapeHtml(categoryLabels[item.category] || item.category) + ' | stack ' + escapeHtml(item.stack) + '</div>' +
                        (item.description ? '<div class="admin-catalog-desc">' + escapeHtml(item.description) + '</div>' : '') +
                    '</div>';
            }).join('') + '</div>';
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
                    container_id: cell.dataset.container,
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
                    container_id: cell.dataset.container,
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
            search.addEventListener('input', function () {
                renderModal(activePayload, true);
            });
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

            row.addEventListener('mousedown', function (event) {
                startCatalogMouseDrag(event, item);
            });

            row.addEventListener('click', function (event) {
                if (suppressNextCatalogClick) {
                    event.preventDefault();
                    event.stopPropagation();
                    suppressNextCatalogClick = false;
                    return;
                }

                if (event.ctrlKey) {
                    var amount = askAmount(item);
                    if (amount === null) return;
                    selectedAmount = amount;
                } else {
                    selectedAmount = 1;
                }

                selectedCatalog = item;
                selectedRotated = false;
                debug('selected catalog item', item.name, 'amount', selectedAmount);
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
                    item: item,
                    characterId: resolveCharacterId(),
                    character_id: resolveCharacterId()
                };

                debug('native dragstart catalog item fallback', payload);
                event.dataTransfer.setData('application/json', JSON.stringify(payload));
                event.dataTransfer.setData('text/plain', JSON.stringify(payload));
            });
        });
    }

    function renderDebugLine(payload, state) {
        var definitions = payload.definitions || state.definitions || {};
        return '' +
            '<div class="inventory-debug-line">' +
                '<b>DEBUG:</b> characterId=' + escapeHtml(resolveCharacterId() || '-') +
                ' | state.character_id=' + escapeHtml(state.character_id || state.characterId || '-') +
                ' | revision=' + escapeHtml(state.revision || 0) +
                ' | containers=' + escapeHtml((state.containers || []).length) + (state._containersFallback ? ' fallback' : '') +
                ' | equipmentSlots=' + escapeHtml((state.equipmentSlots || []).length) + (state._equipmentFallback ? ' fallback' : '') +
                ' | items=' + escapeHtml((state.items || []).length) +
                ' | definitions=' + escapeHtml(countMap(definitions)) +
            '</div>';
    }

    function renderModal(payload, keepSearch) {
        ensureModal();

        activePayload = payload || activePayload || {};
        activeState = normalizeState(activePayload);

        var oldSearch = '';
        var search = document.getElementById('adminCatalogSearch');
        if (keepSearch && search) oldSearch = search.value || '';

        activeCharacterId = resolveCharacterId();
        if (!activeCharacterId) {
            var character = activePayload.character || {};
            activeCharacterId = normalizeNumber(character.id || activeState.character_id || activePayload.characterId || activePayload.character_id);
        }

        var characterData = activePayload.character || {};
        var logs = activePayload.logs || [];
        var title = characterName(characterData);
        var itemCount = (activeState.items || []).length;

        debug('render modal', {
            characterId: activeCharacterId,
            stateCharacterId: activeState.character_id || activeState.characterId,
            revision: activeState.revision,
            containers: (activeState.containers || []).length,
            equipmentSlots: (activeState.equipmentSlots || []).length,
            items: itemCount,
            definitions: countMap(activePayload.definitions || activeState.definitions || {}),
            fallbackContainers: activeState._containersFallback === true,
            fallbackEquipment: activeState._equipmentFallback === true
        });

        modalBody.dataset.characterId = activeCharacterId || '';
        modalBody.innerHTML = '' +
            '<div class="inventory-head">' +
                '<div>' +
                    '<h2>Инвентарь: ' + escapeHtml(title) + '</h2>' +
                    '<div class="inventory-small">Character ID: ' + escapeHtml(activeCharacterId || '-') + ' | Account ID: ' + escapeHtml(characterData.account_id || '-') + ' | Revision: ' + escapeHtml(activeState.revision || 0) + ' | Предметов: ' + escapeHtml(itemCount) + '</div>' +
                '</div>' +
                '<div class="inventory-head-actions"><button type="button" id="inventoryRefreshBtn">Обновить</button><button type="button" id="inventoryCloseBtn">Закрыть</button></div>' +
            '</div>' +
            renderDebugLine(activePayload, activeState) +
            '<div class="inventory-main-grid">' +
                '<div class="inventory-column">' +
                    '<div class="inventory-block"><h3>Экипировка</h3>' + renderEquipment(activeState) + '</div>' +
                '</div>' +
                '<div class="inventory-column">' +
                    renderContainers(activeState) +
                    '<div class="inventory-block"><h3>Логи инвентаря</h3>' + renderLogs(logs) + '</div>' +
                '</div>' +
                '<div class="inventory-column inventory-block">' + renderCatalog() + '</div>' +
            '</div>';

        var newSearch = document.getElementById('adminCatalogSearch');
        if (keepSearch && newSearch) newSearch.value = oldSearch;

        document.getElementById('inventoryCloseBtn').addEventListener('click', closeModal);
        document.getElementById('inventoryRefreshBtn').addEventListener('click', function () {
            post('characterInventoryRefresh', { characterId: resolveCharacterId(), character_id: resolveCharacterId() });
        });

        bindDropTargets();
        bindCatalog();
        modal.classList.remove('hidden');
    }

    function decorateCharacterCards(characters) {
        characters = characters || lastCharacters || [];
        if (!canUseInventory()) {
            debug('decorate skipped role', currentAdminRole);
            return;
        }

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
                activeCharacterId = Number(character.id);
                debug('open inventory button', character);
                post('characterInventoryOpen', { characterId: character.id, character_id: character.id });
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

    var observer = new MutationObserver(function () {
        if (lastCharacters && lastCharacters.length) {
            decorateCharacterCards(lastCharacters);
        }
    });

    document.addEventListener('DOMContentLoaded', function () {
        observer.observe(document.body, { childList: true, subtree: true });
    });

    document.addEventListener('mousemove', function (event) {
        if (!customDrag) return;

        var dx = Math.abs((event.clientX || 0) - customDrag.startX);
        var dy = Math.abs((event.clientY || 0) - customDrag.startY);

        if (!customDrag.dragging && (dx > 4 || dy > 4)) {
            customDrag.dragging = true;
            selectedCatalog = customDrag.item;
            selectedAmount = customDrag.amount;
            selectedRotated = customDrag.rotated === true;
            debug('custom drag start', {
                itemName: customDrag.item && customDrag.item.name,
                amount: customDrag.amount,
                rotated: customDrag.rotated
            });
        }

        if (customDrag.dragging) {
            event.preventDefault();
            updateDragGhost(event.clientX, event.clientY);
        }
    });

    document.addEventListener('mouseup', function (event) {
        finishCatalogMouseDrag(event);
    });

    document.addEventListener('keydown', function (event) {
        if (!activePayload || !selectedCatalog) return;
        if (event.key === 'r' || event.key === 'R' || event.key === 'к' || event.key === 'К') {
            selectedRotated = !selectedRotated;
            debug('rotate selected item', selectedCatalog.name, selectedRotated);
            renderModal(activePayload, true);
        }
    });

    window.addEventListener('message', function (event) {
        var data = event.data || {};

        if ((data.action === 'panel:open' || data.action === 'dashboard:set') && data.payload && data.payload.admin) {
            currentAdminRole = data.payload.admin.role || null;
            debug('admin role from message', data.action, currentAdminRole);
            setTimeout(function () { decorateCharacterCards(lastCharacters); }, 0);
        }

        if (data.action === 'characters:set') {
            lastCharacters = data.characters || [];
            debug('characters:set count', lastCharacters.length);
            setTimeout(function () { decorateCharacterCards(lastCharacters); }, 30);
            return;
        }

        if (data.action === 'inventory:receive') {
            debug('inventory:receive raw payload', data.payload || {});
            renderModal(data.payload || {}, false);
            return;
        }

        if (data.action === 'ui:close') {
            closeModal();
        }
    });
})();
