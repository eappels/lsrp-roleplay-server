const resourceName = typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'lsrp_economy';

const app = document.getElementById('bank-app');
const terminalTypeEl = document.getElementById('terminal-type');
const locationLabelEl = document.getElementById('location-label');
const balanceValueEl = document.getElementById('balance-value');
const cashValueEl = document.getElementById('cash-value');
const cashFormEl = document.getElementById('cash-form');
const cashAmountInputEl = document.getElementById('cash-amount');
const depositSubmitEl = document.getElementById('deposit-submit');
const withdrawSubmitEl = document.getElementById('withdraw-submit');
const transferStatusCardEl = document.getElementById('transfer-status');
const transferStatusValueEl = document.getElementById('transfer-status-value');
const accountIdValueEl = document.getElementById('account-id-value');
const transferNoteEl = document.getElementById('transfer-note');
const transferFormEl = document.getElementById('transfer-form');
const targetIdInputEl = document.getElementById('target-id');
const amountInputEl = document.getElementById('transfer-amount');
const transferSubmitEl = document.getElementById('transfer-submit');
const transactionsEmptyEl = document.getElementById('transactions-empty');
const transactionsListEl = document.getElementById('transactions-list');
const toastContainerEl = document.getElementById('toast-container');
const closeButtonEl = document.getElementById('close-button');
const refreshButtonEl = document.getElementById('refresh-button');

const state = {
    open: false,
    allowTransfers: false,
    currencySymbol: 'LS$',
    balance: 0,
    cash: 0,
    accountId: null
};

function setStartupHidden() {
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
}

function normalizeWholeAmount(rawValue) {
    const parsed = Number(rawValue);
    if (!Number.isFinite(parsed)) {
        return null;
    }

    const whole = Math.floor(parsed);
    if (whole <= 0 || whole !== parsed) {
        return null;
    }

    return whole;
}

function normalizeAccountId(rawValue) {
    const parsed = Number(rawValue);
    if (!Number.isFinite(parsed)) {
        return null;
    }

    const whole = Math.floor(parsed);
    if (whole <= 0 || whole !== parsed) {
        return null;
    }

    return whole;
}

function formatCurrency(amount) {
    const value = Number.isFinite(Number(amount))
        ? Math.max(0, Math.floor(Number(amount)))
        : 0;

    return `${state.currencySymbol}${value.toLocaleString('en-US')}`;
}

function prettifyReason(reason) {
    const cleaned = String(reason || 'system').replace(/_/g, ' ').trim();
    if (!cleaned) {
        return 'System';
    }

    return cleaned.replace(/\b\w/g, (char) => char.toUpperCase());
}

function formatTimestamp(rawValue) {
    const text = String(rawValue || '').trim();
    if (!text) {
        return 'Unknown time';
    }

    const normalized = text.includes('T') ? text : text.replace(' ', 'T');
    const parsed = new Date(normalized);

    if (Number.isNaN(parsed.getTime())) {
        return text;
    }

    return parsed.toLocaleString();
}

function showToast(message, level = 'info') {
    const text = String(message || '').trim();
    if (!text) {
        return;
    }

    const toast = document.createElement('div');
    toast.className = `toast ${level}`;
    toast.textContent = text;

    toastContainerEl.appendChild(toast);

    setTimeout(() => {
        toast.remove();
    }, 3200);
}

async function postNui(eventName, payload = {}) {
    const response = await fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        throw new Error(`NUI callback failed: ${eventName} (${response.status})`);
    }

    const raw = await response.text();
    if (!raw) {
        return null;
    }

    try {
        return JSON.parse(raw);
    } catch (_error) {
        return raw;
    }
}

function updateTransferState() {
    transferStatusCardEl.classList.remove('bank-mode', 'atm-mode');

    if (state.allowTransfers) {
        transferStatusCardEl.classList.add('bank-mode');
        transferStatusValueEl.textContent = 'Enabled';
        transferNoteEl.textContent = 'Send LS$ using the recipient account ID. Transfers work even if they are offline.';
    } else {
        transferStatusCardEl.classList.add('atm-mode');
        transferStatusValueEl.textContent = 'Bank Only';
        transferNoteEl.textContent = 'Transfers are disabled at ATMs. Visit a bank counter for wire transfers.';
    }

    targetIdInputEl.disabled = !state.allowTransfers;
    amountInputEl.disabled = !state.allowTransfers;
    transferSubmitEl.disabled = !state.allowTransfers;
}

function setAccountId(accountId) {
    const normalized = normalizeAccountId(accountId);
    state.accountId = normalized;

    if (state.accountId) {
        accountIdValueEl.textContent = `#${state.accountId}`;
    } else {
        accountIdValueEl.textContent = 'Pending...';
    }
}

function setBalance(balance, currencySymbol) {
    if (typeof currencySymbol === 'string' && currencySymbol.trim() !== '') {
        state.currencySymbol = currencySymbol.trim();
    }

    if (balance !== undefined && balance !== null && Number.isFinite(Number(balance))) {
        state.balance = Math.max(0, Math.floor(Number(balance)));
    }

    balanceValueEl.textContent = formatCurrency(state.balance);
}

function setCash(cash, currencySymbol) {
    if (typeof currencySymbol === 'string' && currencySymbol.trim() !== '') {
        state.currencySymbol = currencySymbol.trim();
    }

    if (cash !== undefined && cash !== null && Number.isFinite(Number(cash))) {
        state.cash = Math.max(0, Math.floor(Number(cash)));
    }

    cashValueEl.textContent = formatCurrency(state.cash);
}

function renderTransactions(transactions) {
    transactionsListEl.innerHTML = '';

    if (!Array.isArray(transactions) || transactions.length === 0) {
        transactionsEmptyEl.classList.remove('hidden');
        return;
    }

    transactionsEmptyEl.classList.add('hidden');

    for (const tx of transactions) {
        const delta = Number.isFinite(Number(tx.delta)) ? Math.floor(Number(tx.delta)) : 0;
        const balanceAfter = Number.isFinite(Number(tx.balanceAfter))
            ? Math.max(0, Math.floor(Number(tx.balanceAfter)))
            : 0;

        const row = document.createElement('article');
        row.className = 'transaction-item';

        const left = document.createElement('div');
        left.className = 'transaction-info';

        const reason = document.createElement('div');
        reason.className = 'transaction-reason';
        reason.textContent = prettifyReason(tx.reason);

        const time = document.createElement('div');
        time.className = 'transaction-time';
        time.textContent = formatTimestamp(tx.created_at);

        left.appendChild(reason);
        left.appendChild(time);

        const right = document.createElement('div');
        right.className = 'transaction-amount';

        if (delta > 0) {
            right.classList.add('credit');
            right.textContent = `+ ${formatCurrency(delta)}`;
        } else if (delta < 0) {
            right.classList.add('debit');
            right.textContent = `- ${formatCurrency(Math.abs(delta))}`;
        } else {
            right.textContent = formatCurrency(0);
        }

        row.appendChild(left);
        row.appendChild(right);
        transactionsListEl.appendChild(row);
    }
}

function applyDataPayload(payload) {
    if (!payload || typeof payload !== 'object') {
        return;
    }

    setAccountId(payload.accountId);
    setBalance(payload.balance, payload.currencySymbol);
    setCash(payload.cash, payload.currencySymbol);
    renderTransactions(payload.transactions);
}

function openApp(payload) {
    state.open = true;
    state.allowTransfers = payload && payload.allowTransfers === true;

    terminalTypeEl.textContent = state.allowTransfers ? 'Bank Counter' : 'ATM Terminal';
    locationLabelEl.textContent = payload && payload.locationLabel
        ? String(payload.locationLabel)
        : 'Nearest Terminal';

    setAccountId(payload && payload.accountId);
    updateTransferState();
    setBalance(payload && payload.balance, payload && payload.currencySymbol);
    setCash(payload && payload.cash, payload && payload.currencySymbol);

    transactionsListEl.innerHTML = '';
    transactionsEmptyEl.classList.remove('hidden');

    document.body.style.display = 'block';
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');
    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
}

function closeApp() {
    state.open = false;
    toastContainerEl.innerHTML = '';
    setStartupHidden();
}

async function requestData() {
    try {
        await postNui('requestData');
    } catch (error) {
        console.error('[lsrp_economy] Failed to request data', error);
        showToast('Could not refresh account data.', 'error');
    }
}

async function submitTransfer() {
    if (!state.allowTransfers) {
        showToast('Transfers are disabled at ATMs.', 'error');
        return;
    }

    const targetAccountId = normalizeAccountId(targetIdInputEl.value);
    const amount = normalizeWholeAmount(amountInputEl.value);

    if (!targetAccountId) {
        showToast('Enter a valid account ID.', 'error');
        return;
    }

    if (state.accountId && targetAccountId === state.accountId) {
        showToast('You cannot transfer money to your own account.', 'error');
        return;
    }

    if (!amount) {
        showToast('Enter a positive whole-dollar amount.', 'error');
        return;
    }

    transferSubmitEl.disabled = true;

    try {
        const response = await postNui('transfer', {
            targetAccountId,
            amount
        });

        if (response && typeof response === 'object' && response.ok === false) {
            showToast('Transfer request rejected.', 'error');
            return;
        }

        showToast('Transfer submitted. Waiting for confirmation...', 'info');
        amountInputEl.value = '';
    } catch (error) {
        console.error('[lsrp_economy] Transfer request failed', error);
        showToast('Could not send transfer request.', 'error');
    } finally {
        transferSubmitEl.disabled = !state.allowTransfers;
    }
}

function getCashFormAmount() {
    return normalizeWholeAmount(cashAmountInputEl.value);
}

async function submitDeposit() {
    const amount = getCashFormAmount();
    if (!amount) {
        showToast('Enter a positive whole-dollar amount.', 'error');
        return;
    }

    depositSubmitEl.disabled = true;
    withdrawSubmitEl.disabled = true;

    try {
        const response = await postNui('deposit', { amount });

        if (response && typeof response === 'object' && response.ok === false) {
            showToast('Deposit request rejected.', 'error');
            return;
        }

        showToast('Deposit submitted.', 'info');
        cashAmountInputEl.value = '';
    } catch (error) {
        console.error('[lsrp_economy] Deposit request failed', error);
        showToast('Could not submit deposit request.', 'error');
    } finally {
        depositSubmitEl.disabled = false;
        withdrawSubmitEl.disabled = false;
    }
}

async function submitWithdraw() {
    const amount = getCashFormAmount();
    if (!amount) {
        showToast('Enter a positive whole-dollar amount.', 'error');
        return;
    }

    depositSubmitEl.disabled = true;
    withdrawSubmitEl.disabled = true;

    try {
        const response = await postNui('withdraw', { amount });

        if (response && typeof response === 'object' && response.ok === false) {
            showToast('Retrieve request rejected.', 'error');
            return;
        }

        showToast('Retrieve submitted.', 'info');
        cashAmountInputEl.value = '';
    } catch (error) {
        console.error('[lsrp_economy] Retrieve request failed', error);
        showToast('Could not submit retrieve request.', 'error');
    } finally {
        depositSubmitEl.disabled = false;
        withdrawSubmitEl.disabled = false;
    }
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') {
        return;
    }

    switch (data.action) {
        case 'open':
            openApp(data);
            break;
        case 'close':
            closeApp();
            break;
        case 'setBalance':
            setBalance(data.balance, data.currencySymbol);
            break;
        case 'setCash':
            setCash(data.cash, data.currencySymbol);
            break;
        case 'setData':
            applyDataPayload(data);
            break;
        case 'toast':
            showToast(data.message, data.level || 'info');
            break;
        default:
            break;
    }
});

transferFormEl.addEventListener('submit', (event) => {
    event.preventDefault();
    submitTransfer();
});

cashFormEl.addEventListener('submit', (event) => {
    event.preventDefault();
    submitDeposit();
});

withdrawSubmitEl.addEventListener('click', () => {
    submitWithdraw();
});

closeButtonEl.addEventListener('click', () => {
    postNui('close').catch((error) => {
        console.error('[lsrp_economy] Failed to close NUI', error);
    });
});

refreshButtonEl.addEventListener('click', () => {
    requestData();
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.open) {
        postNui('close').catch((error) => {
            console.error('[lsrp_economy] Failed to close NUI', error);
        });
    }
});

setStartupHidden();
