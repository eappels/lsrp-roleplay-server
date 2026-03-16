let currentZone = null;
let maxSlots = 0;
let canStoreVehicle = true;
const resourceName = (typeof window.GetParentResourceName === 'function')
    ? window.GetParentResourceName()
    : 'lsrp_vehicleparking';
const storeButtonElement = document.querySelector('.store-btn');

async function postNui(eventName, payload = {}) {
    try {
        const response = await fetch(`https://${resourceName}/${eventName}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            console.error(`[lsrp_vehicleparking] NUI callback failed: ${eventName} (${response.status})`);
        }
    } catch (error) {
        console.error(`[lsrp_vehicleparking] Failed to post NUI callback: ${eventName}`, error);
    }
}

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'openUI':
            openUI(data.zoneName, data.maxSlots, data.canStoreVehicle !== false);
            break;
        case 'closeUI':
            closeUIInternal();
            break;
        case 'updateVehicles':
            updateVehicleList(data.vehicles);
            break;
    }
});

// ESC key to close
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeUI();
    }
});

function openUI(zoneName, slots, allowStoreVehicle) {
    currentZone = zoneName;
    maxSlots = slots;
    canStoreVehicle = allowStoreVehicle !== false;
    
    document.getElementById('zone-name').textContent = zoneName;
    document.getElementById('max-slots').textContent = maxSlots;

    if (storeButtonElement) {
        storeButtonElement.style.display = canStoreVehicle ? '' : 'none';
    }

    document.getElementById('parking-container').classList.remove('hidden');
}

function closeUIInternal() {
    document.getElementById('parking-container').classList.add('hidden');
    currentZone = null;
    canStoreVehicle = true;
}

function closeUI() {
    postNui('close');
}

function storeVehicle() {
    if (!canStoreVehicle) {
        return;
    }

    postNui('storeVehicle');
}

function retrieveVehicle(id, plate) {
    const payload = {};

    if (Number.isFinite(Number(id))) {
        payload.id = Number(id);
    }

    if (typeof plate === 'string' && plate.length > 0) {
        payload.plate = plate;
    }

    postNui('retrieveVehicle', payload);
}

function refreshVehicles() {
    postNui('refreshVehicles');
}

function updateVehicleList(vehicles) {
    const vehiclesContainer = document.getElementById('vehicles');
    const vehicleCount = document.getElementById('vehicle-count');
    
    vehicleCount.textContent = vehicles.length;
    
    if (!vehicles || vehicles.length === 0) {
        vehiclesContainer.innerHTML = '<div class="no-vehicles">No vehicles parked</div>';
        return;
    }
    
    vehiclesContainer.innerHTML = '';
    
    vehicles.forEach(vehicle => {
        const card = createVehicleCard(vehicle);
        vehiclesContainer.appendChild(card);
    });
}

function createVehicleCard(vehicle) {
    const card = document.createElement('div');
    card.className = 'vehicle-card';
    
    const storedDate = new Date(vehicle.stored_at);
    const formattedDate = storedDate.toLocaleDateString() + ' ' + storedDate.toLocaleTimeString();
    
    const parkingId = Number(vehicle.id);
    const safePlate = String(vehicle.vehicle_plate || '').replace(/'/g, "\\'");

    card.innerHTML = `
        <div class="vehicle-card-header">
            <div class="vehicle-model">${vehicle.vehicle_model}</div>
            <div class="vehicle-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M5 17h14v-5l-1.5-4.5h-11L5 12v5z"/>
                    <circle cx="7.5" cy="17" r="1.5"/>
                    <circle cx="16.5" cy="17" r="1.5"/>
                </svg>
            </div>
        </div>
        
        <div class="vehicle-details">
            <div class="vehicle-detail">
                <span class="vehicle-detail-label">Plate:</span>
                <span class="vehicle-detail-value">${vehicle.vehicle_plate}</span>
            </div>
            <div class="vehicle-detail">
                <span class="vehicle-detail-label">Parked:</span>
                <span class="vehicle-detail-value">${formattedDate}</span>
            </div>
        </div>
        
        <div class="vehicle-actions">
            <button class="retrieve-btn" onclick="retrieveVehicle(${Number.isFinite(parkingId) ? parkingId : 'null'}, '${safePlate}')">
                Retrieve Vehicle
            </button>
        </div>
    `;
    
    return card;
}

