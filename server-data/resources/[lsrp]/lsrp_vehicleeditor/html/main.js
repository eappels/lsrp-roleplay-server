window.addEventListener('DOMContentLoaded', () => {
    document.body.style.visibility = 'hidden';

    function reportError(info) {
        try {
            fetch(`https://${GetParentResourceName()}/nuiError`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(info || {})
            });
        } catch (e) {
            console.error('Failed to report NUI error', e);
        }
    }

    window.onerror = function(message, source, lineno, colno, error) {
        reportError({
            type: 'error',
            message: String(message),
            source,
            lineno,
            colno,
            stack: error && error.stack
        });
    };

    window.addEventListener('unhandledrejection', (ev) => {
        reportError({
            type: 'unhandledrejection',
            message: String(ev.reason && (ev.reason.message || ev.reason)),
            stack: ev.reason && ev.reason.stack
        });
    });

    const app = document.getElementById('app');
    const vehicleName = document.getElementById('vehicle-name');
    const modList = document.getElementById('mod-list');
    const detailTitle = document.getElementById('detail-title');

    const modIndex = document.getElementById('mod-index');
    const modVariation = document.getElementById('mod-variation');
    const decIndex = document.getElementById('dec-index');
    const incIndex = document.getElementById('inc-index');
    const applyModBtn = document.getElementById('apply-mod-btn');

    const toggleTurbo = document.getElementById('toggle-turbo');
    const toggleTyresmoke = document.getElementById('toggle-tyresmoke');
    const toggleXenon = document.getElementById('toggle-xenon');

    const primaryColor = document.getElementById('primary-color');
    const secondaryColor = document.getElementById('secondary-color');
    const pearlescentColor = document.getElementById('pearlescent-color');
    const wheelColor = document.getElementById('wheel-color');
    const wheelType = document.getElementById('wheel-type');
    const windowTint = document.getElementById('window-tint');
    const xenonColor = document.getElementById('xenon-color');

    const tyreSmokeR = document.getElementById('tyresmoke-r');
    const tyreSmokeG = document.getElementById('tyresmoke-g');
    const tyreSmokeB = document.getElementById('tyresmoke-b');

    const neonR = document.getElementById('neon-r');
    const neonG = document.getElementById('neon-g');
    const neonB = document.getElementById('neon-b');

    const neon0 = document.getElementById('neon-0');
    const neon1 = document.getElementById('neon-1');
    const neon2 = document.getElementById('neon-2');
    const neon3 = document.getElementById('neon-3');

    const applyColorsBtn = document.getElementById('apply-colors-btn');
    const refreshBtn = document.getElementById('refresh-btn');
    const revertBtn = document.getElementById('revert-btn');
    const closeBtn = document.getElementById('close-nui');

    let vehicleState = null;
    let modTypes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 23, 24, 48];
    let modLabels = {};
    let selectedModType = null;
    const DEFAULT_POST_TIMEOUT_MS = 8000;
    const CAMERA_KEYS = ['w', 'a', 's', 'd', 'q', 'e'];
    const MOD_APPLY_DEBOUNCE_MS = 120;
    const COLOR_APPLY_DEBOUNCE_MS = 120;

    let modApplyTimer = null;
    let colorApplyTimer = null;

    function toInt(value, fallback) {
        const parsed = Number.parseInt(value, 10);
        return Number.isNaN(parsed) ? fallback : parsed;
    }

    function clamp(value, min, max) {
        const n = toInt(value, min);
        return Math.min(max, Math.max(min, n));
    }

    function getModData(modType) {
        if (!vehicleState || !vehicleState.mods) return null;
        return vehicleState.mods[modType] || vehicleState.mods[String(modType)] || null;
    }

    function getToggleMod(modType) {
        if (!vehicleState || !vehicleState.toggleMods) return false;
        return vehicleState.toggleMods[modType] === true || vehicleState.toggleMods[String(modType)] === true;
    }

    async function post(endpoint, payload, timeoutMs) {
        const timeout = Number.isFinite(timeoutMs) ? timeoutMs : DEFAULT_POST_TIMEOUT_MS;

        try {
            const response = await Promise.race([
                fetch(`https://${GetParentResourceName()}/${endpoint}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload || {})
                }),
                new Promise((_, reject) => {
                    setTimeout(() => reject(new Error('request_timeout')), timeout);
                })
            ]);

            if (!response) {
                return { ok: false, error: 'no_response' };
            }

            try {
                return await response.json();
            } catch (e) {
                return { ok: false, error: 'invalid_json' };
            }
        } catch (e) {
            console.error(`[vehicleeditor] ${endpoint} failed`, e);
            return { ok: false, error: 'request_failed' };
        }
    }

    function sendCameraKey(key, down) {
        post('cameraKey', { key, down: down === true });
    }

    function bindValueSteppers() {
        const stepperButtons = document.querySelectorAll('.value-stepper .stepper-btn[data-dir]');

        stepperButtons.forEach((button) => {
            button.addEventListener('click', (event) => {
                event.preventDefault();

                const stepper = button.closest('.value-stepper');
                const input = stepper && stepper.querySelector('input[type="number"]');
                if (!stepper || !input) return;

                const direction = toInt(button.getAttribute('data-dir'), 0);
                if (!direction) return;

                const step = toInt(stepper.getAttribute('data-step') || input.step || 1, 1);
                const currentValue = toInt(input.value, toInt(input.min, 0));
                const min = input.min !== '' ? Number(input.min) : Number.NEGATIVE_INFINITY;
                const max = input.max !== '' ? Number(input.max) : Number.POSITIVE_INFINITY;

                let nextValue = currentValue + (direction * step);
                if (Number.isFinite(min)) nextValue = Math.max(min, nextValue);
                if (Number.isFinite(max)) nextValue = Math.min(max, nextValue);

                input.value = String(toInt(nextValue, currentValue));
                input.dispatchEvent(new Event('change', { bubbles: true }));
            });
        });
    }

    function releaseCameraKeys() {
        CAMERA_KEYS.forEach((key) => sendCameraKey(key, false));
    }

    function isEditableElement(element) {
        if (!element || !(element instanceof HTMLElement)) {
            return false;
        }

        if (element.isContentEditable) {
            return true;
        }

        const tag = element.tagName;
        return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
    }

    function shouldHandleCameraKeys(eventTarget) {
        if (app.style.display !== 'block') {
            return false;
        }

        if (isEditableElement(eventTarget) || isEditableElement(document.activeElement)) {
            return false;
        }

        return true;
    }

    function renderModList() {
        if (!vehicleState || !vehicleState.mods) {
            modList.innerHTML = '';
            return;
        }

        let html = '';
        modTypes.forEach((modType) => {
            const mod = getModData(modType) || { index: -1, count: 0, variation: false };
            const label = modLabels[modType] || modLabels[String(modType)] || `Mod ${modType}`;
            const index = toInt(mod.index, -1);
            const count = Math.max(0, toInt(mod.count, 0));

            html += `
                <div class="mod-row ${selectedModType === modType ? 'active' : ''}" data-mod="${modType}">
                    <div>
                        <div class="mod-label">${label}</div>
                        <div class="mod-sub">Index: ${index} / ${Math.max(0, count - 1)}</div>
                    </div>
                    <div class="mod-sub">Type ${modType}</div>
                </div>
            `;
        });

        modList.innerHTML = html;
    }

    function selectMod(modType) {
        selectedModType = modType;
        const label = modLabels[modType] || modLabels[String(modType)] || `Mod ${modType}`;
        detailTitle.textContent = `${label} (${modType})`;

        const mod = getModData(modType) || { index: -1, variation: false };
        modIndex.value = toInt(mod.index, -1);
        modVariation.checked = mod.variation === true;

        renderModList();
    }

    function syncToggleInputs() {
        toggleTurbo.checked = getToggleMod(18);
        toggleTyresmoke.checked = getToggleMod(20);
        toggleXenon.checked = getToggleMod(22);
    }

    function syncColorInputs() {
        const colors = (vehicleState && vehicleState.colors) || {};
        const tyreSmoke = colors.tyreSmoke || {};
        const neon = colors.neon || {};
        const neonEnabled = colors.neonEnabled || {};

        primaryColor.value = toInt(colors.primary, 0);
        secondaryColor.value = toInt(colors.secondary, 0);
        pearlescentColor.value = toInt(colors.pearlescent, 0);
        wheelColor.value = toInt(colors.wheel, 0);
        wheelType.value = toInt(colors.wheelType, 0);
        windowTint.value = toInt(colors.windowTint, -1);
        xenonColor.value = toInt(colors.xenonColor, -1);

        tyreSmokeR.value = clamp(tyreSmoke.r, 0, 255);
        tyreSmokeG.value = clamp(tyreSmoke.g, 0, 255);
        tyreSmokeB.value = clamp(tyreSmoke.b, 0, 255);

        neonR.value = clamp(neon.r, 0, 255);
        neonG.value = clamp(neon.g, 0, 255);
        neonB.value = clamp(neon.b, 0, 255);

        const hasLegacyZeroBased = neonEnabled[0] !== undefined || neonEnabled['0'] !== undefined;
        const isNeonSideEnabled = (sideKey, legacyIndex) => {
            if (neonEnabled[sideKey] === true) {
                return true;
            }

            if (neonEnabled[legacyIndex] === true || neonEnabled[String(legacyIndex)] === true) {
                return true;
            }

            if (!hasLegacyZeroBased) {
                const shifted = legacyIndex + 1;
                if (neonEnabled[shifted] === true || neonEnabled[String(shifted)] === true) {
                    return true;
                }
            }

            return false;
        };

        neon0.checked = isNeonSideEnabled('left', 0);
        neon1.checked = isNeonSideEnabled('right', 1);
        neon2.checked = isNeonSideEnabled('front', 2);
        neon3.checked = isNeonSideEnabled('back', 3);
    }



    async function refreshVehicleState() {
        const response = await post('getVehicleState', {});
        if (!response || response.ok !== true || !response.state) {
            vehicleState = null;
            vehicleName.textContent = 'Enter a vehicle as driver to edit setup';
            modList.innerHTML = '';
            return false;
        }

        vehicleState = response.state;
        modLabels = response.modLabels || modLabels;

        if (Array.isArray(response.modTypes) && response.modTypes.length > 0) {
            modTypes = response.modTypes.slice();
        }

        vehicleName.textContent = vehicleState.displayName || 'Vehicle';

        if (selectedModType === null || !modTypes.includes(selectedModType)) {
            selectedModType = modTypes[0] || 0;
        }

        renderModList();
        selectMod(selectedModType);
        syncToggleInputs();
        syncColorInputs();
        return true;
    }

    async function applySelectedMod() {
        if (selectedModType === null) return;

        const payload = {
            modType: selectedModType,
            index: toInt(modIndex.value, -1),
            variation: modVariation.checked === true
        };

        const response = await post('applyMod', payload);
        if (response && response.ok && response.state) {
            vehicleState = response.state;
            renderModList();
            selectMod(selectedModType);
            return;
        }

        await refreshVehicleState();
    }

    function scheduleApplySelectedMod() {
        if (modApplyTimer) {
            clearTimeout(modApplyTimer);
        }

        modApplyTimer = setTimeout(() => {
            modApplyTimer = null;
            applySelectedMod();
        }, MOD_APPLY_DEBOUNCE_MS);
    }

    async function applyToggle(modType, enabled) {
        const response = await post('applyToggleMod', { modType, enabled: enabled === true });
        if (response && response.ok && response.state) {
            vehicleState = response.state;
            syncToggleInputs();
            return;
        }

        await refreshVehicleState();
    }

    async function applyColorBlock() {
        const neonEnabledState = {
            left: neon0.checked === true,
            right: neon1.checked === true,
            front: neon2.checked === true,
            back: neon3.checked === true
        };

        const payload = {
            colors: {
                primary: clamp(primaryColor.value, 0, 255),
                secondary: clamp(secondaryColor.value, 0, 255),
                pearlescent: clamp(pearlescentColor.value, 0, 255),
                wheel: clamp(wheelColor.value, 0, 255),
                wheelType: clamp(wheelType.value, 0, 12),
                windowTint: clamp(windowTint.value, -1, 6),
                xenonColor: clamp(xenonColor.value, -1, 13),
                tyreSmoke: {
                    r: clamp(tyreSmokeR.value, 0, 255),
                    g: clamp(tyreSmokeG.value, 0, 255),
                    b: clamp(tyreSmokeB.value, 0, 255)
                },
                neon: {
                    r: clamp(neonR.value, 0, 255),
                    g: clamp(neonG.value, 0, 255),
                    b: clamp(neonB.value, 0, 255)
                },
                neonEnabled: {
                    left: neonEnabledState.left,
                    right: neonEnabledState.right,
                    front: neonEnabledState.front,
                    back: neonEnabledState.back
                }
            }
        };

        const response = await post('applyColorData', payload);
        if (response && response.ok && response.state) {
            vehicleState = response.state;
            syncColorInputs();
            syncToggleInputs();
            return;
        }

        await refreshVehicleState();
    }

    function scheduleApplyColorBlock() {
        if (colorApplyTimer) {
            clearTimeout(colorApplyTimer);
        }

        colorApplyTimer = setTimeout(() => {
            colorApplyTimer = null;
            applyColorBlock();
        }, COLOR_APPLY_DEBOUNCE_MS);
    }

    modList.addEventListener('click', (ev) => {
        const row = ev.target.closest('.mod-row');
        if (!row) return;

        const modType = toInt(row.getAttribute('data-mod'), null);
        if (modType === null) return;

        selectMod(modType);
    });

    decIndex.addEventListener('click', async () => {
        modIndex.value = toInt(modIndex.value, -1) - 1;
        await applySelectedMod();
    });

    incIndex.addEventListener('click', async () => {
        modIndex.value = toInt(modIndex.value, -1) + 1;
        await applySelectedMod();
    });

    applyModBtn.addEventListener('click', applySelectedMod);
    modIndex.addEventListener('input', scheduleApplySelectedMod);
    modIndex.addEventListener('change', scheduleApplySelectedMod);
    modVariation.addEventListener('change', applySelectedMod);

    toggleTurbo.addEventListener('change', () => applyToggle(18, toggleTurbo.checked));
    toggleTyresmoke.addEventListener('change', () => applyToggle(20, toggleTyresmoke.checked));
    toggleXenon.addEventListener('change', () => applyToggle(22, toggleXenon.checked));

    applyColorsBtn.addEventListener('click', applyColorBlock);

    const liveColorInputs = [
        primaryColor,
        secondaryColor,
        pearlescentColor,
        wheelColor,
        wheelType,
        windowTint,
        xenonColor,
        tyreSmokeR,
        tyreSmokeG,
        tyreSmokeB,
        neonR,
        neonG,
        neonB
    ];

    liveColorInputs.forEach((input) => {
        if (!input) return;
        input.addEventListener('input', scheduleApplyColorBlock);
        input.addEventListener('change', scheduleApplyColorBlock);
    });

    [neon0, neon1, neon2, neon3].forEach((checkbox) => {
        if (!checkbox) return;
        checkbox.addEventListener('change', scheduleApplyColorBlock);
    });

    revertBtn.addEventListener('click', async () => {
        const response = await post('revertVehicle', {});
        if (response && response.ok && response.state) {
            vehicleState = response.state;
            await refreshVehicleState();
            return;
        }

        await refreshVehicleState();
    });

    refreshBtn.addEventListener('click', async () => {
        await refreshVehicleState();
    });

    closeBtn.addEventListener('click', () => {
        post('closeNUI', {});
    });



    window.addEventListener('message', async (event) => {
        if (!event || !event.data) return;

        if (event.data.type === 'show') {
            app.style.display = 'block';
            document.body.style.visibility = 'visible';
            await refreshVehicleState();
            return;
        }

        if (event.data.type === 'hide') {
            releaseCameraKeys();
            app.style.display = 'none';
            document.body.style.visibility = 'hidden';
        }
    });

    const keyMap = { w: 'w', W: 'w', a: 'a', A: 'a', s: 's', S: 's', d: 'd', D: 'd', q: 'q', Q: 'q', e: 'e', E: 'e' };

    window.addEventListener('keydown', (ev) => {
        const mapped = keyMap[ev.key];
        if (!mapped) return;

        if (!shouldHandleCameraKeys(ev.target)) {
            sendCameraKey(mapped, false);
            return;
        }

        if (ev.repeat) {
            ev.preventDefault();
            return;
        }

        ev.preventDefault();
        sendCameraKey(mapped, true);
    });

    window.addEventListener('keyup', (ev) => {
        const mapped = keyMap[ev.key];
        if (!mapped) return;

        if (!shouldHandleCameraKeys(ev.target)) {
            sendCameraKey(mapped, false);
            return;
        }

        ev.preventDefault();
        sendCameraKey(mapped, false);
    });

    bindValueSteppers();
});
