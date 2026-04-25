const app = document.getElementById('app')
const keypad = document.getElementById('keypad')
const catalog = document.getElementById('catalog')
const kiosk = document.getElementById('kiosk')
const closet = document.getElementById('closet')
const display = document.getElementById('display')
const catalogList = document.getElementById('catalogList')
const ownedList = document.getElementById('ownedList')
const availableList = document.getElementById('availableList')
const closetList = document.getElementById('closetList')
const toast = document.getElementById('toast')

let currentInput = ''
let toastTimeout = null

document.documentElement.style.background = 'transparent'
document.documentElement.style.backgroundColor = 'transparent'
document.documentElement.classList.add('nui-closed')
document.body.style.background = 'transparent'
document.body.style.backgroundColor = 'transparent'
document.body.style.display = 'none'
document.body.style.visibility = 'hidden'
document.body.style.opacity = '0'
document.body.classList.add('nui-closed')
document.body.classList.remove('nui-open')

function hideHousingShell() {
  document.documentElement.classList.remove('nui-open')
  document.documentElement.classList.add('nui-closed')
  document.body.classList.remove('nui-open')
  document.body.classList.add('nui-closed')
  document.body.style.display = 'none'
  document.body.style.visibility = 'hidden'
  document.body.style.opacity = '0'
  document.body.style.background = 'transparent'
  document.body.style.backgroundColor = 'transparent'
  app.classList.remove('active')
  app.classList.add('hidden')
  app.style.display = 'none'
  app.setAttribute('aria-hidden', 'true')
}

function showHousingShell(panel) {
  document.documentElement.classList.remove('nui-closed')
  document.documentElement.classList.add('nui-open')
  document.body.classList.remove('nui-closed')
  document.body.classList.add('nui-open')
  document.body.style.display = 'block'
  document.body.style.visibility = 'visible'
  document.body.style.opacity = '1'
  document.body.style.background = 'transparent'
  document.body.style.backgroundColor = 'transparent'
  app.classList.add('active')
  app.classList.remove('hidden')
  app.style.display = ''
  app.setAttribute('aria-hidden', 'false')
  panel.classList.remove('hidden')
}

function post(name, payload = {}) {
  return fetch(`https://lsrp_housing/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).catch(() => null)
}

function setVisible(panel) {
  keypad.classList.add('hidden')
  catalog.classList.add('hidden')
  kiosk.classList.add('hidden')
  closet.classList.add('hidden')

  if (panel) {
    showHousingShell(panel)
  } else {
    hideHousingShell()
  }
}

function renderClosetList(items) {
  closetList.innerHTML = ''

  if (!Array.isArray(items) || items.length === 0) {
    renderEmptyState(closetList, 'You do not have any saved outfits yet.')
    return
  }

  items.forEach((item) => {
    const card = document.createElement('div')
    card.className = 'card'

    const top = document.createElement('div')
    top.className = 'card-top'
    top.innerHTML = `
      <div class="card-title">${item.name || `Outfit ${item.slot || ''}`}</div>
      <div>Slot ${item.slot || ''}</div>
    `

    const actions = document.createElement('div')
    actions.className = 'card-actions'
    const button = document.createElement('button')
    button.className = 'accent-primary'
    button.textContent = 'Change'
    button.addEventListener('click', () => {
      post('applyClosetOutfit', { slot: item.slot })
    })
    actions.appendChild(button)

    card.appendChild(top)
    card.appendChild(actions)
    closetList.appendChild(card)
  })
}

function setDisplay(value) {
  currentInput = value || ''
  display.textContent = currentInput || ' '
}

function showToast(message, success) {
  if (!message) {
    return
  }

  toast.textContent = message
  toast.classList.remove('hidden', 'success', 'error')
  toast.classList.add(success ? 'success' : 'error')

  if (toastTimeout) {
    window.clearTimeout(toastTimeout)
  }

  toastTimeout = window.setTimeout(() => {
    toast.classList.add('hidden')
  }, 3500)
}

function renderEmptyState(container, message) {
  container.innerHTML = ''
  const element = document.createElement('div')
  element.className = 'empty-state'
  element.textContent = message
  container.appendChild(element)
}

function renderApartmentList(container, items, actionLabel, actionName, includeRentDue) {
  container.innerHTML = ''

  if (!Array.isArray(items) || items.length === 0) {
    renderEmptyState(container, actionName === 'payRent' ? 'You do not own any apartments.' : 'No apartments are available right now.')
    return
  }

  items.forEach((item) => {
    const card = document.createElement('div')
    card.className = 'card'

    const top = document.createElement('div')
    top.className = 'card-top'
    top.innerHTML = `
      <div class="card-title">Apartment ${item.apartment_number || ''}</div>
      <div>${item.location_label || ''}</div>
    `

    const meta = document.createElement('div')
    meta.className = 'card-meta'
    meta.innerHTML = `
      <div>Rent: LS$${Number(item.price || 0).toLocaleString()}</div>
      ${includeRentDue ? `<div>Next due: ${item.rent_due || 'Not set'}</div>` : ''}
    `

    const actions = document.createElement('div')
    actions.className = 'card-actions'
    const button = document.createElement('button')
    button.className = 'accent-primary'
    button.textContent = actionLabel
    button.addEventListener('click', () => {
      post(actionName, { apartment: item.apartment_number, price: item.price })
    })
    actions.appendChild(button)

    card.appendChild(top)
    card.appendChild(meta)
    card.appendChild(actions)
    container.appendChild(card)
  })
}

document.querySelectorAll('.digit').forEach((button) => {
  button.addEventListener('click', () => {
    setDisplay(`${currentInput}${button.textContent}`)
  })
})

document.getElementById('clearKeypad').addEventListener('click', () => {
  setDisplay('')
})

document.getElementById('submitKeypad').addEventListener('click', () => {
  post('enterApartment', { apartment: currentInput })
})

document.querySelectorAll('[data-close]').forEach((button) => {
  button.addEventListener('click', () => {
    post(button.dataset.close)
  })
})

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    post('close')
  }
})

window.addEventListener('message', (event) => {
  const data = event.data || {}

  switch (data.action) {
    case 'openKeypad':
      setVisible(keypad)
      setDisplay('')
      break
    case 'openCatalog':
      setVisible(catalog)
      break
    case 'openKiosk':
      setVisible(kiosk)
      break
    case 'openCloset':
      setVisible(closet)
      break
    case 'closeAll':
      setVisible(null)
      setDisplay('')
      toast.classList.add('hidden')
      break
    case 'populateCatalog':
      renderApartmentList(catalogList, data.items, 'Rent', 'rentApartment', false)
      break
    case 'populateOwned':
      renderApartmentList(ownedList, data.items, 'Pay Rent', 'payRent', true)
      break
    case 'populateAvailable':
      renderApartmentList(availableList, data.items, 'Rent', 'rentApartment', false)
      break
    case 'populateCloset':
      renderClosetList(data.items)
      break
    case 'toast':
      showToast(data.message, data.success === true)
      break
    default:
      break
  }
})

setVisible(null)
window.addEventListener('load', () => {
  post('uiReady')
})