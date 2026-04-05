const COMPASS_VIEW_RANGE = 90;
const COMPASS_TICK_INTERVAL = 5;

const CARDINAL_LABELS = {
	0: 'N',
	45: 'NE',
	90: 'E',
	135: 'SE',
	180: 'S',
	225: 'SW',
	270: 'W',
	315: 'NW'
};

const NEEDS_ANIMATION_DURATION_MS = 900;

const hudRootEl = document.getElementById('hud-root');
const vehicleShellEl = document.getElementById('vehicle-shell');
const needsShellEl = document.getElementById('needs-shell');
const fuelShellEl = document.getElementById('fuel-shell');
const compassTrackEl = document.getElementById('compass-track');
const vehicleNameEl = document.getElementById('vehicle-name');
const speedValueEl = document.getElementById('speed-value');
const headingNumberEl = document.getElementById('heading-number');
const headingCardinalEl = document.getElementById('heading-cardinal');
const streetValueEl = document.getElementById('street-value');
const areaValueEl = document.getElementById('area-value');
const hungerIndicatorEl = document.getElementById('hunger-indicator');
const thirstIndicatorEl = document.getElementById('thirst-indicator');
const fuelIndicatorEl = document.getElementById('fuel-indicator');
const hungerFillBarEl = document.getElementById('hunger-fill-bar');
const thirstFillBarEl = document.getElementById('thirst-fill-bar');
const fuelFillBarEl = document.getElementById('fuel-fill-bar');
const hungerValueEl = document.getElementById('hunger-value');
const thirstValueEl = document.getElementById('thirst-value');
const fuelValueEl = document.getElementById('fuel-value');

const state = {
	vehicleVisible: false,
	vehicle: {
		heading: 0,
		speed: 0,
		street: 'Unknown Road',
		area: 'San Andreas',
		vehicleName: 'Vehicle'
	},
	needsVisible: false,
	needs: {
		hunger: 100,
		thirst: null
	},
	fuelVisible: false,
	fuel: {
		percent: 100,
		isLow: false,
		isCritical: false
	},
	animatedNeeds: {
		hunger: 100,
		thirst: null
	}
};

const needsAnimationState = {
	frameId: null,
	startedAt: 0,
	from: {
		hunger: 100,
		thirst: null
	},
	to: {
		hunger: 100,
		thirst: null
	}
};

function setText(element, value) {
	element.textContent = String(value ?? '');
}

function setHidden(element, isHidden) {
	element.classList.toggle('is-hidden', isHidden);
	element.setAttribute('aria-hidden', isHidden ? 'true' : 'false');
}

function normalizeHeading(heading) {
	const numericHeading = Number(heading) || 0;
	const normalized = numericHeading % 360;
	return normalized < 0 ? normalized + 360 : normalized;
}

function getCardinalLabel(heading) {
	const snappedHeading = Math.round(normalizeHeading(heading) / 45) * 45;
	return CARDINAL_LABELS[normalizeHeading(snappedHeading)] || 'N';
}

function getWrappedHeadingDelta(targetHeading, currentHeading) {
	return ((normalizeHeading(targetHeading) - normalizeHeading(currentHeading) + 540) % 360) - 180;
}

function updateRootVisibility() {
	const isVisible = state.vehicleVisible || state.needsVisible || state.fuelVisible;
	hudRootEl.classList.toggle('hud-root--hidden', !isVisible);
	hudRootEl.setAttribute('aria-hidden', isVisible ? 'false' : 'true');
	setHidden(vehicleShellEl, !state.vehicleVisible);
	setHidden(needsShellEl, !state.needsVisible);
	setHidden(fuelShellEl, !state.fuelVisible);
}

function renderCompass(heading) {
	if (!Number.isFinite(heading)) {
		compassTrackEl.replaceChildren();
		return;
	}

	const fragment = document.createDocumentFragment();
	for (let tickOffset = -COMPASS_VIEW_RANGE; tickOffset <= COMPASS_VIEW_RANGE; tickOffset += COMPASS_TICK_INTERVAL) {
		const tickHeading = normalizeHeading(heading + tickOffset);
		const isMajor = tickHeading % 15 === 0;
		const isCardinal = tickHeading % 45 === 0;

		const markerEl = document.createElement('div');
		markerEl.className = 'marker';
		if (isMajor) {
			markerEl.classList.add('marker--major');
		}
		if (isCardinal) {
			markerEl.classList.add('marker--bold');
		}
		markerEl.style.transform = `translateX(${tickOffset * 10}px)`;

		const lineEl = document.createElement('span');
		lineEl.className = 'marker-line';
		markerEl.appendChild(lineEl);

		if (isCardinal) {
			const labelEl = document.createElement('span');
			labelEl.className = 'marker-label';
			labelEl.textContent = CARDINAL_LABELS[tickHeading] || '';
			markerEl.appendChild(labelEl);
		}

		fragment.appendChild(markerEl);
	}

	compassTrackEl.replaceChildren(fragment);
}

function renderVehicle() {
	const vehicle = state.vehicle;
	const heading = normalizeHeading(vehicle.heading);

	setText(vehicleNameEl, vehicle.vehicleName || 'Vehicle');
	setText(speedValueEl, Math.max(0, Math.floor(Number(vehicle.speed) || 0)));
	setText(headingNumberEl, Math.round(heading).toString().padStart(3, '0'));
	setText(headingCardinalEl, getCardinalLabel(heading));
	setText(streetValueEl, vehicle.street || 'Unknown Road');
	setText(areaValueEl, vehicle.area || 'San Andreas');

	renderCompass(heading);
}

function easeOutCubic(progress) {
	const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
	return 1 - ((1 - clamped) ** 3);
}

function interpolateNeedsValue(fromValue, toValue, progress) {
	if (toValue == null) {
		return null;
	}

	const numericTo = Math.max(0, Math.min(100, Number(toValue) || 0));
	const numericFrom = fromValue == null ? numericTo : Math.max(0, Math.min(100, Number(fromValue) || 0));
	return numericFrom + ((numericTo - numericFrom) * progress);
}

function stopNeedsAnimation() {
	if (needsAnimationState.frameId !== null) {
		cancelAnimationFrame(needsAnimationState.frameId);
		needsAnimationState.frameId = null;
	}
}

function animateNeeds() {
	stopNeedsAnimation();

	needsAnimationState.startedAt = performance.now();
	needsAnimationState.from = {
		hunger: state.animatedNeeds.hunger,
		thirst: state.animatedNeeds.thirst
	};
	needsAnimationState.to = {
		hunger: state.needs.hunger,
		thirst: state.needs.thirst
	};

	const step = (timestamp) => {
		const elapsedMs = timestamp - needsAnimationState.startedAt;
		const progress = easeOutCubic(elapsedMs / NEEDS_ANIMATION_DURATION_MS);

		state.animatedNeeds = {
			hunger: interpolateNeedsValue(needsAnimationState.from.hunger, needsAnimationState.to.hunger, progress),
			thirst: interpolateNeedsValue(needsAnimationState.from.thirst, needsAnimationState.to.thirst, progress)
		};

		renderNeeds();

		if (progress < 1) {
			needsAnimationState.frameId = requestAnimationFrame(step);
			return;
		}

		state.animatedNeeds = {
			hunger: needsAnimationState.to.hunger,
			thirst: needsAnimationState.to.thirst
		};
		renderNeeds();
		needsAnimationState.frameId = null;
	};

	needsAnimationState.frameId = requestAnimationFrame(step);
}

function renderNeeds() {
	const hungerPercent = Math.max(0, Math.min(100, Math.round(Number(state.animatedNeeds.hunger) || 0)));
	const thirstPercent = state.animatedNeeds.thirst == null
		? null
		: Math.max(0, Math.min(100, Math.round(Number(state.animatedNeeds.thirst) || 0)));

	hungerFillBarEl.style.width = `${hungerPercent}%`;
	setText(hungerValueEl, `${hungerPercent}%`);
	hungerIndicatorEl.setAttribute('aria-label', `Hunger ${hungerPercent}%`);
	hungerIndicatorEl.classList.toggle('is-low', hungerPercent > 10 && hungerPercent <= 25);
	hungerIndicatorEl.classList.toggle('is-critical', hungerPercent <= 10);

	if (thirstPercent == null) {
		setHidden(thirstIndicatorEl, true);
	}
	else {
		setHidden(thirstIndicatorEl, false);
		thirstFillBarEl.style.width = `${thirstPercent}%`;
		setText(thirstValueEl, `${thirstPercent}%`);
		thirstIndicatorEl.setAttribute('aria-label', `Thirst ${thirstPercent}%`);
		thirstIndicatorEl.classList.toggle('is-low', thirstPercent > 10 && thirstPercent <= 25);
		thirstIndicatorEl.classList.toggle('is-critical', thirstPercent <= 10);
	}
}

function renderFuel() {
	const fuelPercent = Math.max(0, Math.min(100, Math.round(Number(state.fuel.percent) || 0)));

	fuelFillBarEl.style.width = `${fuelPercent}%`;
	setText(fuelValueEl, `${fuelPercent}%`);
	fuelIndicatorEl.setAttribute('aria-label', `Fuel ${fuelPercent}%`);
	fuelIndicatorEl.classList.toggle('is-low', state.fuel.isLow === true && state.fuel.isCritical !== true);
	fuelIndicatorEl.classList.toggle('is-critical', state.fuel.isCritical === true);
}

window.addEventListener('message', (event) => {
	const message = event.data || {};
	if (!message || typeof message !== 'object' || !message.action) {
		return;
	}

	if (message.action === 'vehicleCompass:show' || message.action === 'vehicleCompass:update') {
		state.vehicleVisible = true;
		state.vehicle = {
			...state.vehicle,
			...(message.data || {})
		};
		renderVehicle();
		updateRootVisibility();
		return;
	}

	if (message.action === 'vehicleCompass:hide') {
		state.vehicleVisible = false;
		updateRootVisibility();
		return;
	}

	if (message.action === 'playerNeeds:show' || message.action === 'playerNeeds:update') {
		state.needsVisible = true;
		state.needs = {
			...state.needs,
			...(message.data || {})
		};
		animateNeeds();
		updateRootVisibility();
		return;
	}

	if (message.action === 'playerNeeds:hide') {
		state.needsVisible = false;
		stopNeedsAnimation();
		updateRootVisibility();
		return;
	}

	if (message.action === 'vehicleFuel:show' || message.action === 'vehicleFuel:update') {
		state.fuelVisible = true;
		state.fuel = {
			...state.fuel,
			...(message.data || {})
		};
		renderFuel();
		updateRootVisibility();
		return;
	}

	if (message.action === 'vehicleFuel:hide') {
		state.fuelVisible = false;
		updateRootVisibility();
	}
});

updateRootVisibility();