const appEl = document.getElementById('app');
const eyebrowEl = document.getElementById('eyebrow');
const titleEl = document.getElementById('mdt-title');
const subtitleEl = document.getElementById('subtitle');
const unitNameEl = document.getElementById('unit-name');
const unitMetaEl = document.getElementById('unit-meta');
const unitDutyEl = document.getElementById('unit-duty');
const unitStateEl = document.getElementById('unit-state');
const noticeListEl = document.getElementById('notice-list');
const statusStripEl = document.getElementById('status-strip');
const searchSummaryEl = document.getElementById('search-summary');
const resultListEl = document.getElementById('result-list');
const profileNameEl = document.getElementById('profile-name');
const profileMetaEl = document.getElementById('profile-meta');
const profileBadgesEl = document.getElementById('profile-badges');
const tagListEl = document.getElementById('tag-list');
const tagEditorEl = document.getElementById('tag-editor');
const tagInputEl = document.getElementById('tag-input');
const addTagButtonEl = document.getElementById('add-tag-button');
const intelAccessCopyEl = document.getElementById('intel-access-copy');
const intelEditorEl = document.getElementById('intel-editor');
const intelInputEl = document.getElementById('intel-input');
const addIntelButtonEl = document.getElementById('add-intel-button');
const intelListEl = document.getElementById('intel-list');
const rosterSummaryEl = document.getElementById('roster-summary');
const rosterListEl = document.getElementById('roster-list');
const footerTextEl = document.getElementById('footer-text');
const closeButtonEl = document.getElementById('close-button');
const refreshButtonEl = document.getElementById('refresh-button');
const personQueryEl = document.getElementById('person-query');
const personSearchEl = document.getElementById('person-search');

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

	const label = document.createElement('span');
	label.className = 'status-card__label';
	label.textContent = item.label || 'Status';

	const value = document.createElement('strong');
	value.textContent = item.value || '-';

	card.append(label, value);
	return card;
}

function createBadge(text, removable, onRemove) {
	const badge = document.createElement('span');
	badge.className = removable ? 'tag tag--interactive' : 'tag';
	badge.textContent = text || '';

	if (removable) {
		const removeButton = document.createElement('button');
		removeButton.type = 'button';
		removeButton.className = 'tag__remove';
		removeButton.textContent = 'x';
		removeButton.addEventListener('click', (event) => {
			event.stopPropagation();
			onRemove();
		});
		badge.appendChild(removeButton);
	}

	return badge;
}

function createStackCard(entry, clickHandler) {
	const card = document.createElement('button');
	card.className = 'stack-card';
	card.type = 'button';

	const header = document.createElement('div');
	header.className = 'stack-card__header';

	const title = document.createElement('strong');
	title.textContent = entry.title || 'Record';

	const meta = document.createElement('span');
	meta.textContent = entry.meta || '';

	header.append(title, meta);
	card.appendChild(header);

	if (entry.subtitle) {
		const subtitle = document.createElement('p');
		subtitle.textContent = entry.subtitle;
		card.appendChild(subtitle);
	}

	if (Array.isArray(entry.badges) && entry.badges.length > 0) {
		const badgeRow = document.createElement('div');
		badgeRow.className = 'badge-row';
		entry.badges.filter(Boolean).forEach((badge) => badgeRow.appendChild(createBadge(badge, false, null)));
		card.appendChild(badgeRow);
	}

	card.addEventListener('click', () => clickHandler(entry));
	return card;
}

function renderEmptyState(container, message) {
	container.innerHTML = '';
	const empty = document.createElement('div');
	empty.className = 'empty-state';
	empty.textContent = message;
	container.appendChild(empty);
}

function renderSearchResults() {
	const search = state.payload.search || {};
	searchSummaryEl.textContent = search.summary || 'Search by player name or exact state ID.';
	personQueryEl.value = search.query || personQueryEl.value || '';

	resultListEl.innerHTML = '';
	if (!Array.isArray(search.results) || search.results.length === 0) {
		renderEmptyState(resultListEl, search.emptyMessage || 'No results found.');
		return;
	}

	search.results.forEach((entry) => {
		resultListEl.appendChild(createStackCard(entry, (selectedEntry) => {
			postNui('mdtAction', {
				event: 'selectProfile',
				stateId: selectedEntry.stateId
			});
		}));
	});
}

function renderProfile() {
	const profile = state.payload.selectedProfile || {};
	const permissions = state.payload.permissions || {};
	const canEdit = permissions.canEditIntel === true && typeof profile.stateId === 'number';

	profileNameEl.textContent = profile.fullName || 'No profile selected';
	profileMetaEl.textContent = profile.meta || 'Select a search result to open a profile.';
	profileBadgesEl.innerHTML = '';
	(profile.badges || []).filter(Boolean).forEach((badge) => profileBadgesEl.appendChild(createBadge(badge, false, null)));

	tagListEl.innerHTML = '';
	if (Array.isArray(profile.tags) && profile.tags.length > 0) {
		profile.tags.forEach((tag) => {
			tagListEl.appendChild(createBadge(tag, canEdit, () => {
				postNui('mdtAction', {
					event: 'removeTag',
					stateId: profile.stateId,
					tag
				});
			}));
		});
	} else {
		renderEmptyState(tagListEl, profile.stateId ? 'No tags on this profile.' : 'Select a profile to view tags.');
	}

	tagEditorEl.classList.toggle('hidden', !canEdit);
	tagInputEl.disabled = !canEdit;
	addTagButtonEl.disabled = !canEdit;

	intelListEl.innerHTML = '';
	if (Array.isArray(profile.notes) && profile.notes.length > 0) {
		profile.notes.forEach((note) => {
			const noteCard = document.createElement('article');
			noteCard.className = 'timeline-item';

			const header = document.createElement('div');
			header.className = 'timeline-item__header';

			const author = document.createElement('strong');
			author.textContent = note.authorName || 'Unknown';

			const stamp = document.createElement('span');
			stamp.textContent = note.createdAt || '';

			header.append(author, stamp);

			const text = document.createElement('p');
			text.textContent = note.text || '';

			noteCard.append(header, text);
			intelListEl.appendChild(noteCard);
		});
	} else {
		renderEmptyState(intelListEl, profile.stateId ? 'No intel has been added to this profile yet.' : 'Select a profile to view intel.');
	}

	intelEditorEl.classList.toggle('hidden', !canEdit);
	intelInputEl.disabled = !canEdit;
	addIntelButtonEl.disabled = !canEdit;
	intelAccessCopyEl.textContent = canEdit
		? 'On-duty police can append intel and manage profile tags.'
		: (profile.stateId ? 'This profile is read-only with your current access.' : 'Select a profile to review intel history.');
}

function renderRoster() {
	const roster = state.payload.roster || {};
	rosterSummaryEl.textContent = roster.summary || 'No active roster data loaded yet.';
	rosterListEl.innerHTML = '';
	if (!Array.isArray(roster.entries) || roster.entries.length === 0) {
		renderEmptyState(rosterListEl, roster.emptyMessage || 'No active police units found.');
		return;
	}

	roster.entries.forEach((entry) => {
		rosterListEl.appendChild(createStackCard(entry, () => {
			if (typeof entry.stateId !== 'number') {
				return;
			}
			postNui('mdtAction', {
				event: 'selectProfile',
				stateId: entry.stateId
			});
		}));
	});
}

function renderNotices() {
	noticeListEl.innerHTML = '';
	const notices = Array.isArray(state.payload.notices) ? state.payload.notices : [];
	if (notices.length === 0) {
		return;
	}

	notices.forEach((notice) => {
		const row = document.createElement('li');
		row.textContent = notice;
		noticeListEl.appendChild(row);
	});
}

function render() {
	const payload = state.payload || {};
	const unit = payload.unit || {};

	eyebrowEl.textContent = payload.eyebrow || 'LSRP MDT';
	titleEl.textContent = payload.title || 'Minimal MDT';
	subtitleEl.textContent = payload.subtitle || 'Player lookup, intel, tags, and active police duty roster.';
	unitNameEl.textContent = unit.name || 'Unit';
	unitMetaEl.textContent = `${unit.jobLabel || 'Agency'} - ${unit.gradeLabel || 'Role'}`;
	unitDutyEl.textContent = unit.dutyLabel || 'Duty Unknown';
	unitStateEl.textContent = `State ID ${unit.stateId || 'Unknown'}`;
	footerTextEl.textContent = payload.footer || 'Press Escape to close the terminal.';

	statusStripEl.innerHTML = '';
	(payload.statusItems || []).forEach((item) => statusStripEl.appendChild(createStatusCard(item)));

	renderSearchResults();
	renderProfile();
	renderRoster();
	renderNotices();
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
	personQueryEl.value = '';
	tagInputEl.value = '';
	intelInputEl.value = '';
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

personQueryEl.addEventListener('keydown', (event) => {
	if (event.key !== 'Enter') {
		return;
	}

	event.preventDefault();
	personSearchEl.click();
});

addTagButtonEl.addEventListener('click', () => {
	const selectedProfile = state.payload.selectedProfile || {};
	if (typeof selectedProfile.stateId !== 'number') {
		return;
	}

	postNui('mdtAction', {
		event: 'addTag',
		stateId: selectedProfile.stateId,
		tag: tagInputEl.value || ''
	});
	tagInputEl.value = '';
});

addIntelButtonEl.addEventListener('click', () => {
	const selectedProfile = state.payload.selectedProfile || {};
	if (typeof selectedProfile.stateId !== 'number') {
		return;
	}

	postNui('mdtAction', {
		event: 'addIntel',
		stateId: selectedProfile.stateId,
		note: intelInputEl.value || ''
	});
	intelInputEl.value = '';
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