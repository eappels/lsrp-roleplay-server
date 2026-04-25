const resourceName = (typeof window.GetParentResourceName === 'function')
    ? window.GetParentResourceName()
    : 'lsrp_vehicleshop';

// URL template for vehicle thumbnails. Use {model} as the placeholder.
// Default: FiveM docs CDN (covers all GTA base vehicles by model name).
const VEHICLE_IMAGE_URL = 'https://docs.fivem.net/vehicles/{model}.webp';
const VEHICLES_PER_PAGE = 6;

function getVehicleImageUrl(model) {
    const normalizedModel = String(model || '').trim().toLowerCase();
    return VEHICLE_IMAGE_URL.replace('{model}', encodeURIComponent(normalizedModel));
}

const state = {
    open: false,
    shop: null,
    categories: [],
    vehicles: [],
    selectedCategory: 'compact',
    search: '',
    currentPage: 1,
    balance: 0,
    formattedBalance: 'LS$0',
    canAdminCustomPurchase: false,
    adminCustomUnlistedPrice: 0,
    formattedAdminCustomUnlistedPrice: 'LS$0',
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
const paginationBarElement = document.getElementById('pagination-bar');
const paginationMetaElement = document.getElementById('pagination-meta');
const paginationPrevElement = document.getElementById('pagination-prev');
const paginationNextElement = document.getElementById('pagination-next');
const adminQuickBuyElement = document.getElementById('admin-quick-buy');
const adminPurchaseFormElement = document.getElementById('admin-purchase-form');
const adminModelInputElement = document.getElementById('admin-model-input');
const adminBuyButtonElement = document.getElementById('admin-buy-btn');
const adminQuickBuyHintElement = document.getElementById('admin-quick-buy-hint');
const closeButtonElement = document.getElementById('close-btn');
const toastElement = document.getElementById('toast');

function setShopHidden() {
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');

    appElement.classList.add('hidden');
    appElement.setAttribute('aria-hidden', 'true');
}

function showShopShell() {
    document.body.style.display = 'block';
    document.body.style.visibility = 'visible';
    document.body.style.opacity = '1';
    document.body.style.setProperty('background', 'transparent', 'important');
    document.body.style.setProperty('background-color', 'transparent', 'important');

    appElement.classList.remove('hidden');
    appElement.setAttribute('aria-hidden', 'false');
}

function formatFallbackCurrency(value) {
    const amount = Math.max(0, Math.floor(Number(value) || 0));
    return `LS$${amount.toLocaleString('en-US')}`;
}

function setAppVisibility(visible) {
    if (visible) {
        showShopShell();
        return;
    }

    setShopHidden();
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

function normalizeModelInput(value) {
    return String(value || '').trim().toLowerCase().replace(/\s+/g, '');
}

function getPurchaseRequestErrorMessage(errorCode) {
    switch (String(errorCode || '')) {
        case 'admin_forbidden':
            return 'You do not have permission to use admin quick buy.';
        case 'invalid_model':
        case 'invalid_vehicle':
            return 'Enter a valid vehicle model.';
        case 'shop_not_open':
            return 'The vehicle shop is not open.';
        default:
            return 'Purchase request failed.';
    }
}

function updateAdminState(payload = {}) {
    state.canAdminCustomPurchase = payload.canAdminCustomPurchase === true;
    state.adminCustomUnlistedPrice = Math.max(0, Math.floor(Number(payload.adminCustomUnlistedPrice) || 0));
    state.formattedAdminCustomUnlistedPrice = (typeof payload.formattedAdminCustomUnlistedPrice === 'string' && payload.formattedAdminCustomUnlistedPrice.trim() !== '')
        ? payload.formattedAdminCustomUnlistedPrice
        : formatFallbackCurrency(state.adminCustomUnlistedPrice);

    renderAdminQuickBuy();
}

function renderAdminQuickBuy() {
    adminQuickBuyElement.classList.toggle('hidden', !state.canAdminCustomPurchase);
    adminBuyButtonElement.disabled = state.purchasePending;
    adminModelInputElement.disabled = state.purchasePending;
    adminQuickBuyHintElement.textContent = `Configured vehicles use their catalog price. Unlisted vehicles use ${state.formattedAdminCustomUnlistedPrice}.`;
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

function getPaginationState(totalItems) {
    const safeTotalItems = Math.max(0, Math.floor(Number(totalItems) || 0));
    const totalPages = Math.max(1, Math.ceil(safeTotalItems / VEHICLES_PER_PAGE));
    state.currentPage = Math.max(1, Math.min(totalPages, Math.floor(Number(state.currentPage) || 1)));

    return {
        totalItems: safeTotalItems,
        totalPages,
        currentPage: state.currentPage,
        startIndex: (state.currentPage - 1) * VEHICLES_PER_PAGE,
        endIndex: state.currentPage * VEHICLES_PER_PAGE
    };
}

function renderPagination(pagination) {
    const totalPages = pagination && pagination.totalPages ? pagination.totalPages : 1;
    const currentPage = pagination && pagination.currentPage ? pagination.currentPage : 1;
    const shouldShow = (pagination && pagination.totalItems > VEHICLES_PER_PAGE) === true;

    paginationBarElement.classList.toggle('hidden', !shouldShow);
    paginationMetaElement.textContent = `Page ${currentPage} of ${totalPages}`;
    paginationPrevElement.disabled = currentPage <= 1;
    paginationNextElement.disabled = currentPage >= totalPages;
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
            state.currentPage = 1;
            renderCategories();
            renderVehicles();
        });

        categoryListElement.appendChild(button);
    });
}

function renderVehicles() {
    const filteredVehicles = getFilteredVehicles();
    const pagination = getPaginationState(filteredVehicles.length);
    const pagedVehicles = filteredVehicles.slice(pagination.startIndex, pagination.endIndex);
    vehicleGridElement.innerHTML = '';

    inventoryMetaElement.textContent = `${filteredVehicles.length} vehicle${filteredVehicles.length === 1 ? '' : 's'} listed`;
    renderPagination(pagination);

    if (filteredVehicles.length === 0) {
        const emptyState = document.createElement('div');
        emptyState.className = 'empty-state';
        emptyState.textContent = 'No vehicles match the current filter.';
        vehicleGridElement.appendChild(emptyState);
        return;
    }

    pagedVehicles.forEach((vehicle) => {
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
            renderAdminQuickBuy();

            const result = await postNui('purchaseVehicle', {
                model: vehicle.model
            });

            if (result && result.ok === false) {
                showToast(getPurchaseRequestErrorMessage(result.error), 'error');
            }

            window.setTimeout(() => {
                state.purchasePending = false;
                renderVehicles();
                renderAdminQuickBuy();
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
    state.currentPage = 1;
    searchInputElement.value = '';
    adminModelInputElement.value = '';

    shopNameElement.textContent = (state.shop && state.shop.name) || 'Vehicle Shop';
    shopSubtitleElement.textContent = (state.shop && state.shop.subtitle) || 'Choose your next ride.';
    deliveryZoneElement.textContent = (state.shop && state.shop.deliveryParkingZone) || 'Unknown';

    updateBalance(payload.balance, payload.formattedBalance);
    updateAdminState(payload);

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
    state.currentPage = 1;
    state.purchasePending = false;
    state.canAdminCustomPurchase = false;
    state.adminCustomUnlistedPrice = 0;
    state.formattedAdminCustomUnlistedPrice = 'LS$0';

    adminModelInputElement.value = '';
    renderAdminQuickBuy();

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
    } else if (data.action === 'setAdminState') {
        updateAdminState(data);
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
    state.currentPage = 1;
    renderVehicles();
});

paginationPrevElement.addEventListener('click', () => {
    if (state.currentPage <= 1) {
        return;
    }

    state.currentPage -= 1;
    renderVehicles();
});

paginationNextElement.addEventListener('click', () => {
    state.currentPage += 1;
    renderVehicles();
});

adminPurchaseFormElement.addEventListener('submit', async (event) => {
    event.preventDefault();

    if (!state.open || !state.canAdminCustomPurchase || state.purchasePending) {
        return;
    }

    const model = normalizeModelInput(adminModelInputElement.value);
    if (!model) {
        showToast('Enter a vehicle model.', 'error');
        return;
    }

    state.purchasePending = true;
    renderVehicles();
    renderAdminQuickBuy();

    const result = await postNui('purchaseCustomVehicle', {
        model
    });

    if (result && result.ok === false) {
        showToast(getPurchaseRequestErrorMessage(result.error), 'error');
    }

    window.setTimeout(() => {
        state.purchasePending = false;
        renderVehicles();
        renderAdminQuickBuy();
    }, 700);
});

closeButtonElement.addEventListener('click', () => {
    postNui('close');
});

setShopHidden();
