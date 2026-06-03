const app = document.getElementById('app');
const closeBtn = document.getElementById('closeBtn');
const categoryList = document.getElementById('categoryList');
const itemList = document.getElementById('itemList');
const detailsBox = document.getElementById('detailsBox');
const buyBtn = document.getElementById('buyBtn');
const buyNowBtn = document.getElementById('buyNowBtn');
const revertBtn = document.getElementById('revertBtn');
const basketList = document.getElementById('basketList');
const categoryTitle = document.getElementById('categoryTitle');
const visualStatus = document.getElementById('visualStatus');
const clearVendorBtn = document.getElementById('clearVendorBtn');
const takeAllBtn = document.getElementById('takeAllBtn');

let categories = [];
let catalog = {};
let basket = [];
let categoryIndex = 0;
let itemIndex = 0;
let variationIndex = 0;
let selectedItem = null;
let selectedVariation = null;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function currentCategory() {
    return categories[categoryIndex] || null;
}

function currentItems() {
    const cat = currentCategory();
    return cat ? (catalog[cat.id] || []) : [];
}

function genderedValue(value) {
    if (value && typeof value === 'object') {
        return value.male || value.female || value[0] || '';
    }

    return value;
}

function hasVisual(variation) {
    const component = variation?.component || {};
    return Boolean(genderedValue(component.shopItem) || genderedValue(component.drawable));
}

function setVisualStatus(text, state = '') {
    visualStatus.textContent = text || '';
    visualStatus.classList.remove('good', 'bad');

    if (state) {
        visualStatus.classList.add(state);
    }
}

function renderCategories() {
    categoryList.innerHTML = '';

    categories.forEach((category, index) => {
        const div = document.createElement('div');
        div.className = `category ${index === categoryIndex ? 'active' : ''}`;
        div.textContent = category.label;
        div.addEventListener('click', () => {
            categoryIndex = index;
            itemIndex = 0;
            variationIndex = 0;
            renderAll();
            previewSelected();
        });
        categoryList.appendChild(div);
    });
}

function renderItems() {
    const cat = currentCategory();
    const items = currentItems();

    categoryTitle.textContent = cat ? cat.label : 'Ассортимент';
    itemList.innerHTML = '';

    if (!items.length) {
        itemList.innerHTML = '<div class="empty">В этом разделе пока пусто.</div>';
        selectedItem = null;
        selectedVariation = null;
        return;
    }

    if (itemIndex >= items.length) itemIndex = 0;
    selectedItem = items[itemIndex];

    items.forEach((item, index) => {
        const div = document.createElement('div');
        div.className = `item ${index === itemIndex ? 'active' : ''}`;
        div.innerHTML = `<strong>${item.label}</strong><span>${item.description || ''}</span>`;
        div.addEventListener('click', () => {
            itemIndex = index;
            variationIndex = 0;
            renderAll();
            previewSelected();
        });
        itemList.appendChild(div);
    });
}

function renderDetails() {
    detailsBox.innerHTML = '';
    buyBtn.disabled = true;
    buyNowBtn.disabled = true;

    if (!selectedItem) {
        detailsBox.innerHTML = '<div class="empty">Выбери предмет.</div>';
        setVisualStatus('Выбери вещь для примерки.');
        return;
    }

    const variations = selectedItem.variations || [];
    if (variationIndex >= variations.length) variationIndex = 0;
    selectedVariation = variations[variationIndex] || null;

    const title = document.createElement('div');
    title.className = 'item';
    title.innerHTML = `<strong>${selectedItem.label}</strong><span>${selectedItem.description || ''}</span>`;
    detailsBox.appendChild(title);

    variations.forEach((variation, index) => {
        const div = document.createElement('div');
        div.className = `variation ${index === variationIndex ? 'active' : ''}`;
        div.textContent = variation.label || 'Обычная';
        div.addEventListener('click', () => {
            variationIndex = index;
            renderAll();
            previewSelected();
        });
        detailsBox.appendChild(div);
    });

    setVisualStatus(
        hasVisual(selectedVariation)
            ? 'Примерка должна сразу отобразиться на персонаже. Если вещь не меняется, значит hash не подошёл к текущему ped/полу.'
            : 'У этой позиции пока не задан визуальный hash.',
        hasVisual(selectedVariation) ? 'good' : 'bad'
    );

    buyBtn.disabled = !selectedVariation;
    buyNowBtn.disabled = !selectedVariation;
}

function renderBasket() {
    basketList.innerHTML = '';
    takeAllBtn.disabled = !basket.length;

    if (!basket.length) {
        basketList.innerHTML = '<div class="empty">У продавца пока ничего нет.</div>';
        return;
    }

    basket.forEach((entry) => {
        const div = document.createElement('div');
        div.className = 'basket-item';
        div.innerHTML = `
            <strong>${entry.label}</strong>
            <span>${entry.variationLabel || 'Обычная'}<br>${entry.description || ''}</span>
            <button class="take-btn">Забрать в инвентарь</button>
        `;
        div.querySelector('.take-btn').addEventListener('click', () => {
            post('takeFromVendor', { orderId: entry.orderId });
        });
        basketList.appendChild(div);
    });
}

function renderAll() {
    renderCategories();
    renderItems();
    renderDetails();
    renderBasket();
}

function selectedPayload() {
    const cat = currentCategory();
    if (!cat || !selectedItem || !selectedVariation) return null;

    return {
        categoryId: cat.id,
        itemId: selectedItem.id,
        variationId: selectedVariation.id,
        component: selectedVariation.component || {}
    };
}

function previewSelected() {
    const payload = selectedPayload();
    if (!payload) return;
    post('preview', payload);
}

function addSelectedToVendor() {
    const payload = selectedPayload();
    if (!payload) return;
    post('addToVendor', payload);
}

function buySelectedNow() {
    const payload = selectedPayload();
    if (!payload) return;
    post('buySelectedNow', payload);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        app.classList.remove('hidden');
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
    }

    if (data.action === 'catalog') {
        categories = data.payload?.categories || [];
        catalog = data.payload?.catalog || {};
        categoryIndex = 0;
        itemIndex = 0;
        variationIndex = 0;
        renderAll();
        previewSelected();
    }

    if (data.action === 'basket') {
        basket = data.basket || [];
        renderBasket();
    }

    if (data.action === 'visualStatus') {
        setVisualStatus(data.text || '', data.ok ? 'good' : 'bad');
    }
});

closeBtn.addEventListener('click', () => post('close'));
buyBtn.addEventListener('click', addSelectedToVendor);
buyNowBtn.addEventListener('click', buySelectedNow);
revertBtn.addEventListener('click', () => post('revertPreview'));
clearVendorBtn.addEventListener('click', () => post('clearVendor'));
takeAllBtn.addEventListener('click', () => post('takeAllFromVendor'));

document.addEventListener('keydown', (event) => {
    if (app.classList.contains('hidden')) return;

    if (event.key === 'Escape') {
        post('close');
    }

    if (event.key === 'ArrowRight') {
        categoryIndex = Math.min(categories.length - 1, categoryIndex + 1);
        itemIndex = 0;
        variationIndex = 0;
        renderAll();
        previewSelected();
    }

    if (event.key === 'ArrowLeft') {
        categoryIndex = Math.max(0, categoryIndex - 1);
        itemIndex = 0;
        variationIndex = 0;
        renderAll();
        previewSelected();
    }

    if (event.key === 'ArrowDown') {
        const items = currentItems();
        itemIndex = Math.min(items.length - 1, itemIndex + 1);
        variationIndex = 0;
        renderAll();
        previewSelected();
    }

    if (event.key === 'ArrowUp') {
        itemIndex = Math.max(0, itemIndex - 1);
        variationIndex = 0;
        renderAll();
        previewSelected();
    }

    if (event.key.toLowerCase() === 'q') {
        post('rotatePed', { delta: -12.5 });
    }

    if (event.key.toLowerCase() === 'e') {
        post('rotatePed', { delta: 12.5 });
    }

    if (event.key === 'Enter') {
        buySelectedNow();
    }
});
