const resourceName = typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'lsrp_vehiclebehaviour';

const app = document.getElementById('door-control-app');
const titleEl = document.getElementById('vehicle-title');
const metaEl = document.getElementById('vehicle-meta');
const statusEl = document.getElementById('status-text');
const doorGridEl = document.getElementById('door-grid');
const closeButtonEl = document.getElementById('close-button');

const state = {
    open: false,
    pending: false,
    payload: null,
    payloadKey: null
};

const DOOR_LAYOUT_ORDER = {
    4: 0,
    0: 1,
    1: 2,
    2: 3,
    3: 4,
    5: 5
};

function setAppHidden() {
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');

    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
}

function showAppShell() {
    document.body.style.display = 'block';
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');

    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
}

function getPayloadKey(payload) {
    if (!payload || typeof payload !== 'object') {
        return null;
    }

    const parts = [
        String(payload.plate || ''),
        String(payload.vehicleName || '')
    ];

    const doors = Array.isArray(payload.doors) ? payload.doors : [];
    for (const door of doors) {
        parts.push(`${String(door && door.index)}:${String(door && door.label)}:${door && door.isOpen ? '1' : '0'}`);
    }

    return parts.join('|');
}

async function notifyReady() {
    try {
        await postNui('doorControlReady');
    } catch (error) {
        console.error('[lsrp_vehiclebehaviour] Failed to report NUI ready state', error);
    }
}

function setStatus(message, isError = false) {
    statusEl.textContent = message || 'F2 closes this menu.';
    statusEl.style.color = isError ? '#f0b1a3' : '#b0bbc7';
}

async function postNui(endpoint, payload = {}) {
    const response = await fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        throw new Error(`NUI callback failed: ${endpoint} (${response.status})`);
    }

    return response.json();
}

function renderDoors() {
    doorGridEl.innerHTML = '';

    const payload = state.payload;
    const doors = payload && Array.isArray(payload.doors) ? payload.doors : [];
    const orderedDoors = doors.slice().sort((leftDoor, rightDoor) => {
        const leftIndex = Number(leftDoor && leftDoor.index);
        const rightIndex = Number(rightDoor && rightDoor.index);
        const leftOrder = Object.prototype.hasOwnProperty.call(DOOR_LAYOUT_ORDER, leftIndex)
            ? DOOR_LAYOUT_ORDER[leftIndex]
            : 99;
        const rightOrder = Object.prototype.hasOwnProperty.call(DOOR_LAYOUT_ORDER, rightIndex)
            ? DOOR_LAYOUT_ORDER[rightIndex]
            : 99;

        if (leftOrder !== rightOrder) {
            return leftOrder - rightOrder;
        }

        return leftIndex - rightIndex;
    });

    if (!orderedDoors.length) {
        setStatus('No controllable doors are available for this vehicle.', true);
        return;
    }

    for (const door of orderedDoors) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `door-button${door.isOpen ? ' is-open' : ''}`;
        button.disabled = state.pending;
        button.dataset.doorIndex = String(door.index);

        if (Number(door.index) === 4) {
            button.classList.add('door-button-front');
        } else if (Number(door.index) === 5) {
            button.classList.add('door-button-rear');
        }

        const label = document.createElement('span');
        label.className = 'door-label';
        label.textContent = String(door.label || 'Door');

        const stateText = document.createElement('span');
        stateText.className = 'door-state';
        stateText.textContent = door.isOpen ? 'Open' : 'Closed';

        button.appendChild(label);
        button.appendChild(stateText);
        button.addEventListener('click', () => toggleDoor(door.index));
        doorGridEl.appendChild(button);
    }
}

function applyPayload(payload) {
    const payloadKey = getPayloadKey(payload);
    if (payloadKey && payloadKey === state.payloadKey) {
        return;
    }

    state.payload = payload || null;
    state.payloadKey = payloadKey;

    const vehicleName = payload && payload.vehicleName ? String(payload.vehicleName) : 'Vehicle Door Controls';
    const plate = payload && payload.plate ? String(payload.plate) : 'UNKNOWN';

    titleEl.textContent = vehicleName;
    metaEl.textContent = `Plate ${plate} · Select a door to open or close it.`;
    renderDoors();
}

function openApp(payload) {
    state.open = true;
    state.pending = false;
    showAppShell();
    applyPayload(payload);
    setStatus('F2 closes this menu.');
}

function closeApp() {
    state.open = false;
    state.pending = false;
    state.payload = null;
    state.payloadKey = null;
    setAppHidden();
    doorGridEl.innerHTML = '';
}

async function requestClose() {
    try {
        await postNui('doorControlClose');
    } catch (error) {
        console.error('[lsrp_vehiclebehaviour] Failed to close door control', error);
    } finally {
        closeApp();
    }
}

async function toggleDoor(doorIndex) {
    if (!state.open || state.pending) {
        return;
    }

    state.pending = true;
    renderDoors();
    setStatus('Updating door state...');

    try {
        const response = await postNui('doorControlToggleDoor', { doorIndex });
        if (!response || response.ok !== true) {
            setStatus((response && response.message) || 'Could not update the selected door.', true);
            return;
        }

        if (response.payload) {
            applyPayload(response.payload);
        }

        setStatus('Door state updated.');
    } catch (error) {
        console.error('[lsrp_vehiclebehaviour] Failed to toggle vehicle door', error);
        setStatus('Could not update the selected door.', true);
    } finally {
        state.pending = false;
        renderDoors();
    }
}

closeButtonEl.addEventListener('click', () => {
    requestClose();
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') {
        return;
    }

    if (data.action === 'openDoorControl') {
        openApp(data.payload);
        return;
    }

    if (data.action === 'updateDoorControl') {
        applyPayload(data.payload);
        return;
    }

    if (data.action === 'closeDoorControl') {
        closeApp();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.open) {
        requestClose();
    }
});

if (document.readyState === 'complete' || document.readyState === 'interactive') {
    notifyReady();
}

window.addEventListener('DOMContentLoaded', () => {
    notifyReady();
});

window.addEventListener('load', () => {
    notifyReady();
});

window.setTimeout(() => {
    notifyReady();
}, 250);

setAppHidden();