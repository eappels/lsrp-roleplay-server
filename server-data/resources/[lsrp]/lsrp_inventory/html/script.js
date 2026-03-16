const resourceName = (typeof window.GetParentResourceName === 'function')
    ? window.GetParentResourceName()
    : 'lsrp_inventory';
const nuiBaseUrl = `https://cfx-nui-${resourceName}/html/`;

const state = {
    visible: false,
    inventory: {
        slots: 6,
        maxWeight: 0,
        items: []
    }
};

const appElement = document.getElementById('app');
const closeButtonElement = document.getElementById('close-btn');
const slotsTextElement = document.getElementById('slots-text');
const weightTextElement = document.getElementById('weight-text');
const statusTextElement = document.getElementById('status-text');
const slotGridElement = document.getElementById('slot-grid');

function postNui(eventName, payload = {}) {
    return fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(payload)
    }).catch(() => null);
}

function toInteger(value, fallback = 0) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
        return fallback;
    }

    return Math.floor(parsed);
}

function normalizeItem(rawItem, slotIndex) {
    const item = (rawItem && typeof rawItem === 'object') ? rawItem : {};
    const name = String(item.name || item.label || 'Unknown Item').trim() || 'Unknown Item';
    const count = Math.max(1, toInteger(item.count || item.amount || 1, 1));
    const itemWeight = Math.max(0, toInteger(item.weight, 0));
    const image = typeof item.image === 'string' ? item.image.trim() : '';
    const description = typeof item.description === 'string' ? item.description.trim() : '';

    return {
        slot: Math.max(1, toInteger(item.slot || slotIndex, slotIndex)),
        name,
        code: String(item.code || item.id || '').trim(),
        count,
        weight: itemWeight,
        totalWeight: Math.max(0, toInteger(item.totalWeight, itemWeight * count)),
        image,
        description
    };
}

function normalizeInventory(rawInventory) {
    const inventory = (rawInventory && typeof rawInventory === 'object') ? rawInventory : {};
    const slots = Math.max(1, toInteger(inventory.slots, 6));
    const maxWeight = Math.max(0, toInteger(inventory.maxWeight, 0));
    const rawItems = Array.isArray(inventory.items) ? inventory.items : [];
    const items = rawItems.map((item, index) => normalizeItem(item, index + 1));

    return {
        slots,
        maxWeight,
        items
    };
}

function setVisibility(visible) {
    state.visible = Boolean(visible);
    appElement.classList.toggle('hidden', !state.visible);
}

function toNuiImageUrl(path) {
    const rawPath = String(path || '').trim();
    if (!rawPath) {
        return null;
    }

    if (/^(https?:\/\/|nui:\/\/|data:|blob:)/i.test(rawPath)) {
        return rawPath;
    }

    let normalizedPath = rawPath.replace(/^\.\//, '').replace(/^\//, '');
    if (!normalizedPath.includes('/')) {
        normalizedPath = `images/${normalizedPath}`;
    }

    const encodedPath = normalizedPath
        .split('/')
        .map((segment) => encodeURIComponent(segment))
        .join('/');

    return `${nuiBaseUrl}${encodedPath}`;
}

function resolveItemImagePath(item) {
    if (!item) {
        return null;
    }

    const explicitImage = String(item.image || '').trim();
    if (explicitImage) {
        return toNuiImageUrl(explicitImage);
    }

    const identity = String(item.code || item.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
    if (identity.includes('carkey') || identity === 'vehiclekey') {
        return toNuiImageUrl('images/carkey-mWjjjPPC.png');
    }

    return null;
}

function buildSlotElement(slotIndex, item) {
    const slotElement = document.createElement('article');
    slotElement.className = 'slot';
    if (!item) {
        slotElement.classList.add('empty');
    }

    const slotIdElement = document.createElement('span');
    slotIdElement.className = 'slot-index';
    slotIdElement.textContent = `Slot ${slotIndex}`;

    const visualElement = document.createElement('div');
    visualElement.className = 'item-visual';

    if (item) {
        const imagePath = resolveItemImagePath(item);
        if (imagePath) {
            const imageElement = document.createElement('img');
            imageElement.className = 'item-image';
            imageElement.src = imagePath;
            imageElement.alt = item.name;
            imageElement.loading = 'lazy';
            imageElement.addEventListener('error', () => {
                imageElement.remove();
            });
            visualElement.appendChild(imageElement);
        }
    }

    const nameElement = document.createElement('p');
    nameElement.className = 'item-name';
    nameElement.textContent = item ? item.name : 'Empty';

    const detailElement = document.createElement('p');
    detailElement.className = 'item-detail';
    detailElement.textContent = item && item.description ? item.description : '';

    const metaElement = document.createElement('p');
    metaElement.className = 'item-meta';
    if (item) {
        metaElement.textContent = `x${item.count} • ${item.totalWeight}g`;
    } else {
        metaElement.textContent = 'No item';
    }

    slotElement.appendChild(slotIdElement);
    slotElement.appendChild(visualElement);
    slotElement.appendChild(nameElement);
    slotElement.appendChild(detailElement);
    slotElement.appendChild(metaElement);

    return slotElement;
}

function renderInventory() {
    const inventory = state.inventory;
    const items = Array.isArray(inventory.items) ? inventory.items : [];

    const usedSlots = Math.min(inventory.slots, items.length);
    const usedWeight = items.reduce((sum, item) => sum + Math.max(0, toInteger(item.totalWeight, 0)), 0);

    slotsTextElement.textContent = `${usedSlots} / ${inventory.slots}`;
    weightTextElement.textContent = `${usedWeight} / ${inventory.maxWeight}`;

    slotGridElement.innerHTML = '';

    const itemsBySlot = {};
    items.forEach((item, index) => {
        const slot = Math.max(1, Math.min(inventory.slots, toInteger(item.slot, index + 1)));
        if (!itemsBySlot[slot]) {
            itemsBySlot[slot] = item;
        }
    });

    for (let slotIndex = 1; slotIndex <= inventory.slots; slotIndex += 1) {
        const item = itemsBySlot[slotIndex] || null;
        slotGridElement.appendChild(buildSlotElement(slotIndex, item));
    }

    if (items.length === 0) {
        statusTextElement.textContent = 'Inventory is empty.';
    } else if (inventory.slots > 9) {
        statusTextElement.textContent = '3x3 layout active. Scroll for more slots. Press ESC to close.';
    } else {
        statusTextElement.textContent = '3x3 layout active. Press ESC to close.';
    }
}

function applyInventory(rawInventory) {
    state.inventory = normalizeInventory(rawInventory);
    renderInventory();
}

closeButtonElement.addEventListener('click', () => {
    postNui('closeInventory');
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        postNui('closeInventory');
    }
});

window.addEventListener('message', (event) => {
    const payload = event.data || {};

    if (payload.action === 'setVisible') {
        setVisibility(payload.visible === true);
        if (payload.visible === true) {
            postNui('requestInventory');
        }
        return;
    }

    if (payload.action === 'setInventoryData') {
        applyInventory(payload.inventory || {});
    }
});

setVisibility(false);
renderInventory();
