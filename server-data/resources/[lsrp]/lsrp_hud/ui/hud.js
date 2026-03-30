const COMPASS_VIEW_RANGE = 90;
const COMPASS_TICK_INTERVAL = 15;
const COMPASS_MAJOR_INTERVAL = 45;
const COMPASS_CARDINAL_INTERVAL = 90;

const DIRECTION_LABELS = {
	0: 'N',
	45: 'NE',
	90: 'E',
	135: 'SE',
	180: 'S',
	225: 'SW',
	270: 'W',
	315: 'NW'
};

const rootEl = document.getElementById('hud-root');
const compassSectionEl = document.getElementById('compass-section');
const compassRailEl = document.getElementById('compass-rail');
const xValueEl = document.getElementById('x-value');
const yValueEl = document.getElementById('y-value');
const zValueEl = document.getElementById('z-value');
const directionValueEl = document.getElementById('direction-value');
const headingValueEl = document.getElementById('heading-value');
const streetValueEl = document.getElementById('street-value');

document.documentElement.style.background = 'transparent';
document.documentElement.style.backgroundColor = 'transparent';
document.documentElement.style.width = '100%';
document.documentElement.style.height = '100%';
document.body.style.display = 'block';
document.body.style.visibility = 'visible';
document.body.style.opacity = '1';
document.body.style.margin = '0';
document.body.style.width = '100%';
document.body.style.height = '100%';
document.body.style.background = 'transparent';
document.body.style.backgroundColor = 'transparent';
document.body.style.overflow = 'hidden';

function setVisible(isVisible) {
	rootEl.classList.toggle('hud-root--hidden', !isVisible);
	rootEl.setAttribute('aria-hidden', isVisible ? 'false' : 'true');
}

function setHidden(element, isHidden) {
	element.classList.toggle('is-hidden', isHidden);
}

function setText(element, value) {
	element.textContent = value || '';
}

function normalizeHeading(heading) {
	const numericHeading = Number(heading) || 0;
	const normalized = numericHeading % 360;
	return normalized < 0 ? normalized + 360 : normalized;
}

function getWrappedHeadingDelta(targetHeading, currentHeading) {
	return ((normalizeHeading(targetHeading) - normalizeHeading(currentHeading) + 540) % 360) - 180;
}

function renderCompass(heading) {
	if (!Number.isFinite(heading)) {
		compassRailEl.replaceChildren();
		return;
	}

	const fragment = document.createDocumentFragment();
	const startHeading = Math.floor((heading - COMPASS_VIEW_RANGE) / COMPASS_TICK_INTERVAL) * COMPASS_TICK_INTERVAL;
	const endHeading = Math.ceil((heading + COMPASS_VIEW_RANGE) / COMPASS_TICK_INTERVAL) * COMPASS_TICK_INTERVAL;

	for (let tickHeading = startHeading; tickHeading <= endHeading; tickHeading += COMPASS_TICK_INTERVAL) {
		const delta = getWrappedHeadingDelta(tickHeading, heading);
		if (Math.abs(delta) > COMPASS_VIEW_RANGE) {
			continue;
		}

		const normalizedTickHeading = normalizeHeading(tickHeading);
		const positionPercent = 50 + (delta / COMPASS_VIEW_RANGE) * 50;
		const isCardinal = normalizedTickHeading % COMPASS_CARDINAL_INTERVAL === 0;
		const isMajor = normalizedTickHeading % COMPASS_MAJOR_INTERVAL === 0;

		const tickEl = document.createElement('div');
		tickEl.className = 'hud-compass__tick';
		if (isMajor) {
			tickEl.classList.add('hud-compass__tick--major');
		}
		if (isCardinal) {
			tickEl.classList.add('hud-compass__tick--cardinal');
		}
		tickEl.style.left = `${positionPercent}%`;
		fragment.appendChild(tickEl);

		if (isMajor) {
			const labelEl = document.createElement('div');
			labelEl.className = 'hud-compass__label';
			if (isCardinal) {
				labelEl.classList.add('hud-compass__label--cardinal');
			}
			labelEl.style.left = `${positionPercent}%`;
			labelEl.textContent = DIRECTION_LABELS[normalizedTickHeading] || String(normalizedTickHeading);
			fragment.appendChild(labelEl);
		}
	}

	compassRailEl.replaceChildren(fragment);
}

function renderHud(payload) {
	if (!payload || typeof payload !== 'object') {
		return;
	}

	const showCompass = payload.showCompass === true;
	const showDirection = payload.showDirection === true && Boolean(payload.direction);
	const showHeading = payload.showHeading === true && Boolean(payload.heading);
	const showStreet = payload.showStreet === true && Boolean(payload.street);

	setHidden(compassSectionEl, !showCompass);
	setHidden(directionValueEl, !showDirection);
	setHidden(headingValueEl, !showHeading);
	setHidden(streetValueEl, !showStreet);

	if (showStreet) {
		setText(streetValueEl, payload.street);
	}

	if (showDirection) {
		setText(directionValueEl, payload.direction);
	}

	if (showHeading) {
		setText(headingValueEl, payload.heading);
	}

	setText(xValueEl, payload.x || '0.00');
	setText(yValueEl, payload.y || '0.00');
	setText(zValueEl, payload.z || '0.00');

	if (showCompass) {
		renderCompass(Number(payload.compassHeading));
	}
	else {
		compassRailEl.replaceChildren();
	}
}

window.addEventListener('message', (event) => {
	const message = event.data || {};

	if (message.action === 'visibility') {
		setVisible(message.visible === true);
		return;
	}

	if (message.action === 'hud') {
		renderHud(message.payload || {});
	}
});

setVisible(false);