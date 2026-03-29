const appEl = document.getElementById('app');
const eyebrowEl = document.getElementById('eyebrow');
const titleEl = document.getElementById('shell-title');
const subtitleEl = document.getElementById('subtitle');
const statusStripEl = document.getElementById('status-strip');
const sectionListEl = document.getElementById('section-list');
const footerTextEl = document.getElementById('footer-text');
const closeButtonEl = document.getElementById('close-button');
const primaryButtonEl = document.getElementById('primary-button');
const secondaryButtonEl = document.getElementById('secondary-button');

const state = {
    open: false,
    payload: {}
};

function postNui(endpoint, payload) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload || {})
    });
}

function setStartupHidden() {
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');
    appEl.classList.add('hidden');
    appEl.setAttribute('aria-hidden', 'true');
}

function createStatusCard(item) {
    const card = document.createElement('article');
    card.className = 'status-card';
    card.innerHTML = `
        <span class="status-card__label">${item.label || 'Status'}</span>
        <strong>${item.value || '-'}</strong>
    `;
    return card;
}

function createContentCard(section) {
    const card = document.createElement('article');
    card.className = 'content-card';
    card.innerHTML = `
        <h2>${section.title || 'Section'}</h2>
        <p>${section.body || ''}</p>
    `;
    return card;
}

function render() {
    const payload = state.payload || {};

    eyebrowEl.textContent = payload.eyebrow || 'LSRP Template';
    titleEl.textContent = payload.title || 'Reusable NUI Shell';
    subtitleEl.textContent = payload.subtitle || 'Use this shell as the default starting point for new LSRP interfaces.';
    footerTextEl.textContent = payload.footer || 'Swap these sections and actions for your feature-specific UI.';

    statusStripEl.innerHTML = '';
    const statusItems = Array.isArray(payload.statusItems) ? payload.statusItems : [];
    statusItems.forEach((item) => statusStripEl.appendChild(createStatusCard(item)));

    sectionListEl.innerHTML = '';
    const sections = Array.isArray(payload.sections) ? payload.sections : [];
    sections.forEach((section) => sectionListEl.appendChild(createContentCard(section)));

    if (statusItems.length === 0) {
        statusStripEl.classList.add('hidden');
    } else {
        statusStripEl.classList.remove('hidden');
    }

    if (sections.length === 0) {
        sectionListEl.classList.add('hidden');
    } else {
        sectionListEl.classList.remove('hidden');
    }

    const primary = payload.primary || {};
    const secondary = payload.secondary || {};

    primaryButtonEl.textContent = primary.label || 'Primary';
    primaryButtonEl.classList.toggle('hidden', primary.hidden === true);
    primaryButtonEl.dataset.event = primary.event || 'primary';

    secondaryButtonEl.textContent = secondary.label || 'Secondary';
    secondaryButtonEl.classList.toggle('hidden', secondary.hidden === true);
    secondaryButtonEl.dataset.event = secondary.event || 'secondary';
}

function openApp(payload) {
    state.open = true;
    state.payload = payload && typeof payload === 'object' ? payload : {};

    document.body.style.display = 'block';
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');

    appEl.classList.remove('hidden');
    appEl.setAttribute('aria-hidden', 'false');
    render();
}

function closeApp() {
    state.open = false;
    state.payload = {};
    setStartupHidden();
}

closeButtonEl.addEventListener('click', () => {
    postNui('close');
});

primaryButtonEl.addEventListener('click', () => {
    postNui('primaryAction', {
        event: primaryButtonEl.dataset.event || 'primary',
        payload: state.payload || {}
    });
});

secondaryButtonEl.addEventListener('click', () => {
    postNui('secondaryAction', {
        event: secondaryButtonEl.dataset.event || 'secondary',
        payload: state.payload || {}
    });
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'open') {
        openApp(message.payload || {});
    }
    if (message.action === 'close') {
        closeApp();
    }
});

window.addEventListener('keydown', (event) => {
    if (!state.open) {
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        postNui('close');
    }
});

setStartupHidden();