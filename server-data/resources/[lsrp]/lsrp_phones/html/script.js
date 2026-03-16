// Update time display
function updateTime() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    document.getElementById('phone-time').innerText = hours + ':' + minutes;
}

const appScreens = ['balance-app', 'parking-app', 'calls-app', 'phonebook-app'];

const balanceState = {
    rawBalance: 0,
    formattedBalance: 'LS$0',
    available: true,
    updatedAt: null
};

const callState = {
    myNumber: null,
    incomingFrom: null,
    ringingTarget: null,
    inCall: false,
    otherParty: null,
    phonebookEntries: [],
    phoneVisible: false
};

const MAX_PHONE_DIGITS = 7;

function postNui(endpoint, payload = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload)
    });
}

// Close phone
function closePhone() {
    postNui('closePhone');
}

function formatBalanceTimestamp(date) {
    if (!(date instanceof Date)) {
        return 'Not synced yet.';
    }

    return `Updated at ${date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
}

function loadBalance() {
    const balanceStatus = document.getElementById('balance-status');
    const balanceMeta = document.getElementById('balance-meta');

    if (balanceStatus) {
        balanceStatus.innerText = 'Checking your LS$ account...';
    }

    if (balanceMeta && !balanceState.updatedAt) {
        balanceMeta.innerText = 'Syncing now...';
    }

    postNui('getBalance');
}

function setBalance(balance, formattedBalance, available) {
    const numericBalance = Number.isFinite(Number(balance))
        ? Math.max(0, Math.floor(Number(balance)))
        : 0;

    balanceState.rawBalance = numericBalance;
    balanceState.formattedBalance = typeof formattedBalance === 'string' && formattedBalance
        ? formattedBalance
        : `LS$${numericBalance}`;
    balanceState.available = available !== false;
    balanceState.updatedAt = new Date();

    const balanceValue = document.getElementById('balance-value');
    const balanceStatus = document.getElementById('balance-status');
    const balanceMeta = document.getElementById('balance-meta');

    if (balanceValue) {
        balanceValue.innerText = balanceState.formattedBalance;
    }

    if (balanceStatus) {
        balanceStatus.innerText = balanceState.available
            ? 'Synced with your LS$ account.'
            : 'Economy service is unavailable right now.';
    }

    if (balanceMeta) {
        balanceMeta.innerText = formatBalanceTimestamp(balanceState.updatedAt);
    }
}

// Open app
function openApp(appName) {
    appScreens.forEach((screenId) => {
        const screen = document.getElementById(screenId);
        if (screen) {
            screen.style.display = 'none';
        }
    });

    document.getElementById('home-screen').style.display = 'none';
    const appScreen = document.getElementById(`${appName}-app`);
    if (!appScreen) {
        document.getElementById('home-screen').style.display = 'block';
        return;
    }

    appScreen.style.display = 'flex';

    if (appName === 'parking') {
        loadParkedVehicles();
    } else if (appName === 'balance') {
        loadBalance();
    } else if (appName === 'calls') {
        updateCallUI();
    } else if (appName === 'phonebook') {
        renderPhonebook();
        loadPhonebook();
    }
}

// Close app
function closeApp() {
    appScreens.forEach((screenId) => {
        const screen = document.getElementById(screenId);
        if (screen) {
            screen.style.display = 'none';
        }
    });

    document.getElementById('home-screen').style.display = 'block';
}

// Load parked vehicles
function loadParkedVehicles() {
    console.log('[Phone] Loading owned vehicles...');
    document.getElementById('vehicle-list').innerHTML = '<p class="loading">Loading vehicles...</p>';
    setParkingStatus('Loading your vehicles...', false);

    postNui('getParkedVehicles');
}

function setParkingStatus(message, isError = false) {
    const parkingStatusElement = document.getElementById('parking-status');
    if (!parkingStatusElement) {
        return;
    }

    parkingStatusElement.innerText = message || '';
    parkingStatusElement.classList.toggle('parking-status-error', Boolean(isError));
}

function setParkingWaypoint(parkingZone, vehicleLabel) {
    const zoneName = String(parkingZone || '').trim();
    const label = String(vehicleLabel || 'vehicle').trim() || 'vehicle';

    if (!zoneName) {
        setParkingStatus('No parking location is available for this vehicle.', true);
        return;
    }

    postNui('setParkingWaypoint', { zoneName })
        .then((response) => response.json().catch(() => ({ ok: true })))
        .then((result) => {
            if (result && result.ok === false) {
                if (result.error === 'parking_unavailable') {
                    setParkingStatus('Parking GPS is unavailable right now.', true);
                } else {
                    setParkingStatus('Could not set GPS for this vehicle.', true);
                }
                return;
            }

            setParkingStatus(`GPS request sent for ${label}.`, false);
        })
        .catch(() => {
            setParkingStatus('Could not set GPS right now.', true);
        });
}

function loadPhonebook() {
    const phonebookList = document.getElementById('phonebook-list');
    if (phonebookList) {
        phonebookList.innerHTML = '<p class="loading">Loading contacts...</p>';
    }

    postNui('getPhonebook');
}

// Display vehicles
function displayVehicles(vehicles) {
    console.log('[Phone] Displaying vehicles:', vehicles);
    const vehicleList = document.getElementById('vehicle-list');

    if (!vehicles || vehicles.length === 0) {
        vehicleList.innerHTML = '<p class="loading">No owned vehicles found</p>';
        setParkingStatus('No vehicles are registered to you yet.', false);
        return;
    }

    vehicleList.innerHTML = '';
    setParkingStatus('Tap a parked vehicle or use Set GPS to navigate to its parking zone.', false);

    vehicles.forEach(vehicle => {
        const vehicleItem = document.createElement('div');
        const vehicleStatus = String(vehicle.status || '').trim().toLowerCase();
        const isParked = vehicleStatus !== 'out';
        const modelName = vehicle.vehicle_model || 'Unknown';
        const plateName = vehicle.vehicle_plate || 'Unknown';
        const parkingZone = typeof vehicle.parking_zone === 'string' ? vehicle.parking_zone.trim() : '';
        const parkingZoneLabel = parkingZone || 'Unknown Location';
        const statusLabel = isParked ? 'Parked' : 'Out';

        vehicleItem.className = isParked ? 'vehicle-item vehicle-item-interactive' : 'vehicle-item';

        const setGpsForVehicle = () => {
            if (!isParked) {
                return;
            }

            setParkingWaypoint(parkingZone, modelName);
        };

        if (isParked) {
            vehicleItem.addEventListener('click', () => {
                setGpsForVehicle();
            });

            vehicleItem.addEventListener('keydown', (event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    setGpsForVehicle();
                }
            });

            vehicleItem.tabIndex = 0;
        }

        const titleRow = document.createElement('div');
        titleRow.className = 'vehicle-heading';

        const title = document.createElement('h4');
        title.innerText = modelName;

        const statusBadge = document.createElement('span');
        statusBadge.className = `vehicle-status ${isParked ? 'vehicle-status-parked' : 'vehicle-status-out'}`;
        statusBadge.innerText = statusLabel;

        titleRow.appendChild(title);
        titleRow.appendChild(statusBadge);

        const info = document.createElement('div');
        info.className = 'vehicle-info';

        const locationText = document.createElement('span');
        locationText.innerText = isParked ? `📍 ${parkingZoneLabel}` : '🚗 Currently out in the world';

        const plateText = document.createElement('span');
        plateText.innerText = `🔢 ${plateName}`;

        const garageText = document.createElement('span');
        garageText.innerText = `🏁 Home garage: ${parkingZoneLabel}`;

        info.appendChild(locationText);
        info.appendChild(plateText);
        info.appendChild(garageText);

        const actions = document.createElement('div');
        actions.className = 'vehicle-actions';

        const gpsButton = document.createElement('button');
        gpsButton.type = 'button';
        gpsButton.className = 'vehicle-gps-btn';
        gpsButton.innerText = isParked ? 'Set GPS' : 'Vehicle Out';
        gpsButton.disabled = !isParked;

        if (isParked) {
            gpsButton.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                setGpsForVehicle();
            });
        }

        actions.appendChild(gpsButton);

        vehicleItem.appendChild(titleRow);
        vehicleItem.appendChild(info);
        vehicleItem.appendChild(actions);

        vehicleList.appendChild(vehicleItem);
    });
}

function updateIncomingToast() {
    const toastNumber = document.getElementById('incoming-toast-number');
    const shouldShowToast = Boolean(callState.incomingFrom) && !callState.inCall && !callState.phoneVisible;

    if (toastNumber) {
        toastNumber.innerText = callState.incomingFrom || 'Unknown';
    }

    document.body.classList.toggle('show-incoming-toast', shouldShowToast);
}

function setMyPhoneNumber(phoneNumber) {
    const myNumberElement = document.getElementById('my-phone-number');
    callState.myNumber = phoneNumber || null;

    if (myNumberElement) {
        if (callState.myNumber) {
            myNumberElement.innerText = `Your number: ${callState.myNumber}`;
        } else {
            myNumberElement.innerText = 'Your number: Unassigned';
        }
    }

    renderPhonebook();
}

function normalizePhoneNumber(value) {
    const raw = String(value || '').trim();
    if (!raw) {
        return null;
    }

    if (/^555-\d{4}$/.test(raw)) {
        return raw;
    }

    const digits = raw.replace(/\D/g, '');

    if (/^555\d{4}$/.test(digits)) {
        return `${digits.slice(0, 3)}-${digits.slice(3, 7)}`;
    }

    if (/^\d{4}$/.test(digits)) {
        return `555-${digits}`;
    }

    return null;
}

function formatPhoneDigits(digits) {
    const safeDigits = String(digits || '').replace(/\D/g, '').slice(0, MAX_PHONE_DIGITS);
    if (safeDigits.length <= 3) {
        return safeDigits;
    }

    return `${safeDigits.slice(0, 3)}-${safeDigits.slice(3)}`;
}

function getDialInputElement() {
    return document.getElementById('call-target-id');
}

function getDialDigits() {
    const targetInput = getDialInputElement();
    if (!targetInput) {
        return '';
    }

    return targetInput.value.replace(/\D/g, '').slice(0, MAX_PHONE_DIGITS);
}

function setDialDigits(digits) {
    const targetInput = getDialInputElement();
    if (!targetInput) {
        return;
    }

    targetInput.value = formatPhoneDigits(digits);
}

function dialPadPress(value) {
    const targetInput = getDialInputElement();
    if (!targetInput || targetInput.disabled) {
        return;
    }

    const numericValue = String(value || '').replace(/\D/g, '');
    if (!numericValue) {
        return;
    }

    const currentDigits = getDialDigits();
    if (currentDigits.length >= MAX_PHONE_DIGITS) {
        return;
    }

    setDialDigits(currentDigits + numericValue);
}

function dialPadBackspace() {
    const targetInput = getDialInputElement();
    if (!targetInput || targetInput.disabled) {
        return;
    }

    const currentDigits = getDialDigits();
    setDialDigits(currentDigits.slice(0, -1));
}

function dialPadClear() {
    const targetInput = getDialInputElement();
    if (!targetInput || targetInput.disabled) {
        return;
    }

    setDialDigits('');
}

function setupDialInput() {
    const targetInput = getDialInputElement();
    if (!targetInput || targetInput.dataset.dialReady === '1') {
        return;
    }

    targetInput.dataset.dialReady = '1';
    targetInput.addEventListener('input', () => {
        setDialDigits(targetInput.value);
    });
}

function callPhonebookEntry(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber);
    if (!normalized) {
        return;
    }

    openApp('calls');
    startCall(normalized);
}

function updatePhonebookButtonStates() {
    const busy = callState.inCall || callState.ringingTarget !== null || callState.incomingFrom !== null;

    document.querySelectorAll('.phonebook-entry-main').forEach((button) => {
        const phoneNumber = button.dataset.phoneNumber || '';
        const online = button.dataset.online === '1';
        const isSelf = phoneNumber === callState.myNumber;
        button.disabled = busy || !online || isSelf;
    });
}

function renderPhonebook() {
    const phonebookList = document.getElementById('phonebook-list');
    if (!phonebookList) {
        return;
    }

    const entries = Array.isArray(callState.phonebookEntries) ? callState.phonebookEntries : [];
    phonebookList.innerHTML = '';

    if (entries.length === 0) {
        phonebookList.innerHTML = '<p class="phonebook-empty">No contacts available yet.</p>';
        return;
    }

    entries.forEach((entry) => {
        if (!entry || !entry.phoneNumber) {
            return;
        }

        const row = document.createElement('div');
        row.className = 'phonebook-entry';

        const mainButton = document.createElement('button');
        mainButton.type = 'button';
        mainButton.className = 'phonebook-entry-main';
        mainButton.dataset.phoneNumber = entry.phoneNumber;
        mainButton.dataset.online = entry.online ? '1' : '0';
        mainButton.addEventListener('click', () => {
            callPhonebookEntry(entry.phoneNumber);
        });

        const name = document.createElement('span');
        name.className = 'phonebook-entry-name';
        name.innerText = entry.phoneNumber === callState.myNumber
            ? `${entry.displayName || 'Unknown'} (You)`
            : (entry.displayName || 'Unknown');

        const details = document.createElement('div');
        details.className = 'phonebook-entry-details';

        const number = document.createElement('span');
        number.innerText = entry.phoneNumber;

        const status = document.createElement('span');
        status.className = `phonebook-status ${entry.online ? 'online' : 'offline'}`;
        status.innerText = entry.online ? 'Online' : 'Offline';

        details.appendChild(number);
        details.appendChild(status);
        mainButton.appendChild(name);
        mainButton.appendChild(details);
        row.appendChild(mainButton);
        phonebookList.appendChild(row);
    });

    if (!phonebookList.children.length) {
        phonebookList.innerHTML = '<p class="phonebook-empty">No contacts available yet.</p>';
        return;
    }

    updatePhonebookButtonStates();
}

function displayPhonebook(entries) {
    callState.phonebookEntries = Array.isArray(entries) ? entries : [];
    renderPhonebook();
}

function updateCallUI() {
    const callsContent = document.querySelector('.calls-content');
    const incomingPanel = document.getElementById('incoming-call');
    const incomingText = document.getElementById('incoming-call-text');
    const endButton = document.getElementById('end-call-btn');
    const startButton = document.getElementById('start-call-btn');
    const targetInput = document.getElementById('call-target-id');

    if (!callsContent || !incomingPanel || !incomingText || !endButton || !startButton || !targetInput) {
        return;
    }

    const incomingMode = Boolean(callState.incomingFrom) && !callState.inCall;
    callsContent.classList.toggle('incoming-mode', incomingMode);

    if (incomingMode) {
        incomingPanel.style.display = 'block';
        incomingText.innerText = `Incoming call from ${callState.incomingFrom}`;
    } else {
        incomingPanel.style.display = 'none';
    }

    const busy = callState.inCall || callState.ringingTarget !== null;
    const lockDialInput = busy || callState.incomingFrom !== null;

    startButton.disabled = lockDialInput;
    targetInput.disabled = lockDialInput;

    const dialButtons = document.querySelectorAll('.dial-key');
    dialButtons.forEach((button) => {
        button.disabled = lockDialInput;
    });

    if (busy) {
        endButton.style.display = 'block';
    } else {
        endButton.style.display = 'none';
    }

    updatePhonebookButtonStates();
    updateIncomingToast();
}

function startCall(prefilledNumber) {
    const targetInput = document.getElementById('call-target-id');
    if (!targetInput) {
        return;
    }

    const rawValue = prefilledNumber || formatPhoneDigits(getDialDigits());
    const targetNumber = normalizePhoneNumber(rawValue);
    if (!targetNumber) {
        setCallStatus('Enter a valid number (example: 555-0001).');
        return;
    }

    targetInput.value = targetNumber;
    postNui('startCall', { phoneNumber: targetNumber });
}

function acceptCall() {
    postNui('acceptCall');
}

function declineCall() {
    postNui('declineCall');
}

function endCall() {
    postNui('endCall');
}

function onCallIncoming(fromNumber) {
    callState.incomingFrom = fromNumber;
    callState.ringingTarget = null;
    setCallStatus(`Incoming call from ${fromNumber}`);

    if (callState.phoneVisible) {
        openApp('calls');
    }

    updateCallUI();
}

function onCallOutgoing(targetNumber) {
    callState.incomingFrom = null;
    callState.ringingTarget = targetNumber;
    callState.inCall = false;
    callState.otherParty = targetNumber;
    setCallStatus(`Ringing ${targetNumber}...`);
    updateCallUI();
}

function onCallConnected(otherNumber) {
    callState.incomingFrom = null;
    callState.ringingTarget = null;
    callState.inCall = true;
    callState.otherParty = otherNumber;
    setCallStatus(`Connected with ${otherNumber}.`);
    updateCallUI();
}

function onCallEnded(reason) {
    callState.incomingFrom = null;
    callState.ringingTarget = null;
    callState.inCall = false;
    callState.otherParty = null;
    setCallStatus(reason || 'Call ended.');
    updateCallUI();
}

// Update time every minute
setInterval(updateTime, 60000);
updateTime();
setupDialInput();
updateCallUI();

// Listen for messages from Lua
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'openPhone') {
        callState.phoneVisible = true;
        document.body.classList.add('show-phone');

        if (callState.incomingFrom && !callState.inCall) {
            openApp('calls');
        }

        updateIncomingToast();
    } else if (data.action === 'closePhone') {
        callState.phoneVisible = false;
        document.body.classList.remove('show-phone');
        closeApp(); // Return to home screen when closing phone
        updateIncomingToast();
    } else if (data.action === 'displayVehicles') {
        displayVehicles(data.vehicles);
    } else if (data.action === 'displayPhonebook') {
        displayPhonebook(data.entries);
    } else if (data.action === 'callIncoming') {
        onCallIncoming(data.fromNumber);
    } else if (data.action === 'callOutgoing') {
        onCallOutgoing(data.targetNumber);
    } else if (data.action === 'callConnected') {
        onCallConnected(data.otherNumber);
    } else if (data.action === 'callEnded') {
        onCallEnded(data.reason);
    } else if (data.action === 'callStatus') {
        setCallStatus(data.message || '');
        updateCallUI();
    } else if (data.action === 'setBalance') {
        setBalance(data.balance, data.formattedBalance, data.available);
    } else if (data.action === 'setPhoneNumber') {
        setMyPhoneNumber(data.phoneNumber);
    }
});

// Close phone with Escape key
window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closePhone();
    }
});

updateIncomingToast();
