const resourceName = (typeof window.GetParentResourceName === 'function')
    ? window.GetParentResourceName()
    : 'lsrp_vehicleshop';

// URL template for vehicle thumbnails. Use {model} as the placeholder.
// Default: FiveM docs CDN (covers all GTA base vehicles by model name).
const VEHICLE_IMAGE_URL = 'https://docs.fivem.net/vehicles/{model}.webp';

function getVehicleImageUrl(model) {
    return VEHICLE_IMAGE_URL.replace('{model}', encodeURIComponent(model));
}

const state = {
    open: false,
    shop: null,
    categories: [],
    vehicles: [],
    selectedCategory: 'compact',
    search: '',
    balance: 0,
    formattedBalance: 'LS$0',
    purchasePending: false,
    toastTimer: null
};

const appElement = document.getElementById('app');
const shopNameElement = document.getElementById('shop-name');
const shopSubtitleElement = document.getElementById('shop-subtitle');
const balanceTextElement = document.getElementById('balance-text');
const deliveryZoneElement = document.getElementById('delivery-zone');
const categoryListElement = document.getElementById('category-list');
const vehicleGridElement = document.getElementById('vehicle-grid');
const inventoryMetaElement = document.getElementById('inventory-meta');
const searchInputElement = document.getElementById('search-input');
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
    }, 3600);
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
        console.error(`[lsrp_vehicleshop] Failed NUI POST ${eventName}:`, error);
        return { ok: false, error: 'request_failed' };
    }
}

function updateBalance(balance, formattedBalance) {
    const parsedBalance = Math.max(0, Math.floor(Number(balance) || 0));
    state.balance = parsedBalance;
    state.formattedBalance = (typeof formattedBalance === 'string' && formattedBalance.trim() !== '')
        ? formattedBalance
        : formatFallbackCurrency(parsedBalance);

    balanceTextElement.textContent = state.formattedBalance;
}

function getFilteredVehicles() {
    const activeCategory = state.selectedCategory;
    const query = state.search.trim().toLowerCase();

    return state.vehicles.filter((vehicle) => {
        const categoryMatch = activeCategory === 'all' || vehicle.category === activeCategory;
        if (!categoryMatch) {
            return false;
        }

        if (!query) {
            return true;
        }

        const label = String(vehicle.label || '').toLowerCase();
        const model = String(vehicle.model || '').toLowerCase();
        const categoryLabel = String(vehicle.categoryLabel || '').toLowerCase();

        return label.includes(query) || model.includes(query) || categoryLabel.includes(query);
    });
}

function buildStatRow(name, value) {
    const row = document.createElement('div');
    row.className = 'stat-row';

    const label = document.createElement('span');
    label.className = 'stat-name';
    label.textContent = name;

    const bar = document.createElement('div');
    bar.className = 'stat-bar';

    const fill = document.createElement('div');
    fill.className = 'stat-fill';
    const statValue = Math.max(1, Math.min(10, Number(value) || 1));
    fill.style.width = `${statValue * 10}%`;

    bar.appendChild(fill);
    row.appendChild(label);
    row.appendChild(bar);

    return row;
}

function renderCategories() {
    categoryListElement.innerHTML = '';

    state.categories.forEach((category) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'category-btn';
        button.textContent = category.label;

        if (category.id === state.selectedCategory) {
            button.classList.add('active');
        }

        button.addEventListener('click', () => {
            state.selectedCategory = category.id;
            renderCategories();
            renderVehicles();
        });

        categoryListElement.appendChild(button);
    });
}

function renderVehicles() {
    const filteredVehicles = getFilteredVehicles();
    vehicleGridElement.innerHTML = '';

    inventoryMetaElement.textContent = `${filteredVehicles.length} vehicle${filteredVehicles.length === 1 ? '' : 's'} listed`;

    if (filteredVehicles.length === 0) {
        const emptyState = document.createElement('div');
        emptyState.className = 'empty-state';
        emptyState.textContent = 'No vehicles match the current filter.';
        vehicleGridElement.appendChild(emptyState);
        return;
    }

    filteredVehicles.forEach((vehicle) => {
        const card = document.createElement('article');
        card.className = 'vehicle-card';

        const header = document.createElement('div');
        header.className = 'vehicle-head';

        const titleWrap = document.createElement('div');

        const title = document.createElement('h3');
        title.className = 'vehicle-title';
        title.textContent = vehicle.label || vehicle.model;

        const subtitle = document.createElement('p');
        subtitle.className = 'vehicle-subtitle';
        subtitle.textContent = `${vehicle.categoryLabel || vehicle.category} | ${vehicle.model}`;

        titleWrap.appendChild(title);
        titleWrap.appendChild(subtitle);

        const price = document.createElement('strong');
        price.className = 'vehicle-price';
        price.textContent = vehicle.formattedPrice || formatFallbackCurrency(vehicle.price);

        header.appendChild(titleWrap);
        header.appendChild(price);

        const stats = document.createElement('div');
        stats.className = 'stats';
        stats.appendChild(buildStatRow('Speed', vehicle.speed));
        stats.appendChild(buildStatRow('Accel', vehicle.accel));
        stats.appendChild(buildStatRow('Handling', vehicle.handling));
        stats.appendChild(buildStatRow('Braking', vehicle.braking));

        const buyButton = document.createElement('button');
        buyButton.type = 'button';
        buyButton.className = 'buy-btn';
        buyButton.textContent = `Buy ${vehicle.formattedPrice || formatFallbackCurrency(vehicle.price)}`;
        buyButton.disabled = state.purchasePending;

        buyButton.addEventListener('click', async () => {
            if (state.purchasePending) {
                return;
            }

            state.purchasePending = true;
            renderVehicles();

            const result = await postNui('purchaseVehicle', {
                model: vehicle.model
            });

            if (result && result.ok === false) {
                showToast('Purchase request failed.', 'error');
            }

            window.setTimeout(() => {
                state.purchasePending = false;
                renderVehicles();
            }, 700);
        });

        const thumb = document.createElement('div');
        thumb.className = 'vehicle-thumb';

        const thumbImg = document.createElement('img');
        thumbImg.className = 'vehicle-thumb-img';
        thumbImg.alt = vehicle.label || vehicle.model;
        thumbImg.src = getVehicleImageUrl(vehicle.model);
        thumbImg.addEventListener('error', () => {
            thumb.classList.add('no-img');
        });

        thumb.appendChild(thumbImg);

        card.appendChild(thumb);
        card.appendChild(header);
        card.appendChild(stats);
        card.appendChild(buyButton);

        vehicleGridElement.appendChild(card);
    });
}

function openShop(payload) {
    state.open = true;
    state.shop = payload.shop || null;
    state.categories = Array.isArray(payload.categories) ? payload.categories : [];
    state.vehicles = Array.isArray(payload.vehicles) ? payload.vehicles : [];

    const compactCategory = state.categories.find((category) => category && category.id === 'compact');
    if (compactCategory) {
        state.selectedCategory = 'compact';
    } else if (state.categories.length > 0 && state.categories[0] && state.categories[0].id) {
        state.selectedCategory = String(state.categories[0].id);
    } else {
        state.selectedCategory = '';
    }

    state.search = '';
    searchInputElement.value = '';

    shopNameElement.textContent = (state.shop && state.shop.name) || 'Vehicle Shop';
    shopSubtitleElement.textContent = (state.shop && state.shop.subtitle) || 'Choose your next ride.';
    deliveryZoneElement.textContent = (state.shop && state.shop.deliveryParkingZone) || 'Unknown';

    updateBalance(payload.balance, payload.formattedBalance);

    setAppVisibility(true);
    renderCategories();
    renderVehicles();
}

function closeShopInternal() {
    state.open = false;
    state.shop = null;
    state.categories = [];
    state.vehicles = [];
    state.selectedCategory = 'compact';
    state.search = '';
    state.purchasePending = false;

    setAppVisibility(false);
}

function handlePurchaseResult(result) {
    if (!result || typeof result !== 'object') {
        return;
    }

    if (Object.prototype.hasOwnProperty.call(result, 'balance')) {
        updateBalance(result.balance, result.formattedBalance);
    }

    if (result.message) {
        showToast(result.message, result.ok ? 'success' : 'error');
    }
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') {
        return;
    }

    if (data.action === 'openShop') {
        openShop(data);
    } else if (data.action === 'closeShop') {
        closeShopInternal();
    } else if (data.action === 'updateBalance') {
        updateBalance(data.balance, data.formattedBalance);
    } else if (data.action === 'purchaseResult') {
        handlePurchaseResult(data.result);
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.open) {
        postNui('close');
    }
});

searchInputElement.addEventListener('input', () => {
    state.search = searchInputElement.value || '';
    renderVehicles();
});

closeButtonElement.addEventListener('click', () => {
    postNui('close');
});
