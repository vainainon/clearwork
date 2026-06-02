(function () {
    var app = document.getElementById('app');
    var closeBtn = document.getElementById('closeBtn');
    var refreshBtn = document.getElementById('refreshBtn');
    var notice = document.getElementById('notice');
    var equipmentEl = document.getElementById('equipment');
    var containersEl = document.getElementById('containers');
    var selectionInfo = document.getElementById('selectionInfo');

    var CELL = 48;
    var state = {
        items: [],
        equipment: {},
        containers: [],
        equipmentSlots: [],
        definitions: {}
    };
    var selected = null;
    var selectedRotated = false;

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
            setTimeout(function () {
                if (notice.textContent === message) setNotice('');
            }, 3500);
        }
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

    function updateSelectionInfo() {
        var item = selectedItem();
        if (!item) {
            selectionInfo.textContent = 'Ничего не выбрано';
            return;
        }
        var size = selectedSize(item);
        selectionInfo.textContent = itemLabel(item) + ' • ' + size.w + 'x' + size.h + (selectedRotated ? ' • повернут' : '');
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
                itemEl.addEventListener('click', function (e) {
                    e.stopPropagation();
                    selectItem(item);
                });
                box.appendChild(itemEl);
            } else {
                box.innerHTML += '<div class="empty-slot">пусто</div>';
            }

            box.addEventListener('click', function () {
                var item = selectedItem();
                if (!item) return;
                if (item.equip_slot) return;
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

        for (var y = 0; y < container.height; y++) {
            for (var x = 0; x < container.width; x++) {
                var cell = document.createElement('div');
                cell.className = 'cell';
                cell.dataset.container = container.id;
                cell.dataset.x = x;
                cell.dataset.y = y;
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
            el.addEventListener('click', function (e) {
                e.stopPropagation();
                selectItem(item);
            });
            grid.appendChild(el);
        });

        wrap.appendChild(grid);
        return wrap;
    }

    function renderContainers() {
        containersEl.innerHTML = '';
        (state.containers || []).forEach(function (container) {
            containersEl.appendChild(renderContainer(container));
        });
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

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            post('close');
            return;
        }
        if ((e.key === 'r' || e.key === 'R' || e.key === 'к' || e.key === 'К') && selected) {
            selectedRotated = !selectedRotated;
            render();
        }
    });

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'open') {
            app.classList.remove('hidden');
            return;
        }
        if (data.action === 'close') {
            app.classList.add('hidden');
            return;
        }
        if (data.action === 'state') {
            state = data.payload || state;
            selected = selected && findItem(selected) ? selected : null;
            render();
            return;
        }
        if (data.action === 'notice') {
            setNotice(data.message || '', data.kind || '');
            return;
        }
    });
})();
