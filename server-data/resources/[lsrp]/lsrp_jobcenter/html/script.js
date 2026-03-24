const resourceName = typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'lsrp_jobcenter';

const appEl = document.getElementById('app');
const heroSubtitleEl = document.getElementById('hero-subtitle');
const employmentLabelEl = document.getElementById('employment-label');
const employmentGradeEl = document.getElementById('employment-grade');
const employmentDutyEl = document.getElementById('employment-duty');
const employmentPayEl = document.getElementById('employment-pay');
const resignButtonEl = document.getElementById('resign-button');
const closeButtonEl = document.getElementById('close-button');
const jobsListEl = document.getElementById('jobs-list');
const emptyStateEl = document.getElementById('empty-state');
const jobCardTemplateEl = document.getElementById('job-card-template');
const gradeTemplateEl = document.getElementById('grade-template');

const state = {
    currentEmployment: null,
    jobs: []
};

appEl.hidden = true;

function createPill(text, tone = 'neutral') {
    const pill = document.createElement('span');
    pill.className = `pill ${tone}`;
    pill.textContent = String(text || '').trim();
    return pill;
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

    return JSON.parse(raw);
}

function signalUiReady() {
    postNui('uiReady').catch(() => undefined);
}

function signalUiOpened() {
    postNui('uiOpened').catch(() => undefined);
}

function setEmploymentSummary(currentEmployment) {
    state.currentEmployment = currentEmployment || null;

    if (!state.currentEmployment) {
        employmentLabelEl.textContent = 'Unemployed';
        employmentGradeEl.textContent = 'No active contract';
        employmentDutyEl.textContent = 'Off Duty';
        employmentPayEl.textContent = 'No payroll';
        resignButtonEl.disabled = true;
        return;
    }

    employmentLabelEl.textContent = state.currentEmployment.jobLabel || state.currentEmployment.jobId || 'Unknown Job';
    employmentGradeEl.textContent = state.currentEmployment.gradeLabel || state.currentEmployment.gradeId || 'No grade';
    employmentDutyEl.textContent = state.currentEmployment.onDuty ? 'On Duty' : 'Off Duty';
    employmentPayEl.textContent = `${state.currentEmployment.formattedPay || 'LS$0'} / ${Math.max(1, Math.floor(Number(state.currentEmployment.payIntervalSeconds || 900) / 60))} min`;
    resignButtonEl.disabled = false;
}

function renderJobs(jobs) {
    state.jobs = Array.isArray(jobs) ? jobs : [];
    jobsListEl.innerHTML = '';

    if (state.jobs.length === 0) {
        emptyStateEl.classList.remove('hidden');
        return;
    }

    emptyStateEl.classList.add('hidden');

    for (const job of state.jobs) {
        const fragment = jobCardTemplateEl.content.cloneNode(true);
        const cardEl = fragment.querySelector('.job-card');
        const accentEl = fragment.querySelector('.job-accent');
        const subtitleEl = fragment.querySelector('.job-subtitle');
        const titleEl = fragment.querySelector('.job-title');
        const stateEl = fragment.querySelector('.job-state');
        const descriptionEl = fragment.querySelector('.job-description');
        const tagsRowEl = fragment.querySelector('.tags-row');
        const requirementsListEl = fragment.querySelector('.requirements-list');
        const gradesBlockEl = fragment.querySelector('.grades-block');

        accentEl.style.background = String(job.jobCenter && job.jobCenter.accent ? job.jobCenter.accent : '#f2c14e');
        subtitleEl.textContent = String(job.jobCenter && job.jobCenter.subtitle ? job.jobCenter.subtitle : 'Civilian position');
        titleEl.textContent = String(job.label || job.id || 'Job');
        descriptionEl.textContent = String(job.description || 'No description available.');

        if (job.isCurrent) {
            stateEl.textContent = 'Current';
            stateEl.classList.add('current');
        } else if (job.canApply) {
            stateEl.textContent = 'Open';
            stateEl.classList.add('open');
        } else {
            stateEl.textContent = 'Unavailable';
        }

        for (const tag of Array.isArray(job.tags) ? job.tags : []) {
            const pill = createPill(tag, 'gold');
            tagsRowEl.appendChild(pill);
        }

        for (const requirement of Array.isArray(job.jobCenter && job.jobCenter.requirements) ? job.jobCenter.requirements : []) {
            const item = document.createElement('li');
            item.textContent = String(requirement);
            requirementsListEl.appendChild(item);
        }

        for (const grade of Array.isArray(job.grades) ? job.grades : []) {
            const gradeFragment = gradeTemplateEl.content.cloneNode(true);
            const gradeLabelEl = gradeFragment.querySelector('.grade-label');
            const gradePayEl = gradeFragment.querySelector('.grade-pay');
            const applyButtonEl = gradeFragment.querySelector('.apply-button');
            const permissionsRowEl = gradeFragment.querySelector('.permissions-row');

            gradeLabelEl.textContent = String(grade.label || grade.id || 'Grade');
            gradePayEl.textContent = `${String(grade.formattedPay || 'LS$0')} every ${Math.max(1, Math.floor(Number(grade.payIntervalSeconds || 900) / 60))} min on duty`;

            applyButtonEl.disabled = job.isCurrent === true || job.canApply !== true;
            applyButtonEl.addEventListener('click', () => {
                postNui('apply', { jobId: job.id, gradeId: grade.id }).catch(() => undefined);
            });

            for (const permission of Array.isArray(grade.permissions) ? grade.permissions : []) {
                permissionsRowEl.appendChild(createPill(permission, 'slate'));
            }

            gradesBlockEl.appendChild(gradeFragment);
        }

        jobsListEl.appendChild(fragment);
    }
}

function openApp(payload) {
    appEl.hidden = false;
    appEl.classList.remove('hidden');
    heroSubtitleEl.textContent = payload && payload.loading
        ? 'Loading current employment and available positions...'
        : String(payload && payload.centerId ? `Processing applications at ${payload.centerId}.` : 'Browse open jobs, accept a position, or step away from your current contract.');
    setEmploymentSummary(payload && payload.currentEmployment);
    renderJobs(payload && payload.jobs);
    signalUiOpened();
}

function closeApp() {
    appEl.classList.add('hidden');
    appEl.hidden = true;
}

window.addEventListener('message', (event) => {
    const payload = event.data;
    if (!payload || typeof payload !== 'object') {
        return;
    }

    if (payload.action === 'open') {
        openApp(payload.payload || {});
    }

    if (payload.action === 'close') {
        closeApp();
    }
});

closeButtonEl.addEventListener('click', () => {
    postNui('close').catch(() => undefined);
});

resignButtonEl.addEventListener('click', () => {
    postNui('resign').catch(() => undefined);
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        postNui('close').catch(() => undefined);
    }
});

closeApp();
signalUiReady();