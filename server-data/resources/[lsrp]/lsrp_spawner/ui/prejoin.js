(function () {
    var app = document.getElementById('app');
    var authPanel = document.getElementById('auth-panel');
    var spawnPanel = document.getElementById('spawn-panel');
    var statusEl = document.getElementById('status');
    var emailEl = document.getElementById('email');
    var passwordEl = document.getElementById('password');
    var rememberEl = document.getElementById('remember');
    var spawnGateEl = document.getElementById('spawn-gate');
    var mapActiveLabelEl = document.getElementById('map-active-label');
    var mapActiveCoordsEl = document.getElementById('map-active-coords');
    var markersEl = document.getElementById('markers');
    var spawnListEl = document.getElementById('spawn-list');
    var spawnPoints = [];
    var activeSpawnIndex = -1;
    var isAuthenticated = false;
    var MAP_LIMITS = {
        minX: -2050,
        maxX: 1700,
        minY: -3550,
        maxY: 1200,
        drawLeft: 116,
        drawRight: 912,
        drawTop: 88,
        drawBottom: 672
    };

    function resourceUrl(path) {
        return 'https://' + GetParentResourceName() + '/' + path;
    }

    function clamp(value, minValue, maxValue) {
        if (value < minValue) {
            return minValue;
        }

        if (value > maxValue) {
            return maxValue;
        }

        return value;
    }

    function createSvgElement(name, className) {
        var node = document.createElementNS('http://www.w3.org/2000/svg', name);
        if (className) {
            node.setAttribute('class', className);
        }

        return node;
    }

    function getNumericValue(value) {
        var parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : null;
    }

    function projectSpawn(point) {
        var worldX = getNumericValue(point && point.x);
        var worldY = getNumericValue(point && point.y);

        if (worldX === null || worldY === null) {
            return {
                mapX: getNumericValue(point && point.mapX) || ((MAP_LIMITS.drawLeft + MAP_LIMITS.drawRight) / 2),
                mapY: getNumericValue(point && point.mapY) || ((MAP_LIMITS.drawTop + MAP_LIMITS.drawBottom) / 2),
                edge: false
            };
        }

        var normalizedX = (worldX - MAP_LIMITS.minX) / (MAP_LIMITS.maxX - MAP_LIMITS.minX);
        var normalizedY = (worldY - MAP_LIMITS.minY) / (MAP_LIMITS.maxY - MAP_LIMITS.minY);
        var clampedX = clamp(normalizedX, 0, 1);
        var clampedY = clamp(normalizedY, 0, 1);

        return {
            mapX: MAP_LIMITS.drawLeft + (clampedX * (MAP_LIMITS.drawRight - MAP_LIMITS.drawLeft)),
            mapY: MAP_LIMITS.drawBottom - (clampedY * (MAP_LIMITS.drawBottom - MAP_LIMITS.drawTop)),
            edge: clampedX !== normalizedX || clampedY !== normalizedY
        };
    }

    function formatCoords(point) {
        var x = getNumericValue(point && point.x);
        var y = getNumericValue(point && point.y);

        if (x === null || y === null) {
            return 'No coordinate data';
        }

        return 'X ' + x.toFixed(0) + '  Y ' + y.toFixed(0);
    }

    function updateMapSummary(index) {
        var point = spawnPoints[index];

        if (!point) {
            mapActiveLabelEl.textContent = 'Hover a spawn point to preview it';
            mapActiveCoordsEl.textContent = 'Awaiting selection';
            return;
        }

        mapActiveLabelEl.textContent = point.label || 'Unnamed spawn';
        mapActiveCoordsEl.textContent = formatCoords(point) + (projectSpawn(point).edge ? ' • outside city view' : '');
    }

    function setStatus(message) {
        statusEl.textContent = message || '';
    }

    function updateSpawnLockState() {
        spawnPanel.classList.toggle('locked', !isAuthenticated);
        spawnGateEl.textContent = isAuthenticated ? 'Authenticated. Choose any spawn point.' : 'Log in to unlock spawn selection.';

        Array.prototype.forEach.call(document.querySelectorAll('.spawn-card button'), function (button) {
            button.disabled = !isAuthenticated;
        });
    }

    function loadRemembered() {
        try {
            var raw = localStorage.getItem('lsrp_prejoin_credentials');
            if (!raw) {
                return;
            }

            var saved = JSON.parse(raw);
            emailEl.value = saved.email || '';
            passwordEl.value = saved.password || '';
            rememberEl.checked = !!saved.remember;
        } catch (error) {
        }
    }

    function saveRemembered() {
        if (!rememberEl.checked) {
            localStorage.removeItem('lsrp_prejoin_credentials');
            return;
        }

        localStorage.setItem('lsrp_prejoin_credentials', JSON.stringify({
            email: emailEl.value || '',
            password: passwordEl.value || '',
            remember: true
        }));
    }

    function post(path, payload) {
        return fetch(resourceUrl(path), {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload || {})
        }).then(function (response) {
            return response.json();
        });
    }

    function setActiveSpawn(index) {
        activeSpawnIndex = index;
        updateMapSummary(index);

        Array.prototype.forEach.call(document.querySelectorAll('.spawn-card'), function (node, cardIndex) {
            node.classList.toggle('active', cardIndex === index);
        });

        Array.prototype.forEach.call(document.querySelectorAll('.map-marker'), function (node, markerIndex) {
            node.classList.toggle('active', markerIndex === index);
        });
    }

    function renderSpawns(points) {
        spawnPoints = points || [];
        spawnListEl.innerHTML = '';
        markersEl.innerHTML = '';

        spawnPoints.forEach(function (point, index) {
            var projection = projectSpawn(point);
            var card = document.createElement('article');
            card.className = 'spawn-card';
            var title = document.createElement('h3');
            title.textContent = point.label || 'Unnamed spawn';

            var description = document.createElement('p');
            description.textContent = point.description || 'Standard city entry point.';

            var meta = document.createElement('div');
            meta.className = 'spawn-card-meta';
            meta.textContent = formatCoords(point) + (projection.edge ? ' • outside city view' : '');

            var button = document.createElement('button');
            button.type = 'button';
            button.textContent = 'Spawn here';
            button.addEventListener('click', function () {
                chooseSpawn(index);
            });

            card.appendChild(title);
            card.appendChild(description);
            card.appendChild(meta);
            card.appendChild(button);
            card.addEventListener('mouseenter', function () {
                setActiveSpawn(index);
            });
            card.addEventListener('focusin', function () {
                setActiveSpawn(index);
            });
            spawnListEl.appendChild(card);

            var group = createSvgElement('g', 'map-marker' + (projection.edge ? ' edge' : ''));
            group.setAttribute('transform', 'translate(' + projection.mapX.toFixed(2) + ' ' + projection.mapY.toFixed(2) + ')');
            group.setAttribute('tabindex', '0');
            group.setAttribute('role', 'button');
            group.setAttribute('aria-label', 'Spawn at ' + (point.label || 'selected location'));

            var pulse = createSvgElement('circle', 'marker-pulse');
            pulse.setAttribute('r', '28');
            group.appendChild(pulse);

            var ring = createSvgElement('circle', 'marker-ring');
            ring.setAttribute('r', '16');
            group.appendChild(ring);

            var core = createSvgElement('circle', 'marker-core');
            core.setAttribute('r', '6');
            group.appendChild(core);

            var label = createSvgElement('text', 'marker-label');
            label.setAttribute('x', '22');
            label.setAttribute('y', '-18');
            label.textContent = point.label || 'Spawn';
            group.appendChild(label);

            group.addEventListener('click', function () {
                chooseSpawn(index);
            });
            group.addEventListener('mouseenter', function () {
                setActiveSpawn(index);
            });
            group.addEventListener('focus', function () {
                setActiveSpawn(index);
            });
            group.addEventListener('keydown', function (event) {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    chooseSpawn(index);
                }
            });
            markersEl.appendChild(group);
        });

        if (spawnPoints.length > 0) {
            setActiveSpawn(0);
        } else {
            updateMapSummary(-1);
        }

        updateSpawnLockState();
    }

    function showAuth(spawns) {
        isAuthenticated = false;
        renderSpawns(spawns);
        app.classList.remove('hidden');
        authPanel.classList.remove('hidden');
        setStatus('');
        loadRemembered();
        updateSpawnLockState();
    }

    function showSpawnPanel() {
        isAuthenticated = true;
        saveRemembered();
        setStatus('Authenticated. Choose a spawn point.');
        updateSpawnLockState();
    }

    function chooseSpawn(index) {
        if (index < 0 || index >= spawnPoints.length) {
            return;
        }

        if (!isAuthenticated) {
            setStatus('Log in before choosing a spawn point.');
            return;
        }

        setActiveSpawn(index);
        post('prejoinSpawnSelect', { spawnIndex: index }).then(function (data) {
            if (!data || !data.success) {
                setStatus((data && data.reason) || 'Unable to spawn there.');
                return;
            }

            app.classList.add('hidden');
        }).catch(function () {
            setStatus('Spawn request failed.');
        });
    }

    document.getElementById('login').addEventListener('click', function () {
        post('prejoinLogin', {
            email: emailEl.value || '',
            password: passwordEl.value || ''
        }).then(function (data) {
            if (!data || !data.success) {
                setStatus((data && data.reason) || 'Login failed.');
                return;
            }

            showSpawnPanel();
        }).catch(function () {
            setStatus('Login request failed.');
        });
    });

    document.getElementById('register').addEventListener('click', function () {
        post('prejoinRegister', {
            email: emailEl.value || '',
            password: passwordEl.value || ''
        }).then(function (data) {
            if (!data || !data.success) {
                setStatus((data && data.reason) || 'Registration failed.');
                return;
            }

            setStatus('Registration complete. You can log in now.');
        }).catch(function () {
            setStatus('Registration request failed.');
        });
    });

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'showPrejoin') {
            showAuth(data.spawnPoints || []);
        } else if (data.action === 'updateSpawnPoints') {
            renderSpawns(data.spawnPoints || []);
        }
    });
})();