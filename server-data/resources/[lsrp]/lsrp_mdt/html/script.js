const appEl = document.getElementById('app');
const eyebrowEl = document.getElementById('eyebrow');
const titleEl = document.getElementById('mdt-title');
const subtitleEl = document.getElementById('subtitle');
const unitNameEl = document.getElementById('unit-name');
const unitMetaEl = document.getElementById('unit-meta');
const unitDutyEl = document.getElementById('unit-duty');
const unitStateEl = document.getElementById('unit-state');
const shortcutListEl = document.getElementById('shortcut-list');
const statusStripEl = document.getElementById('status-strip');
const sectionListEl = document.getElementById('section-list');
const noticeListEl = document.getElementById('notice-list');
const lookupSummaryEl = document.getElementById('lookup-summary');
const resultListEl = document.getElementById('result-list');
const rosterSummaryEl = document.getElementById('roster-summary');
const rosterListEl = document.getElementById('roster-list');
const footerTextEl = document.getElementById('footer-text');
const closeButtonEl = document.getElementById('close-button');
const refreshButtonEl = document.getElementById('refresh-button');
const personQueryEl = document.getElementById('person-query');
const vehicleQueryEl = document.getElementById('vehicle-query');
const personSearchEl = document.getElementById('person-search');
const vehicleSearchEl = document.getElementById('vehicle-search');

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

function createShortcut(item) {
	const card = document.createElement('button');
	card.className = 'shortcut';
	card.type = 'button';
	card.innerHTML = `
		<strong>${item.label || 'Shortcut'}</strong>
		<p>${item.description || ''}</p>
	`;
	card.addEventListener('click', () => {
		postNui('mdtAction', {
			event: item.event || item.id || 'shortcut',
			query: ''
		});
	});
	return card;
}

function createSectionCard(section) {
	const card = document.createElement('article');
	card.className = 'section-card';
	card.innerHTML = `
		<h3>${section.title || 'Section'}</h3>
		<p>${section.body || ''}</p>
	`;
	return card;
}

function createDetailCard(entry) {
	const card = document.createElement('article');
	card.className = 'detail-card';

	const badges = Array.isArray(entry.badges)
		? entry.badges.filter(Boolean).map((badge) => `<span class="detail-badge">${badge}</span>`).join('')
		: '';
	const lines = Array.isArray(entry.lines)
		? entry.lines.filter(Boolean).map((line) => `<li>${line}</li>`).join('')
		: '';

	card.innerHTML = `
		<div class="detail-card__header">
			<div>
				<h3>${entry.title || 'Record'}</h3>
				<p>${entry.meta || ''}</p>
			</div>
			<div class="detail-badge-row">${badges}</div>
		</div>
		<ul class="detail-line-list">${lines}</ul>
	`;

	return card;
}

function renderDetailCollection(container, collection, emptyMessage) {
	container.innerHTML = '';
	if (!collection || !Array.isArray(collection.entries) || collection.entries.length === 0) {
		const empty = document.createElement('div');
		empty.className = 'detail-empty';
		empty.textContent = emptyMessage || 'No records found.';
		container.appendChild(empty);
		return;
	}

	collection.entries.forEach((entry) => container.appendChild(createDetailCard(entry)));
}

function render() {
	const payload = state.payload || {};
	const unit = payload.unit || {};
	const lookupResult = payload.lookupResult || {};
	const unitRoster = payload.unitRoster || {};

	eyebrowEl.textContent = payload.eyebrow || 'LSRP MDT';
	titleEl.textContent = payload.title || 'Mobile Data Terminal';
	subtitleEl.textContent = payload.subtitle || 'Starter terminal shell.';
	unitNameEl.textContent = unit.name || 'Unit';
	unitMetaEl.textContent = `${unit.jobLabel || 'Agency'} • ${unit.gradeLabel || 'Role'}`;
	unitDutyEl.textContent = unit.dutyLabel || 'Duty Unknown';
	unitStateEl.textContent = `State ID ${unit.stateId || 'Unknown'}`;
	footerTextEl.textContent = payload.footer || 'Press Escape to close the terminal.';

	shortcutListEl.innerHTML = '';
	(payload.shortcuts || []).forEach((item) => shortcutListEl.appendChild(createShortcut(item)));

	statusStripEl.innerHTML = '';
	(payload.statusItems || []).forEach((item) => statusStripEl.appendChild(createStatusCard(item)));

	sectionListEl.innerHTML = '';
	(payload.sections || []).forEach((section) => sectionListEl.appendChild(createSectionCard(section)));

	noticeListEl.innerHTML = '';
	(payload.notices || []).forEach((notice) => {
		const row = document.createElement('li');
		row.textContent = notice || '';
		noticeListEl.appendChild(row);
	});

	lookupSummaryEl.textContent = lookupResult.summary || 'Run a search to populate this panel.';
	renderDetailCollection(resultListEl, lookupResult, lookupResult.emptyMessage || 'No lookup results yet.');

	rosterSummaryEl.textContent = unitRoster.summary || 'No active roster data loaded yet.';
	renderDetailCollection(rosterListEl, unitRoster, unitRoster.emptyMessage || 'No active units found.');
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
	personQueryEl.value = '';
	vehicleQueryEl.value = '';
}

function closeApp() {
	state.open = false;
	state.payload = {};
	setStartupHidden();
}

closeButtonEl.addEventListener('click', () => {
	postNui('close');
});

refreshButtonEl.addEventListener('click', () => {
	postNui('refreshMdt');
});

personSearchEl.addEventListener('click', () => {
	postNui('mdtAction', {
		event: 'personLookup',
		query: personQueryEl.value || ''
	});
});

vehicleSearchEl.addEventListener('click', () => {
	postNui('mdtAction', {
		event: 'vehicleLookup',
		query: vehicleQueryEl.value || ''
	});
});

personQueryEl.addEventListener('keydown', (event) => {
	if (event.key !== 'Enter') {
		return;
	}

	event.preventDefault();
	personSearchEl.click();
});

vehicleQueryEl.addEventListener('keydown', (event) => {
	if (event.key !== 'Enter') {
		return;
	}

	event.preventDefault();
	vehicleSearchEl.click();
});

window.addEventListener('message', (event) => {
	const message = event.data || {};
	if (message.action === 'open') {
		openApp(message.payload || {});
	}
	if (message.action === 'close') {
		closeApp();
	}
	if (message.action === 'update') {
		state.payload = message.payload || {};
		render();
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