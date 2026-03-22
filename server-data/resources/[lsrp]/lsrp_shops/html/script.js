const resourceName = (typeof window.GetParentResourceName === 'function')
    ? window.GetParentResourceName()
    : 'lsrp_shops';

const state = {
    open: false,
    shop: null,
    items: [],
    quantities: {},
    balance: 0,
    formattedBalance: 'LS$0',
    purchasePending: false,
    toastTimer: null
};

const appElement = document.getElementById('app');
const catalogLabelElement = document.getElementById('catalog-label');
const shopNameElement = document.getElementById('shop-name');
const shopSubtitleElement = document.getElementById('shop-subtitle');
const balanceTextElement = document.getElementById('balance-text');
const itemGridElement = document.getElementById('item-grid');
const closeButtonElement = document.getElementById('close-btn');
const toastElement = document.getElementById('toast');

function formatFallbackCurrency(value) {
    const amount = Math.max(0, Math.floor(Number(value) || 0));
    return `LS$${amount.toLocaleString('en-US')}`;
}

function setAppVisibility(visible) {
    appElement.classList.toggle('hidden', !visible);
}

function showToast(message, kind = 'info') {
    if (!message) {
        return;
    }

    toastElement.textContent = String(message);
    toastElement.classList.remove('hidden', 'success', 'error');

    if (kind === 'success') {
        toastElement.classList.add('success');
    } else if (kind === 'error') {
        toastElement.classList.add('error');
    }

    if (state.toastTimer) {
        window.clearTimeout(state.toastTimer);
    }

    state.toastTimer = window.setTimeout(() => {
        toastElement.classList.add('hidden');
    }, 3200);
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
    } catch (error) {
        console.error(`[lsrp_shops] Failed NUI POST ${eventName}:`, error);
        return { ok: false, error: 'request_failed' };
    }
}

function setBalance(balance, formattedBalance) {
    state.balance = Math.max(0, Math.floor(Number(balance) || 0));
    state.formattedBalance = (typeof formattedBalance === 'string' && formattedBalance.trim() !== '')
        ? formattedBalance
        : formatFallbackCurrency(state.balance);
    balanceTextElement.textContent = state.formattedBalance;
}

function getQuantity(itemName, maxQuantity) {
    const current = Math.max(1, Math.floor(Number(state.quantities[itemName]) || 1));
    return Math.min(Math.max(1, current), Math.max(1, Math.floor(Number(maxQuantity) || 1)));
}

function setQuantity(itemName, maxQuantity, nextValue) {
    const clamped = Math.min(Math.max(1, Math.floor(Number(nextValue) || 1)), Math.max(1, Math.floor(Number(maxQuantity) || 1)));
    state.quantities[itemName] = clamped;
    renderItems();
}

async function handleClose() {
    state.purchasePending = false;
    await postNui('close');
}

async function handlePurchase(item) {
    if (!item || state.purchasePending) {
        return;
    }

    const quantity = getQuantity(item.name, item.maxQuantity);
    state.purchasePending = true;
    renderItems();

    const result = await postNui('purchase', {
        itemName: item.name,
        quantity
    });

    if (!result || result.ok !== true) {
        state.purchasePending = false;
        renderItems();
        showToast('Purchase request failed.', 'error');
    }
}

function buildEmptyState(message) {
    const container = document.createElement('div');
    container.className = 'empty-state';
    container.textContent = message;
    return container;
}

function renderItems() {
    itemGridElement.innerHTML = '';

    if (!state.items.length) {
        itemGridElement.appendChild(buildEmptyState('No items are configured for this store.'));
        return;
    }

    state.items.forEach((item) => {
        const card = document.createElement('article');
        card.className = 'item-card';

        const head = document.createElement('div');
        head.className = 'item-head';

        const titleWrap = document.createElement('div');
        const title = document.createElement('h2');
        title.className = 'item-title';
        title.textContent = item.label;

        const meta = document.createElement('div');
        meta.className = 'item-meta';
        meta.textContent = `Max ${item.maxQuantity} per purchase`;

        titleWrap.appendChild(title);
        titleWrap.appendChild(meta);

        const price = document.createElement('div');
        price.className = 'item-price';
        price.textContent = item.formattedPrice;

        head.appendChild(titleWrap);
        head.appendChild(price);

        const description = document.createElement('p');
        description.className = 'item-description';
        description.textContent = item.description;

        const actions = document.createElement('div');
        actions.className = 'item-actions';

        const quantityPicker = document.createElement('div');
        quantityPicker.className = 'quantity-picker';

        const subtractButton = document.createElement('button');
        subtractButton.type = 'button';
        subtractButton.className = 'quantity-btn';
        subtractButton.textContent = '-';
        subtractButton.disabled = state.purchasePending;
        subtractButton.addEventListener('click', () => {
            setQuantity(item.name, item.maxQuantity, getQuantity(item.name, item.maxQuantity) - 1);
        });

        const quantityValue = document.createElement('span');
        quantityValue.className = 'quantity-value';
        quantityValue.textContent = String(getQuantity(item.name, item.maxQuantity));

        const addButton = document.createElement('button');
        addButton.type = 'button';
        addButton.className = 'quantity-btn';
        addButton.textContent = '+';
        addButton.disabled = state.purchasePending;
        addButton.addEventListener('click', () => {
            setQuantity(item.name, item.maxQuantity, getQuantity(item.name, item.maxQuantity) + 1);
        });

        quantityPicker.appendChild(subtractButton);
        quantityPicker.appendChild(quantityValue);
        quantityPicker.appendChild(addButton);

        const buyButton = document.createElement('button');
        buyButton.type = 'button';
        buyButton.className = 'buy-btn';
        buyButton.disabled = state.purchasePending;
        buyButton.textContent = state.purchasePending
            ? 'Processing...'
            : `Buy ${formatFallbackCurrency((Number(item.price) || 0) * getQuantity(item.name, item.maxQuantity))}`;
        buyButton.addEventListener('click', () => {
            handlePurchase(item);
        });

        actions.appendChild(quantityPicker);
        actions.appendChild(buyButton);

        card.appendChild(head);
        card.appendChild(description);
        card.appendChild(actions);
        itemGridElement.appendChild(card);
    });
}

function openShop(payload = {}) {
    state.open = true;
    state.shop = payload.shop || null;
    state.items = Array.isArray(payload.items) ? payload.items : [];
    state.purchasePending = false;
    state.quantities = {};

    catalogLabelElement.textContent = payload.shop?.catalogLabel || 'Store Items';
    shopNameElement.textContent = payload.shop?.name || 'Convenience Store';
    shopSubtitleElement.textContent = payload.shop?.subtitle || 'Quick essentials.';
    setBalance(payload.balance, payload.formattedBalance);
    renderItems();
    setAppVisibility(true);
}

function closeShop() {
    state.open = false;
    state.shop = null;
    state.items = [];
    state.quantities = {};
    state.purchasePending = false;
    itemGridElement.innerHTML = '';
    setAppVisibility(false);
}

window.addEventListener('message', (event) => {
    const payload = event.data || {};

    switch (payload.action) {
        case 'openShop':
            openShop(payload);
            break;
        case 'closeShop':
            closeShop();
            break;
        case 'updateBalance':
            setBalance(payload.balance, payload.formattedBalance);
            break;
        case 'purchaseResult':
            state.purchasePending = false;
            renderItems();
            showToast(payload.message || 'Purchase updated.', payload.success ? 'success' : 'error');
            break;
        default:
            break;
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.open) {
        event.preventDefault();
        handleClose();
    }
});

closeButtonElement.addEventListener('click', () => {
    handleClose();
});