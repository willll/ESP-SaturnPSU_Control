// D1 Control UI Logic
const statusEl = document.getElementById('status');
const debugEl = document.getElementById('debug');
const btnOn = document.getElementById('btnOn');
const btnOff = document.getElementById('btnOff');
const latchInput = document.getElementById('latchSeconds');
let lastState = 0;
let latchTimer = null;

function logDebug(message) {
  const timestamp = new Date().toLocaleTimeString();
  const line = `[${timestamp}] ${message}`;
  if (debugEl.textContent === 'Debug log...') {
    debugEl.textContent = line;
  } else {
    debugEl.textContent += '\n' + line;
  }
  debugEl.scrollTop = debugEl.scrollHeight;
}

function getLatchMs() {
  const seconds = Number.parseInt(latchInput.value, 10);
  return Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : 0;
}

function updateButtons(state) {
  btnOn.classList.toggle('active', state === 1);
  btnOff.classList.toggle('active', state === 0);
}

async function refresh() {
  try {
    const res = await fetch('/api/status');
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    let data;
    try {
      data = await res.json();
    } catch (jsonErr) {
      logDebug(`Failed to parse status JSON: ${jsonErr}`);
      statusEl.textContent = 'Status: ERROR';
      return;
    }
    if (typeof data.d1 !== 'number') {
      logDebug('Malformed status response');
      statusEl.textContent = 'Status: ERROR';
      return;
    }
    lastState = data.d1 === 1 ? 1 : 0;
    statusEl.textContent = `D1 is ${lastState === 1 ? 'ON' : 'OFF'}`;
    updateButtons(lastState);
    logDebug('Status refreshed');
  } catch (err) {
    logDebug(`Status refresh failed: ${err}`);
    statusEl.textContent = 'Status: ERROR';
  }
}

async function sendAction(action) {
  try {
    const res = await fetch(`/api/${action}`, { method: 'POST' });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return true;
  } catch (err) {
    logDebug(`API request failed: ${err}`);
    throw err;
  }
}

async function applyState(action, scheduleLatch) {
  const previousState = lastState;
  if (latchTimer) {
    clearTimeout(latchTimer);
    latchTimer = null;
  }

  try {
    await sendAction(action);
    await refresh();
    logDebug(`Action: ${action}`);
  } catch (err) {
    logDebug(`Action failed: ${err}`);
    // Optionally, show a UI error or disable buttons here
    return;
  }

  if (!scheduleLatch) {
    return;
  }

  const latchMs = getLatchMs();
  if (latchMs === 0) {
    return;
  }

  // Always revert to the opposite state after latch period
  latchTimer = setTimeout(() => {
    const revertAction = action === 'on' ? 'off' : 'on';
    logDebug(`Latch expired, reverting to ${revertAction.toUpperCase()}`);
    applyState(revertAction, false);
  }, latchMs);
}

async function setState(action) {
  const desiredAction = action === 'toggle'
    ? (lastState === 1 ? 'off' : 'on')
    : action;
  await applyState(desiredAction, true);
}

document.getElementById('btnOn').onclick = () => setState('on');
document.getElementById('btnOff').onclick = () => setState('off');
document.querySelector('button[onclick*="toggle"]').onclick = () => setState('toggle');
document.querySelector('button[onclick*="refresh"]').onclick = () => refresh();

refresh();
