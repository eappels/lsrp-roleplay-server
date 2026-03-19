function updateTime() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    document.getElementById('phone-time').innerText = hours + ':' + minutes;
}

const appScreens = ['balance-app', 'parking-app', 'calls-app', 'phonebook-app', 'messages-app'];

const uiState = {
    currentApp: null
};

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

const messagesState = {
    conversations: [],
    unreadTotal: 0,
    activeThreadNumber: null,
    activeThread: null
};

const MAX_PHONE_DIGITS = 7;
const MAX_MESSAGE_LENGTH = 280;

function postNui(endpoint, payload = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload)
    });
}

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

function hideAllApps() {
    appScreens.forEach((screenId) => {
        const screen = document.getElementById(screenId);
        if (screen) {
            screen.style.display = 'none';
        }
    });

    const homeScreen = document.getElementById('home-screen');
    if (homeScreen) {
        homeScreen.style.display = 'none';
    }
}

function openApp(appName) {
    hideAllApps();

    const appScreen = document.getElementById(`${appName}-app`);
    const homeScreen = document.getElementById('home-screen');

    if (!appScreen) {
        uiState.currentApp = null;
        if (homeScreen) {
            homeScreen.style.display = 'block';
        }
        return;
    }

    uiState.currentApp = appName;
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
    } else if (appName === 'messages') {
        renderMessageConversations();

        if (messagesState.activeThread && messagesState.activeThread.phoneNumber) {
            showMessageThreadView();
            renderMessageThread();
        } else {
            showMessagesOverview();
        }

        loadMessageConversations();
    }
}

function closeApp() {
    hideAllApps();
    uiState.currentApp = null;

    const homeScreen = document.getElementById('home-screen');
    if (homeScreen) {
        homeScreen.style.display = 'block';
    }
}

function loadParkedVehicles() {
    const vehicleList = document.getElementById('vehicle-list');
    if (vehicleList) {
        vehicleList.innerHTML = '<p class="loading">Loading vehicles...</p>';
    }

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

function displayVehicles(vehicles) {
    const vehicleList = document.getElementById('vehicle-list');
    if (!vehicleList) {
        return;
    }

    if (!vehicles || vehicles.length === 0) {
        vehicleList.innerHTML = '<p class="loading">No owned vehicles found</p>';
        setParkingStatus('No vehicles are registered to you yet.', false);
        return;
    }

    vehicleList.innerHTML = '';
    setParkingStatus('Tap a parked vehicle or use Set GPS to navigate to its parking zone.', false);

    vehicles.forEach((vehicle) => {
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
        myNumberElement.innerText = callState.myNumber
            ? `Your number: ${callState.myNumber}`
            : 'Your number: Unassigned';
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

function setupPhoneNumberInput(elementId) {
    const input = document.getElementById(elementId);
    if (!input || input.dataset.phoneNumberReady === '1') {
        return;
    }

    input.dataset.phoneNumberReady = '1';
    input.addEventListener('input', () => {
        input.value = formatPhoneDigits(input.value);
    });
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
    setupPhoneNumberInput('call-target-id');
}

function setCallStatus(message) {
    const callStatus = document.getElementById('call-status');
    if (!callStatus) {
        return;
    }

    callStatus.innerText = message || '';
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

    document.querySelectorAll('.dial-key').forEach((button) => {
        button.disabled = lockDialInput;
    });

    endButton.style.display = busy ? 'block' : 'none';

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

function getMessageTargetInputElement() {
    return document.getElementById('message-target-id');
}

function setMessageTargetInput(phoneNumber) {
    const targetInput = getMessageTargetInputElement();
    if (!targetInput) {
        return;
    }

    const normalized = normalizePhoneNumber(phoneNumber);
    targetInput.value = normalized || formatPhoneDigits(phoneNumber);
}

function sanitizeMessageBody(value) {
    const sanitized = String(value || '')
        .replace(/\r\n/g, '\n')
        .replace(/\r/g, '\n')
        .trim();

    if (!sanitized) {
        return '';
    }

    return sanitized.slice(0, MAX_MESSAGE_LENGTH);
}

function formatMessageTimestamp(unixSeconds, includeTime = false) {
    const timestamp = Number(unixSeconds);
    if (!Number.isFinite(timestamp) || timestamp <= 0) {
        return '';
    }

    const date = new Date(timestamp * 1000);
    if (Number.isNaN(date.getTime())) {
        return '';
    }

    const now = new Date();
    const sameDay = date.toDateString() === now.toDateString();
    if (!includeTime && sameDay) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    if (!includeTime && date.toDateString() === yesterday.toDateString()) {
        return 'Yesterday';
    }

    if (includeTime) {
        return date.toLocaleString([], {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    return date.toLocaleDateString([], {
        month: 'short',
        day: 'numeric'
    });
}

function setMessagesStatus(message, isError = false) {
    ['messages-status', 'messages-thread-status'].forEach((elementId) => {
        const element = document.getElementById(elementId);
        if (!element) {
            return;
        }

        element.innerText = message || '';
        element.classList.toggle('messages-status-error', Boolean(isError));
    });
}

function updateMessagesUnreadSummary() {
    const summaryElement = document.getElementById('messages-unread-summary');
    if (!summaryElement) {
        return;
    }

    if (messagesState.unreadTotal <= 0) {
        summaryElement.innerText = 'No unread messages';
    } else if (messagesState.unreadTotal === 1) {
        summaryElement.innerText = '1 unread message';
    } else {
        summaryElement.innerText = `${messagesState.unreadTotal} unread messages`;
    }
}

function updateMessagesBadge() {
    const badge = document.getElementById('messages-badge');
    if (!badge) {
        return;
    }

    if (messagesState.unreadTotal > 0) {
        badge.style.display = 'flex';
        badge.innerText = messagesState.unreadTotal > 99 ? '99+' : String(messagesState.unreadTotal);
    } else {
        badge.style.display = 'none';
        badge.innerText = '0';
    }
}

function loadMessageConversations() {
    const list = document.getElementById('messages-thread-list');
    if (list && !list.children.length) {
        list.innerHTML = '<p class="loading">Loading conversations...</p>';
    }

    postNui('getMessageConversations');
}

function findConversationEntry(phoneNumber) {
    return messagesState.conversations.find((entry) => entry && entry.phoneNumber === phoneNumber) || null;
}

function setMessageThreadHeader(contact) {
    const titleElement = document.getElementById('messages-thread-title');
    const subtitleElement = document.getElementById('messages-thread-subtitle');
    const presenceElement = document.getElementById('messages-thread-presence');

    const displayName = contact && contact.displayName ? contact.displayName : 'Unknown';
    const phoneNumber = contact && contact.phoneNumber ? contact.phoneNumber : 'Unknown';
    const online = Boolean(contact && contact.online);

    if (titleElement) {
        titleElement.innerText = displayName;
    }

    if (subtitleElement) {
        subtitleElement.innerText = phoneNumber;
    }

    if (presenceElement) {
        presenceElement.className = `phonebook-status ${online ? 'online' : 'offline'}`;
        presenceElement.innerText = online ? 'Online' : 'Offline';
    }
}

function showMessagesOverview() {
    const overview = document.getElementById('messages-overview');
    const threadView = document.getElementById('messages-thread-view');

    if (overview) {
        overview.style.display = 'flex';
    }

    if (threadView) {
        threadView.style.display = 'none';
    }
}

function showMessageThreadView() {
    const overview = document.getElementById('messages-overview');
    const threadView = document.getElementById('messages-thread-view');

    if (overview) {
        overview.style.display = 'none';
    }

    if (threadView) {
        threadView.style.display = 'flex';
    }
}

function closeMessagesThread() {
    messagesState.activeThreadNumber = null;
    messagesState.activeThread = null;
    showMessagesOverview();
    renderMessageConversations();
}

function renderMessageConversations() {
    const list = document.getElementById('messages-thread-list');
    if (!list) {
        return;
    }

    list.innerHTML = '';

    const conversations = Array.isArray(messagesState.conversations) ? messagesState.conversations : [];
    if (!conversations.length) {
        list.innerHTML = '<p class="messages-empty">No conversations yet.</p>';
        return;
    }

    conversations.forEach((conversation) => {
        if (!conversation || !conversation.phoneNumber) {
            return;
        }

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'messages-conversation';

        if (messagesState.activeThreadNumber === conversation.phoneNumber) {
            button.classList.add('active');
        }

        button.addEventListener('click', () => {
            openMessageThread(conversation.phoneNumber);
        });

        const top = document.createElement('div');
        top.className = 'messages-conversation-top';

        const name = document.createElement('span');
        name.className = 'messages-conversation-name';
        name.innerText = conversation.displayName || conversation.phoneNumber;

        const time = document.createElement('span');
        time.className = 'messages-conversation-time';
        time.innerText = formatMessageTimestamp(conversation.lastMessageAt);

        top.appendChild(name);
        top.appendChild(time);

        const preview = document.createElement('p');
        preview.className = 'messages-conversation-preview';
        const previewPrefix = conversation.lastMessageFromSelf ? 'You: ' : '';
        preview.innerText = `${previewPrefix}${conversation.lastMessage || 'No messages yet.'}`;

        const bottom = document.createElement('div');
        bottom.className = 'messages-conversation-bottom';

        const meta = document.createElement('div');
        meta.className = 'messages-conversation-meta';

        const number = document.createElement('span');
        number.className = 'messages-conversation-number';
        number.innerText = conversation.phoneNumber;

        const status = document.createElement('span');
        status.className = `phonebook-status ${conversation.online ? 'online' : 'offline'}`;
        status.innerText = conversation.online ? 'Online' : 'Offline';

        meta.appendChild(number);
        meta.appendChild(status);
        bottom.appendChild(meta);

        if (conversation.unreadCount > 0) {
            const unread = document.createElement('span');
            unread.className = 'messages-unread-badge';
            unread.innerText = conversation.unreadCount > 99 ? '99+' : String(conversation.unreadCount);
            bottom.appendChild(unread);
        }

        button.appendChild(top);
        button.appendChild(preview);
        button.appendChild(bottom);
        list.appendChild(button);
    });

    if (!list.children.length) {
        list.innerHTML = '<p class="messages-empty">No conversations yet.</p>';
    }
}

function displayMessageConversations(conversations, unreadTotal) {
    messagesState.conversations = Array.isArray(conversations) ? conversations : [];
    messagesState.unreadTotal = Number.isFinite(Number(unreadTotal)) ? Math.max(0, Number(unreadTotal)) : 0;

    const activeConversation = messagesState.activeThreadNumber
        ? findConversationEntry(messagesState.activeThreadNumber)
        : null;

    if (messagesState.activeThread && activeConversation) {
        messagesState.activeThread.displayName = activeConversation.displayName || messagesState.activeThread.displayName;
        messagesState.activeThread.online = activeConversation.online === true;
    }

    renderMessageConversations();
    updateMessagesUnreadSummary();
    updateMessagesBadge();

    if (messagesState.activeThread) {
        setMessageThreadHeader(messagesState.activeThread);
    }

    if (!messagesState.conversations.length && !messagesState.activeThread) {
        setMessagesStatus('No conversations yet. Send the first text.', false);
    }
}

function setMessageThreadLoading(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber) || String(phoneNumber || '').trim();
    const contact = findConversationEntry(normalized) || {
        phoneNumber: normalized,
        displayName: normalized,
        online: false
    };

    setMessageThreadHeader(contact);
    showMessageThreadView();

    const messagesContainer = document.getElementById('messages-thread-messages');
    if (messagesContainer) {
        messagesContainer.innerHTML = '<p class="loading">Loading conversation...</p>';
    }
}

function renderMessageThread() {
    const messagesContainer = document.getElementById('messages-thread-messages');
    if (!messagesContainer) {
        return;
    }

    const thread = messagesState.activeThread;
    if (!thread || !thread.phoneNumber) {
        messagesContainer.innerHTML = '<p class="messages-empty">Select a conversation.</p>';
        return;
    }

    setMessageThreadHeader(thread);
    messagesContainer.innerHTML = '';

    const messages = Array.isArray(thread.messages) ? thread.messages : [];
    if (!messages.length) {
        messagesContainer.innerHTML = '<p class="messages-empty">No messages yet. Send the first text in this conversation.</p>';
        return;
    }

    messages.forEach((message) => {
        const bubble = document.createElement('div');
        bubble.className = `messages-bubble ${message.mine ? 'messages-bubble-mine' : 'messages-bubble-other'}`;

        const body = document.createElement('div');
        body.className = 'messages-bubble-body';
        body.innerText = message.body || '';

        const meta = document.createElement('div');
        meta.className = 'messages-bubble-meta';
        const timestamp = formatMessageTimestamp(message.sentAt, true);

        if (message.mine) {
            meta.innerText = message.readAt ? `${timestamp} • Seen` : `${timestamp} • Sent`;
        } else {
            meta.innerText = timestamp;
        }

        bubble.appendChild(body);
        bubble.appendChild(meta);
        messagesContainer.appendChild(bubble);
    });

    requestAnimationFrame(() => {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    });
}

function displayMessageThread(thread) {
    if (!thread || !thread.phoneNumber) {
        setMessagesStatus('Conversation could not be loaded.', true);
        return;
    }

    messagesState.activeThreadNumber = thread.phoneNumber;
    messagesState.activeThread = {
        phoneNumber: thread.phoneNumber,
        displayName: thread.displayName || thread.phoneNumber,
        online: thread.online === true,
        messages: Array.isArray(thread.messages) ? thread.messages : []
    };

    setMessageTargetInput(thread.phoneNumber);

    if (uiState.currentApp === 'messages') {
        showMessageThreadView();
    }

    renderMessageThread();

    if (!messagesState.activeThread.messages.length) {
        setMessagesStatus('No messages yet. Send the first text.', false);
    }
}

function openMessageThread(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber);
    if (!normalized) {
        setMessagesStatus('Select a valid phone number.', true);
        return;
    }

    messagesState.activeThreadNumber = normalized;
    messagesState.activeThread = null;
    setMessageTargetInput(normalized);
    setMessageThreadLoading(normalized);
    setMessagesStatus(`Loading conversation with ${normalized}...`, false);
    postNui('getMessageThread', { phoneNumber: normalized });
}

function sendNewMessage() {
    const targetInput = getMessageTargetInputElement();
    const bodyInput = document.getElementById('message-body');
    const phoneNumber = normalizePhoneNumber(targetInput ? targetInput.value : '');
    const body = sanitizeMessageBody(bodyInput ? bodyInput.value : '');

    if (!phoneNumber) {
        setMessagesStatus('Enter a valid number (example: 555-0001).', true);
        return;
    }

    if (!body) {
        setMessagesStatus('Type a message before sending.', true);
        return;
    }

    messagesState.activeThreadNumber = phoneNumber;
    messagesState.activeThread = null;
    setMessageTargetInput(phoneNumber);
    setMessagesStatus(`Sending to ${phoneNumber}...`, false);
    postNui('sendMessage', { phoneNumber, body });

    if (bodyInput) {
        bodyInput.value = '';
    }
}

function sendThreadReply() {
    const bodyInput = document.getElementById('message-reply-body');
    const phoneNumber = normalizePhoneNumber(messagesState.activeThreadNumber);
    const body = sanitizeMessageBody(bodyInput ? bodyInput.value : '');

    if (!phoneNumber) {
        setMessagesStatus('Open a conversation before replying.', true);
        return;
    }

    if (!body) {
        setMessagesStatus('Type a message before sending.', true);
        return;
    }

    setMessagesStatus(`Sending to ${phoneNumber}...`, false);
    postNui('sendMessage', { phoneNumber, body });

    if (bodyInput) {
        bodyInput.value = '';
    }
}

function handleMessageIncoming(phoneNumber, preview) {
    const normalized = normalizePhoneNumber(phoneNumber);
    if (!normalized) {
        return;
    }

    const conversation = findConversationEntry(normalized);
    const label = conversation ? (conversation.displayName || normalized) : normalized;

    if (uiState.currentApp === 'messages' && messagesState.activeThreadNumber === normalized) {
        postNui('getMessageThread', { phoneNumber: normalized });
        return;
    }

    const previewText = String(preview || '').trim();
    setMessagesStatus(
        previewText ? `New message from ${label}: ${previewText}` : `New message from ${label}.`,
        false
    );
}

setInterval(updateTime, 60000);
updateTime();
setupDialInput();
setupPhoneNumberInput('message-target-id');
updateCallUI();
updateMessagesUnreadSummary();
updateMessagesBadge();

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
        closeApp();
        updateIncomingToast();
    } else if (data.action === 'displayVehicles') {
        displayVehicles(data.vehicles);
    } else if (data.action === 'displayPhonebook') {
        displayPhonebook(data.entries);
    } else if (data.action === 'displayMessageConversations') {
        displayMessageConversations(data.conversations, data.unreadTotal);
    } else if (data.action === 'displayMessageThread') {
        displayMessageThread(data.thread);
    } else if (data.action === 'messageIncoming') {
        handleMessageIncoming(data.phoneNumber, data.preview);
    } else if (data.action === 'messageStatus') {
        setMessagesStatus(data.message || '', data.isError === true);
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

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closePhone();
    }
});

updateIncomingToast();
