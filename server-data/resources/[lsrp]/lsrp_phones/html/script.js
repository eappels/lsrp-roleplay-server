function updateTime() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const timeElement = document.getElementById('phone-time');
    const dayElement = document.getElementById('phone-day');
    const homeDateElement = document.getElementById('home-date-label');

    if (timeElement) {
        timeElement.innerText = hours + ':' + minutes;
    }

    if (dayElement) {
        dayElement.innerText = formatCalendarLabel(now, false);
    }

    if (homeDateElement) {
        homeDateElement.innerText = formatCalendarLabel(now, true);
    }
}

const appScreens = ['balance-app', 'parking-app', 'taxi-app', 'calls-app', 'phonebook-app', 'messages-app'];

const uiState = {
    currentApp: null
};

const balanceState = {
    rawBalance: 0,
    rawCash: 0,
    formattedBalance: 'LS$0',
    formattedCash: 'LS$0',
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

const taxiState = {
    canBook: true,
    driverEligible: false,
    employed: false,
    onDuty: false,
    availableDriverCount: 0,
    myRide: null,
    activeAssignment: null,
    openRides: [],
    unavailable: false,
    currentView: 'menu'
};

function setPhoneHidden() {
    const container = document.getElementById('phone-container');
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');
    document.body.classList.remove('show-phone', 'show-incoming-toast');

    if (container) {
        container.classList.add('hidden');
        container.setAttribute('aria-hidden', 'true');
    }
}

function showPhoneShell() {
    const container = document.getElementById('phone-container');
    document.body.style.display = 'block';
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');

    if (container) {
        container.classList.remove('hidden');
        container.setAttribute('aria-hidden', 'false');
    }
}

const MAX_PHONE_DIGITS = 7;
const MAX_MESSAGE_LENGTH = 280;

function formatCalendarLabel(date, includeWeekday = false) {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
        return '';
    }

    return date.toLocaleDateString([], {
        weekday: includeWeekday ? 'long' : undefined,
        month: 'short',
        day: 'numeric'
    });
}

function truncateInlineText(value, maxLength) {
    const text = String(value || '').replace(/\s+/g, ' ').trim();
    if (!text) {
        return '';
    }

    if (text.length <= maxLength) {
        return text;
    }

    return `${text.slice(0, Math.max(0, maxLength - 1)).trimEnd()}...`;
}

function getIdentityLabel(value) {
    const raw = String(value || '').trim();
    if (!raw) {
        return '--';
    }

    const digitsOnly = raw.replace(/\D/g, '');
    if (digitsOnly.length >= 2 && !/[A-Za-z]/.test(raw)) {
        return digitsOnly.slice(-2);
    }

    const normalized = raw.replace(/[^A-Za-z0-9]+/g, ' ').trim();
    if (!normalized) {
        return raw.slice(0, 2).toUpperCase();
    }

    const parts = normalized.split(/\s+/).filter(Boolean);
    if (parts.length === 1) {
        return parts[0].slice(0, 2).toUpperCase();
    }

    return `${parts[0].charAt(0)}${parts[parts.length - 1].charAt(0)}`.toUpperCase();
}

function createIdentityOrb(label, extraClass = '') {
    const orb = document.createElement('span');
    orb.className = extraClass ? `identity-orb ${extraClass}` : 'identity-orb';
    orb.innerText = getIdentityLabel(label);
    return orb;
}

function recalculateUnreadTotal() {
    return messagesState.conversations.reduce((total, conversation) => {
        return total + Math.max(0, Number(conversation && conversation.unreadCount) || 0);
    }, 0);
}

function setPhoneSurfaceState(appName) {
    const container = document.getElementById('phone-container');
    if (!container) {
        return;
    }

    container.dataset.app = appName || 'home';
}

function renderHomeDashboard() {
    const homePhoneLabel = document.getElementById('home-phone-label');
    const homeBalanceValue = document.getElementById('home-balance-value');
    const homeBalanceStatus = document.getElementById('home-balance-status');
    const homeMessagesUnread = document.getElementById('home-messages-unread');
    const homeMessagesSummary = document.getElementById('home-messages-summary');
    const homeCallHeading = document.getElementById('home-call-heading');
    const homeCallSummary = document.getElementById('home-call-summary');
    const homePhonebookTotal = document.getElementById('home-phonebook-total');
    const homePhonebookSummary = document.getElementById('home-phonebook-summary');

    const latestConversation = Array.isArray(messagesState.conversations) && messagesState.conversations.length
        ? messagesState.conversations[0]
        : null;
    const phonebookEntries = Array.isArray(callState.phonebookEntries)
        ? callState.phonebookEntries.filter((entry) => entry && entry.phoneNumber)
        : [];
    const onlineContacts = phonebookEntries.filter((entry) => entry.online === true).length;

    if (homePhoneLabel) {
        homePhoneLabel.innerText = callState.myNumber
            ? `Assigned line ${callState.myNumber}`
            : 'Assigning your city line...';
    }

    if (homeBalanceValue) {
        homeBalanceValue.innerText = balanceState.formattedBalance || 'LS$0';
    }

    if (homeBalanceStatus) {
        if (!balanceState.updatedAt) {
            homeBalanceStatus.innerText = 'Syncing account...';
        } else if (!balanceState.available) {
            homeBalanceStatus.innerText = 'Economy service unavailable';
        } else {
            homeBalanceStatus.innerText = formatBalanceTimestamp(balanceState.updatedAt);
        }
    }

    if (homeMessagesUnread) {
        if (messagesState.unreadTotal <= 0) {
            homeMessagesUnread.innerText = 'No unread';
        } else if (messagesState.unreadTotal === 1) {
            homeMessagesUnread.innerText = '1 unread';
        } else {
            homeMessagesUnread.innerText = `${messagesState.unreadTotal} unread`;
        }
    }

    if (homeMessagesSummary) {
        if (!latestConversation) {
            homeMessagesSummary.innerText = 'Your latest conversation will show up here.';
        } else {
            const preview = truncateInlineText(latestConversation.lastMessage || 'No messages yet.', 56);
            const label = latestConversation.displayName || latestConversation.phoneNumber || 'Latest';
            homeMessagesSummary.innerText = `${label}: ${preview}`;
        }
    }

    if (homeCallHeading && homeCallSummary) {
        if (callState.incomingFrom) {
            homeCallHeading.innerText = 'Incoming call';
            homeCallSummary.innerText = `${callState.incomingFrom} is waiting to connect.`;
        } else if (callState.inCall) {
            homeCallHeading.innerText = 'Connected';
            homeCallSummary.innerText = `Live with ${callState.otherParty || 'your caller'}.`;
        } else if (callState.ringingTarget) {
            homeCallHeading.innerText = 'Calling...';
            homeCallSummary.innerText = `Ringing ${callState.ringingTarget}.`;
        } else {
            homeCallHeading.innerText = 'Dialer ready';
            homeCallSummary.innerText = 'No active call.';
        }
    }

    if (homePhonebookTotal) {
        homePhonebookTotal.innerText = `${phonebookEntries.length} ${phonebookEntries.length === 1 ? 'contact' : 'contacts'}`;
    }

    if (homePhonebookSummary) {
        if (!phonebookEntries.length) {
            homePhonebookSummary.innerText = 'Refresh to sync your phonebook.';
        } else if (onlineContacts > 0) {
            homePhonebookSummary.innerText = `${onlineContacts} online right now.`;
        } else {
            homePhonebookSummary.innerText = 'Everyone is currently offline.';
        }
    }
}

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

function setBalance(balance, formattedBalance, cash, formattedCash, available) {
    const numericBalance = Number.isFinite(Number(balance))
        ? Math.max(0, Math.floor(Number(balance)))
        : 0;
    const numericCash = Number.isFinite(Number(cash))
        ? Math.max(0, Math.floor(Number(cash)))
        : 0;

    balanceState.rawBalance = numericBalance;
    balanceState.rawCash = numericCash;
    balanceState.formattedBalance = typeof formattedBalance === 'string' && formattedBalance
        ? formattedBalance
        : `LS$${numericBalance}`;
    balanceState.formattedCash = typeof formattedCash === 'string' && formattedCash
        ? formattedCash
        : `LS$${numericCash}`;
    balanceState.available = available !== false;
    balanceState.updatedAt = new Date();

    const balanceValue = document.getElementById('balance-value');
    const cashValue = document.getElementById('cash-value');
    const balanceStatus = document.getElementById('balance-status');
    const balanceMeta = document.getElementById('balance-meta');

    if (balanceValue) {
        balanceValue.innerText = balanceState.formattedBalance;
    }

    if (cashValue) {
        cashValue.innerText = balanceState.formattedCash;
    }

    if (balanceStatus) {
        balanceStatus.innerText = balanceState.available
            ? 'Synced with your LS$ account and carried cash.'
            : 'Economy service is unavailable right now.';
    }

    if (balanceMeta) {
        balanceMeta.innerText = formatBalanceTimestamp(balanceState.updatedAt);
    }

    renderHomeDashboard();
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
        setPhoneSurfaceState('home');
        if (homeScreen) {
            homeScreen.style.display = 'block';
        }
        renderHomeDashboard();
        return;
    }

    uiState.currentApp = appName;
    setPhoneSurfaceState(appName);
    appScreen.style.display = 'flex';

    if (appName === 'parking') {
        loadParkedVehicles();
    } else if (appName === 'balance') {
        loadBalance();
    } else if (appName === 'taxi') {
        taxiState.currentView = 'menu';
        renderTaxiApp();
        loadTaxiAppState();
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
    setPhoneSurfaceState('home');

    const homeScreen = document.getElementById('home-screen');
    if (homeScreen) {
        homeScreen.style.display = 'block';
    }

    renderHomeDashboard();
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

function setTaxiAppStatus(message, isError = false) {
    const element = document.getElementById('taxi-status');
    if (!element) {
        return;
    }

    element.innerText = message || '';
    element.classList.toggle('taxi-status-error', Boolean(isError));
}

function syncTaxiAppStatus() {
    if (taxiState.unavailable) {
        setTaxiAppStatus('Taxi dispatch is unavailable right now.', true);
        return;
    }

    if (taxiState.myRide) {
        setTaxiAppStatus(`Ride #${taxiState.myRide.id} is ${String(taxiState.myRide.statusLabel || 'active').toLowerCase()}.`, false);
        return;
    }

    if (taxiState.currentView === 'driver') {
        if (!taxiState.driverEligible) {
            setTaxiAppStatus('Dispatch access is limited to taxi employees.', true);
            return;
        }

        if (taxiState.onDuty) {
            setTaxiAppStatus('Dispatch synced. Claim a ride when you are ready.', false);
            return;
        }

        setTaxiAppStatus('Clock in at the taxi depot to use dispatch.', false);
        return;
    }

    if (taxiState.currentView === 'rider') {
        setTaxiAppStatus('Set a waypoint and request a ride.', false);
        return;
    }

    if (taxiState.driverEligible && taxiState.onDuty) {
        setTaxiAppStatus('Choose passenger booking or driver dispatch.', false);
        return;
    }

    setTaxiAppStatus('Choose how you want to use the taxi service.', false);
}

function setTaxiView(viewName) {
    if (viewName === 'rider' || viewName === 'driver') {
        taxiState.currentView = viewName;
    } else {
        taxiState.currentView = 'menu';
    }

    renderTaxiApp();
    syncTaxiAppStatus();
}

function loadTaxiAppState() {
    setTaxiAppStatus('Syncing taxi dispatch...', false);
    postNui('getTaxiAppState');
}

function getTaxiImmediateErrorMessage(errorCode) {
    if (errorCode === 'missing_waypoint') {
        return 'Set a GPS waypoint before booking a taxi.';
    }

    if (errorCode === 'invalid_ride') {
        return 'That ride is no longer available.';
    }

    if (errorCode === 'player_unavailable') {
        return 'Your position is unavailable right now. Try again in a moment.';
    }

    return 'Taxi dispatch is unavailable right now.';
}

function createTaxiDetailRow(label, value) {
    const row = document.createElement('div');
    row.className = 'taxi-detail-row';

    const labelElement = document.createElement('span');
    labelElement.className = 'taxi-detail-label';
    labelElement.innerText = label;

    const valueElement = document.createElement('span');
    valueElement.className = 'taxi-detail-value';
    valueElement.innerText = value || 'Unknown';

    row.appendChild(labelElement);
    row.appendChild(valueElement);
    return row;
}

function createTaxiRideCard(ride, options = {}) {
    const card = document.createElement('div');
    card.className = 'taxi-ride-card';

    const top = document.createElement('div');
    top.className = 'taxi-ride-top';

    const heading = document.createElement('div');
    heading.className = 'taxi-ride-heading';

    const title = document.createElement('strong');
    title.innerText = `Ride #${ride.id}`;

    const subtitle = document.createElement('span');
    subtitle.className = 'taxi-ride-subtitle';
    subtitle.innerText = `${ride.pickup && ride.pickup.label ? ride.pickup.label : 'Pickup'} → ${ride.destination && ride.destination.label ? ride.destination.label : 'Destination'}`;

    heading.appendChild(title);
    heading.appendChild(subtitle);

    const status = document.createElement('span');
    status.className = `taxi-status-pill taxi-status-${ride.status || 'open'}`;
    status.innerText = ride.statusLabel || 'Waiting';

    top.appendChild(heading);
    top.appendChild(status);

    const details = document.createElement('div');
    details.className = 'taxi-ride-details';
    details.appendChild(createTaxiDetailRow('Pickup', ride.pickup && ride.pickup.label ? ride.pickup.label : 'Current location'));
    details.appendChild(createTaxiDetailRow('Destination', ride.destination && ride.destination.label ? ride.destination.label : 'Waypoint'));
    details.appendChild(createTaxiDetailRow('Schedule', ride.scheduledFor || 'ASAP'));
    details.appendChild(createTaxiDetailRow('Fare', ride.formattedPayout || 'LS$0'));

    if (ride.driverName) {
        details.appendChild(createTaxiDetailRow('Driver', ride.driverName));
    }

    if (ride.riderName && options.showRider === true) {
        details.appendChild(createTaxiDetailRow('Passenger', ride.riderName));
    }

    if (ride.notes) {
        details.appendChild(createTaxiDetailRow('Notes', ride.notes));
    }

    card.appendChild(top);
    card.appendChild(details);

    if (options.buttonLabel && typeof options.onButtonClick === 'function') {
        const actions = document.createElement('div');
        actions.className = 'taxi-ride-actions';

        const button = document.createElement('button');
        button.type = 'button';
        button.className = options.buttonClassName || 'btn';
        button.innerText = options.buttonLabel;
        button.addEventListener('click', options.onButtonClick);

        actions.appendChild(button);
        card.appendChild(actions);
    }

    return card;
}

function renderTaxiApp() {
    const menuSection = document.getElementById('taxi-mode-menu');
    const riderPanel = document.getElementById('taxi-rider-panel');
    const driverPanel = document.getElementById('taxi-driver-panel');
    const driverCount = document.getElementById('taxi-driver-count');
    const myRideContainer = document.getElementById('taxi-my-ride');
    const dispatchPanel = document.getElementById('taxi-dispatch-panel');
    const dispatchState = document.getElementById('taxi-dispatch-state');
    const activeAssignmentContainer = document.getElementById('taxi-active-assignment');
    const openRidesContainer = document.getElementById('taxi-open-rides');

    if (menuSection) {
        menuSection.style.display = taxiState.currentView === 'menu' ? 'grid' : 'none';
    }

    if (riderPanel) {
        riderPanel.style.display = taxiState.currentView === 'rider' ? 'flex' : 'none';
    }

    if (driverPanel) {
        driverPanel.style.display = taxiState.currentView === 'driver' ? 'flex' : 'none';
    }

    if (driverCount) {
        const count = Number(taxiState.availableDriverCount) || 0;
        driverCount.innerText = `${count} ${count === 1 ? 'driver' : 'drivers'}`;
    }

    if (myRideContainer) {
        myRideContainer.innerHTML = '';

        if (taxiState.myRide) {
            myRideContainer.appendChild(createTaxiRideCard(taxiState.myRide, {
                buttonLabel: 'Cancel Ride',
                buttonClassName: 'btn btn-danger',
                onButtonClick: () => {
                    cancelTaxiRide();
                }
            }));
        } else {
            myRideContainer.innerHTML = '<p class="messages-empty">No active taxi ride.</p>';
        }
    }

    if (dispatchPanel) {
        dispatchPanel.style.display = 'flex';
    }

    if (dispatchState) {
        if (!taxiState.driverEligible) {
            dispatchState.innerText = 'Civilian';
        } else if (taxiState.onDuty) {
            dispatchState.innerText = 'On duty';
        } else {
            dispatchState.innerText = 'Off duty';
        }
    }

    if (activeAssignmentContainer) {
        activeAssignmentContainer.innerHTML = '';

        if (taxiState.activeAssignment) {
            const allowRelease = taxiState.activeAssignment.status !== 'picked_up';
            activeAssignmentContainer.appendChild(createTaxiRideCard(taxiState.activeAssignment, {
                showRider: true,
                buttonLabel: allowRelease ? 'Release Ride' : '',
                buttonClassName: 'btn btn-danger',
                onButtonClick: allowRelease ? () => {
                    releaseTaxiRide();
                } : null
            }));
        } else if (taxiState.driverEligible && !taxiState.onDuty) {
            activeAssignmentContainer.innerHTML = '<p class="messages-empty">Clock in at the taxi depot to claim rides.</p>';
        } else {
            activeAssignmentContainer.innerHTML = '<p class="messages-empty">No active assignment.</p>';
        }
    }

    if (openRidesContainer) {
        openRidesContainer.innerHTML = '';

        if (!taxiState.driverEligible) {
            openRidesContainer.innerHTML = '<p class="messages-empty">Dispatch access is limited to taxi employees.</p>';
        } else if (!taxiState.onDuty) {
            openRidesContainer.innerHTML = '<p class="messages-empty">Go on duty to view open ride requests.</p>';
        } else if (taxiState.activeAssignment) {
            openRidesContainer.innerHTML = '<p class="messages-empty">Finish or release your current assignment to claim another ride.</p>';
        } else if (Array.isArray(taxiState.openRides) && taxiState.openRides.length > 0) {
            taxiState.openRides.forEach((ride) => {
                openRidesContainer.appendChild(createTaxiRideCard(ride, {
                    showRider: true,
                    buttonLabel: 'Claim Ride',
                    buttonClassName: 'btn',
                    onButtonClick: () => {
                        claimTaxiRide(ride.id);
                    }
                }));
            });
        } else {
            openRidesContainer.innerHTML = '<p class="messages-empty">No open rides right now.</p>';
        }
    }
}

function displayTaxiAppState(state) {
    Object.assign(taxiState, {
        canBook: state && state.canBook !== false,
        driverEligible: state && state.driverEligible === true,
        employed: state && state.employed === true,
        onDuty: state && state.onDuty === true,
        availableDriverCount: Number(state && state.availableDriverCount) || 0,
        myRide: state && state.myRide ? state.myRide : null,
        activeAssignment: state && state.activeAssignment ? state.activeAssignment : null,
        openRides: Array.isArray(state && state.openRides) ? state.openRides : [],
        unavailable: state && state.unavailable === true
    });

    renderTaxiApp();
    syncTaxiAppStatus();
}

function bookTaxiRide() {
    const destinationInput = document.getElementById('taxi-destination-label');
    const scheduleInput = document.getElementById('taxi-schedule');
    const notesInput = document.getElementById('taxi-notes');

    setTaxiAppStatus('Sending ride request to dispatch...', false);
    postNui('bookTaxiRide', {
        destinationLabel: destinationInput ? destinationInput.value : '',
        scheduledFor: scheduleInput ? scheduleInput.value : '',
        notes: notesInput ? notesInput.value : ''
    })
        .then((response) => response.json().catch(() => ({ ok: true })))
        .then((result) => {
            if (result && result.ok === false) {
                setTaxiAppStatus(getTaxiImmediateErrorMessage(result.error), true);
            }
        })
        .catch(() => {
            setTaxiAppStatus('Taxi dispatch is unavailable right now.', true);
        });
}

function cancelTaxiRide() {
    setTaxiAppStatus('Cancelling your taxi request...', false);
    postNui('cancelTaxiRide')
        .catch(() => {
            setTaxiAppStatus('Could not cancel your taxi request right now.', true);
        });
}

function claimTaxiRide(rideId) {
    setTaxiAppStatus(`Claiming ride #${rideId}...`, false);
    postNui('claimTaxiRide', { rideId })
        .then((response) => response.json().catch(() => ({ ok: true })))
        .then((result) => {
            if (result && result.ok === false) {
                setTaxiAppStatus(getTaxiImmediateErrorMessage(result.error), true);
            }
        })
        .catch(() => {
            setTaxiAppStatus('Could not claim that ride right now.', true);
        });
}

function releaseTaxiRide() {
    setTaxiAppStatus('Releasing your active ride...', false);
    postNui('releaseTaxiRide')
        .catch(() => {
            setTaxiAppStatus('Could not release your assignment right now.', true);
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
    renderHomeDashboard();
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

function textPhonebookEntry(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber);
    if (!normalized || normalized === callState.myNumber) {
        return;
    }

    openApp('messages');
    openMessageThread(normalized);

    requestAnimationFrame(() => {
        const replyInput = document.getElementById('message-reply-body');
        if (replyInput) {
            replyInput.focus();
        }
    });
}

function updatePhonebookButtonStates() {
    const busy = callState.inCall || callState.ringingTarget !== null || callState.incomingFrom !== null;

    document.querySelectorAll('.phonebook-action-call').forEach((button) => {
        const phoneNumber = button.dataset.phoneNumber || '';
        const online = button.dataset.online === '1';
        const isSelf = phoneNumber === callState.myNumber;
        button.disabled = busy || !online || isSelf;
    });

    document.querySelectorAll('.phonebook-action-text').forEach((button) => {
        const phoneNumber = button.dataset.phoneNumber || '';
        button.disabled = phoneNumber === callState.myNumber;
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
        row.className = 'phonebook-entry-card';

        const identity = createIdentityOrb(entry.displayName || entry.phoneNumber);
        const copy = document.createElement('div');
        copy.className = 'phonebook-entry-copy';

        const name = document.createElement('span');
        name.className = 'phonebook-entry-name';
        name.innerText = entry.phoneNumber === callState.myNumber
            ? `${entry.displayName || 'Unknown'} (You)`
            : (entry.displayName || 'Unknown');

        const details = document.createElement('div');
        details.className = 'phonebook-entry-details';

        const number = document.createElement('span');
        number.className = 'phonebook-number';
        number.innerText = entry.phoneNumber;

        const status = document.createElement('span');
        status.className = `phonebook-status ${entry.online ? 'online' : 'offline'}`;
        status.innerText = entry.online ? 'Online' : 'Offline';

        const actions = document.createElement('div');
        actions.className = 'phonebook-entry-actions';

        const textButton = document.createElement('button');
        textButton.type = 'button';
        textButton.className = 'phonebook-action-btn phonebook-action-text';
        textButton.dataset.phoneNumber = entry.phoneNumber;
        textButton.innerText = 'Text';
        textButton.addEventListener('click', () => {
            textPhonebookEntry(entry.phoneNumber);
        });

        const callButton = document.createElement('button');
        callButton.type = 'button';
        callButton.className = 'phonebook-action-btn phonebook-action-call';
        callButton.dataset.phoneNumber = entry.phoneNumber;
        callButton.dataset.online = entry.online ? '1' : '0';
        callButton.innerText = 'Call';
        callButton.addEventListener('click', () => {
            callPhonebookEntry(entry.phoneNumber);
        });

        details.appendChild(number);
        details.appendChild(status);
        copy.appendChild(name);
        copy.appendChild(details);
        actions.appendChild(textButton);
        actions.appendChild(callButton);
        row.appendChild(identity);
        row.appendChild(copy);
        row.appendChild(actions);
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
    renderHomeDashboard();
}

function updateCallUI() {
    const callsContent = document.querySelector('.calls-content');
    const incomingPanel = document.getElementById('incoming-call');
    const incomingText = document.getElementById('incoming-call-text');
    const incomingSubtitle = document.getElementById('incoming-call-subtitle');
    const incomingAvatar = document.getElementById('incoming-call-avatar');
    const endButton = document.getElementById('end-call-btn');
    const startButton = document.getElementById('start-call-btn');
    const targetInput = document.getElementById('call-target-id');

    if (!callsContent || !incomingPanel || !incomingText || !endButton || !startButton || !targetInput) {
        return;
    }

    const incomingMode = Boolean(callState.incomingFrom) && !callState.inCall;
    callsContent.classList.toggle('incoming-mode', incomingMode);

    if (incomingMode) {
        incomingPanel.style.display = 'grid';
        incomingText.innerText = callState.incomingFrom || 'Unknown';

        if (incomingSubtitle) {
            incomingSubtitle.innerText = 'Press F4 or accept below.';
        }

        if (incomingAvatar) {
            incomingAvatar.innerText = getIdentityLabel(callState.incomingFrom);
        }
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
    renderHomeDashboard();
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

function findPhonebookEntry(phoneNumber) {
    return callState.phonebookEntries.find((entry) => entry && entry.phoneNumber === phoneNumber) || null;
}

function buildThreadContact(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber) || String(phoneNumber || '').trim();
    const conversation = findConversationEntry(normalized);
    const phonebookEntry = findPhonebookEntry(normalized);

    return {
        phoneNumber: normalized,
        displayName: (conversation && conversation.displayName)
            || (phonebookEntry && phonebookEntry.displayName)
            || normalized
            || 'Unknown',
        online: (conversation && conversation.online === true)
            || (phonebookEntry && phonebookEntry.online === true)
            || false
    };
}

function setMessageThreadHeader(contact) {
    const titleElement = document.getElementById('messages-thread-title');
    const subtitleElement = document.getElementById('messages-thread-subtitle');
    const presenceElement = document.getElementById('messages-thread-presence');
    const avatarElement = document.getElementById('messages-thread-avatar');

    const displayName = contact && contact.displayName ? contact.displayName : 'Unknown';
    const phoneNumber = contact && contact.phoneNumber ? contact.phoneNumber : 'Unknown';
    const online = Boolean(contact && contact.online);

    if (titleElement) {
        titleElement.innerText = displayName;
    }

    if (subtitleElement) {
        subtitleElement.innerText = phoneNumber;
    }

    if (avatarElement) {
        avatarElement.innerText = getIdentityLabel(displayName || phoneNumber);
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

function focusMessagesQuickStart() {
    showMessagesOverview();

    const targetInput = getMessageTargetInputElement();
    if (targetInput) {
        requestAnimationFrame(() => {
            targetInput.focus();
            targetInput.select();
        });
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
    setMessagesStatus('Open a conversation to start texting.', false);
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

        const identity = createIdentityOrb(conversation.displayName || conversation.phoneNumber);
        const body = document.createElement('div');
        body.className = 'messages-conversation-body';

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

        const openLabel = document.createElement('span');
        openLabel.className = 'messages-conversation-open';
        openLabel.innerText = 'Open';

        meta.appendChild(number);
        meta.appendChild(status);
        bottom.appendChild(meta);
        bottom.appendChild(openLabel);

        if (conversation.unreadCount > 0) {
            const unread = document.createElement('span');
            unread.className = 'messages-unread-badge';
            unread.innerText = conversation.unreadCount > 99 ? '99+' : String(conversation.unreadCount);
            bottom.appendChild(unread);
        }

        body.appendChild(top);
        body.appendChild(preview);
        body.appendChild(bottom);
        button.appendChild(identity);
        button.appendChild(body);
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

    renderHomeDashboard();
}

function setMessageThreadLoading(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber) || String(phoneNumber || '').trim();
    const contact = buildThreadContact(normalized);

    setMessageThreadHeader(contact);
    showMessageThreadView();

    const messagesContainer = document.getElementById('messages-thread-messages');
    if (messagesContainer) {
        messagesContainer.innerHTML = '<p class="loading">Loading conversation...</p>';
    }
}

function focusMessageReplyInput() {
    const replyInput = document.getElementById('message-reply-body');
    if (replyInput) {
        requestAnimationFrame(() => {
            replyInput.focus();
        });
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

    const activeConversation = findConversationEntry(thread.phoneNumber);
    const latestMessage = messagesState.activeThread.messages.length
        ? messagesState.activeThread.messages[messagesState.activeThread.messages.length - 1]
        : null;

    if (activeConversation) {
        activeConversation.unreadCount = 0;

        if (latestMessage) {
            activeConversation.lastMessage = latestMessage.body || activeConversation.lastMessage;
            activeConversation.lastMessageAt = latestMessage.sentAt || activeConversation.lastMessageAt;
            activeConversation.lastMessageFromSelf = latestMessage.mine === true;
        }

        messagesState.unreadTotal = recalculateUnreadTotal();
        renderMessageConversations();
        updateMessagesUnreadSummary();
        updateMessagesBadge();
    }

    setMessageTargetInput(thread.phoneNumber);

    if (uiState.currentApp === 'messages') {
        showMessageThreadView();
    }

    renderMessageThread();

    if (!messagesState.activeThread.messages.length) {
        setMessagesStatus('No messages yet. Send the first text.', false);
    }

    renderHomeDashboard();
}

function openMessageThread(phoneNumber) {
    const normalized = normalizePhoneNumber(phoneNumber);
    if (!normalized) {
        setMessagesStatus('Select a valid phone number.', true);
        return;
    }

    const contact = buildThreadContact(normalized);
    messagesState.activeThreadNumber = normalized;
    messagesState.activeThread = {
        phoneNumber: contact.phoneNumber,
        displayName: contact.displayName,
        online: contact.online,
        messages: []
    };
    setMessageTargetInput(normalized);
    setMessageThreadLoading(normalized);
    setMessagesStatus(`Loading conversation with ${normalized}...`, false);
    postNui('getMessageThread', { phoneNumber: normalized });
}

function openQuickMessageThread() {
    const targetInput = getMessageTargetInputElement();
    const phoneNumber = normalizePhoneNumber(targetInput ? targetInput.value : '');

    if (!phoneNumber) {
        setMessagesStatus('Enter a valid number (example: 555-0001).', true);
        return;
    }

    openMessageThread(phoneNumber);
    focusMessageReplyInput();
}

function sendNewMessage() {
    openQuickMessageThread();
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

    focusMessageReplyInput();
}

function applyIncomingConversationPreview(phoneNumber, preview) {
    const normalized = normalizePhoneNumber(phoneNumber);
    if (!normalized) {
        return;
    }

    const previewText = truncateInlineText(preview || 'New message', 64) || 'New message';
    const now = Math.floor(Date.now() / 1000);
    const existing = findConversationEntry(normalized);

    if (existing) {
        existing.lastMessage = previewText;
        existing.lastMessageAt = now;
        existing.lastMessageFromSelf = false;
        existing.unreadCount = Math.max(0, Number(existing.unreadCount) || 0) + 1;
    } else {
        const phonebookEntry = callState.phonebookEntries.find((entry) => entry && entry.phoneNumber === normalized) || null;

        messagesState.conversations.unshift({
            phoneNumber: normalized,
            displayName: phonebookEntry && phonebookEntry.displayName ? phonebookEntry.displayName : normalized,
            lastMessage: previewText,
            lastMessageAt: now,
            lastMessageFromSelf: false,
            unreadCount: 1,
            online: phonebookEntry ? phonebookEntry.online === true : false
        });
    }

    messagesState.conversations.sort((left, right) => {
        return Number((right && right.lastMessageAt) || 0) - Number((left && left.lastMessageAt) || 0);
    });

    messagesState.unreadTotal = recalculateUnreadTotal();
    renderMessageConversations();
    updateMessagesUnreadSummary();
    updateMessagesBadge();
    renderHomeDashboard();
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

    if (uiState.currentApp === 'messages' && !messagesState.activeThreadNumber) {
        applyIncomingConversationPreview(normalized, preview);
        openMessageThread(normalized);
        setMessagesStatus(`Opening conversation with ${label}.`, false);
        return;
    }

    applyIncomingConversationPreview(normalized, preview);

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
setPhoneSurfaceState('home');
updateCallUI();
updateMessagesUnreadSummary();
updateMessagesBadge();
renderHomeDashboard();
renderTaxiApp();
setPhoneHidden();

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'openPhone') {
        showPhoneShell();
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
        setPhoneHidden();
    } else if (data.action === 'displayVehicles') {
        displayVehicles(data.vehicles);
    } else if (data.action === 'displayPhonebook') {
        displayPhonebook(data.entries);
    } else if (data.action === 'displayMessageConversations') {
        displayMessageConversations(data.conversations, data.unreadTotal);
    } else if (data.action === 'displayMessageThread') {
        displayMessageThread(data.thread);
    } else if (data.action === 'displayTaxiAppState') {
        displayTaxiAppState(data.state || {});
    } else if (data.action === 'taxiAppStatus') {
        setTaxiAppStatus(data.message || '', data.isError === true);
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
        setBalance(data.balance, data.formattedBalance, data.cash, data.formattedCash, data.available);
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
