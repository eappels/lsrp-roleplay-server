const resourceName = typeof window.GetParentResourceName === 'function'
	? window.GetParentResourceName()
	: 'lsrp_inventory';

const state = {
	visible: false,
	inventory: { slots: 0, maxWeight: 0, items: [] },
	target: null,
	drag: null
};

const appElement = document.getElementById('app');
const closeButton = document.getElementById('close-btn');
const slotsText = document.getElementById('slots-text');
const weightText = document.getElementById('weight-text');
const selfGrid = document.getElementById('self-grid');
const targetGrid = document.getElementById('target-grid');
const targetPanel = document.getElementById('target-panel');
const targetPanelTitle = document.getElementById('target-panel-title');
const targetInput = document.getElementById('transfer-target-id');
const openTargetButton = document.getElementById('open-target-btn');
const statusText = document.getElementById('status-text');
const amountModal = document.getElementById('amount-modal');
const amountTitle = document.getElementById('amount-modal-title');
const amountInput = document.getElementById('amount-input');
const amountConfirm = document.getElementById('amount-confirm');
const amountCancel = document.getElementById('amount-cancel');
let activeAmountCleanup = null;

function postNui(endpoint, payload = {}) {
	return fetch(`https://${resourceName}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(payload)
	}).then(async (response) => {
		try {
			return await response.json();
		} catch (_error) {
			return { ok: response.ok };
		}
	}).catch(() => ({ ok: false }));
}

function toInteger(value, fallback = 0) {
	const parsed = Number(value);
	return Number.isFinite(parsed) ? Math.floor(parsed) : fallback;
}

function normalizeInventory(raw) {
	const inventory = raw && typeof raw === 'object' ? raw : {};
	return {
		slots: Math.max(1, toInteger(inventory.slots, 1)),
		maxWeight: Math.max(0, toInteger(inventory.maxWeight, 0)),
		items: Array.isArray(inventory.items) ? inventory.items : []
	};
}

function normalizeTarget(raw) {
	if (!raw || typeof raw !== 'object') {
		return null;
	}
	return {
		targetId: Math.max(1, toInteger(raw.targetId, 0)),
		targetName: String(raw.targetName || 'Player'),
		targetInventory: normalizeInventory(raw.targetInventory || {})
	};
}

function getItemsBySlot(inventory) {
	const map = {};
	for (const item of inventory.items || []) {
		const slot = Math.max(1, toInteger(item.slot, 1));
		if (!map[slot]) {
			map[slot] = item;
		}
	}
	return map;
}

function getInventoryWeight(inventory) {
	return (inventory.items || []).reduce((sum, item) => sum + Math.max(0, toInteger(item.totalWeight, 0)), 0);
}

function resolveItemImage(item) {
	const image = String((item && item.image) || '').trim();
	if (!image) {
		return null;
	}
	return `https://cfx-nui-${resourceName}/html/images/${encodeURIComponent(image)}`;
}

function setVisible(visible) {
	state.visible = Boolean(visible);
	appElement.classList.toggle('hidden', !state.visible);
}

function setStatus(message) {
	statusText.textContent = String(message || '');
}

function clearDropHighlights() {
	document.querySelectorAll('.drop-target').forEach((element) => element.classList.remove('drop-target'));
}

function destroyDragPreview() {
	if (state.drag && state.drag.previewElement) {
		state.drag.previewElement.remove();
	}
	if (state.drag && state.drag.sourceElement) {
		state.drag.sourceElement.classList.remove('dragging');
	}
	clearDropHighlights();
	document.body.classList.remove('drag-active');
}

function resetDragState() {
	destroyDragPreview();
	state.drag = null;
}

function positionDragPreview(clientX, clientY) {
	if (!state.drag || !state.drag.previewElement) {
		return;
	}
	state.drag.previewElement.style.left = `${clientX + 14}px`;
	state.drag.previewElement.style.top = `${clientY + 14}px`;
}

function updateDropHighlight(clientX, clientY) {
	clearDropHighlights();
	const element = document.elementFromPoint(clientX, clientY);
	if (!element) {
		return null;
	}

	const slotElement = element.closest('.slot');
	if (slotElement) {
		slotElement.classList.add('drop-target');
		return {
			type: 'slot',
			panel: slotElement.dataset.panel,
			slot: toInteger(slotElement.dataset.slot, 0)
		};
	}

	const dropZoneElement = element.closest('#ground-drop-zone');
	if (dropZoneElement) {
		dropZoneElement.classList.add('drop-target');
		return { type: 'ground' };
	}

	return null;
}

function createDragPreview(item) {
	const preview = document.createElement('div');
	preview.className = 'drag-preview';
	preview.innerHTML = `
		<div class="drag-preview-label">${item.label || item.name || 'Item'}</div>
		<div class="drag-preview-count">x${toInteger(item.count, 1)}</div>
	`;

	const image = resolveItemImage(item);
	if (image) {
		const imageElement = document.createElement('img');
		imageElement.className = 'drag-preview-image';
		imageElement.src = image;
		imageElement.alt = item.label || item.name || 'Item';
		preview.prepend(imageElement);
	}

	document.body.appendChild(preview);
	return preview;
}

function showAmountModal(title, maximum) {
	return new Promise((resolve) => {
		amountTitle.textContent = title;
		amountInput.value = String(Math.max(1, maximum));
		amountInput.max = String(Math.max(1, maximum));
		amountModal.classList.remove('hidden');
		amountInput.focus();
		amountInput.select();

		function cleanup(result) {
			activeAmountCleanup = null;
			amountModal.classList.add('hidden');
			amountConfirm.removeEventListener('click', onConfirm);
			amountCancel.removeEventListener('click', onCancel);
			resolve(result);
		}

		activeAmountCleanup = cleanup;

		function onConfirm() {
			const amount = toInteger(amountInput.value, 0);
			if (amount < 1 || amount > maximum) {
				cleanup(null);
				return;
			}
			cleanup(amount);
		}

		function onCancel() {
			cleanup(null);
		}

		amountConfirm.addEventListener('click', onConfirm);
		amountCancel.addEventListener('click', onCancel);
	});
}

async function resolveDragAmount(item, verb) {
	const maximum = Math.max(1, toInteger(item.count, 1));
	if (maximum <= 1) {
		return 1;
	}
	return showAmountModal(`${verb} how many ${item.label || item.name}?`, maximum);
}

function beginDrag(event, slotIndex, item, sourceElement) {
	if (event.button !== 0 || !state.visible || !amountModal.classList.contains('hidden')) {
		return;
	}

	event.preventDefault();
	resetDragState();
	state.drag = {
		panel: 'self',
		slot: slotIndex,
		item,
		sourceElement,
		previewElement: createDragPreview(item)
	};
	document.body.classList.add('drag-active');
	sourceElement.classList.add('dragging');
	positionDragPreview(event.clientX, event.clientY);
	updateDropHighlight(event.clientX, event.clientY);
}

function buildSlot(slotIndex, item, panel) {
	const slot = document.createElement('article');
	slot.className = 'slot';
	slot.dataset.slot = String(slotIndex);
	slot.dataset.panel = panel;
	if (!item) {
		slot.classList.add('empty');
	}

	const header = document.createElement('div');
	header.className = 'slot-header';
	header.innerHTML = `<span>Slot ${slotIndex}</span>`;
	slot.appendChild(header);

	const visual = document.createElement('div');
	visual.className = 'item-visual';
	if (item) {
		const image = resolveItemImage(item);
		if (image) {
			const img = document.createElement('img');
			img.className = 'item-image';
			img.src = image;
			img.alt = item.label || item.name || 'Item';
			img.draggable = false;
			visual.appendChild(img);
		}
	}
	slot.appendChild(visual);

	const info = document.createElement('div');
	if (item) {
		const label = document.createElement('div');
		label.className = 'item-label';
		label.textContent = item.label || item.name || 'Item';
		info.appendChild(label);

		const meta = document.createElement('div');
		meta.className = 'item-meta';
		meta.textContent = `${toInteger(item.totalWeight, 0)}g • stack ${toInteger(item.maxStack, 1)}`;
		info.appendChild(meta);

		if (toInteger(item.count, 1) > 1) {
			const count = document.createElement('div');
			count.className = 'item-count';
			count.textContent = `x${toInteger(item.count, 1)}`;
			slot.appendChild(count);
		}
	} else {
		const empty = document.createElement('div');
		empty.className = 'item-meta';
		empty.textContent = 'Empty';
		info.appendChild(empty);
	}
	slot.appendChild(info);

	if (panel === 'self' && item) {
		slot.addEventListener('mousedown', (event) => beginDrag(event, slotIndex, item, slot));
	}

	return slot;
}

function renderInventoryPanels() {
	const inventory = normalizeInventory(state.inventory);
	const itemsBySlot = getItemsBySlot(inventory);
	const usedSlots = Object.keys(itemsBySlot).length;
	const usedWeight = getInventoryWeight(inventory);

	slotsText.textContent = `${usedSlots} / ${inventory.slots}`;
	weightText.textContent = `${usedWeight} / ${inventory.maxWeight}`;

	selfGrid.innerHTML = '';
	for (let slot = 1; slot <= inventory.slots; slot += 1) {
		selfGrid.appendChild(buildSlot(slot, itemsBySlot[slot] || null, 'self'));
	}

	if (!state.target) {
		targetPanel.classList.add('panel-hidden');
		return;
	}

	targetPanel.classList.remove('panel-hidden');
	targetPanelTitle.textContent = `${state.target.targetName} (${state.target.targetId})`;
	targetGrid.innerHTML = '';
	const targetInventory = normalizeInventory(state.target.targetInventory);
	const targetItemsBySlot = getItemsBySlot(targetInventory);
	for (let slot = 1; slot <= targetInventory.slots; slot += 1) {
		targetGrid.appendChild(buildSlot(slot, targetItemsBySlot[slot] || null, 'target'));
	}
}

async function handleDropAction(target) {
	if (!state.drag || state.drag.panel !== 'self') {
		return;
	}

	const sourceItem = state.drag.item;
	const sourceSlot = state.drag.slot;

	if (!target) {
		setStatus('Drag cancelled.');
		return;
	}

	if (target.type === 'ground') {
		const amount = await resolveDragAmount(sourceItem, 'Drop');
		if (amount === null) {
			setStatus('Drop cancelled.');
			return;
		}
		const response = await postNui('dropItem', { fromSlot: sourceSlot, amount });
		if (!response || response.ok !== true) {
			setStatus('Could not drop item.');
			return;
		}
		setStatus(`Dropped ${sourceItem.label || sourceItem.name} x${amount}.`);
		return;
	}

	if (target.type === 'slot' && target.panel === 'self') {
		if (target.slot < 1 || target.slot === sourceSlot) {
			setStatus('Drag cancelled.');
			return;
		}
		const amount = await resolveDragAmount(sourceItem, 'Move');
		if (amount === null) {
			setStatus('Move cancelled.');
			return;
		}
		const response = await postNui('moveItem', { fromSlot: sourceSlot, toSlot: target.slot, amount });
		if (!response || response.ok !== true) {
			setStatus('Could not move item.');
			return;
		}
		setStatus('Item moved.');
		return;
	}

	if (target.type === 'slot' && target.panel === 'target') {
		if (!state.target || !state.target.targetId) {
			setStatus('Open a target inventory first.');
			return;
		}
		const amount = await resolveDragAmount(sourceItem, 'Give');
		if (amount === null) {
			setStatus('Transfer cancelled.');
			return;
		}
		const response = await postNui('giveItem', {
			targetId: state.target.targetId,
			fromSlot: sourceSlot,
			toSlot: target.slot,
			amount
		});
		if (!response || response.ok !== true) {
			setStatus('Could not give item.');
			return;
		}
		setStatus(`Gave ${sourceItem.label || sourceItem.name} x${amount}.`);
	}
}

document.addEventListener('mousemove', (event) => {
	if (!state.drag) {
		return;
	}
	positionDragPreview(event.clientX, event.clientY);
	updateDropHighlight(event.clientX, event.clientY);
});

document.addEventListener('mouseup', async (event) => {
	if (!state.drag) {
		return;
	}
	const currentDrag = state.drag;
	const target = updateDropHighlight(event.clientX, event.clientY);
	await handleDropAction(target);
	if (state.drag === currentDrag) {
		resetDragState();
	}
});

closeButton.addEventListener('click', () => {
	postNui('closeInventory');
});

openTargetButton.addEventListener('click', async () => {
	if (state.target) {
		state.target = null;
		renderInventoryPanels();
		setStatus('Target panel closed.');
		return;
	}

	const targetId = Math.max(0, toInteger(targetInput.value, 0));
	if (targetId < 1) {
		setStatus('Enter a valid target server ID.');
		return;
	}

	const response = await postNui('requestTransferTargetInventory', { targetId });
	if (!response || response.ok !== true) {
		setStatus('Could not open target inventory.');
		return;
	}

	setStatus(`Requested inventory for ID ${targetId}.`);
});

window.addEventListener('keydown', (event) => {
	if (event.key === 'Escape') {
		if (!amountModal.classList.contains('hidden')) {
			if (activeAmountCleanup) {
				activeAmountCleanup(null);
			}
			return;
		}
		if (state.drag) {
			resetDragState();
			setStatus('Drag cancelled.');
			return;
		}
		postNui('closeInventory');
	}
});

window.addEventListener('message', (event) => {
	const payload = event.data || {};

	if (payload.action === 'setVisible') {
		setVisible(payload.visible === true);
		if (payload.visible === true) {
			postNui('requestInventory');
		} else {
			resetDragState();
		}
		return;
	}

	if (payload.action === 'setInventoryData') {
		state.inventory = normalizeInventory(payload.inventory);
		renderInventoryPanels();
		return;
	}

	if (payload.action === 'setTransferTarget') {
		state.target = normalizeTarget(payload.target);
		renderInventoryPanels();
		return;
	}

	if (payload.action === 'clearTransferTarget') {
		state.target = null;
		renderInventoryPanels();
	}
});

setVisible(false);
renderInventoryPanels();
