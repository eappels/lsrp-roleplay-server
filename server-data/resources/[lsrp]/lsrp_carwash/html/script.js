const resourceName = (typeof window.GetParentResourceName === 'function')
	? window.GetParentResourceName()
	: 'lsrp_carwash';

const state = {
	open: false,
	washDurationMs: 3500,
	washing: false,
	statusText: 'Ready for wash.'
};

const appElement = document.getElementById('app');
const closeButtonElement = document.getElementById('close-button');
const washButtonElement = document.getElementById('wash-button');
const locationLabelElement = document.getElementById('location-label');
const vehicleLabelElement = document.getElementById('vehicle-label');
const washPriceElement = document.getElementById('wash-price');
const balanceLabelElement = document.getElementById('balance-label');
const washTimeElement = document.getElementById('wash-time');
const statusTextElement = document.getElementById('status-text');

function setVisibility(visible) {
	if (visible) {
		document.body.style.display = 'block';
		document.body.style.visibility = 'visible';
		document.body.style.opacity = '1';
		appElement.classList.remove('hidden');
		appElement.setAttribute('aria-hidden', 'false');
		return;
	}

	document.body.style.display = 'none';
	document.body.style.visibility = 'hidden';
	document.body.style.opacity = '0';
	appElement.classList.add('hidden');
	appElement.setAttribute('aria-hidden', 'true');
}

async function postNui(eventName, payload = {}) {
	try {
		const response = await fetch(`https://${resourceName}/${eventName}`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json; charset=UTF-8'
			},
			body: JSON.stringify(payload)
		});

		const text = await response.text();
		if (!text) {
			return { ok: response.ok };
		}

		try {
			return JSON.parse(text);
		} catch (_error) {
			return { ok: response.ok };
		}
	} catch (_error) {
		return { ok: false, error: 'request_failed' };
	}
}

function getWashErrorMessage(errorCode) {
	switch (String(errorCode || '')) {
		case 'insufficient_funds':
			return 'Not enough LS$ for this wash.';
		case 'vehicle_not_in_bay':
		case 'not_in_bay':
			return 'Move into the wash bay first.';
		case 'invalid_location':
			return 'This carwash location is unavailable.';
		case 'callback_not_registered':
			return 'Carwash backend is not ready yet.';
		case 'timeout':
			return 'Carwash request timed out.';
		case 'framework_unavailable':
			return 'Carwash payment services are unavailable right now.';
		case 'framework_callback_failed':
		case 'callback_failed':
			return 'Carwash backend failed to respond.';
		case 'request_failed':
			return 'The UI could not reach the carwash callback.';
		default:
			return 'Could not start wash.';
	}
}

function render() {
	washButtonElement.disabled = state.washing;
	statusTextElement.textContent = state.statusText;
	washTimeElement.textContent = `${(state.washDurationMs / 1000).toFixed(1)}s`;
}

function openUi(payload = {}) {
	state.open = true;
	state.washDurationMs = Math.max(1000, Math.floor(Number(payload.washDurationMs) || 3500));
	state.washing = false;
	state.statusText = 'Ready for wash.';
	locationLabelElement.textContent = payload.locationLabel || 'Carwash';
	vehicleLabelElement.textContent = payload.vehicleLabel || 'Current Vehicle';
	washPriceElement.textContent = payload.formattedWashPrice || 'LS$0';
	balanceLabelElement.textContent = payload.formattedBalance || 'LS$0';
	setVisibility(true);
	render();
}

function applySnapshot(payload = {}) {
	washPriceElement.textContent = payload.formattedWashPrice || washPriceElement.textContent || 'LS$0';
	balanceLabelElement.textContent = payload.formattedBalance || balanceLabelElement.textContent || 'LS$0';
}

function closeUi() {
	state.open = false;
	state.washing = false;
	state.statusText = 'Ready for wash.';
	setVisibility(false);
	render();
}

closeButtonElement.addEventListener('click', () => {
	postNui('close');
});

washButtonElement.addEventListener('click', async () => {
	if (!state.open || state.washing) {
		return;
	}

	state.washing = true;
	state.statusText = 'Processing payment...';
	render();

	const response = await postNui('washVehicle');
	if (!response || response.ok !== true) {
		state.washing = false;
		state.statusText = getWashErrorMessage(response && response.error);
		render();
		return;
	}

	if (response.data && response.data.formattedBalance) {
		applySnapshot(response.data);
	}
	state.statusText = 'Wash in progress...';

	window.setTimeout(() => {
		state.washing = false;
		state.statusText = 'Wash complete.';
		render();
	}, state.washDurationMs + 100);
});

window.addEventListener('message', (event) => {
	const data = event.data;
	if (!data || typeof data !== 'object') {
		return;
	}

	if (data.action === 'open') {
		openUi(data.payload || {});
	} else if (data.action === 'setSnapshot') {
		applySnapshot(data.payload || {});
	} else if (data.action === 'close') {
		closeUi();
	}
});

document.addEventListener('keydown', (event) => {
	if (event.key === 'Escape' && state.open) {
		postNui('close');
	}
});

render();
setVisibility(false);