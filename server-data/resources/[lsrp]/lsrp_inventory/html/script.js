const resourceName = typeof window.GetParentResourceName === 'function'
	? window.GetParentResourceName()
	: 'lsrp_inventory';

const state = {
	visible: false,
	inventory: { slots: 0, maxWeight: 0, items: [] },
	transferTarget: null,
	stashTarget: null,
	nearbyPlayers: [],
	drag: null
};

function getActiveTarget() {
	return state.stashTarget || state.transferTarget;
}

const appElement = document.getElementById('app');
const closeButton = document.getElementById('close-btn');
const weightText = document.getElementById('weight-text');
const selfGrid = document.getElementById('self-grid');
const targetGrid = document.getElementById('target-grid');
const targetPanel = document.getElementById('target-panel');
const targetPanelTitle = document.getElementById('target-panel-title');
const nearbyPanel = document.getElementById('nearby-panel');
const closeTargetButton = document.getElementById('close-target-btn');
const refreshNearbyButton = document.getElementById('refresh-nearby-btn');
const nearbyPlayersElement = document.getElementById('nearby-players');
const statusText = document.getElementById('status-text');
const useDropZone = document.getElementById('use-drop-zone');
const amountModal = document.getElementById('amount-modal');
const amountTitle = document.getElementById('amount-modal-title');
const amountInput = document.getElementById('amount-input');
const amountConfirm = document.getElementById('amount-confirm');
const amountCancel = document.getElementById('amount-cancel');
let activeAmountCleanup = null;
let lastNearbyPlayersRenderKey = '';

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
	const rawTargetId = raw.targetId;
	const normalizedTargetId = typeof rawTargetId === 'string'
		? rawTargetId
		: Math.max(1, toInteger(rawTargetId, 0));
	return {
		targetId: normalizedTargetId,
		targetName: String(raw.targetName || 'Player'),
		targetKind: String(raw.targetKind || 'player'),
		targetInventory: normalizeInventory(raw.targetInventory || {}),
		targetMeta: raw.targetMeta && typeof raw.targetMeta === 'object' ? raw.targetMeta : null
	};
}

function isStashTarget() {
	const activeTarget = getActiveTarget();
	return Boolean(activeTarget && activeTarget.targetKind === 'stash');
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

function isTransientInventoryItem(item) {
	return Boolean(item && item.metadata && item.metadata.transient === true);
}

function setVisible(visible) {
	state.visible = Boolean(visible);
	appElement.classList.toggle('hidden', !state.visible);
}

function setStatus(message) {
	statusText.textContent = String(message || '');
}

function getNearbyPlayersRenderKey(players) {
	if (!Array.isArray(players)) {
		return '';
	}

	return players.map((player) => {
		const targetId = toInteger(player && player.targetId, 0);
		const targetName = String((player && player.targetName) || '');
		return `${targetId}:${targetName}`;
	}).join('|');
}

async function requestOpenTargetInventory(targetId) {
	const normalizedTargetId = Math.max(1, toInteger(targetId, 0));
	const response = await postNui('requestTransferTargetInventory', { targetId: normalizedTargetId });
	if (!response || response.ok !== true) {
		setStatus('Could not open target inventory.');
		return;
	}

	setStatus(`Requested inventory for ID ${normalizedTargetId}.`);
}

function renderNearbyPlayers() {
	if (!nearbyPlayersElement) {
		return;
	}

	const players = Array.isArray(state.nearbyPlayers) ? state.nearbyPlayers : [];
	const renderKey = getNearbyPlayersRenderKey(players);
	if (renderKey === lastNearbyPlayersRenderKey) {
		return;
	}

	lastNearbyPlayersRenderKey = renderKey;
	nearbyPlayersElement.innerHTML = '';
	if (players.length === 0) {
		const empty = document.createElement('div');
		empty.className = 'nearby-empty';
		empty.textContent = 'No nearby players in transfer range.';
		nearbyPlayersElement.appendChild(empty);
		return;
	}

	for (const player of players) {
		const row = document.createElement('div');
		row.className = 'nearby-player';

		const info = document.createElement('div');
		const name = document.createElement('div');
		name.className = 'nearby-player-name';
		name.textContent = `${player.targetName || 'Player'} (${toInteger(player.targetId, 0)})`;
		info.appendChild(name);

		const meta = document.createElement('div');
		meta.className = 'nearby-player-meta';
		meta.textContent = `${Number(player.distance || 0).toFixed(1)}m away`;
		info.appendChild(meta);

		const button = document.createElement('button');
		button.type = 'button';
		button.textContent = 'Open';
		button.addEventListener('click', () => {
			requestOpenTargetInventory(player.targetId);
		});

		row.appendChild(info);
		row.appendChild(button);
		nearbyPlayersElement.appendChild(row);
	}
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

	const useZoneElement = element.closest('#use-drop-zone');
	if (useZoneElement) {
		useZoneElement.classList.add('drop-target');
		return { type: 'use' };
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

function beginDrag(event, slotIndex, item, sourceElement, panel) {
	if (event.button !== 0 || !state.visible || !amountModal.classList.contains('hidden')) {
		return;
	}

	event.preventDefault();
	resetDragState();
	state.drag = {
		panel: panel,
		slot: slotIndex,
		item,
		sourceElement,
		previewElement: createDragPreview(item),
		ctrl: Boolean(event.ctrlKey || event.metaKey)
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
		meta.textContent = isTransientInventoryItem(item)
			? `${toInteger(item.totalWeight, 0)}g • key item`
			: `${toInteger(item.totalWeight, 0)}g`;
		info.appendChild(meta);

		if (toInteger(item.count, 1) > 1) {
			const count = document.createElement('div');
			count.className = 'item-count';
			count.textContent = `x${toInteger(item.count, 1)}`;
			slot.appendChild(count);
		}
	}
	slot.appendChild(info);

	if ((panel === 'self' && item) || (panel === 'target' && item && isStashTarget())) {
		slot.addEventListener('mousedown', (event) => beginDrag(event, slotIndex, item, slot, panel));
	}

	return slot;
}

function renderInventoryPanels() {
	const inventory = normalizeInventory(state.inventory);
	const itemsBySlot = getItemsBySlot(inventory);
	const usedSlots = Object.keys(itemsBySlot).length;
	const usedWeight = getInventoryWeight(inventory);

	weightText.textContent = `${usedWeight} / ${inventory.maxWeight}`;

	selfGrid.innerHTML = '';
	for (let slot = 1; slot <= inventory.slots; slot += 1) {
		selfGrid.appendChild(buildSlot(slot, itemsBySlot[slot] || null, 'self'));
	}

	const activeTarget = getActiveTarget();
	if (!activeTarget) {
		targetPanelTitle.textContent = 'Nearby Players';
		targetGrid.classList.add('panel-hidden');
		if (nearbyPanel) {
			nearbyPanel.classList.remove('panel-hidden');
		}
		lastNearbyPlayersRenderKey = '';
		if (closeTargetButton) {
			closeTargetButton.disabled = true;
		}
		if (refreshNearbyButton) {
			refreshNearbyButton.disabled = false;
		}
		renderNearbyPlayers();
		return;
	}

	targetPanelTitle.textContent = isStashTarget()
		? activeTarget.targetName
		: `${activeTarget.targetName} (${activeTarget.targetId})`;
	targetGrid.classList.remove('panel-hidden');
	if (nearbyPanel) {
		nearbyPanel.classList.add('panel-hidden');
	}
	if (closeTargetButton) {
		closeTargetButton.disabled = false;
	}
	if (refreshNearbyButton) {
		refreshNearbyButton.disabled = true;
	}
	targetGrid.innerHTML = '';
	const targetInventory = normalizeInventory(activeTarget.targetInventory);
	const targetItemsBySlot = getItemsBySlot(targetInventory);
	for (let slot = 1; slot <= targetInventory.slots; slot += 1) {
		targetGrid.appendChild(buildSlot(slot, targetItemsBySlot[slot] || null, 'target'));
	}
}

async function handleDropAction(target) {
	if (!state.drag) {
		return;
	}

	const sourceItem = state.drag.item;
	const sourceSlot = state.drag.slot;
	const isSelfDrag = state.drag.panel === 'self';
	const isTargetDrag = state.drag.panel === 'target';

	if (!target) {
		setStatus('Drag cancelled.');
		return;
	}

	if (target.type === 'use') {
		if (!isSelfDrag) {
			setStatus('Only your own inventory items can be used here.');
			return;
		}

		if (isTransientInventoryItem(sourceItem)) {
			setStatus('Key items cannot be used here.');
			return;
		}

		if (!sourceItem.use || typeof sourceItem.use !== 'object') {
			setStatus('That item cannot be used.');
			return;
		}

		const response = await postNui('useItem', { fromSlot: sourceSlot });
		if (!response || response.ok !== true) {
			if (response && response.error === 'busy') {
				setStatus('You are already using an item.');
			} else if (response && response.error === 'not_usable') {
				setStatus('That item cannot be used.');
			} else {
				setStatus('Could not use item.');
			}
			return;
		}

		setStatus(`${sourceItem.use.label || 'Using'} ${sourceItem.label || sourceItem.name}...`);
		return;
	}

	if (target.type === 'ground') {
		if (!isSelfDrag) {
			setStatus('Storage items cannot be dropped directly to the ground.');
			return;
		}

		if (isTransientInventoryItem(sourceItem)) {
			setStatus('Key items cannot be dropped.');
			return;
		}

		let amount;
		if (state.drag && state.drag.ctrl) {
			amount = await resolveDragAmount(sourceItem, 'Drop');
			if (amount === null) {
				setStatus('Drop cancelled.');
				return;
			}
		} else {
			amount = Math.max(1, toInteger(sourceItem.count, 1));
		}
		const response = await postNui('dropItem', { fromSlot: sourceSlot, amount });
		if (!response || response.ok !== true) {
			setStatus('Could not drop item.');
			return;
		}
		setStatus(`Dropped ${sourceItem.label || sourceItem.name} x${amount}.`);
		return;
	}

	if (target.type === 'slot' && target.panel === 'self' && isSelfDrag) {
		if (target.slot < 1 || target.slot === sourceSlot) {
			setStatus('Drag cancelled.');
			return;
		}
		let amount;
		if (state.drag && state.drag.ctrl) {
			amount = await resolveDragAmount(sourceItem, 'Move');
			if (amount === null) {
				setStatus('Move cancelled.');
				return;
			}
		} else {
			amount = Math.max(1, toInteger(sourceItem.count, 1));
		}
		const response = await postNui('moveItem', { fromSlot: sourceSlot, toSlot: target.slot, amount });
		if (!response || response.ok !== true) {
			setStatus('Could not move item.');
			return;
		}
		setStatus('Item moved.');
		return;
	}

	if (target.type === 'slot' && target.panel === 'target' && isSelfDrag) {
		if (isTransientInventoryItem(sourceItem)) {
			setStatus('Key items cannot be transferred.');
			return;
		}

		const activeTarget = getActiveTarget();
		if (!activeTarget || !activeTarget.targetId) {
			setStatus('Open a target inventory first.');
			return;
		}
		let amount;
		if (state.drag && state.drag.ctrl) {
			amount = await resolveDragAmount(sourceItem, 'Give');
			if (amount === null) {
				setStatus('Transfer cancelled.');
				return;
			}
		} else {
			amount = Math.max(1, toInteger(sourceItem.count, 1));
		}
		let response;
		if (isStashTarget()) {
			response = await postNui('storeItemInStash', {
				stashId: activeTarget.targetId,
				fromSlot: sourceSlot,
				toSlot: target.slot,
				amount
			});
		} else {
			response = await postNui('giveItem', {
				targetId: activeTarget.targetId,
				fromSlot: sourceSlot,
				toSlot: target.slot,
				amount
			});
		}
		if (!response || response.ok !== true) {
			setStatus(isStashTarget() ? 'Could not store item.' : 'Could not give item.');
			return;
		}
		setStatus(isStashTarget()
			? `Stored ${sourceItem.label || sourceItem.name} x${amount}.`
			: `Gave ${sourceItem.label || sourceItem.name} x${amount}.`);
		return;
	}

	if (isTargetDrag && isStashTarget() && target.type === 'slot' && target.panel === 'self') {
		let amount;
		if (state.drag && state.drag.ctrl) {
			amount = await resolveDragAmount(sourceItem, 'Retrieve');
			if (amount === null) {
				setStatus('Retrieve cancelled.');
				return;
			}
		} else {
			amount = Math.max(1, toInteger(sourceItem.count, 1));
		}

		const response = await postNui('takeItemFromStash', {
			stashId: getActiveTarget().targetId,
			fromSlot: sourceSlot,
			toSlot: target.slot,
			amount
		});
		if (!response || response.ok !== true) {
			setStatus('Could not retrieve item.');
			return;
		}
		setStatus(`Retrieved ${sourceItem.label || sourceItem.name} x${amount}.`);
		return;
	}

	if (isTargetDrag && isStashTarget() && target.type === 'slot' && target.panel === 'target') {
		if (target.slot < 1 || target.slot === sourceSlot) {
			setStatus('Drag cancelled.');
			return;
		}

		let amount;
		if (state.drag && state.drag.ctrl) {
			amount = await resolveDragAmount(sourceItem, 'Move');
			if (amount === null) {
				setStatus('Move cancelled.');
				return;
			}
		} else {
			amount = Math.max(1, toInteger(sourceItem.count, 1));
		}

		const response = await postNui('moveItemInStash', {
			stashId: getActiveTarget().targetId,
			fromSlot: sourceSlot,
			toSlot: target.slot,
			amount
		});
		if (!response || response.ok !== true) {
			setStatus('Could not move storage item.');
			return;
		}
		setStatus('Storage item moved.');
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

if (closeTargetButton) {
	closeTargetButton.addEventListener('click', () => {
		postNui('closeTargetContext');
			state.transferTarget = null;
			state.stashTarget = null;
		renderInventoryPanels();
		setStatus('Target panel closed.');
	});
}

if (refreshNearbyButton) {
	refreshNearbyButton.addEventListener('click', async () => {
		const response = await postNui('requestNearbyPlayers');
		if (!response || response.ok !== true) {
			setStatus('Could not refresh nearby players.');
			return;
		}
		setStatus('Nearby players refreshed.');
	});
}

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

	if (payload.action === 'setNearbyPlayers') {
		state.nearbyPlayers = Array.isArray(payload.players) ? payload.players : [];
		if (!getActiveTarget()) {
			renderNearbyPlayers();
		}
		return;
	}

	if (payload.action === 'setSecondaryTarget') {
		const normalizedTarget = normalizeTarget(payload.target);
		if (normalizedTarget && normalizedTarget.targetKind === 'stash') {
			state.stashTarget = normalizedTarget;
		} else {
			state.transferTarget = normalizedTarget;
		}
		renderInventoryPanels();
		return;
	}

	if (payload.action === 'clearSecondaryTarget') {
		state.transferTarget = null;
		state.stashTarget = null;
		renderInventoryPanels();
		return;
	}

	if (payload.action === 'clearTransferTarget') {
		state.transferTarget = null;
		renderInventoryPanels();
		return;
	}

	if (payload.action === 'clearStashTarget') {
		state.stashTarget = null;
		renderInventoryPanels();
	}
});

setVisible(false);
renderInventoryPanels();
