(function () {
    var app = document.getElementById('app');
    var authView = document.getElementById('auth-view');
    var characterView = document.getElementById('character-view');
    var readyView = document.getElementById('ready-view');
    var spawnPanel = document.getElementById('spawn-panel');
    var statusEl = document.getElementById('status');
    var emailEl = document.getElementById('email');
    var passwordEl = document.getElementById('password');
    var rememberEl = document.getElementById('remember');
    var firstNameEl = document.getElementById('first-name');
    var lastNameEl = document.getElementById('last-name');
    var dateOfBirthEl = document.getElementById('date-of-birth');
    var sexEl = document.getElementById('character-sex');
    var spawnGateEl = document.getElementById('spawn-gate');
    var spawnCharacterSummaryEl = document.getElementById('spawn-character-summary');
    var spawnCharacterNameEl = document.getElementById('spawn-character-name');
    var spawnCharacterMetaEl = document.getElementById('spawn-character-meta');
    var readyFullNameEl = document.getElementById('ready-full-name');
    var readyDateOfBirthEl = document.getElementById('ready-date-of-birth');
    var readySexEl = document.getElementById('ready-sex');
    var spawnAirportEl = document.getElementById('spawn-airport');
    var mapActiveLabelEl = document.getElementById('map-active-label');
    var mapActiveCoordsEl = document.getElementById('map-active-coords');
    var markersEl = document.getElementById('markers');
    var spawnListEl = document.getElementById('spawn-list');
    var spawnPoints = [];
    var activeSpawnIndex = -1;
    var isAuthenticated = false;
    var hasCharacter = false;
    var currentCharacter = null;
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

    function hidePrejoinShell() {
        document.body.style.display = 'none';
        document.body.style.visibility = 'hidden';
        document.body.style.opacity = '0';
        document.body.style.background = 'transparent';
        document.body.style.backgroundColor = 'transparent';
        app.classList.add('hidden');
        app.setAttribute('aria-hidden', 'true');
    }

    function showPrejoinShell() {
        document.body.style.display = 'block';
        document.body.style.visibility = 'visible';
        document.body.style.opacity = '1';
        document.body.style.background = 'transparent';
        document.body.style.backgroundColor = 'transparent';
        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
    }

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

    function friendlyReason(reason, fallback) {
        var messages = {
            not_authenticated: 'Log in again before continuing.',
            invalid_first_name: 'Enter a valid first name using letters, spaces, apostrophes, or hyphens.',
            invalid_last_name: 'Enter a valid last name using letters, spaces, apostrophes, or hyphens.',
            invalid_date_of_birth: 'Choose a valid date of birth for a character aged 16 to 100.',
            invalid_sex: 'Choose a valid sex for this character.',
            db_error: 'Character creation failed while saving. Try again.',
            create_failed: 'Character creation did not complete. Try again.',
            character_service_unavailable: 'Character service is unavailable right now.'
        };

        return messages[reason] || fallback || 'Request failed.';
    }

    function setLeftStage(stage) {
        authView.classList.toggle('hidden', stage !== 'auth');
        characterView.classList.toggle('hidden', stage !== 'character');
        readyView.classList.toggle('hidden', stage !== 'ready');
    }

    function titleCase(value) {
        return String(value || '').replace(/\b([a-z])/g, function (match) {
            return match.toUpperCase();
        });
    }

    function normalizeName(value) {
        return String(value || '').trim().replace(/\s+/g, ' ');
    }

    function getDaysInMonth(year, month) {
        return new Date(year, month, 0).getDate();
    }

    function getLatestAllowedBirthDate() {
        var today = new Date();
        var latest = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        latest.setFullYear(latest.getFullYear() - 16);
        return latest;
    }

    function normalizeDateInput(value) {
        var raw = String(value || '').trim();
        if (!raw) {
            return '';
        }

        var match = raw.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
        if (!match) {
            return '';
        }

        var year = Number(match[1]);
        var month = Number(match[2]);
        var day = Number(match[3]);
        if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
            return '';
        }

        if (year < 1900 || month < 1 || month > 12) {
            return '';
        }

        var maxDay = getDaysInMonth(year, month);
        if (day < 1 || day > maxDay) {
            return '';
        }

        return String(year).padStart(4, '0') + '-' + String(month).padStart(2, '0') + '-' + String(day).padStart(2, '0');
    }

    function isValidCharacterDateOfBirth(value) {
        var normalized = normalizeDateInput(value);
        if (!normalized) {
            return false;
        }

        var parts = normalized.split('-');
        var year = Number(parts[0]);
        var month = Number(parts[1]);
        var day = Number(parts[2]);
        var birthDate = new Date(year, month - 1, day);
        if (birthDate.getFullYear() !== year || (birthDate.getMonth() + 1) !== month || birthDate.getDate() !== day) {
            return false;
        }

        var latest = getLatestAllowedBirthDate();
        if (birthDate > latest) {
            return false;
        }

        var oldest = new Date(latest.getFullYear() - 84, latest.getMonth(), latest.getDate());
        if (birthDate < oldest) {
            return false;
        }

        return true;
    }

    function formatSex(value) {
        if (!value) {
            return '-';
        }

        return titleCase(String(value).toLowerCase());
    }

    function formatDateOfBirth(value) {
        var raw = value;
        if (raw === null || raw === undefined || raw === '') {
            return '-';
        }

        if (typeof raw === 'number' || (/^\d+(\.\d+)?$/).test(String(raw))) {
            var numeric = Number(raw);
            if (Number.isFinite(numeric) && numeric > 0) {
                if (Math.abs(numeric) >= 100000000000) {
                    numeric = numeric / 1000;
                }

                var timestampDate = new Date(numeric * 1000);
                if (!Number.isNaN(timestampDate.getTime())) {
                    var year = String(timestampDate.getUTCFullYear()).padStart(4, '0');
                    var month = String(timestampDate.getUTCMonth() + 1).padStart(2, '0');
                    var day = String(timestampDate.getUTCDate()).padStart(2, '0');
                    return year + '-' + month + '-' + day;
                }
            }
        }

        var normalized = normalizeDateInput(String(raw));
        if (normalized) {
            return normalized;
        }

        var dateMatch = String(raw).match(/^(\d{4}-\d{2}-\d{2})/);
        if (dateMatch) {
            return dateMatch[1];
        }

        return String(raw);
    }

    function updateCharacterPresentation() {
        if (!currentCharacter) {
            spawnCharacterSummaryEl.classList.add('hidden');
            spawnCharacterNameEl.textContent = 'No character';
            spawnCharacterMetaEl.textContent = 'Identity pending';
            readyFullNameEl.textContent = 'No character loaded';
            readyDateOfBirthEl.textContent = '-';
            readySexEl.textContent = '-';
            return;
        }

        var fullName = currentCharacter.fullName || ((currentCharacter.firstName || '') + ' ' + (currentCharacter.lastName || '')).trim();
        var displayDateOfBirth = formatDateOfBirth(currentCharacter.dateOfBirth);
        spawnCharacterSummaryEl.classList.remove('hidden');
        spawnCharacterNameEl.textContent = fullName || 'Unnamed character';
        spawnCharacterMetaEl.textContent = 'DOB ' + displayDateOfBirth + ' • ' + formatSex(currentCharacter.sex);
        readyFullNameEl.textContent = fullName || 'Unnamed character';
        readyDateOfBirthEl.textContent = displayDateOfBirth;
        readySexEl.textContent = formatSex(currentCharacter.sex);
    }

    function setCurrentCharacter(character) {
        currentCharacter = character || null;
        hasCharacter = !!currentCharacter;
        updateCharacterPresentation();
        updateSpawnLockState();
    }

    function updateSpawnLockState() {
        var unlocked = isAuthenticated && hasCharacter;
        spawnPanel.classList.toggle('locked', !unlocked);

        if (!isAuthenticated) {
            spawnGateEl.textContent = 'Log in to unlock character creation.';
        } else if (!hasCharacter) {
            spawnGateEl.textContent = 'Create a character to unlock spawn selection.';
        } else {
            spawnGateEl.textContent = 'Identity ready. Choose any spawn point.';
        }

        Array.prototype.forEach.call(document.querySelectorAll('.spawn-card button'), function (button) {
            button.disabled = !unlocked;
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
        setCurrentCharacter(null);
        firstNameEl.value = '';
        lastNameEl.value = '';
        dateOfBirthEl.value = '';
        sexEl.value = 'male';
        renderSpawns(spawns);
        showPrejoinShell();
        setLeftStage('auth');
        setStatus('');
        loadRemembered();
        updateSpawnLockState();
    }

    function showCharacterCreation() {
        setLeftStage('character');
        setStatus('Create your first character to unlock spawn selection.');
        updateSpawnLockState();
    }

    function showSpawnPanel() {
        saveRemembered();
        setLeftStage('ready');
        setStatus('Identity verified. Choose a spawn point.');
        updateSpawnLockState();
    }

    function fetchCharacterState() {
        setStatus('Loading character profile...');

        return post('prejoinGetCharacter', {}).then(function (data) {
            if (!data || !data.success) {
                setStatus(friendlyReason(data && data.reason, 'Character lookup failed.'));
                return;
            }

            if (data.hasCharacter && data.character) {
                setCurrentCharacter(data.character);
                showSpawnPanel();
                return;
            }

            setCurrentCharacter(null);
            showCharacterCreation();
        }).catch(function () {
            setStatus('Character lookup failed.');
        });
    }

    function chooseSpawn(index) {
        if (index < 0 || index >= spawnPoints.length) {
            return;
        }

        if (!isAuthenticated) {
            setStatus('Log in before choosing a spawn point.');
            return;
        }

        if (!hasCharacter) {
            setStatus('Create a character before choosing a spawn point.');
            return;
        }

        setActiveSpawn(index);
        post('prejoinSpawnSelect', { spawnIndex: index }).then(function (data) {
            if (!data || !data.success) {
                setStatus((data && data.reason) || 'Unable to spawn there.');
                return;
            }

            hidePrejoinShell();
        }).catch(function () {
            setStatus('Spawn request failed.');
        });
    }

    function findAirportSpawnIndex() {
        var airportIndex = -1;

        spawnPoints.some(function (point, pointIndex) {
            var label = String(point && point.label || '');
            var description = String(point && point.description || '');
            if (/airport|international/i.test(label) || /airport|international/i.test(description)) {
                airportIndex = pointIndex;
                return true;
            }

            return false;
        });

        return airportIndex;
    }

    document.getElementById('login').addEventListener('click', function () {
        post('prejoinLogin', {
            email: emailEl.value || '',
            password: passwordEl.value || ''
        }).then(function (data) {
            if (!data || !data.success) {
                setStatus(friendlyReason(data && data.reason, 'Login failed.'));
                return;
            }

            isAuthenticated = true;
            fetchCharacterState();
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

    document.getElementById('create-character').addEventListener('click', function () {
        var payload = {
            firstName: normalizeName(firstNameEl.value),
            lastName: normalizeName(lastNameEl.value),
            dateOfBirth: normalizeDateInput(dateOfBirthEl.value),
            sex: sexEl.value || ''
        };

        if (!payload.firstName || !payload.lastName || !payload.dateOfBirth || !payload.sex) {
            setStatus('Complete all character fields before continuing.');
            return;
        }

        if (!isValidCharacterDateOfBirth(payload.dateOfBirth)) {
            setStatus('Enter the date of birth as YYYY-MM-DD for a character aged 16 to 100.');
            return;
        }

        setStatus('Creating character profile...');
        post('prejoinCreateCharacter', payload).then(function (data) {
            if (!data || !data.success || !data.character) {
                setStatus(friendlyReason(data && data.reason, 'Character creation failed.'));
                return;
            }

            setCurrentCharacter(data.character);
            setStatus('Opening appearance editor...');
            return post('prejoinBeginFirstCharacterCreation', {
                sex: data.character.sex || payload.sex
            }).then(function (startData) {
                if (!startData || !startData.success) {
                    setStatus('Could not start the appearance editor.');
                    return;
                }

                hidePrejoinShell();
            });
        }).catch(function () {
            setStatus('Character creation request failed.');
        });
    });

    document.getElementById('back-to-login').addEventListener('click', function () {
        isAuthenticated = false;
        setCurrentCharacter(null);
        setLeftStage('auth');
        setStatus('Sign in to continue.');
        updateSpawnLockState();
    });

    spawnAirportEl.addEventListener('click', function () {
        var airportIndex = findAirportSpawnIndex();
        if (airportIndex < 0) {
            setStatus('Los Santos Airport spawn is unavailable.');
            return;
        }

        chooseSpawn(airportIndex);
    });

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'showPrejoin') {
            showAuth(data.spawnPoints || []);
        } else if (data.action === 'updateSpawnPoints') {
            renderSpawns(data.spawnPoints || []);
        }
    });

    dateOfBirthEl.addEventListener('blur', function () {
        var normalized = normalizeDateInput(dateOfBirthEl.value);
        if (normalized) {
            dateOfBirthEl.value = normalized;
        }
    });

    hidePrejoinShell();
})();