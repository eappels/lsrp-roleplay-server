window.addEventListener('DOMContentLoaded', () => {
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    document.body.style.opacity = '0';
    document.body.style.background = 'transparent';
    document.body.style.backgroundColor = 'transparent';
    document.getElementById('app').classList.add('hidden');
    document.getElementById('app').setAttribute('aria-hidden', 'true');

    // helper: report JS errors back to client Lua
    function reportError(info) {
        try {
            fetch(`https://${GetParentResourceName()}/nuiError`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(info) });
        } catch (e) {
            console.error('Failed to report NUI error', e);
        }
    }

    // global error handlers
    window.onerror = function(message, source, lineno, colno, error) {
        reportError({ type: 'error', message: String(message), source: source, lineno: lineno, colno: colno, stack: error && error.stack });
    };
    window.addEventListener('error', function(ev) {
        reportError({ type: 'error', message: ev.message || String(ev), source: ev.filename, lineno: ev.lineno, colno: ev.colno, stack: ev.error && ev.error.stack });
    });
    window.addEventListener('unhandledrejection', function(ev) {
        reportError({ type: 'unhandledrejection', message: String(ev.reason && (ev.reason.message || ev.reason)), stack: ev.reason && ev.reason.stack });
    });

    const compList = document.getElementById('component-list');
    const detailTitle = document.getElementById('detail-title');
    const drawVal = document.getElementById('draw-val');
    const textVal = document.getElementById('text-val');
    const decDraw = document.getElementById('dec-draw');
    const incDraw = document.getElementById('inc-draw');
    const decText = document.getElementById('dec-text');
    const incText = document.getElementById('inc-text');
    const revertBtn = document.getElementById('revert-btn');
    const closeBtn = document.getElementById('close-nui');
    const maleBtn = document.getElementById('male-btn');
    const femaleBtn = document.getElementById('female-btn');
    const characterCreationBanner = document.getElementById('character-creation-banner');
    const spawnCharacterBtn = document.getElementById('spawn-character-btn');
    let characterCreationMode = false;

    const componentNames = [
        'Face', 'Mask', 'Hair', 'Torso', 'Legs', 'Bags/Parachutes', 'Shoes', 'Accessories', 'Undershirt', 'Body Armor', 'Decals', 'Torso 2'
    ];

    const outfitsList = document.getElementById('outfits-list');
    const cameraKeys = ['w', 's', 'a', 'd'];

    function setCameraKeyState(key, down) {
        return fetch(`https://${GetParentResourceName()}/cameraKey`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ key, down })
        }).catch(() => {});
    }

    function releaseCameraKeys() {
        cameraKeys.forEach((key) => {
            setCameraKeyState(key, false);
        });
    }

    function isTypingInEditor() {
        const activeElement = document.activeElement;
        if (!activeElement) {
            return false;
        }

        const tagName = String(activeElement.tagName || '').toLowerCase();
        return tagName === 'input' || tagName === 'textarea';
    }

    function renderOutfits(list) {
        let html = '';
        // show the first 5 slots in the editor while keeping the backend slot model intact
        const slots = {};
        (list || []).forEach(o => { slots[o.slot] = o; });
        for (let i = 1; i <= 5; i++) {
            const o = slots[i];
            const name = o && o.name ? o.name : 'Empty';
            html += `
                <div class="outfit-row" data-slot="${i}">
                    <div class="oname">${name}</div>
                    <div class="outfit-actions">
                        <button class="load-outfit">Load</button>
                        <button class="save-outfit">Save</button>
                        <button class="del-outfit">Del</button>
                    </div>
                </div>
            `;
        }
        outfitsList.innerHTML = html;
    }

    function refreshOutfits() {
        fetch(`https://${GetParentResourceName()}/listOutfits`, { method: 'POST', body: '{}' }).then(r => r.json()).then(data => {
            renderOutfits(data || []);
        }).catch(()=>{});
    }

    let currentComponents = {};
    let selectedId = null;
    let previewTimer = null;

    function renderComponents() {
        let html = '';
        for (let i = 0; i <= 11; i++) {
            const name = componentNames[i] || `Component ${i}`;
            html += `
                <div class="component-row" data-id="${i}">
                    <div>
                        <div class="comp-label">${name}</div>
                    </div>
                    <div class="comp-actions">Select</div>
                </div>
            `;
        }
        compList.innerHTML = html;
    }

    function selectComponent(id) {
        const prev = compList.querySelector('.component-row.active');
        if (prev) prev.classList.remove('active');
        const row = compList.querySelector(`.component-row[data-id="${id}"]`);
        if (row) row.classList.add('active');
        selectedId = id;
        const name = componentNames[id] || `Component ${id}`;
        detailTitle.textContent = `${name} (${id})`;
        const comp = currentComponents[id] || { drawable: 0, texture: 0 };
        if (drawVal) drawVal.value = comp.drawable ?? 0;
        if (textVal) textVal.value = comp.texture ?? 0;
    }

    function fetchAndRenderComponents() {
        fetch(`https://${GetParentResourceName()}/getPedComponents`, { method: 'POST', body: '{}' }).then(r => r.json()).then(data => {
            currentComponents = data || {};
            renderComponents();
            // select first component with non-zero values or first
            let selected = null;
            for (let i = 0; i <= 11; i++) {
                const c = currentComponents[i] || {};
                if ((c.drawable && c.drawable > 0) || (c.texture && c.texture > 0)) {
                    selected = i; break;
                }
            }
            if (selected === null) {
                const first = compList.querySelector('.component-row');
                if (first) selected = parseInt(first.getAttribute('data-id'), 10);
            }
            if (selected !== null) selectComponent(selected);
        }).catch(() => {});
    }

    // click to select
    compList.addEventListener('click', (ev) => {
        const row = ev.target.closest('.component-row');
        if (!row) return;
        const id = parseInt(row.getAttribute('data-id'), 10);
        selectComponent(id);
    });

    // outfits click handlers
    function createSaveEditor(row, slot) {
        // prevent multiple editors
        if (row.querySelector('.save-editor')) return;
        const nameDiv = row.querySelector('.oname');
        const origName = nameDiv ? nameDiv.textContent : '';
        // hide actions
        const actions = Array.from(row.querySelectorAll('button'));
        actions.forEach(b => b.style.display = 'none');
        // create editor
        const editor = document.createElement('div');
        editor.className = 'save-editor';
        const input = document.createElement('input');
        input.type = 'text';
        input.placeholder = 'Outfit name (optional)';
        input.value = origName === 'Empty' ? '' : origName;
        input.className = 'save-editor__input';
        input.autocomplete = 'off';
        releaseCameraKeys();
        const ok = document.createElement('button'); ok.textContent = 'OK';
        const cancel = document.createElement('button'); cancel.textContent = 'Cancel';
        const actionsRow = document.createElement('div');
        actionsRow.className = 'save-editor__actions';
        actionsRow.appendChild(ok);
        actionsRow.appendChild(cancel);
        editor.appendChild(input);
        editor.appendChild(actionsRow);
        nameDiv.replaceWith(editor);
        input.focus();
        input.select();

        ok.addEventListener('click', async () => {
            try {
                ok.disabled = true;
                const name = input.value || '';
                const comps = currentComponents || {};
                const payload = { slot, name, comps };
                const r2 = await fetch(`https://${GetParentResourceName()}/saveOutfit`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
                let parsed = null; try { parsed = await r2.json(); } catch(e) { parsed = null; }
                if (!r2.ok || (parsed && parsed.ok === false)) {
                    console.error('Failed to save outfit, response:', r2, parsed);
                    alert('Failed to save outfit (server error).');
                } else {
                    setTimeout(refreshOutfits, 200);
                }
            } catch (err) {
                console.error('Failed saving outfit:', err);
                alert('Failed to save outfit (see console).');
            } finally {
                try { editor.replaceWith(createRowNameDiv(origName)); actions.forEach(b => b.style.display = 'inline-block'); } catch(e){}
            }
        });

        cancel.addEventListener('click', () => {
            try { editor.replaceWith(createRowNameDiv(origName)); actions.forEach(b => b.style.display = 'inline-block'); } catch(e){}
        });
    }

    function createRowNameDiv(name) {
        const div = document.createElement('div');
        div.className = 'oname';
        div.textContent = name;
        return div;
    }

    if (outfitsList) {
        outfitsList.addEventListener('click', (ev) => {
        const row = ev.target.closest('.outfit-row');
        if (!row) return;
        const slot = parseInt(row.getAttribute('data-slot'), 10);
        if (ev.target.classList.contains('load-outfit')) {
            fetch(`https://${GetParentResourceName()}/getOutfit`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ slot }) }).then(r => r.json()).then(resp => {
                if (resp.ok && resp.outfit && resp.outfit.comps) {
                    const outfit = resp.outfit;
                    const comps = outfit.comps;
                    const modelPromise = outfit.model
                        ? fetch(`https://${GetParentResourceName()}/applyModel`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: outfit.model }) })
                        : Promise.resolve();

                    modelPromise.then(() => {
                        // apply each component after model is ready
                        for (let i = 0; i <= 11; i++) {
                            const c = comps[i] || { drawable: 0, texture: 0 };
                            fetch(`https://${GetParentResourceName()}/applyComponent`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ component: i, drawable: c.drawable, texture: c.texture }) });
                        }

                        // refresh displayed components after short delay
                        setTimeout(() => {
                            fetchAndRenderComponents();
                            refreshGenderSelection();
                        }, 300);
                    }).catch(() => {});
                }
            }).catch(()=>{});
        } else if (ev.target.classList.contains('save-outfit')) {
            try {
                createSaveEditor(row, slot);
            } catch (e) {
                console.error('Failed to open save editor', e);
                alert('Failed to open save editor.');
            }
        } else if (ev.target.classList.contains('del-outfit')) {
            try {
                // inline confirmation editor
                if (row.querySelector('.confirm-editor')) return;
                const actions = Array.from(row.querySelectorAll('button'));
                actions.forEach(b => b.style.display = 'none');
                const nameDiv = row.querySelector('.oname');
                const orig = nameDiv ? nameDiv.textContent : '';
                const editor = document.createElement('div');
                editor.className = 'confirm-editor';
                editor.style.display = 'flex';
                editor.style.gap = '6px';
                const msg = document.createElement('div'); msg.textContent = 'Delete slot ' + slot + '?'; msg.style.flex = '1';
                const yes = document.createElement('button'); yes.textContent = 'Yes';
                const no = document.createElement('button'); no.textContent = 'No';
                editor.appendChild(msg); editor.appendChild(yes); editor.appendChild(no);
                nameDiv.replaceWith(editor);

                yes.addEventListener('click', async () => {
                    try {
                        yes.disabled = true;
                        await fetch(`https://${GetParentResourceName()}/deleteOutfit`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ slot }) });
                        setTimeout(refreshOutfits, 200);
                    } catch (e) {
                        console.error('Failed deleting outfit', e);
                        alert('Failed to delete outfit (see console).');
                    } finally {
                        try { editor.replaceWith(createRowNameDiv(orig)); actions.forEach(b => b.style.display = 'inline-block'); } catch(e){}
                    }
                });

                no.addEventListener('click', () => {
                    try { editor.replaceWith(createRowNameDiv(orig)); actions.forEach(b => b.style.display = 'inline-block'); } catch(e){}
                });
            } catch (e) {
                console.error('Failed to open delete editor', e);
            }
        }
    });
    }

    // log unhandled promise rejections to help diagnose crashes
    window.addEventListener('unhandledrejection', (ev) => {
        console.error('Unhandled promise rejection in ped editor NUI', ev.reason);
        try { alert('An unexpected error occurred (see console).'); } catch(e){}
    });

    // control buttons
    function clamp(n) { return Math.max(0, parseInt(n || 0, 10)); }
    if (incDraw) incDraw.addEventListener('click', () => { drawVal.value = clamp(drawVal.value) + 1; sendPreview(); });
    if (decDraw) decDraw.addEventListener('click', () => { drawVal.value = Math.max(0, clamp(drawVal.value) - 1); sendPreview(); });
    if (incText) incText.addEventListener('click', () => { textVal.value = clamp(textVal.value) + 1; sendPreview(); });
    if (decText) decText.addEventListener('click', () => { textVal.value = Math.max(0, clamp(textVal.value) - 1); sendPreview(); });

    // preview sender (debounced)
    function sendPreview(force) {
        if (selectedId === null) return;
        const drawable = clamp(drawVal.value);
        const texture = clamp(textVal.value);
        currentComponents[selectedId] = { drawable, texture };
        renderComponents();
        if (previewTimer) clearTimeout(previewTimer);
        if (force) {
            fetch(`https://${GetParentResourceName()}/applyComponent`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ component: selectedId, drawable, texture }) });
        } else {
            previewTimer = setTimeout(() => {
                fetch(`https://${GetParentResourceName()}/applyComponent`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ component: selectedId, drawable, texture }) });
                previewTimer = null;
            }, 160);
        }
    }

    // revert
    if (revertBtn) revertBtn.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/revertPed`, { method: 'POST', body: '{}' }).then(() => {
            fetchAndRenderComponents();
        });
    });

    // close
    if (closeBtn) closeBtn.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/closeNUI`, { method: 'POST', body: '{}' });
    });

    if (spawnCharacterBtn) spawnCharacterBtn.addEventListener('click', async () => {
        try {
            spawnCharacterBtn.disabled = true;
            const response = await fetch(`https://${GetParentResourceName()}/finishCharacterCreation`, { method: 'POST', body: '{}' });
            const payload = await response.json().catch(() => ({}));
            if (!response.ok || !payload || payload.ok !== true) {
                throw new Error((payload && payload.error) || 'finish_failed');
            }
        } catch (error) {
            console.error('Failed to finish character creation', error);
            alert('Could not finish character creation.');
        } finally {
            spawnCharacterBtn.disabled = false;
        }
    });

    // gender selection
    function setGenderSelection(g) {
        if (maleBtn) maleBtn.classList.toggle('active', g === 'male');
        if (femaleBtn) femaleBtn.classList.toggle('active', g === 'female');
    }

    function refreshGenderSelection() {
        fetch(`https://${GetParentResourceName()}/getCurrentModel`, { method: 'POST', body: '{}' })
            .then(r => r.json())
            .then(data => {
                const gender = data && data.gender;
                if (gender === 'male' || gender === 'female') {
                    setGenderSelection(gender);
                } else {
                    setGenderSelection('');
                }
            })
            .catch(() => {
                setGenderSelection('');
            });
    }

    if (maleBtn) maleBtn.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/applyModel`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'mp_m_freemode_01' }) })
            .then(() => {
                setGenderSelection('male');
                fetchAndRenderComponents();
            })
            .catch(() => {});
    });
    if (femaleBtn) femaleBtn.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/applyModel`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'mp_f_freemode_01' }) })
            .then(() => {
                setGenderSelection('female');
                fetchAndRenderComponents();
            })
            .catch(() => {});
    });

    // when shown
    window.addEventListener('message', (event) => {
        if (event.data.type === 'show') {
            characterCreationMode = event.data.characterCreationMode === true;
            if (spawnCharacterBtn) {
                spawnCharacterBtn.textContent = event.data.spawnLabel || 'Spawn Los Santos Airport';
            }
            if (characterCreationBanner) {
                characterCreationBanner.classList.toggle('hidden', !characterCreationMode);
                characterCreationBanner.setAttribute('aria-hidden', characterCreationMode ? 'false' : 'true');
            }
            if (closeBtn) {
                closeBtn.classList.toggle('hidden', characterCreationMode);
            }
            document.body.style.display = 'block';
            document.body.style.visibility = 'visible';
            document.body.style.opacity = '1';
            document.getElementById('app').classList.remove('hidden');
            document.getElementById('app').setAttribute('aria-hidden', 'false');
            fetchAndRenderComponents();
            refreshOutfits();
            refreshGenderSelection();
        } else if (event.data.type === 'hide') {
            document.getElementById('app').classList.add('hidden');
            document.getElementById('app').setAttribute('aria-hidden', 'true');
            document.body.style.display = 'none';
            document.body.style.visibility = 'hidden';
            document.body.style.opacity = '0';
            characterCreationMode = false;
        }
    });

    // send W/S keydown/keyup to client so camera can move while NUI has focus
    const keyMap = { 'w': 'w', 'W': 'w', 's': 's', 'S': 's', 'a': 'a', 'A': 'a', 'd': 'd', 'D': 'd' };
    window.addEventListener('keydown', (e) => {
        try {
            const k = keyMap[e.key];
            if (k) {
                if (isTypingInEditor()) {
                    return;
                }

                setCameraKeyState(k, true);
            }
        } catch (err) { }
    });
    window.addEventListener('keyup', (e) => {
        try {
            const k = keyMap[e.key];
            if (k) {
                setCameraKeyState(k, false);
            }
        } catch (err) { }
    });
});
