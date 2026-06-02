(function () {
    'use strict';

    var app = document.getElementById('app');
    var closeBtn = document.getElementById('closeBtn');
    var refreshBtn = document.getElementById('refreshBtn');
    var notice = document.getElementById('notice');
    var equipmentEl = document.getElementById('equipment');
    var containersEl = document.getElementById('containers');
    var selectionInfo = document.getElementById('selectionInfo');

    var APP_VERSION = 'v19-drag-opacity-target-outline';
    var CELL = 48;
    var state = { items: [], equipment: {}, containers: [], equipmentSlots: [], definitions: {} };
    var selected = null;
    var selectedRotated = false;
    var customDrag = null;
    var dragGhost = null;
    var dragOverElement = null;
    var dragPreviewElements = [];
    var suppressItemClick = false;

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
        var w = Number((item && (item.width || item.base_width || item.w)) || def.width || 1) || 1;
        var h = Number((item && (item.height || item.base_height || item.h)) || def.height || 1) || 1;
        var rotated = rotatedOverride;
        if (rotated === undefined || rotated === null) rotated = !!(item && item.rotated);
        if (rotated) {
            var tmp = w;
            w = h;
            h = tmp;
        }
        return { w: Math.max(1, w), h: Math.max(1, h) };
    }

    function fillItemDragGhost(el, item) {
        var size = visualSizeForItem(item, !!selectedRotated);
        var label = itemLabel(item) + (Number(item.amount || 1) > 1 ? ' x' + item.amount : '');
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
        selectionInfo.textContent = itemLabel(item) + ' • ' + size.w + 'x' + size.h + (selectedRotated ? ' • повернут' : '');
    }

    function clearDragOverElement() {
        if (dragOverElement && dragOverElement.classList) dragOverElement.classList.remove('drag-over');
        dragOverElement = null;

        dragPreviewElements.forEach(function (el) {
            if (el && el.classList) el.classList.remove('drop-preview');
        });
        dragPreviewElements = [];
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
        if (dragOverElement === element && dragPreviewElements.length) return;

        clearDragOverElement();
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

        customDrag = {
            itemId: Number(item.id),
            sourceElement: closestElement(event.target, '.grid-item, .equip-item'),
            startX: event.clientX,
            startY: event.clientY,
            dragging: false
        };
    }

    function updateItemDragGhost(x, y) {
        if (!customDrag || !customDrag.dragging) return;
        var item = findItem(customDrag.itemId);
        if (!item) return;

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
                rotated: selectedRotated
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
                    '<div class="item-meta">#' + escapeHtml(item.id) + '</div>';
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

            box.addEventListener('click', function () {
                var item = selectedItem();
                if (!item) return;
                post('equipItem', { itemId: item.id, slot: slot.id });
            });

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
                cell.addEventListener('click', function (e) {
                    var item = selectedItem();
                    if (!item) return;
                    var payload = {
                        itemId: item.id,
                        containerId: e.currentTarget.dataset.container,
                        x: Number(e.currentTarget.dataset.x),
                        y: Number(e.currentTarget.dataset.y),
                        rotated: selectedRotated
                    };
                    if (item.equip_slot) post('unequipItem', payload);
                    else post('moveItem', payload);
                });
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
                '<div class="item-meta">' + (Number(item.amount || 1) > 1 ? 'x' + escapeHtml(item.amount) + ' ' : '') + '#' + escapeHtml(item.id) + '</div>';
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
                selectedRotated = !!item.rotated;
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
        if ((e.key === 'r' || e.key === 'R' || e.key === 'к' || e.key === 'К') && selected) {
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
