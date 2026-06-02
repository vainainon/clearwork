(function () {
    'use strict';

    var DEBUG = false;
    var INVENTORY_JS_VERSION = 'v29-admin-clean-logs';
    var CELL = 56;

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
    var dragPreviewElements = [];
    var dragPreviewKey = '';
    var suppressNextCatalogClick = false;
    var inventoryDrag = null;
    var inventoryDragGhost = null;
    var suppressNextInventoryClick = false;
    var pendingInventoryMoveAmounts = {};
    var adminQuantityDialog = null;
    var catalogInfoItem = null;

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

    var COWBOY_BG_DATA_URL = 'paperdoll_silhouette.png';

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
        { id: 'main', label: 'Основной', width: 8, height: 5, order: 10, fallback: true }
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
        debug('post', name, data || {}, 'jsVersion', INVENTORY_JS_VERSION);
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

    function catalogDefaultAmount(item) {
        return Math.max(1, Math.floor(Number(item && item.stack ? item.stack : 1) || 1));
    }

    function closeAdminQuantityDialog() {
        if (adminQuantityDialog && adminQuantityDialog.parentNode) adminQuantityDialog.parentNode.removeChild(adminQuantityDialog);
        adminQuantityDialog = null;
    }

    function openAdminQuantityDialog(title, max, current, onOk) {
        closeAdminQuantityDialog();
        max = Math.max(1, Math.floor(Number(max) || 1));
        current = clampAmount(current || max, max);
        adminQuantityDialog = document.createElement('div');
        adminQuantityDialog.className = 'admin-quantity-backdrop';
        adminQuantityDialog.innerHTML = '' +
            '<div class="admin-quantity-dialog">' +
                '<div class="admin-quantity-title">' + escapeHtml(title || 'Количество') + '</div>' +
                '<div class="admin-quantity-help">Максимум: ' + escapeHtml(max) + '</div>' +
                '<input class="admin-quantity-input" type="number" min="1" max="' + escapeHtml(max) + '" value="' + escapeHtml(current) + '">' +
                '<div class="admin-quantity-actions">' +
                    '<button type="button" data-action="ok">ОК</button>' +
                    '<button type="button" data-action="cancel">Отмена</button>' +
                '</div>' +
            '</div>';
        document.body.appendChild(adminQuantityDialog);
        var input = adminQuantityDialog.querySelector('.admin-quantity-input');
        setTimeout(function () { if (input) { input.focus(); input.select(); } }, 0);
        adminQuantityDialog.addEventListener('click', function (event) {
            var action = event.target && event.target.dataset ? event.target.dataset.action : '';
            if (!action) return;
            event.preventDefault();
            if (action === 'cancel') { closeAdminQuantityDialog(); return; }
            var amount = clampAmount(input && input.value, max);
            closeAdminQuantityDialog();
            if (typeof onOk === 'function') onOk(amount);
        });
        adminQuantityDialog.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') { closeAdminQuantityDialog(); return; }
            if (event.key === 'Enter') {
                var amount = clampAmount(input && input.value, max);
                closeAdminQuantityDialog();
                if (typeof onOk === 'function') onOk(amount);
            }
        });
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
            '.cw-inventory-modal-open { overflow: hidden !important; }',
            '#inventoryModal, #inventoryModal *:not(input):not(textarea) { user-select: none; -webkit-user-select: none; }',
            '#inventoryModal { position: fixed !important; inset: 0 !important; z-index: 99990 !important; background: rgba(0,0,0,.48); display: flex; align-items: center; justify-content: center; overflow: hidden !important; }',
            '#inventoryModal.hidden { display: none !important; }',
            '#inventoryModal .inventory-modal-box { width: 1480px; max-width: 96vw; max-height: 88vh; overflow: hidden !important; display: flex; flex-direction: column; }',
            '#inventoryModalBody { min-height: 0; overflow: hidden; }',
            '.inventory-head { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; margin-bottom: 12px; }',
            '.inventory-head h2 { margin: 0; }',
            '.inventory-head-actions { display: grid; grid-template-columns: 140px 140px; gap: 8px; }',
            '.inventory-debug-line { border: 1px solid rgba(139,0,0,.45); background: rgba(139,0,0,.08); padding: 6px; margin: 8px 0 10px; font-size: 12px; }',
            '.inventory-main-grid { display: grid; grid-template-columns: 430px minmax(0, 1fr) 315px; gap: 12px; height: calc(88vh - 128px); max-height: calc(88vh - 128px); overflow: hidden; }',
            '.inventory-column { min-height: 0; min-width: 0; overflow-y: auto; overflow-x: hidden; padding-right: 4px; overscroll-behavior: contain; }',
            '.inventory-block { border: 2px solid #3b210f; background: rgba(255,244,205,.55); padding: 10px; margin-bottom: 10px; }',
            '.inventory-block h3 { margin: 0 0 8px; font-size: 20px; }',
            '.inventory-small { font-size: 13px; opacity: .85; }',
            '.admin-paperdoll { position: relative; width: 400px; height: 720px; margin: 0 auto; background: linear-gradient(180deg, rgba(0,0,0,.02), rgba(0,0,0,.07)); overflow: hidden; }',
            '.admin-paperdoll::after { content: ""; position: absolute; left: 112px; top: 20px; width: 176px; height: 640px; background: url(' + COWBOY_BG_DATA_URL + ') center top / contain no-repeat; opacity: .19; filter: saturate(0) brightness(.45); pointer-events: none; z-index: 0; }',
            '.admin-equip-slot { position: absolute; width: 120px; min-height: 80px; border: 1px solid rgba(59,33,15,.65); background: rgba(241,223,170,.5); padding: 7px; z-index: 1; }',
            '.admin-equip-slot.drag-over, .admin-inv-cell.drag-over { outline: 2px solid #8b0000; outline-offset: -2px; }',
            '.admin-inv-cell.drop-preview { outline: 2px solid rgba(139,0,0,.95); outline-offset: -2px; background: rgba(139,0,0,.18); box-shadow: inset 0 0 0 1px rgba(255,244,205,.45); }',
            '.admin-equip-slot.drag-over { background: rgba(139,0,0,.14); box-shadow: inset 0 0 0 1px rgba(255,244,205,.4); }',
            '.slot-title { font-weight: 700; letter-spacing: .05em; text-transform: uppercase; font-size: 12px; }',
            '.empty-slot { font-size: 13px; opacity: .68; margin-top: 5px; font-style: italic; }',
            '.admin-equip-item { position: relative; margin-top: 5px; border: 1px solid rgba(59,33,15,.45); padding: 4px; background: rgba(59,33,15,.12); cursor: grab; user-select: none; min-height: 32px; overflow: hidden; }',
            '.admin-equip-item:hover, .admin-grid-item:hover { outline: 2px solid #8b0000; outline-offset: -2px; box-shadow: inset 0 0 0 1px rgba(255,244,205,.45); }',
            '.admin-container-head { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 8px; }',
            '.admin-inv-grid { position: relative; display: grid; border: 1px solid rgba(59,33,15,.6); background: rgba(0,0,0,.05); width: max-content; }',
            '.admin-inv-cell { width: ' + CELL + 'px; height: ' + CELL + 'px; border-right: 1px solid rgba(59,33,15,.24); border-bottom: 1px solid rgba(59,33,15,.24); box-sizing: border-box; }',
            '.admin-grid-item { position: absolute; box-sizing: border-box; border: 2px solid rgba(59,33,15,.8); background: rgba(59,33,15,.18); padding: 4px; overflow: hidden; pointer-events: auto; cursor: grab; user-select: none; }',
            '.admin-catalog-item.dragging-source, .admin-grid-item.dragging-source, .admin-equip-item.dragging-source { opacity: .32 !important; filter: grayscale(.25); }',
            '.admin-catalog-item.dragging-source *, .admin-grid-item.dragging-source *, .admin-equip-item.dragging-source * { opacity: .45 !important; }',
            '.admin-grid-item .item-name, .admin-equip-item .item-name { position: absolute; inset: 0; padding: 3px 4px 14px; display: flex; align-items: center; justify-content: center; text-align: center; font-weight: 700; font-size: 13px; line-height: 1.02; overflow-wrap: anywhere; word-break: break-word; overflow: hidden; }',
            '.admin-grid-item .item-meta, .admin-equip-item .item-meta { position: absolute; right: 2px; bottom: 1px; min-width: 14px; text-align: right; font-size: 11px; line-height: 13px; opacity: .95; background: rgba(241,223,170,.72); padding: 0 2px; z-index: 2; }',
            '.admin-equip-item { overflow-wrap: anywhere; word-break: break-word; }',
            '.admin-catalog-tabs { display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 8px; }',
            '.admin-catalog-tabs button { padding: 7px 9px; font-size: 12px; }',
            '.admin-catalog-tabs button.active { background: #8b0000; }',
            '.admin-catalog-list { display: grid; gap: 6px; }',
            '.admin-catalog-item { border: 1px solid rgba(59,33,15,.6); background: rgba(241,223,170,.58); padding: 7px; cursor: grab; user-select: none; }',
            '.admin-catalog-item:hover { outline: 2px solid #8b0000; background: rgba(255,244,205,.92); }',
            '.admin-catalog-item:active { cursor: grabbing; }',
            '.admin-catalog-drag-ghost, .admin-inventory-drag-ghost { position: fixed; z-index: 999999; pointer-events: none; border: 2px solid rgba(59,33,15,.95); background: rgba(241,223,170,.96); color: #2b180c; padding: 0; min-width: 0; box-shadow: 0 4px 12px rgba(0,0,0,.35); font-weight: 700; overflow: hidden; opacity: .58; }',
            '.admin-drag-ghost-grid { position: absolute; inset: 0; display: grid; }',
            '.admin-drag-ghost-cell { border-right: 1px solid rgba(59,33,15,.35); border-bottom: 1px solid rgba(59,33,15,.35); background: rgba(59,33,15,.09); }',
            '.admin-drag-ghost-label { position: absolute; left: 4px; right: 4px; top: 4px; font-size: 12px; line-height: 1.05; overflow: hidden; text-shadow: 0 1px 0 rgba(255,244,205,.65); }',
            '.admin-catalog-title { display: flex; justify-content: space-between; gap: 8px; font-weight: 700; align-items: center; min-height: 18px; }',
            '.admin-catalog-desc { margin-top: 4px; font-size: 12px; opacity: .78; }',
            '.admin-catalog-controls { display: grid; gap: 6px; margin-bottom: 8px; }',
            '.admin-catalog-controls input { padding: 8px; font-size: 14px; }',
            '.admin-selected-line { border: 1px solid rgba(59,33,15,.5); padding: 7px; background: rgba(59,33,15,.08); font-size: 12px; height: 96px; min-height: 96px; max-height: 96px; line-height: 1.22; overflow: hidden; }',
            '.inventory-main-grid, .inventory-column { scrollbar-width: none; }',
            '.inventory-log-wrap { max-height: 210px; overflow: auto; overscroll-behavior: contain; border: 1px solid rgba(59,33,15,.28); scrollbar-width: none; }',
            '.inventory-log-wrap::-webkit-scrollbar, .admin-catalog-list::-webkit-scrollbar { width: 0; height: 0; }',
            '.admin-catalog-list, .inventory-log-wrap { scrollbar-width: none; }',
            '.inventory-log-table { width: 100%; min-width: 620px; border-collapse: collapse; font-size: 12px; table-layout: fixed; }',
            '.inventory-log-table th, .inventory-log-table td { border: 1px solid rgba(59,33,15,.45); padding: 5px; vertical-align: top; word-break: break-word; }',
            '.inventory-log-table th { background: rgba(59,33,15,.12); position: sticky; top: 0; z-index: 1; }',
            '.inventory-log-details { margin-top: 3px; font-size: 11px; line-height: 1.15; opacity: .85; }',
            '.inventory-log-time { width: 112px; white-space: nowrap; }',
            '.inventory-log-action { width: 108px; }',
            '.inventory-log-amount { width: 48px; text-align: center; }',
            '.admin-quantity-backdrop { position: fixed; inset: 0; z-index: 1000000; display: flex; align-items: center; justify-content: center; background: rgba(0,0,0,.45); }',
            '.admin-quantity-dialog { width: 360px; border: 2px solid #3b210f; background: #e4cb86; color: #2b180c; padding: 16px; box-shadow: 0 18px 55px rgba(0,0,0,.65); }',
            '.admin-quantity-title { font-size: 20px; font-weight: 700; margin-bottom: 8px; }',
            '.admin-quantity-help { font-size: 13px; margin-bottom: 10px; }',
            '.admin-quantity-input { width: 100%; padding: 10px; border: 1px solid #3b210f; background: #f4e7b8; color: #2b180c; font-family: Georgia, serif; font-size: 16px; }',
            '.admin-quantity-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 12px; }',
            ".inventory-block h3 { margin: 0 0 10px; font-size: 18px; }",
            ".admin-paperdoll .slot-hat { top: 4px; left: 140px; }",
            ".admin-paperdoll .slot-accessory_1 { top: 28px; left: 0; }",
            ".admin-paperdoll .slot-accessory_2 { top: 28px; right: 0; }",
            ".admin-paperdoll .slot-back_long_1 { top: 128px; left: 0; }",
            ".admin-paperdoll .slot-back_long_2 { top: 128px; right: 0; }",
            ".admin-paperdoll .slot-coat { top: 108px; left: 140px; }",
            ".admin-paperdoll .slot-shirt { top: 206px; left: 140px; }",
            ".admin-paperdoll .slot-vest { top: 304px; left: 140px; }",
            ".admin-paperdoll .slot-holster_left { top: 398px; left: 0; }",
            ".admin-paperdoll .slot-holster_right { top: 398px; right: 0; }",
            ".admin-paperdoll .slot-pants { top: 410px; left: 140px; }",
            ".admin-paperdoll .slot-boots { top: 530px; left: 140px; }",
            ".admin-container-head h3 { margin:0; }",
            ".admin-inv-grid { position: relative; display: grid; border: 1px solid rgba(59,33,15,.6); background: rgba(0,0,0,.05); width: max-content; }"
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

        modal.addEventListener('wheel', function (event) {
            event.stopPropagation();
        }, { passive: true });

        modal.addEventListener('mousedown', function (event) {
            if (event.button === 1) {
                event.preventDefault();
                event.stopPropagation();
            }
        }, true);

        modal.addEventListener('auxclick', function (event) {
            if (event.button === 1) {
                event.preventDefault();
                event.stopPropagation();
            }
        }, true);
    }

    function closeModal() {
        document.body.classList.remove('cw-inventory-modal-open');
        if (modal) modal.classList.add('hidden');
        activePayload = null;
        activeState = null;
        activeCharacterId = null;
        selectedCatalog = null;
        selectedAmount = 1;
        selectedRotated = false;
        catalogInfoItem = null;
        destroyDragGhost();
        destroyInventoryDragGhost();
        customDrag = null;
        inventoryDrag = null;
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
        post('characterInventoryAddItemV14', payload);
    }

    function findStateItem(id) {
        id = Number(id);
        var items = activeState && activeState.items ? activeState.items : [];
        for (var i = 0; i < items.length; i++) {
            if (Number(items[i].id) === id) return items[i];
        }
        var equipment = activeState && activeState.equipment ? activeState.equipment : {};
        var found = null;
        Object.keys(equipment).forEach(function (slot) {
            if (!found && equipment[slot] && Number(equipment[slot].id) === id) {
                found = equipment[slot];
            }
        });
        return found;
    }

    function postMoveItem(itemId, target) {
        var characterId = resolveCharacterId();
        target = target || {};
        if (characterId) {
            target.characterId = characterId;
            target.character_id = characterId;
        }

        var payload = {
            characterId: characterId,
            character_id: characterId,
            itemId: Number(itemId),
            amount: target.amount || 1,
            split: target.split === true,
            reason: 'cw-admin inventory panel move',
            target: target
        };

        debug('move item payload', payload);
        post('characterInventoryMoveItemV17', payload);
    }

    function postDeleteItem(itemId) {
        var characterId = resolveCharacterId();
        var payload = {
            characterId: characterId,
            character_id: characterId,
            itemId: Number(itemId),
            reason: 'cw-admin inventory panel right click delete'
        };

        debug('delete item payload', payload);
        post('characterInventoryDeleteItemV17', payload);
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

    function getAdminCellFromPoint(x, y) {
        var under = document.elementFromPoint(x, y);
        var cell = closestElement(under, '.admin-inv-cell');
        if (cell) return cell;

        var grid = closestElement(under, '.admin-inv-grid');
        if (!grid) return null;

        var rect = grid.getBoundingClientRect();
        var cx = Math.floor((x - rect.left) / CELL);
        var cy = Math.floor((y - rect.top) / CELL);
        if (cx < 0 || cy < 0) return null;
        return grid.querySelector('.admin-inv-cell[data-x="' + cx + '"][data-y="' + cy + '"]');
    }

    function getAdminDropTargetFromPoint(x, y) {
        var under = document.elementFromPoint(x, y);
        var slot = closestElement(under, '.admin-equip-slot');
        var cell = getAdminCellFromPoint(x, y);
        return { cell: cell, slot: slot, under: under };
    }

    function clearDragOverElement() {
        if (dragOverElement && dragOverElement.classList) {
            dragOverElement.classList.remove('drag-over');
        }
        dragOverElement = null;

        dragPreviewElements.forEach(function (el) {
            if (el && el.classList) el.classList.remove('drop-preview');
        });
        dragPreviewElements = [];
        dragPreviewKey = '';
    }

    function collectPreviewCells(cell, size) {
        if (!cell) return [];
        size = size || { w: 1, h: 1 };
        var grid = closestElement(cell, '.admin-inv-grid');
        if (!grid) return [];

        var startX = Number(cell.dataset.x || 0);
        var startY = Number(cell.dataset.y || 0);
        var cells = [];
        for (var yy = 0; yy < size.h; yy++) {
            for (var xx = 0; xx < size.w; xx++) {
                var found = grid.querySelector('.admin-inv-cell[data-x="' + (startX + xx) + '"][data-y="' + (startY + yy) + '"]');
                if (found) cells.push(found);
            }
        }
        return cells;
    }

    function setDragPreview(target, size) {
        var element = target && (target.cell || target.slot) ? (target.cell || target.slot) : null;
        size = size || { w: 1, h: 1 };
        var key = 'none';
        if (target && target.cell) {
            key = 'cell:' + (target.cell.dataset.container || '') + ':' + (target.cell.dataset.x || '0') + ':' + (target.cell.dataset.y || '0') + ':' + size.w + 'x' + size.h;
        } else if (target && target.slot) {
            key = 'slot:' + (target.slot.dataset.slot || '');
        }
        if (dragOverElement === element && dragPreviewKey === key && dragPreviewElements.length) return;

        clearDragOverElement();
        dragPreviewKey = key;
        dragOverElement = element || null;

        if (!dragOverElement || !dragOverElement.classList) return;
        dragOverElement.classList.add('drag-over');

        if (target && target.cell) {
            dragPreviewElements = collectPreviewCells(target.cell, size);
            dragPreviewElements.forEach(function (cell) { cell.classList.add('drop-preview'); });
        }
    }

    function destroyDragGhost() {
        if (dragGhost && dragGhost.parentNode) {
            dragGhost.parentNode.removeChild(dragGhost);
        }
        dragGhost = null;
        clearDragOverElement();
    }

    function clearSourceElement(source) {
        if (source && source.classList) source.classList.remove('dragging-source');
    }

    function updateDragGhost(x, y) {
        if (!customDrag || !customDrag.dragging) return;
        customDrag.lastX = x;
        customDrag.lastY = y;

        if (!dragGhost) {
            dragGhost = document.createElement('div');
            dragGhost.className = 'admin-catalog-drag-ghost';
            document.body.appendChild(dragGhost);
        }

        fillDragGhost(
            dragGhost,
            (customDrag.item.label || customDrag.item.name) + ' x' + customDrag.amount,
            visualSizeFromDefinition(customDrag.item, customDrag.rotated === true),
            CELL
        );

        dragGhost.style.left = (x + 12) + 'px';
        dragGhost.style.top = (y + 12) + 'px';

        var target = getAdminDropTargetFromPoint(x, y);
        setDragPreview(target, visualSizeFromDefinition(customDrag.item, customDrag.rotated === true));
    }

    function startCatalogMouseDrag(event, item) {
        if (!event || event.button !== 0) return;
        if (closestElement(event.target, 'input, textarea, select, button')) return;

        var amount = catalogDefaultAmount(item);
        var keepRotated = selectedCatalog && selectedCatalog.name === item.name && selectedRotated === true;

        customDrag = {
            item: item,
            amount: amount,
            ctrlAmount: event.ctrlKey === true,
            rotated: keepRotated,
            sourceElement: closestElement(event.target, '.admin-catalog-item'),
            startX: event.clientX,
            startY: event.clientY,
            lastX: event.clientX,
            lastY: event.clientY,
            dragging: false
        };
    }

    function finishCatalogMouseDrag(event) {
        if (!customDrag) return false;

        var drag = customDrag;
        customDrag = null;
        clearSourceElement(drag.sourceElement);

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
        var target = getAdminDropTargetFromPoint(x, y);
        var cell = target.cell;
        var slot = target.slot;

        debug('custom drag finish', {
            itemName: drag.item && drag.item.name,
            amount: drag.amount,
            rotated: drag.rotated,
            hasCell: !!cell,
            hasSlot: !!slot,
            underClass: target.under && target.under.className
        });

        destroyDragGhost();

        var sendCatalogAdd = function (targetPayload, amount) {
            selectedAmount = clampAmount(amount || drag.amount || catalogDefaultAmount(drag.item), catalogDefaultAmount(drag.item));
            postAddItem(targetPayload);
        };

        if (cell) {
            var cellTarget = {
                type: 'container',
                containerId: cell.dataset.container,
                container_id: cell.dataset.container,
                x: Number(cell.dataset.x),
                y: Number(cell.dataset.y),
                rotated: selectedRotated === true
            };
            if ((drag.ctrlAmount === true || (event && event.ctrlKey === true)) && catalogDefaultAmount(drag.item) > 1) {
                openAdminQuantityDialog('Количество для ' + (drag.item.label || drag.item.name), catalogDefaultAmount(drag.item), catalogDefaultAmount(drag.item), function (amount) {
                    sendCatalogAdd(cellTarget, amount);
                });
            } else {
                sendCatalogAdd(cellTarget, drag.amount);
            }
            return true;
        }

        if (slot) {
            var slotTarget = { type: 'slot', slot: slot.dataset.slot };
            if ((drag.ctrlAmount === true || (event && event.ctrlKey === true)) && catalogDefaultAmount(drag.item) > 1) {
                openAdminQuantityDialog('Количество для ' + (drag.item.label || drag.item.name), catalogDefaultAmount(drag.item), catalogDefaultAmount(drag.item), function (amount) {
                    sendCatalogAdd(slotTarget, amount);
                });
            } else {
                sendCatalogAdd(slotTarget, drag.amount);
            }
            return true;
        }

        debug('custom drag cancelled: no valid target');
        return true;
    }

    function destroyInventoryDragGhost() {
        if (inventoryDragGhost && inventoryDragGhost.parentNode) {
            inventoryDragGhost.parentNode.removeChild(inventoryDragGhost);
        }
        inventoryDragGhost = null;
        clearDragOverElement();
    }

    function startInventoryMouseDrag(event, item) {
        if (!event || event.button !== 0) return;
        if (closestElement(event.target, 'input, textarea, select, button')) return;

        var itemAmount = Math.max(1, Math.floor(Number(item.amount || 1)));
        var moveAmount = itemAmount;
        var splitMode = false;
        var ctrlMode = event.ctrlKey === true && itemAmount > 1;

        if (event.altKey && itemAmount > 1) {
            moveAmount = itemAmount - 1;
            splitMode = true;
            ctrlMode = false;
        }

        inventoryDrag = {
            itemId: Number(item.id),
            amount: moveAmount,
            split: splitMode,
            ctrlAmount: ctrlMode,
            rotated: item.rotated === true || item.rotated === 1,
            sourceElement: closestElement(event.target, '.admin-grid-item, .admin-equip-item'),
            startX: event.clientX,
            startY: event.clientY,
            lastX: event.clientX,
            lastY: event.clientY,
            dragging: false
        };
    }

    function updateInventoryDragGhost(x, y) {
        if (!inventoryDrag || !inventoryDrag.dragging) return;
        inventoryDrag.lastX = x;
        inventoryDrag.lastY = y;
        var item = findStateItem(inventoryDrag.itemId);
        if (!item) return;

        if (!inventoryDragGhost) {
            inventoryDragGhost = document.createElement('div');
            inventoryDragGhost.className = 'admin-inventory-drag-ghost';
            document.body.appendChild(inventoryDragGhost);
        }

        fillDragGhost(
            inventoryDragGhost,
            itemLabel(item) + (Number(inventoryDrag.amount || item.amount || 1) > 1 ? ' x' + (inventoryDrag.amount || item.amount) : ''),
            visualSizeFromStateItem(item, inventoryDrag.rotated === true),
            CELL
        );

        inventoryDragGhost.style.left = (x + 12) + 'px';
        inventoryDragGhost.style.top = (y + 12) + 'px';

        var target = getAdminDropTargetFromPoint(x, y);
        setDragPreview(target, visualSizeFromStateItem(item, inventoryDrag.rotated === true));
    }

    function finishInventoryMouseDrag(event) {
        if (!inventoryDrag) return false;

        var drag = inventoryDrag;
        inventoryDrag = null;
        clearSourceElement(drag.sourceElement);

        if (!drag.dragging) {
            destroyInventoryDragGhost();
            return false;
        }

        if (event && event.preventDefault) event.preventDefault();
        if (event && event.stopPropagation) event.stopPropagation();
        suppressNextInventoryClick = true;

        var x = event && typeof event.clientX === 'number' ? event.clientX : drag.startX;
        var y = event && typeof event.clientY === 'number' ? event.clientY : drag.startY;
        var target = getAdminDropTargetFromPoint(x, y);
        var draggedItem = findStateItem(drag.itemId);

        debug('inventory drag finish', {
            itemId: drag.itemId,
            hasCell: !!target.cell,
            hasSlot: !!target.slot,
            underClass: target.under && target.under.className
        });

        destroyInventoryDragGhost();

        var sendInventoryMove = function (targetPayload, amount) {
            if (draggedItem) {
                targetPayload.amount = clampAmount(amount || drag.amount || 1, Math.max(1, Math.floor(Number(draggedItem.amount || 1))));
            } else {
                targetPayload.amount = Math.max(1, Number(amount || drag.amount || 1));
            }
            targetPayload.split = drag.split === true;
            postMoveItem(drag.itemId, targetPayload);
        };

        if (target.cell) {
            var moveTarget = {
                type: 'container',
                containerId: target.cell.dataset.container,
                container_id: target.cell.dataset.container,
                x: Number(target.cell.dataset.x),
                y: Number(target.cell.dataset.y),
                rotated: drag.rotated === true
            };
            if ((drag.ctrlAmount === true || (event && event.ctrlKey === true)) && draggedItem && Number(draggedItem.amount || 1) > 1 && drag.split !== true) {
                openAdminQuantityDialog('Количество для ' + itemLabel(draggedItem), Number(draggedItem.amount || 1), Number(draggedItem.amount || 1), function (amount) {
                    sendInventoryMove(moveTarget, amount);
                });
            } else {
                sendInventoryMove(moveTarget, drag.amount || 1);
            }
            return true;
        }

        if (target.slot) {
            postMoveItem(drag.itemId, { type: 'slot', slot: target.slot.dataset.slot, amount: 1, split: false });
            return true;
        }

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

        return '<div class="admin-paperdoll">' + slots.map(function (slot) {
            var slotId = slot.id || slot.slot;
            var item = equipment[slotId] || null;
            return '' +
                '<div class="admin-equip-slot slot-' + escapeHtml(String(slotId).replace(/[^a-z0-9_\-]/gi, '_')) + '" data-slot="' + escapeHtml(slotId) + '">' +
                    '<div class="slot-title">' + escapeHtml(slot.label || slotId) + '</div>' +
                    (item
                        ? '<div class="admin-equip-item" data-item-id="' + escapeHtml(item.id) + '" title="#' + escapeHtml(item.id) + ' | ' + escapeHtml(item.item_name || '') + '"><div class="item-name">' + escapeHtml(itemLabel(item)) + '</div>' + (Number(item.amount || 1) > 1 ? '<div class="item-meta">x' + escapeHtml(item.amount) + '</div>' : '') + '</div>'
                        : '<div class="empty-slot">пусто</div>') +
                '</div>';
        }).join('') + '</div>';
    }


    function containerDisplayLabel(container) {
        var id = String(container && container.id || '');
        var label = String(container && (container.label || container.id) || '').trim();
        if (id === 'main' && (!label || label.toLowerCase() === 'инвентарь')) return 'Основной';
        return label || id || 'Контейнер';
    }

    function dedupeLogs(logs) {
        var seen = {};
        var out = [];
        (logs || []).forEach(function (log) {
            var key = [
                log.action || '',
                log.item_id || '',
                log.item_name || '',
                log.amount || '',
                log.from_container || log.from_slot || '',
                log.to_container || log.to_slot || '',
                log.created_at || ''
            ].join('|');
            if (seen[key]) return;
            seen[key] = true;
            out.push(log);
        });
        return out;
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
                        '<h3>' + escapeHtml(containerDisplayLabel(container)) + '</h3>' +
                        '<b>' + escapeHtml(w) + 'x' + escapeHtml(h) + '</b>' +
                    '</div>' +
                    '<div class="admin-inv-grid" style="grid-template-columns: repeat(' + w + ', ' + CELL + 'px); grid-template-rows: repeat(' + h + ', ' + CELL + 'px);">';

            for (var y = 0; y < h; y++) {
                for (var x = 0; x < w; x++) {
                    html += '<div class="admin-inv-cell" data-container="' + escapeHtml(container.id) + '" data-x="' + x + '" data-y="' + y + '"></div>';
                }
            }

            rows.forEach(function (item) {
                // item.width/item.height уже приходят с сервера в текущей ориентации.
                // Не переворачиваем второй раз, иначе в админке отображение не совпадает с БД.
                var itemW = Number(item.width || item.w || 0) || 0;
                var itemH = Number(item.height || item.h || 0) || 0;
                if (itemW < 1 || itemH < 1) {
                    var currentVisual = visualSizeFromStateItem(item);
                    itemW = currentVisual.w;
                    itemH = currentVisual.h;
                }

                html += '' +
                    '<div class="admin-grid-item" data-item-id="' + escapeHtml(item.id) + '" data-container="' + escapeHtml(container.id) + '" title="#' + escapeHtml(item.id) + ' | ' + escapeHtml(item.item_name || '') + '" style="left:' + ((Number(item.x) || 0) * CELL) + 'px; top:' + ((Number(item.y) || 0) * CELL) + 'px; width:' + (itemW * CELL) + 'px; height:' + (itemH * CELL) + 'px;">' +
                        '<div class="item-name">' + escapeHtml(itemLabel(item)) + '</div>' +
                        '<div class="item-meta">' + (Number(item.amount || 1) > 1 ? 'x' + escapeHtml(item.amount) : '') + '</div>' +
                    '</div>';
            });

            html += '</div></div>';
            return html;
        }).join('');
    }

    function formatLogTime(value) {
        if (!value) return '-';

        if (typeof value === 'string') {
            var cleaned = value.trim();
            if (/^\d+$/.test(cleaned)) {
                value = Number(cleaned);
            } else {
                var parsed = Date.parse(cleaned.replace(' ', 'T'));
                if (!Number.isNaN(parsed)) {
                    return new Date(parsed).toLocaleString('ru-RU', {
                        year: '2-digit', month: '2-digit', day: '2-digit',
                        hour: '2-digit', minute: '2-digit', second: '2-digit'
                    });
                }
                return cleaned;
            }
        }

        if (typeof value === 'number' && Number.isFinite(value)) {
            var ms;
            if (value > 1000000000000) {
                ms = value;
            } else if (value > 4102444800 && value < 100000000000) {
                ms = Math.round(value / 10) * 1000;
            } else {
                ms = value * 1000;
            }
            var d = new Date(ms);
            if (!Number.isNaN(d.getTime())) {
                return d.toLocaleString('ru-RU', {
                    year: '2-digit', month: '2-digit', day: '2-digit',
                    hour: '2-digit', minute: '2-digit', second: '2-digit'
                });
            }
        }

        return String(value);
    }

    function actionLabel(action) {
        var labels = {
            admin_add: 'Выдано админом',
            admin_add_equip: 'Выдано в слот',
            admin_move: 'Перемещение админом',
            admin_move_equip: 'Экипировано админом',
            admin_unequip_move: 'Снято админом',
            admin_delete: 'Удалено админом',
            move: 'Перемещение',
            equip: 'Экипировка',
            unequip: 'Снятие',
            drop_ground: 'Выброшено',
            pickup_ground: 'Поднято с земли',
            pickup_ground_stack: 'Поднято в стак',
            pickup_ground_equip: 'Поднято в слот',
            add: 'Добавлено',
            add_stack: 'Добавлено в стак',
            starter: 'Стартовый набор'
        };
        return labels[action] || action || '-';
    }

    function visualSizeFromDefinition(item, rotated) {
        var w = Number(item && (item.width || item.base_width || item.w) || 1) || 1;
        var h = Number(item && (item.height || item.base_height || item.h) || 1) || 1;
        if (rotated) {
            var tmp = w;
            w = h;
            h = tmp;
        }
        return { w: Math.max(1, w), h: Math.max(1, h) };
    }

    function getDefinitionByName(name) {
        var definitions = (activePayload && activePayload.definitions) || (activeState && activeState.definitions) || {};
        return definitions && name ? (definitions[name] || {}) : {};
    }

    function visualSizeFromStateItem(item, rotatedOverride) {
        var def = getDefinitionByName(item && (item.item_name || item.name));
        // item.width/item.height уже рассчитаны сервером с учётом item.rotated.
        // Для drag-preview и R-поворота считаем от base_width/base_height или cw-items definition,
        // чтобы UI не показывал горизонтально то, что сервер реально кладёт вертикально.
        var w = Number(item && (item.base_width || item.base_w) || def.width || (item && (item.width || item.w)) || 1) || 1;
        var h = Number(item && (item.base_height || item.base_h) || def.height || (item && (item.height || item.h)) || 1) || 1;
        var rotated = rotatedOverride;
        if (rotated === undefined || rotated === null) rotated = item && (item.rotated === true || item.rotated === 1);
        if (rotated) {
            var tmp = w;
            w = h;
            h = tmp;
        }
        return { w: Math.max(1, w), h: Math.max(1, h) };
    }

    function fillDragGhost(el, label, size, cellSize) {
        var w = Math.max(1, Number(size && size.w) || 1);
        var h = Math.max(1, Number(size && size.h) || 1);
        el.style.width = (w * cellSize) + 'px';
        el.style.height = (h * cellSize) + 'px';
        el.innerHTML = '' +
            '<div class="admin-drag-ghost-grid" style="grid-template-columns: repeat(' + w + ', ' + cellSize + 'px); grid-template-rows: repeat(' + h + ', ' + cellSize + 'px);">' +
                Array(w * h + 1).join('<div class="admin-drag-ghost-cell"></div>') +
            '</div>' +
            '<div class="admin-drag-ghost-label">' + escapeHtml(label) + '</div>';
    }

    function parseMaybeJson(value) {
        if (!value) return null;
        if (typeof value === 'object') return value;
        if (typeof value !== 'string') return null;
        try { return JSON.parse(value); } catch (e) { return null; }
    }

    function compactDeletedContents(log) {
        var before = parseMaybeJson(log.before_json) || {};
        var after = parseMaybeJson(log.after_json) || {};
        var contents = before.contents || after.contents || [];
        if (!contents || !contents.length) return '';
        return contents.map(function (it) {
            return '#' + escapeHtml(it.id || '-') + ' ' + escapeHtml(it.item_name || it.label || 'item') + ' x' + escapeHtml(it.amount || 1);
        }).join(', ');
    }

    function logActorText(log) {
        var after = parseMaybeJson(log.after_json) || {};
        var before = parseMaybeJson(log.before_json) || {};
        return after.deleted_by || after.reason || before.reason || '';
    }

    function renderLogs(logs) {
        logs = dedupeLogs(logs || []);
        if (!logs.length) {
            return '<div class="inventory-small">Логов пока нет.</div>';
        }

        return '' +
            '<div class="inventory-log-wrap">' +
                '<table class="inventory-log-table">' +
                    '<thead><tr><th class="inventory-log-time">Время</th><th class="inventory-log-action">Действие</th><th>Предмет</th><th class="inventory-log-amount">Кол-во</th><th>Откуда</th><th>Куда</th></tr></thead>' +
                    '<tbody>' + logs.slice(0, 80).map(function (log) {
                        var deletedDetails = compactDeletedContents(log);
                        var actor = logActorText(log);
                        var itemText = escapeHtml(log.item_name || '-');
                        if (deletedDetails) itemText += '<div class="inventory-log-details">Внутри удалено: ' + deletedDetails + '</div>';
                        var fromText = escapeHtml(log.from_container || log.from_slot || '-');
                        if (actor && String(actor).indexOf('Админ:') === 0) fromText += '<div class="inventory-log-details">' + escapeHtml(actor) + '</div>';
                        return '' +
                            '<tr>' +
                                '<td class="inventory-log-time" title="' + escapeHtml(log.created_at || '-') + '">' + escapeHtml(formatLogTime(log.created_at)) + '</td>' +
                                '<td class="inventory-log-action" title="' + escapeHtml(log.action || '-') + '">' + escapeHtml(actionLabel(log.action)) + '</td>' +
                                '<td>' + itemText + '</td>' +
                                '<td class="inventory-log-amount">' + escapeHtml(log.amount || '-') + '</td>' +
                                '<td>' + fromText + '</td>' +
                                '<td>' + escapeHtml(log.to_container || log.to_slot || '-') + '</td>' +
                            '</tr>';
                    }).join('') + '</tbody>' +
                '</table>' +
            '</div>';
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

    function catalogInfoHtml(item) {
        if (!item) {
            return 'Ничего не выбрано<br>Перетащи предмет в слот. Ctrl при переносе — количество после выбора клетки. Alt при переносе стака — оставить 1. R — повернуть.';
        }
        var size = effectiveSize(item);
        return '' +
            '<b>' + escapeHtml(item.label || item.name) + '</b> — ' + escapeHtml(item.name || '-') + '<br>' +
            'Категория: ' + escapeHtml(categoryLabels[item.category] || item.category || '-') + ' | stack ' + escapeHtml(item.stack || 1) + ' | ' + escapeHtml(size.w) + 'x' + escapeHtml(size.h) + (selectedRotated ? ' | повёрнут' : '') + '<br>' +
            (item.description ? escapeHtml(item.description) : 'Описание отсутствует.');
    }

    function updateCatalogInfoBox(item) {
        catalogInfoItem = item || null;
        var box = document.getElementById('adminSelectedLine');
        if (box) box.innerHTML = catalogInfoHtml(catalogInfoItem || selectedCatalog);
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

        var infoItem = catalogInfoItem || selectedCatalog;

        return '' +
            '<h3>Предметы</h3>' +
            '<div class="admin-catalog-controls">' +
                '<input id="adminCatalogSearch" type="text" placeholder="Поиск предмета">' +
                '<div id="adminSelectedLine" class="admin-selected-line">' + catalogInfoHtml(infoItem) + '</div>' +
            '</div>' +
            '<div class="admin-catalog-tabs">' + cats.map(function (cat) {
                return '<button type="button" class="catalog-tab' + (activeCategory === cat ? ' active' : '') + '" data-category="' + escapeHtml(cat) + '">' + escapeHtml(categoryLabels[cat] || cat) + '</button>';
            }).join('') + '</div>' +
            '<div class="admin-catalog-list">' + list.map(function (item) {
                return '' +
                    '<div class="admin-catalog-item" draggable="false" data-item="' + escapeHtml(item.name) + '" title="' + escapeHtml(item.name) + ' | stack ' + escapeHtml(item.stack) + '">' +
                        '<div class="admin-catalog-title"><span>' + escapeHtml(item.label) + '</span><span>x' + escapeHtml(catalogDefaultAmount(item)) + '</span></div>' +
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
        });

        var slots = modalBody.querySelectorAll('.admin-equip-slot');
        Array.prototype.forEach.call(slots, function (slot) {
            slot.addEventListener('dragover', acceptDrop);
            slot.addEventListener('dragleave', leaveDrop);
            slot.addEventListener('drop', function (event) {
                dropToTarget(event, { type: 'slot', slot: slot.dataset.slot });
            });
        });
    }

    function bindInventoryItems() {
        var rows = modalBody.querySelectorAll('.admin-grid-item, .admin-equip-item');
        Array.prototype.forEach.call(rows, function (row) {
            var item = findStateItem(row.dataset.itemId);
            if (!item) return;

            row.addEventListener('mousedown', function (event) {
                startInventoryMouseDrag(event, item);
            });
            row.addEventListener('mouseenter', function () {
                updateCatalogInfoBox({
                    name: item.item_name || item.name || ('item #' + item.id),
                    label: itemLabel(item),
                    category: item.category || item.type || '-',
                    stack: item.amount || 1,
                    width: item.width || 1,
                    height: item.height || 1,
                    description: 'DB ID #' + item.id + ' | container ' + (item.container_id || item.equip_slot || '-')
                });
            });
            row.addEventListener('mouseleave', function () { updateCatalogInfoBox(null); });

            row.addEventListener('click', function (event) {
                if (suppressNextInventoryClick) {
                    event.preventDefault();
                    event.stopPropagation();
                    suppressNextInventoryClick = false;
                }
            });

            row.addEventListener('contextmenu', function (event) {
                event.preventDefault();
                event.stopPropagation();
                postDeleteItem(item.id);
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
            row.addEventListener('mouseenter', function () { updateCatalogInfoBox(item); });
            row.addEventListener('mouseleave', function () { updateCatalogInfoBox(null); });

            row.addEventListener('click', function (event) {
                if (suppressNextCatalogClick) {
                    event.preventDefault();
                    event.stopPropagation();
                    suppressNextCatalogClick = false;
                    return;
                }

                selectedCatalog = item;
                selectedAmount = catalogDefaultAmount(item);
                selectedRotated = false;
                debug('selected catalog item', item.name, 'amount', selectedAmount);
                updateCatalogInfoBox(item);
            });

            row.addEventListener('dragstart', function (event) {
                var amount = catalogDefaultAmount(item);
                if (!selectedCatalog || selectedCatalog.name !== item.name) {
                    selectedRotated = false;
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
            (DEBUG ? renderDebugLine(activePayload, activeState) : '') +
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
        bindInventoryItems();
        bindCatalog();
        document.body.classList.add('cw-inventory-modal-open');
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
        if (inventoryDrag) {
            var idx = Math.abs((event.clientX || 0) - inventoryDrag.startX);
            var idy = Math.abs((event.clientY || 0) - inventoryDrag.startY);

            if (!inventoryDrag.dragging && (idx > 4 || idy > 4)) {
                inventoryDrag.dragging = true;
                if (inventoryDrag.sourceElement && inventoryDrag.sourceElement.classList) inventoryDrag.sourceElement.classList.add('dragging-source');
                debug('inventory drag start', { itemId: inventoryDrag.itemId });
            }

            if (inventoryDrag.dragging) {
                event.preventDefault();
                updateInventoryDragGhost(event.clientX, event.clientY);
                return;
            }
        }

        if (!customDrag) return;

        var dx = Math.abs((event.clientX || 0) - customDrag.startX);
        var dy = Math.abs((event.clientY || 0) - customDrag.startY);

        if (!customDrag.dragging && (dx > 4 || dy > 4)) {
            customDrag.dragging = true;
            if (customDrag.sourceElement && customDrag.sourceElement.classList) customDrag.sourceElement.classList.add('dragging-source');
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
        if (finishInventoryMouseDrag(event)) return;
        finishCatalogMouseDrag(event);
    });

    document.addEventListener('keydown', function (event) {
        if (!activePayload) return;
        if (event.key !== 'r' && event.key !== 'R' && event.key !== 'к' && event.key !== 'К') return;

        if (customDrag && customDrag.dragging) {
            customDrag.rotated = !customDrag.rotated;
            selectedCatalog = customDrag.item;
            selectedRotated = customDrag.rotated === true;
            clearDragOverElement();
            if (typeof customDrag.lastX === 'number' && typeof customDrag.lastY === 'number') {
                updateDragGhost(customDrag.lastX, customDrag.lastY);
            }
            debug('rotate catalog drag item', customDrag.item && customDrag.item.name, selectedRotated);
            event.preventDefault();
            return;
        }

        if (inventoryDrag && inventoryDrag.dragging) {
            inventoryDrag.rotated = !inventoryDrag.rotated;
            selectedRotated = inventoryDrag.rotated === true;
            clearDragOverElement();
            if (typeof inventoryDrag.lastX === 'number' && typeof inventoryDrag.lastY === 'number') {
                updateInventoryDragGhost(inventoryDrag.lastX, inventoryDrag.lastY);
            }
            debug('rotate inventory drag item', inventoryDrag.itemId, selectedRotated);
            event.preventDefault();
            return;
        }

        if (!selectedCatalog) return;
        selectedRotated = !selectedRotated;
        debug('rotate selected item', selectedCatalog.name, selectedRotated);
        renderModal(activePayload, true);
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
