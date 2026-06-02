(function () {
    'use strict';

    var app = document.getElementById('app');
    var closeBtn = document.getElementById('closeBtn');
    var refreshBtn = document.getElementById('refreshBtn');
    var notice = document.getElementById('notice');
    var equipmentEl = document.getElementById('equipment');
    var containersEl = document.getElementById('containers');
    var selectionInfo = document.getElementById('selectionInfo');

    var APP_VERSION = 'v22-stacks-drag-only';
    var CELL = 48;
    var state = { items: [], equipment: {}, containers: [], equipmentSlots: [], definitions: {} };
    var selected = null;
    var selectedRotated = false;
    var customDrag = null;
    var dragGhost = null;
    var dragOverElement = null;
    var dragPreviewElements = [];
    var dragPreviewKey = '';
    var suppressItemClick = false;
    var pendingMoveAmounts = {};
    var quantityDialog = null;

    function post(name, data) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(function () {});
    }

    function escapeHtml(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function setNotice(message, kind) {
        notice.textContent = message || '';
        notice.className = kind || '';
        if (message) {
            setTimeout(function () { if (notice.textContent === message) setNotice(''); }, 3500);
        }
    }

    function clampAmount(raw, max) {
        var value = Math.floor(Number(raw) || 1);
        max = Math.floor(Number(max) || 1);
        if (value < 1) value = 1;
        if (value > max) value = max;
        return value;
    }

    function closeQuantityDialog() {
        if (quantityDialog && quantityDialog.parentNode) quantityDialog.parentNode.removeChild(quantityDialog);
        quantityDialog = null;
    }

    function openQuantityDialog(title, max, current, onOk) {
        closeQuantityDialog();
        max = Math.max(1, Math.floor(Number(max) || 1));
        current = clampAmount(current || max, max);

        quantityDialog = document.createElement('div');
        quantityDialog.className = 'quantity-dialog-backdrop';
        quantityDialog.innerHTML = '' +
            '<div class="quantity-dialog">' +
                '<div class="quantity-title">' + escapeHtml(title || 'Количество') + '</div>' +
                '<div class="quantity-help">Максимум: ' + escapeHtml(max) + '</div>' +
                '<input class="quantity-input" type="number" min="1" max="' + escapeHtml(max) + '" value="' + escapeHtml(current) + '">' +
                '<div class="quantity-actions">' +
                    '<button type="button" data-action="ok">ОК</button>' +
                    '<button type="button" data-action="cancel">Отмена</button>' +
                '</div>' +
            '</div>';
        document.body.appendChild(quantityDialog);

        var input = quantityDialog.querySelector('.quantity-input');
        setTimeout(function () { if (input) { input.focus(); input.select(); } }, 0);

        quantityDialog.addEventListener('click', function (event) {
            var action = event.target && event.target.dataset ? event.target.dataset.action : '';
            if (!action) return;
            event.preventDefault();
            if (action === 'cancel') { closeQuantityDialog(); return; }
            var amount = clampAmount(input && input.value, max);
            closeQuantityDialog();
            if (typeof onOk === 'function') onOk(amount);
        });

        quantityDialog.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') { closeQuantityDialog(); return; }
            if (event.key === 'Enter') {
                var amount = clampAmount(input && input.value, max);
                closeQuantityDialog();
                if (typeof onOk === 'function') onOk(amount);
            }
        });
    }

    function closestElement(element, selector) {
        while (element && element !== document) {
            if (element.matches && element.matches(selector)) return element;
            element = element.parentNode;
        }
        return null;
    }

    function getDef(item) {
        return state.definitions[item.item_name] || {};
    }

    function itemLabel(item) {
        return item.label || getDef(item).label || item.item_name || 'item';
    }

    function findItem(id) {
        id = Number(id);
        for (var i = 0; i < state.items.length; i++) {
            if (Number(state.items[i].id) === id) return state.items[i];
        }
        for (var slot in state.equipment) {
            if (state.equipment[slot] && Number(state.equipment[slot].id) === id) return state.equipment[slot];
        }
        return null;
    }

    function selectItem(item) {
        selected = item ? Number(item.id) : null;
        selectedRotated = item ? !!item.rotated : false;
        render();
    }

    function selectedItem() {
        return selected ? findItem(selected) : null;
    }

    function selectedSize(item) {
        var def = getDef(item);
        var w = Number(def.width || item.base_width || item.width || 1);
        var h = Number(def.height || item.base_height || item.height || 1);
        if (selectedRotated) return { w: h, h: w };
        return { w: w, h: h };
    }

    function visualSizeForItem(item, rotatedOverride) {
        var def = getDef(item || {});
        // item.width/item.height уже приходят с сервера как текущий размер в сетке.
        // Для drag-preview и R-поворота нужна базовая геометрия предмета,
        // иначе повернутый предмет визуально переворачивается второй раз.
        var w = Number((item && (item.base_width || item.base_w)) || def.width || (item && (item.width || item.w)) || 1) || 1;
        var h = Number((item && (item.base_height || item.base_h)) || def.height || (item && (item.height || item.h)) || 1) || 1;
        var rotated = rotatedOverride;
        if (rotated === undefined || rotated === null) rotated = !!(item && (item.rotated === true || item.rotated === 1));
        if (rotated) {
            var tmp = w;
            w = h;
            h = tmp;
        }
        return { w: Math.max(1, w), h: Math.max(1, h) };
    }

    function fillItemDragGhost(el, item) {
        var size = visualSizeForItem(item, !!selectedRotated);
        var dragAmount = customDrag && customDrag.amount ? Number(customDrag.amount) : Number(item.amount || 1);
        var label = itemLabel(item) + (dragAmount > 1 ? ' x' + dragAmount : '');
        el.style.width = (size.w * CELL) + 'px';
        el.style.height = (size.h * CELL) + 'px';
        el.innerHTML = '' +
            '<div class="item-drag-ghost-grid" style="grid-template-columns: repeat(' + size.w + ', ' + CELL + 'px); grid-template-rows: repeat(' + size.h + ', ' + CELL + 'px);">' +
                Array(size.w * size.h + 1).join('<div class="item-drag-ghost-cell"></div>') +
            '</div>' +
            '<div class="item-drag-ghost-label">' + escapeHtml(label) + '</div>';
    }

    function updateSelectionInfo() {
        var item = selectedItem();
        if (!item) {
            selectionInfo.textContent = 'Ничего не выбрано';
            return;
        }
        var size = selectedSize(item);
        selectionInfo.textContent = itemLabel(item) + (Number(item.amount || 1) > 1 ? ' x' + item.amount : '') + ' • ' + size.w + 'x' + size.h + (selectedRotated ? ' • повернут' : '');
    }

    function clearDragOverElement() {
        if (dragOverElement && dragOverElement.classList) dragOverElement.classList.remove('drag-over');
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
        var grid = closestElement(cell, '.grid-wrap');
        if (!grid) return [];

        var startX = Number(cell.dataset.x || 0);
        var startY = Number(cell.dataset.y || 0);
        var cells = [];
        for (var yy = 0; yy < size.h; yy++) {
            for (var xx = 0; xx < size.w; xx++) {
                var found = grid.querySelector('.cell[data-x="' + (startX + xx) + '"][data-y="' + (startY + yy) + '"]');
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
        if (dragGhost && dragGhost.parentNode) dragGhost.parentNode.removeChild(dragGhost);
        dragGhost = null;
        clearDragOverElement();
    }

    function clearSourceElement(source) {
        if (source && source.classList) source.classList.remove('dragging-source');
    }

    function getCellFromPoint(x, y) {
        var under = document.elementFromPoint(x, y);
        var cell = closestElement(under, '.cell');
        if (cell) return cell;

        var grid = closestElement(under, '.grid-wrap');
        if (!grid) return null;

        var rect = grid.getBoundingClientRect();
        var cx = Math.floor((x - rect.left) / CELL);
        var cy = Math.floor((y - rect.top) / CELL);
        if (cx < 0 || cy < 0) return null;
        return grid.querySelector('.cell[data-x="' + cx + '"][data-y="' + cy + '"]');
    }

    function getDropTargetFromPoint(x, y) {
        var under = document.elementFromPoint(x, y);
        var slot = closestElement(under, '.equip-slot');
        var cell = getCellFromPoint(x, y);
        return { cell: cell, slot: slot };
    }

    function startItemMouseDrag(event, item) {
        if (!event || event.button !== 0) return;
        if (closestElement(event.target, 'input, textarea, select, button')) return;

        var itemAmount = Math.max(1, Math.floor(Number(item.amount || 1)));
        var moveAmount = itemAmount;
        var splitMode = false;

        if (event.ctrlKey && itemAmount > 1) {
            event.preventDefault();
            event.stopPropagation();
            openQuantityDialog('Количество для ' + itemLabel(item), itemAmount, itemAmount, function (amount) {
                pendingMoveAmounts[Number(item.id)] = amount;
                setNotice('Выбрано ' + amount + '. Теперь перетащи этот стак.', 'success');
            });
            return;
        }

        if (event.altKey && itemAmount > 1) {
            moveAmount = itemAmount - 1;
            splitMode = true;
        } else if (pendingMoveAmounts[Number(item.id)]) {
            moveAmount = clampAmount(pendingMoveAmounts[Number(item.id)], itemAmount);
            delete pendingMoveAmounts[Number(item.id)];
        }

        customDrag = {
            itemId: Number(item.id),
            amount: moveAmount,
            split: splitMode,
            rotated: item.rotated === true || item.rotated === 1,
            sourceElement: closestElement(event.target, '.grid-item, .equip-item'),
            startX: event.clientX,
            startY: event.clientY,
            lastX: event.clientX,
            lastY: event.clientY,
            dragging: false
        };
    }

    function updateItemDragGhost(x, y) {
        if (!customDrag || !customDrag.dragging) return;
        customDrag.lastX = x;
        customDrag.lastY = y;
        var item = findItem(customDrag.itemId);
        if (!item) return;
        selectedRotated = customDrag.rotated === true;

        if (!dragGhost) {
            dragGhost = document.createElement('div');
            dragGhost.className = 'item-drag-ghost';
            document.body.appendChild(dragGhost);
        }

        fillItemDragGhost(dragGhost, item);

        dragGhost.style.left = (x + 12) + 'px';
        dragGhost.style.top = (y + 12) + 'px';

        var target = getDropTargetFromPoint(x, y);
        setDragPreview(target, visualSizeForItem(item, !!selectedRotated));
    }

    function finishItemMouseDrag(event) {
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
        suppressItemClick = true;

        var item = findItem(drag.itemId);
        var x = event && typeof event.clientX === 'number' ? event.clientX : drag.startX;
        var y = event && typeof event.clientY === 'number' ? event.clientY : drag.startY;
        var target = getDropTargetFromPoint(x, y);
        var shell = closestElement(document.elementFromPoint(x, y), '.inventory-shell');

        destroyDragGhost();

        if (!item) return true;

        if (target.cell) {
            var payload = {
                itemId: item.id,
                containerId: target.cell.dataset.container,
                x: Number(target.cell.dataset.x),
                y: Number(target.cell.dataset.y),
                rotated: drag.rotated === true,
                amount: drag.amount || item.amount || 1,
                split: drag.split === true
            };
            if (item.equip_slot) post('unequipItem', payload);
            else post('moveItem', payload);
            return true;
        }

        if (target.slot) {
            post('equipItem', { itemId: item.id, slot: target.slot.dataset.slot });
            return true;
        }

        if (!shell) {
            post('dropItem', { itemId: item.id });
            return true;
        }

        return true;
    }

    function renderEquipment() {
        equipmentEl.innerHTML = '';
        (state.equipmentSlots || []).forEach(function (slot) {
            var box = document.createElement('div');
            box.className = 'equip-slot';
            box.dataset.slot = slot.id;

            var item = state.equipment ? state.equipment[slot.id] : null;
            box.innerHTML = '<div class="slot-title">' + escapeHtml(slot.label || slot.id) + '</div>';

            if (item) {
                var itemEl = document.createElement('div');
                itemEl.className = 'equip-item ' + escapeHtml(item.type || '') + (selected === Number(item.id) ? ' selected' : '');
                itemEl.innerHTML = '<div class="item-name">' + escapeHtml(itemLabel(item)) + '</div>' +
                    '<div class="item-meta"></div>';
                itemEl.addEventListener('mousedown', function (e) { startItemMouseDrag(e, item); });
                itemEl.addEventListener('click', function (e) {
                    e.stopPropagation();
                    if (suppressItemClick) { suppressItemClick = false; return; }
                    selectItem(item);
                });
                box.appendChild(itemEl);
            } else {
                box.innerHTML += '<div class="empty-slot">пусто</div>';
            }

            equipmentEl.appendChild(box);
        });
    }

    function renderContainer(container) {
        var wrap = document.createElement('div');
        wrap.className = 'container-box';
        wrap.innerHTML = '<div class="container-head"><b>' + escapeHtml(container.label || container.id) + '</b><span>' +
            escapeHtml(container.width) + 'x' + escapeHtml(container.height) + '</span></div>';

        var grid = document.createElement('div');
        grid.className = 'grid-wrap';
        grid.style.gridTemplateColumns = 'repeat(' + container.width + ', ' + CELL + 'px)';
        grid.style.gridTemplateRows = 'repeat(' + container.height + ', ' + CELL + 'px)';
        grid.style.width = (container.width * CELL) + 'px';
        grid.style.height = (container.height * CELL) + 'px';

        for (var yy = 0; yy < container.height; yy++) {
            for (var xx = 0; xx < container.width; xx++) {
                var cell = document.createElement('div');
                cell.className = 'cell';
                cell.dataset.container = container.id;
                cell.dataset.x = xx;
                cell.dataset.y = yy;
                grid.appendChild(cell);
            }
        }

        (state.items || []).forEach(function (item) {
            if (item.container_id !== container.id || item.equip_slot) return;
            var el = document.createElement('div');
            el.className = 'grid-item ' + escapeHtml(item.type || '') + (selected === Number(item.id) ? ' selected' : '');
            el.style.left = (Number(item.x || 0) * CELL) + 'px';
            el.style.top = (Number(item.y || 0) * CELL) + 'px';
            el.style.width = (Number(item.width || 1) * CELL) + 'px';
            el.style.height = (Number(item.height || 1) * CELL) + 'px';
            el.title = itemLabel(item) + '\n' + (item.description || '');
            el.innerHTML = '<div class="item-name">' + escapeHtml(itemLabel(item)) + '</div>' +
                '<div class="item-meta">' + (Number(item.amount || 1) > 1 ? 'x' + escapeHtml(item.amount) : '') + '</div>';
            el.addEventListener('mousedown', function (e) { startItemMouseDrag(e, item); });
            el.addEventListener('click', function (e) {
                e.stopPropagation();
                if (suppressItemClick) { suppressItemClick = false; return; }
                selectItem(item);
            });
            grid.appendChild(el);
        });

        wrap.appendChild(grid);
        return wrap;
    }

    function renderContainers() {
        containersEl.innerHTML = '';
        (state.containers || []).forEach(function (container) { containersEl.appendChild(renderContainer(container)); });
    }

    function render() {
        renderEquipment();
        renderContainers();
        updateSelectionInfo();
    }

    closeBtn.addEventListener('click', function () { post('close'); });
    refreshBtn.addEventListener('click', function () { post('refresh'); });

    document.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        selectItem(null);
    });

    document.addEventListener('mousemove', function (event) {
        if (!customDrag) return;
        var dx = Math.abs((event.clientX || 0) - customDrag.startX);
        var dy = Math.abs((event.clientY || 0) - customDrag.startY);
        if (!customDrag.dragging && (dx > 4 || dy > 4)) {
            customDrag.dragging = true;
            if (customDrag.sourceElement && customDrag.sourceElement.classList) customDrag.sourceElement.classList.add('dragging-source');
            var item = findItem(customDrag.itemId);
            if (item) {
                selected = Number(item.id);
                customDrag.rotated = item.rotated === true || item.rotated === 1;
                selectedRotated = customDrag.rotated === true;
            }
        }
        if (customDrag.dragging) {
            event.preventDefault();
            updateItemDragGhost(event.clientX, event.clientY);
        }
    });

    document.addEventListener('mouseup', function (event) { finishItemMouseDrag(event); });

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { post('close'); return; }
        if (e.key !== 'r' && e.key !== 'R' && e.key !== 'к' && e.key !== 'К') return;

        if (customDrag && customDrag.dragging) {
            customDrag.rotated = !customDrag.rotated;
            selectedRotated = customDrag.rotated === true;
            clearDragOverElement();
            if (typeof customDrag.lastX === 'number' && typeof customDrag.lastY === 'number') {
                updateItemDragGhost(customDrag.lastX, customDrag.lastY);
            }
            e.preventDefault();
            return;
        }

        if (selected) {
            selectedRotated = !selectedRotated;
            render();
        }
    });

    if (window.console && console.log) console.log('[cw-inventory:nui] loaded ' + APP_VERSION);

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'open') { app.classList.remove('hidden'); return; }
        if (data.action === 'close') { app.classList.add('hidden'); destroyDragGhost(); customDrag = null; return; }
        if (data.action === 'state') {
            state = data.payload || state;
            selected = selected && findItem(selected) ? selected : null;
            render();
            return;
        }
        if (data.action === 'notice') { setNotice(data.message || '', data.kind || ''); return; }
    });
})();
