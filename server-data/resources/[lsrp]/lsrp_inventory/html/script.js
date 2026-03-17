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
    },
    target: null,
    dragFromSlot: null,
    dragSourceElement: null
};

const appElement = document.getElementById('app');
const closeButtonElement = document.getElementById('close-btn');
const slotsTextElement = document.getElementById('slots-text');
const weightTextElement = document.getElementById('weight-text');
const statusTextElement = document.getElementById('status-text');
const inventoryPanelsElement = document.getElementById('inventory-panels');
const selfGridElement = document.getElementById('self-grid');
const targetGridElement = document.getElementById('target-grid');
const targetPanelElement = document.getElementById('target-panel');
const targetPanelTitleElement = document.getElementById('target-panel-title');
const transferTargetInputElement = document.getElementById('transfer-target-id');
const openTargetButtonElement = document.getElementById('open-target-btn');

function postNui(eventName, payload = {}) {
    return fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(payload)
    })
        .then(async (response) => {
            try {
                return await response.json();
            } catch (_error) {
                return { ok: response.ok };
            }
        })
        .catch(() => ({ ok: false }));
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

function normalizeTargetPayload(rawTarget) {
    if (!rawTarget || typeof rawTarget !== 'object') {
        return null;
    }

    const targetId = Math.max(1, toInteger(rawTarget.targetId, 0));
    if (targetId < 1) {
        return null;
    }

    return {
        targetId,
        targetName: String(rawTarget.targetName || `ID ${targetId}`),
        targetInventory: normalizeInventory(rawTarget.targetInventory || {})
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

function getItemsBySlot(inventory) {
    const itemsBySlot = {};
    const items = Array.isArray(inventory.items) ? inventory.items : [];
    items.forEach((item, index) => {
        const slot = Math.max(1, Math.min(inventory.slots, toInteger(item.slot, index + 1)));
        if (!itemsBySlot[slot]) {
            itemsBySlot[slot] = item;
        }
    });
    return itemsBySlot;
}

function getItemBySlot(inventory, slot) {
    const itemsBySlot = getItemsBySlot(inventory);
    return itemsBySlot[slot] || null;
}

function hasActiveTransferTarget() {
    return Boolean(state.target && state.target.targetInventory);
}

function updateTransferButtonState() {
    openTargetButtonElement.textContent = hasActiveTransferTarget()
        ? 'Hide Target Inventory'
        : 'Open Target Inventory';
}

function getTargetSlotElementAt(clientX, clientY) {
    const element = document.elementFromPoint(clientX, clientY);
    if (!element) {
        return null;
    }

    const slotElement = element.closest('.slot[data-panel="target"]');
    if (!slotElement || !targetGridElement.contains(slotElement)) {
        return null;
    }

    return slotElement;
}

function clearDropTargetVisuals() {
    targetGridElement.querySelectorAll('.slot.drop-target').forEach((slotElement) => {
        slotElement.classList.remove('drop-target');
    });
}

function clearDragState() {
    state.dragFromSlot = null;

    if (state.dragSourceElement) {
        state.dragSourceElement.classList.remove('dragging');
    }

    state.dragSourceElement = null;
    clearDropTargetVisuals();
}

function beginDragFromSelf(slotIndex, slotElement, event) {
    if (!event || event.button !== 0) {
        return;
    }

    if (state.dragSourceElement && state.dragSourceElement !== slotElement) {
        state.dragSourceElement.classList.remove('dragging');
    }

    state.dragFromSlot = slotIndex;
    state.dragSourceElement = slotElement;
    slotElement.classList.add('dragging');
    event.preventDefault();
}

function buildSlotElement(slotIndex, item, panelType) {
    const slotElement = document.createElement('article');
    slotElement.className = 'slot';
    slotElement.dataset.slot = String(slotIndex);
    slotElement.dataset.panel = panelType;

    if (!item) {
        slotElement.classList.add('empty');
    } else {
        slotElement.classList.add('has-item');
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
            imageElement.draggable = false;
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

    if (panelType === 'self' && item) {
        slotElement.addEventListener('mousedown', (event) => {
            beginDragFromSelf(slotIndex, slotElement, event);
        });
    }

    return slotElement;
}

function renderSelfInventory() {
    const inventory = state.inventory;
    const items = Array.isArray(inventory.items) ? inventory.items : [];

    const usedSlots = Math.min(inventory.slots, items.length);
    const usedWeight = items.reduce((sum, item) => sum + Math.max(0, toInteger(item.totalWeight, 0)), 0);

    slotsTextElement.textContent = `${usedSlots} / ${inventory.slots}`;
    weightTextElement.textContent = `${usedWeight} / ${inventory.maxWeight}`;

    selfGridElement.innerHTML = '';
    const itemsBySlot = getItemsBySlot(inventory);

    for (let slotIndex = 1; slotIndex <= inventory.slots; slotIndex += 1) {
        const item = itemsBySlot[slotIndex] || null;
        selfGridElement.appendChild(buildSlotElement(slotIndex, item, 'self'));
    }
}

function renderTargetInventory() {
    targetGridElement.innerHTML = '';

    if (!hasActiveTransferTarget()) {
        inventoryPanelsElement.classList.add('single-panel');
        targetPanelElement.classList.add('inactive');
        targetPanelElement.classList.add('hidden-panel');
        targetPanelTitleElement.textContent = 'Target Inventory';
        return;
    }

    inventoryPanelsElement.classList.remove('single-panel');
    targetPanelElement.classList.remove('inactive');
    targetPanelElement.classList.remove('hidden-panel');
    targetPanelTitleElement.textContent = `${state.target.targetName} (${state.target.targetId})`;

    const targetInventory = state.target.targetInventory;
    const itemsBySlot = getItemsBySlot(targetInventory);
    for (let slotIndex = 1; slotIndex <= targetInventory.slots; slotIndex += 1) {
        const item = itemsBySlot[slotIndex] || null;
        targetGridElement.appendChild(buildSlotElement(slotIndex, item, 'target'));
    }
}

function renderAll() {
    renderSelfInventory();
    renderTargetInventory();
    updateTransferButtonState();

    if (!hasActiveTransferTarget()) {
        statusTextElement.textContent = 'Inventory open. Enter target ID only when you want to transfer.';
        return;
    }

    const selfItems = Array.isArray(state.inventory.items) ? state.inventory.items : [];
    if (selfItems.length === 0) {
        statusTextElement.textContent = 'Inventory is empty.';
    } else {
        statusTextElement.textContent = 'Drag from your inventory into target inventory. Transfers are one-way: you cannot drag items back.';
    }
}

function applyInventory(rawInventory) {
    state.inventory = normalizeInventory(rawInventory);
    renderAll();
}

function applyTransferTarget(rawTarget) {
    state.target = normalizeTargetPayload(rawTarget);
    renderAll();
}

document.addEventListener('mousemove', (event) => {
    if (state.dragFromSlot === null) {
        return;
    }

    clearDropTargetVisuals();

    const targetSlotElement = getTargetSlotElementAt(event.clientX, event.clientY);
    if (targetSlotElement) {
        targetSlotElement.classList.add('drop-target');
    }
});

document.addEventListener('mouseup', async (event) => {
    if (state.dragFromSlot === null) {
        return;
    }

    const fromSlot = toInteger(state.dragFromSlot, 0);
    const targetSlotElement = getTargetSlotElementAt(event.clientX, event.clientY);
    clearDragState();

    if (!targetSlotElement) {
        return;
    }

    if (!state.target || !state.target.targetId) {
        statusTextElement.textContent = 'Load target inventory first.';
        return;
    }

    if (fromSlot < 1) {
        statusTextElement.textContent = 'Drag an item from your inventory.';
        return;
    }

    const sourceItem = getItemBySlot(state.inventory, fromSlot);
    if (!sourceItem) {
        statusTextElement.textContent = 'Source slot is empty.';
        renderAll();
        return;
    }

    const response = await postNui('transferItem', {
        targetId: state.target.targetId,
        fromSlot,
        amount: Math.max(1, toInteger(sourceItem.count, 1))
    });

    if (!response || response.ok !== true) {
        statusTextElement.textContent = 'Could not submit transfer request.';
        return;
    }

    statusTextElement.textContent = `Transferred ${sourceItem.name} to ${state.target.targetName}.`;
});

closeButtonElement.addEventListener('click', () => {
    postNui('closeInventory');
});

openTargetButtonElement.addEventListener('click', async () => {
    if (hasActiveTransferTarget()) {
        clearDragState();
        applyTransferTarget(null);
        statusTextElement.textContent = 'Transfer panel hidden.';
        return;
    }

    const targetId = toInteger(transferTargetInputElement.value, 0);
    if (targetId < 1) {
        statusTextElement.textContent = 'Enter a valid target server ID.';
        return;
    }

    openTargetButtonElement.disabled = true;
    const response = await postNui('requestTransferTargetInventory', {
        targetId
    });
    openTargetButtonElement.disabled = false;

    if (!response || response.ok !== true) {
        statusTextElement.textContent = 'Could not open target inventory.';
        return;
    }

    statusTextElement.textContent = `Target inventory request sent for ID ${targetId}.`;
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
            clearDragState();
            state.target = null;
            renderAll();
            postNui('requestInventory');
        } else {
            clearDragState();
            state.target = null;
            renderAll();
        }
        return;
    }

    if (payload.action === 'setInventoryData') {
        applyInventory(payload.inventory || {});
        return;
    }

    if (payload.action === 'syncInventory') {
        applyInventory(payload.inventory || {});
        return;
    }

    if (payload.action === 'setTransferTarget') {
        applyTransferTarget(payload.target || null);
        return;
    }

    if (payload.action === 'clearTransferTarget') {
        applyTransferTarget(null);
    }
});

setVisibility(false);
renderAll();
