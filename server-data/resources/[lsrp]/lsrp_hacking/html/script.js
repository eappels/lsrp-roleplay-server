const appEl = document.getElementById('app');
const backdropEl = document.querySelector('.screen-backdrop');
const nodesEl = document.getElementById('nodes');
const timerEl = document.getElementById('timer');
const roundLabelEl = document.getElementById('roundLabel');
const integrityLabelEl = document.getElementById('integrityLabel');
const footerTextEl = document.getElementById('footerText');

const state = {
    visible: false,
    requestId: null,
    rounds: [],
    currentRoundIndex: 0,
    activeNodeIndex: 0,
    deadlineAt: 0,
    timerHandle: null,
    resolved: false
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

function clearTimer() {
    if (state.timerHandle) {
        window.clearInterval(state.timerHandle);
        state.timerHandle = null;
    }
}

function setTransparentRoot() {
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');
    appEl.style.setProperty('background', 'transparent', 'important');
    appEl.style.setProperty('background-color', 'transparent', 'important');

    if (backdropEl) {
        backdropEl.style.setProperty('background', 'transparent', 'important');
        backdropEl.style.setProperty('background-color', 'transparent', 'important');
        backdropEl.style.opacity = '0';
    }
}

function resetState() {
    clearTimer();
    state.visible = false;
    state.requestId = null;
    state.rounds = [];
    state.currentRoundIndex = 0;
    state.activeNodeIndex = 0;
    state.deadlineAt = 0;
    state.resolved = false;

    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';

    appEl.classList.add('hidden');
    appEl.setAttribute('aria-hidden', 'true');
    setTransparentRoot();
    nodesEl.innerHTML = '';
}

function getCurrentRound() {
    return state.rounds[state.currentRoundIndex] || null;
}

function isRoundSolved(round) {
    return round.nodes.every((node) => node.current === node.target);
}

function updateTimer() {
    if (!state.visible) {
        return;
    }

    const remainingMs = Math.max(0, state.deadlineAt - Date.now());
    const totalSeconds = Math.ceil(remainingMs / 1000);
    const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, '0');
    const seconds = String(totalSeconds % 60).padStart(2, '0');

    timerEl.textContent = `${minutes}:${seconds}`;
    integrityLabelEl.textContent = remainingMs <= 10000 ? 'Watchdog alert' : 'Stable';
    footerTextEl.textContent = remainingMs <= 10000
        ? 'The watchdog is closing in. Finish the current stage now.'
        : 'The laptop session will stay open until you finish or the watchdog trips.';

    if (remainingMs <= 0 && !state.resolved) {
        state.resolved = true;
        postNui('hackPuzzleFail', {
            requestId: state.requestId,
            error: 'The watchdog locked the laptop session.'
        });
        resetState();
    }
}

function completePuzzle() {
    if (state.resolved) {
        return;
    }

    state.resolved = true;
    postNui('hackPuzzleComplete', { requestId: state.requestId });
    resetState();
}

function advanceRoundIfSolved() {
    const round = getCurrentRound();
    if (!round || !isRoundSolved(round)) {
        return;
    }

    if (state.currentRoundIndex >= state.rounds.length - 1) {
        completePuzzle();
        return;
    }

    state.currentRoundIndex += 1;
    state.activeNodeIndex = 0;
    render();
}

function adjustNode(delta) {
    const round = getCurrentRound();
    if (!round) {
        return;
    }

    const node = round.nodes[state.activeNodeIndex];
    if (!node) {
        return;
    }

    node.current = (node.current + delta + 10) % 10;
    render();
    advanceRoundIfSolved();
}

function setActiveNode(index) {
    const round = getCurrentRound();
    if (!round) {
        return;
    }

    state.activeNodeIndex = Math.max(0, Math.min(index, round.nodes.length - 1));
    render();
}

function cycleNode(delta) {
    const round = getCurrentRound();
    if (!round) {
        return;
    }

    const nextIndex = (state.activeNodeIndex + delta + round.nodes.length) % round.nodes.length;
    setActiveNode(nextIndex);
}

function render() {
    if (!state.visible) {
        return;
    }

    const round = getCurrentRound();
    if (!round) {
        return;
    }

    roundLabelEl.textContent = `${state.currentRoundIndex + 1} / ${state.rounds.length}`;
    nodesEl.innerHTML = '';

    round.nodes.forEach((node, index) => {
        const card = document.createElement('article');
        card.className = 'node';

        if (index === state.activeNodeIndex) {
            card.classList.add('node--active');
        }

        if (node.current === node.target) {
            card.classList.add('node--solved');
        }

        card.innerHTML = `
            <div class="node__header">
                <span class="node__eyebrow">Node ${index + 1}</span>
                <span class="node__status">${node.current === node.target ? 'Aligned' : 'Live'}</span>
            </div>
            <div class="node__values">
                <div class="node__value-block">
                    <span class="node__value-label">Target</span>
                    <span class="node__value">${node.target}</span>
                </div>
                <div class="node__value-block">
                    <span class="node__value-label">Current</span>
                    <span class="node__value">${node.current}</span>
                </div>
            </div>
            <div class="node__controls">
                <button type="button" data-action="down" aria-label="Decrease node ${index + 1}">-</button>
                <button type="button" data-action="up" aria-label="Increase node ${index + 1}">+</button>
            </div>
        `;

        card.addEventListener('click', () => setActiveNode(index));
        card.querySelector('[data-action="down"]').addEventListener('click', (event) => {
            event.stopPropagation();
            setActiveNode(index);
            adjustNode(-1);
        });
        card.querySelector('[data-action="up"]').addEventListener('click', (event) => {
            event.stopPropagation();
            setActiveNode(index);
            adjustNode(1);
        });

        nodesEl.appendChild(card);
    });
}

function openPuzzle(payload) {
    clearTimer();
    state.visible = true;
    state.requestId = payload.requestId;
    state.rounds = Array.isArray(payload.rounds) ? payload.rounds : [];
    state.currentRoundIndex = 0;
    state.activeNodeIndex = 0;
    state.deadlineAt = Date.now() + (Math.max(10, Number(payload.timeLimitSeconds) || 45) * 1000);
    state.resolved = false;

    document.body.style.display = 'block';
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';

    appEl.classList.remove('hidden');
    appEl.setAttribute('aria-hidden', 'false');
    setTransparentRoot();
    render();
    updateTimer();
    state.timerHandle = window.setInterval(updateTimer, 100);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'showPuzzle') {
        openPuzzle(message.payload || {});
    }
    if (message.action === 'hidePuzzle') {
        resetState();
    }
});

window.addEventListener('keydown', (event) => {
    if (!state.visible) {
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        if (!state.resolved) {
            state.resolved = true;
            postNui('hackPuzzleFail', {
                requestId: state.requestId,
                error: 'You aborted the intrusion.'
            });
        }
        resetState();
        return;
    }

    if (event.key === 'Tab') {
        event.preventDefault();
        cycleNode(event.shiftKey ? -1 : 1);
        return;
    }

    if (event.key === 'ArrowLeft' || event.key === 'a' || event.key === 'A') {
        event.preventDefault();
        adjustNode(-1);
        return;
    }

    if (event.key === 'ArrowRight' || event.key === 'd' || event.key === 'D') {
        event.preventDefault();
        adjustNode(1);
    }
});

resetState();