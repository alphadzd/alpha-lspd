let dutyState = 'on-duty';
let currentCallsign = 'Unit-Alpha-1';
let brakeActive = false;
let mouseVisible = false;
let dispatchActive = false;
let commanderActive = false;

function showNotification(message, style, duration) {
  const notification = document.getElementById('notification');
  notification.textContent = message;
  
  notification.classList.remove('success', 'error', 'primary');
  
  if (style) {
    notification.classList.add(style);
  }
  
  notification.classList.add('show');
  setTimeout(() => {
    notification.classList.remove('show');
  }, duration || 3000);
}

function toggleMenu() {
  const menuItems = document.querySelectorAll('.menu-item');
  const officers = document.querySelectorAll('.radio-item');
  const isOpen = [...menuItems].some(item => item.classList.contains('active'));

  if (isOpen) {
    menuItems.forEach(item => item.classList.remove('active'));
    officers.forEach(officer => officer.classList.remove('hidden'));
  } else {
    menuItems.forEach(item => item.classList.add('active'));
    officers.forEach(officer => officer.classList.add('hidden'));
  }
}

function closeMenu() {
  const menuItems = document.querySelectorAll('.menu-item');
  const officers = document.querySelectorAll('.radio-item');

  menuItems.forEach(item => item.classList.remove('active'));
  officers.forEach(officer => officer.classList.remove('hidden'));
}

function toggleDuty() {
  if (dutyState === 'on-duty') {
    dutyState = 'off-duty';
    sendData('toggleDuty', { status: 'off-duty' });
    showNotification('You are now off duty');
  } else {
    dutyState = 'on-duty';
    sendData('toggleDuty', { status: 'on-duty' });
    showNotification('You are now on duty');
  }
  
  updateDutyDisplay();
  closeMenu();
}

function takeBreak() {
  dutyState = 'on-break';
  sendData('toggleDuty', { status: 'on-break' });
  showNotification('You are now on break');
  updateDutyDisplay();
  closeMenu();
}

function takeDispatch() {
  dispatchActive = !dispatchActive;
  if (dispatchActive) {
    commanderActive = false;
    sendData('toggleDispatch', { status: 'on-dispatch' });
    showNotification('You are now on dispatch');
  } else {
    sendData('toggleDispatch', { status: 'off-dispatch' });
    showNotification('You are no longer on dispatch');
  }
  closeMenu();
}

function takeCommander() {
  commanderActive = !commanderActive;
  if (commanderActive) {
    dispatchActive = false;
    sendData('toggleCommander', { status: 'on-commander' });
    showNotification('You are now commander');
  } else {
    sendData('toggleCommander', { status: 'off-commander' });
    showNotification('You are no longer commander');
  }
  closeMenu();
}

function toggleBrake() {
  brakeActive = !brakeActive;
  const brakeButton = document.getElementById('brakeButton');
  if (brakeActive) {
    brakeButton.classList.add('active-brake');
  } else {
    brakeButton.classList.remove('active-brake');
  }
  
  sendData('toggleBrake', {});
  
  showNotification(brakeActive ? 'Brake activated' : 'Brake deactivated');
  closeMenu();
}

function updateDutyDisplay() {
  const header = document.querySelector('.header h1');
  if (dutyState === 'on-duty') {
    header.innerHTML = 'Police Hub <span class="duty-status on-duty">On Duty</span>';
  } else if (dutyState === 'off-duty') {
    header.innerHTML = 'Police Hub <span class="duty-status off-duty">Off Duty</span>';
  } else if (dutyState === 'on-break') {
    header.innerHTML = 'Police Hub <span class="duty-status on-break">On Break</span>';
  }
}

function changeCallsign() {
  document.getElementById('callsignInput').value = currentCallsign;
  document.getElementById('callsignModal').classList.add('show');
  closeMenu();
}

function updateCallsign() {
  const newCallsign = document.getElementById('callsignInput').value.trim();
  if (newCallsign) {
    currentCallsign = newCallsign;
    
    sendData('changeCallsign', { callsign: newCallsign });
    
    showNotification(`Callsign updated to ${newCallsign}`);
    closeModal('callsignModal');
  } else {
    showNotification('Please enter a valid callsign', 'error');
  }
}

function openChat() {
  document.getElementById('chatModal').classList.add('show');
  
  const chatContainer = document.getElementById('chatContainer');
  if (chatContainer.children.length === 0) {
    const welcomeMessage = document.createElement('div');
    welcomeMessage.className = 'chat-message system-message';
    welcomeMessage.innerHTML = `
      <span class="chat-sender">System:</span>
      <span class="chat-text">Welcome to the police chat. All messages are sent to on-duty officers.</span>
      <span class="chat-time">${new Date().toLocaleTimeString()}</span>
    `;
    chatContainer.appendChild(welcomeMessage);
  }
  
  closeMenu();
}

function sendMessage() {
  const input = document.getElementById('chatInput');
  const message = input.value.trim();
  if (message) {
    sendData('sendChatMessage', { 
      message: message,
      callsign: currentCallsign
    });
    
    addChatMessage(currentCallsign, message, true);
    
    input.value = '';
  }
}

function addChatMessage(sender, message, isLocal) {
  const chatContainer = document.getElementById('chatContainer');
  const messageElement = document.createElement('div');
  messageElement.className = 'chat-message';
  
  if (isLocal) {
    messageElement.classList.add('local-message');
  }
  
  messageElement.innerHTML = `
    <span class="chat-sender">${sender}:</span>
    <span class="chat-text">${message}</span>
    <span class="chat-time">${new Date().toLocaleTimeString()}</span>
  `;
  
  chatContainer.appendChild(messageElement);
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

function executeCommand(command) {
  sendData('executeCommand', {
    command: '/' + command
  });
  closeMenu();
  
  if (command === 'cameras') {
    showNotification('Opening camera system...', 'primary');
  }
}

function closeModal(modalId) {
  document.getElementById(modalId).classList.remove('show');
}

function addOfficer({ id, name, callsign, grade, status, statusText, brakeActive, radioChannel }) {
  const list = document.getElementById('officersList');
  const item = document.createElement('div');
  item.className = 'radio-item animated';
  item.setAttribute('data-id', id);

  let statusClass = 'status-green';
  if (status === 'red') statusClass = 'status-red';
  if (status === 'blue') statusClass = 'status-blue';
  if (status === 'purple') statusClass = 'status-purple';
  if (status === 'yellow') statusClass = 'status-yellow';

  if (brakeActive) {
    item.classList.add('brake-active');
  }

  const displayName = callsign ? `${callsign} ${name}` : name;
  const displayGrade = grade ? `(${grade})` : '';
  const displayStatus = statusText || (status === 'green' ? 'On Duty' : status === 'red' ? 'Off Duty' : 'On Break');

  item.innerHTML = `
    <div class="status-indicator ${statusClass}" title="${displayStatus}"></div>
    <div class="radio-info">
      <span class="radio-id">${id}</span>
      <span class="radio-name">${displayName}</span>
    </div>
    <div class="radio-controls">
      <svg class="gps-icon icon" viewBox="0 0 24 24" onclick="trackOfficer(${id})">
        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zM7 9c0-2.76 2.24-5 5-5s5 2.24 5 5c0 2.33-1.95 5.9-5 9.88C8.97 14.9 7 11.33 7 9z"/>
        <circle cx="12" cy="9" r="2"/>
      </svg>
    </div>
  `;

  list.appendChild(item);
}

function trackOfficer(id) {
  sendData('trackOfficer', { id: id });
  showNotification('Requesting officer location...');

  const officers = document.querySelectorAll('.radio-item');
  officers.forEach(officer => {
    if (officer.getAttribute('data-id') == id) {
      officer.classList.add('tracking');
      setTimeout(() => {
        officer.classList.remove('tracking');
      }, 5000);
    }
  });
}

function showRadioTalk(officerId, duration = 3000) {
  const officers = document.querySelectorAll('.radio-item');
  officers.forEach(officer => {
    if (officer.getAttribute('data-id') == officerId) {
      officer.classList.remove('radio-talking');
      officer.classList.add('radio-talking');

      const statusIndicator = officer.querySelector('.status-indicator');
      if (statusIndicator) {
        statusIndicator.classList.add('status-pulse');
      }

      setTimeout(() => {
        officer.classList.remove('radio-talking');
        if (statusIndicator) {
          statusIndicator.classList.remove('status-pulse');
        }
      }, duration);
    }
  });
}



function simulateRadioChatter() {
  const officers = document.querySelectorAll('.radio-item');
  const onDutyOfficers = Array.from(officers).filter(officer => {
    const statusIndicator = officer.querySelector('.status-indicator');
    return statusIndicator && (
      statusIndicator.classList.contains('status-green') ||
      statusIndicator.classList.contains('status-purple') ||
      statusIndicator.classList.contains('status-yellow')
    );
  });

  if (onDutyOfficers.length > 0 && Math.random() < 0.3) {
    const randomOfficer = onDutyOfficers[Math.floor(Math.random() * onDutyOfficers.length)];
    const officerId = randomOfficer.getAttribute('data-id');
    if (officerId) {
      const duration = Math.random() * 3000 + 1500;
      showRadioTalk(officerId, duration);
    }
  }
}

function updateOfficersList(officers) {
  const officersList = document.getElementById('officersList');
  officersList.innerHTML = '';
  
  const countElement = document.querySelector('.count');
  if (countElement) {
    const onDutyCount = officers ? officers.filter(o => o.status === 'green' || o.status === 'purple' || o.status === 'yellow').length : 0;
    countElement.textContent = onDutyCount;
    
    if (onDutyCount === 0) {
      countElement.classList.add('no-officers');
    } else {
      countElement.classList.remove('no-officers');
    }
  }
  
  if (officers && officers.length > 0) {
    const visibleOfficers = officers.filter(officer => {
      return officer.status !== 'red' || !Config.HideOffDutyOfficers;
    });
    
    if (visibleOfficers.length > 0) {
      visibleOfficers.forEach(officer => {
        addOfficer(officer);
      });
    } else {
      const noOfficers = document.createElement('div');
      noOfficers.className = 'radio-item';
      noOfficers.innerHTML = '<div class="radio-info"><span class="radio-name">No officers currently on duty</span></div>';
      officersList.appendChild(noOfficers);
    }
  } else {
    const noOfficers = document.createElement('div');
    noOfficers.className = 'radio-item';
    noOfficers.innerHTML = '<div class="radio-info"><span class="radio-name">No officers currently on duty</span></div>';
    officersList.appendChild(noOfficers);
  }
}

document.getElementById('chatInput').addEventListener('keypress', function(e) {
  if (e.key === 'Enter') {
    sendMessage();
  }
});

document.getElementById('callsignInput').addEventListener('keypress', function(e) {
  if (e.key === 'Enter') {
    updateCallsign();
  }
});

function updateMouseVisibility() {
  const container = document.getElementById('dispatchContainer');

  if (mouseVisible) {
    container.classList.remove('no-mouse');
    showNotification('Mouse control enabled - Press F11 to toggle or ESC to hide');
  } else {
    container.classList.add('no-mouse');
    showNotification('Mouse control disabled - Press F11 to enable');
  }
}

let isDragging = false;
let moveMode = false;
let offsetX, offsetY;
let lastX, lastY;
let animationFrame;

function toggleMoveMode() {
  moveMode = !moveMode;
  const container = document.getElementById('dispatchContainer');
  const header = container.querySelector('.header');
  
  if (moveMode) {
    container.classList.add('draggable');
    header.classList.add('move-mode');
    
    const moveIndicator = document.createElement('div');
    moveIndicator.id = 'moveIndicator';
    moveIndicator.style.position = 'absolute';
    moveIndicator.style.top = '0';
    moveIndicator.style.left = '0';
    moveIndicator.style.width = '100%';
    moveIndicator.style.textAlign = 'center';
    moveIndicator.style.padding = '2px 0';
    moveIndicator.style.fontSize = '10px';
    moveIndicator.style.backgroundColor = 'rgba(0,0,0,0.5)';
    moveIndicator.style.color = '#fff';
    moveIndicator.textContent = '● MOVE & RESIZE MODE - DRAG TO MOVE, USE HANDLES TO RESIZE ●';
    container.appendChild(moveIndicator);

    showNotification('Move & Resize mode activated. Drag to move, use handles to resize. Press ESC to save.', 'primary');
    
    container.addEventListener('mousedown', startDrag);
    document.addEventListener('mousemove', handleDrag);
    document.addEventListener('mouseup', endDrag);

    if (!container.hasAttribute('data-resize-initialized')) {
      initializeResize();
      container.setAttribute('data-resize-initialized', 'true');
    }

    document.addEventListener('keydown', exitMoveMode);
  } else {
    container.classList.remove('draggable');
    container.classList.remove('dragging');
    header.classList.remove('move-mode');
    
    const moveIndicator = document.getElementById('moveIndicator');
    if (moveIndicator) {
      moveIndicator.remove();
    }
    
    showNotification('Position saved', 'success');
    
    container.removeEventListener('mousedown', startDrag);
    document.removeEventListener('mousemove', handleDrag);
    document.removeEventListener('mouseup', endDrag);
    document.removeEventListener('keydown', exitMoveMode);
    
    if (animationFrame) {
      cancelAnimationFrame(animationFrame);
    }
    
    savePosition();
  }
  
  closeMenu();
}

function exitMoveMode(e) {
  if (e.key === 'Escape' && moveMode) {
    toggleMoveMode();
  }
}

function startDrag(e) {
  if (!moveMode || isResizing) return;
  if (e.target.classList.contains('resize-handle')) return;

  isDragging = true;
  const container = document.getElementById('dispatchContainer');
  
  container.classList.add('dragging');
  
  const rect = container.getBoundingClientRect();
  offsetX = e.clientX - rect.left;
  offsetY = e.clientY - rect.top;
  
  lastX = rect.left;
  lastY = rect.top;
  
  e.preventDefault();
  
  animationFrame = requestAnimationFrame(updatePosition);
}

function handleDrag(e) {
  if (!isDragging) return;
  
  lastX = e.clientX - offsetX;
  lastY = e.clientY - offsetY;
}

function updatePosition() {
  if (!isDragging) return;

  const container = document.getElementById('dispatchContainer');
  const maxX = window.innerWidth - container.offsetWidth;
  const maxY = window.innerHeight - container.offsetHeight;
  
  const rect = container.getBoundingClientRect();
  let currentX = rect.left;
  let currentY = rect.top;
  
  let newX = currentX + (lastX - currentX) * 0.5;
  let newY = currentY + (lastY - currentY) * 0.5;
  
  if (isShiftKeyPressed) {
    const gridSize = 20;
    newX = Math.round(newX / gridSize) * gridSize;
    newY = Math.round(newY / gridSize) * gridSize;
    
    const moveIndicator = document.getElementById('moveIndicator');
    if (moveIndicator) {
      moveIndicator.textContent = '● GRID SNAP ACTIVE - PRECISE POSITIONING ●';
      moveIndicator.style.backgroundColor = 'rgba(46, 204, 113, 0.7)';
    }
  } else {
    const moveIndicator = document.getElementById('moveIndicator');
    if (moveIndicator) {
      moveIndicator.textContent = '● MOVE & RESIZE MODE - DRAG TO MOVE, USE HANDLES TO RESIZE ●';
      moveIndicator.style.backgroundColor = 'rgba(0, 0, 0, 0.5)';
    }
  }
  
  newX = Math.max(0, Math.min(newX, maxX));
  newY = Math.max(0, Math.min(newY, maxY));
  
  container.style.right = 'auto';
  container.style.margin = '0';
  container.style.left = newX + 'px';
  container.style.top = newY + 'px';
  
  animationFrame = requestAnimationFrame(updatePosition);
}

let isShiftKeyPressed = false;

document.addEventListener('keydown', function(e) {
  if (e.key === 'Shift') {
    isShiftKeyPressed = true;
  }
});

document.addEventListener('keyup', function(e) {
  if (e.key === 'Shift') {
    isShiftKeyPressed = false;
  }
});

function endDrag() {
  if (!isDragging) return;

  isDragging = false;
  const container = document.getElementById('dispatchContainer');
  container.classList.remove('dragging');
  
  if (animationFrame) {
    cancelAnimationFrame(animationFrame);
  }
  
  setTimeout(savePosition, 100);
}

function savePosition() {
  const container = document.getElementById('dispatchContainer');
  const position = {
    left: container.style.left,
    top: container.style.top,
    width: container.style.width,
    height: container.style.height
  };

  sendData('savePosition', position);
}

let isResizing = false;
let resizeType = '';
let startX, startY, startWidth, startHeight, startLeft, startTop;

function initializeResize() {
  const container = document.getElementById('dispatchContainer');
  const topHandle = container.querySelector('.resize-handle-top');
  const rightHandle = container.querySelector('.resize-handle-right');
  const bottomHandle = container.querySelector('.resize-handle-bottom');
  const leftHandle = container.querySelector('.resize-handle-left');
  const cornerTL = container.querySelector('.resize-handle-corner-tl');
  const cornerTR = container.querySelector('.resize-handle-corner-tr');
  const cornerBL = container.querySelector('.resize-handle-corner-bl');
  const cornerBR = container.querySelector('.resize-handle-corner-br');

  topHandle.addEventListener('mousedown', (e) => startResize(e, 'top'));
  rightHandle.addEventListener('mousedown', (e) => startResize(e, 'right'));
  bottomHandle.addEventListener('mousedown', (e) => startResize(e, 'bottom'));
  leftHandle.addEventListener('mousedown', (e) => startResize(e, 'left'));
  cornerTL.addEventListener('mousedown', (e) => startResize(e, 'corner-tl'));
  cornerTR.addEventListener('mousedown', (e) => startResize(e, 'corner-tr'));
  cornerBL.addEventListener('mousedown', (e) => startResize(e, 'corner-bl'));
  cornerBR.addEventListener('mousedown', (e) => startResize(e, 'corner-br'));

  document.addEventListener('mousemove', handleResize);
  document.addEventListener('mouseup', stopResize);
}

function startResize(e, type) {
  isResizing = true;
  resizeType = type;
  const container = document.getElementById('dispatchContainer');
  const rect = container.getBoundingClientRect();

  startX = e.clientX;
  startY = e.clientY;
  startWidth = rect.width;
  startHeight = rect.height;
  startLeft = rect.left;
  startTop = rect.top;

  e.preventDefault();
  e.stopPropagation();
  container.style.userSelect = 'none';
  container.classList.add('resizing');
}

function handleResize(e) {
  if (!isResizing) return;

  const container = document.getElementById('dispatchContainer');
  const deltaX = e.clientX - startX;
  const deltaY = e.clientY - startY;

  let newWidth = startWidth;
  let newHeight = startHeight;
  let newLeft = startLeft;
  let newTop = startTop;

  const minWidth = 200;
  const maxWidth = 500;
  const minHeight = 300;
  const maxHeight = window.innerHeight * 0.8;

  switch (resizeType) {
    case 'top':
      newHeight = Math.max(minHeight, Math.min(maxHeight, startHeight - deltaY));
      newTop = startTop + (startHeight - newHeight);
      break;

    case 'right':
      newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + deltaX));
      break;

    case 'bottom':
      newHeight = Math.max(minHeight, Math.min(maxHeight, startHeight + deltaY));
      break;

    case 'left':
      newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth - deltaX));
      newLeft = startLeft + (startWidth - newWidth);
      break;

    case 'corner-tl':
      newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth - deltaX));
      newHeight = Math.max(minHeight, Math.min(maxHeight, startHeight - deltaY));
      newLeft = startLeft + (startWidth - newWidth);
      newTop = startTop + (startHeight - newHeight);
      break;

    case 'corner-tr':
      newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + deltaX));
      newHeight = Math.max(minHeight, Math.min(maxHeight, startHeight - deltaY));
      newTop = startTop + (startHeight - newHeight);
      break;

    case 'corner-bl':
      newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth - deltaX));
      newHeight = Math.max(minHeight, Math.min(maxHeight, startHeight + deltaY));
      newLeft = startLeft + (startWidth - newWidth);
      break;

    case 'corner-br':
      newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + deltaX));
      newHeight = Math.max(minHeight, Math.min(maxHeight, startHeight + deltaY));
      break;
  }

  container.style.width = newWidth + 'px';
  container.style.height = newHeight + 'px';
  container.style.left = newLeft + 'px';
  container.style.top = newTop + 'px';
}

function stopResize() {
  if (isResizing) {
    isResizing = false;
    resizeType = '';
    const container = document.getElementById('dispatchContainer');
    container.style.userSelect = '';
    container.classList.remove('resizing');

    savePosition();
  }
}

window.addEventListener('load', function() {
  setTimeout(() => {
    showNotification('Welcome to Police Hub Interface');
  }, 1000);

  updateOfficersList([]);

  setInterval(simulateRadioChatter, 20000);

  setTimeout(() => {
    setInterval(simulateRadioChatter, 35000);
  }, 10000);
});

document.addEventListener('keydown', function(event) {
  if (event.key === 'Escape' && mouseVisible) {
    mouseVisible = false;
    sendData('hidemouse', {});
  }
});

window.addEventListener('message', function(event) {
  const data = event.data;
  
  if (data.type === "ui") {
    if (data.status) {
      document.getElementById('dispatchContainer').style.display = 'block';

      if (data.mouseVisible !== undefined) {
        mouseVisible = data.mouseVisible;
        updateMouseVisibility();
      }
    } else {
      document.getElementById('dispatchContainer').style.display = 'none';
    }
  }
  
  if (data.type === "mouseVisibility") {
    mouseVisible = data.visible;
    updateMouseVisibility();
  }
  
  if (data.type === "loadCallsign") {
    if (data.callsign) {
      currentCallsign = data.callsign;
      showNotification("Callsign loaded: " + data.callsign, "primary");
    }
  }
  
  if (data.type === "loadPosition") {
    if (data.position) {
      const container = document.getElementById('dispatchContainer');
      container.style.right = 'auto';
      container.style.margin = '0';
      container.style.left = data.position.left;
      container.style.top = data.position.top;
      if (data.position.width) {
        container.style.width = data.position.width;
      }
      if (data.position.height) {
        container.style.height = data.position.height;
      }
    }
  }
  
  if (data.type === "openCameras") {
    showNotification("Opening camera system...", "success");
  }
  
  if (data.type === "updateOfficers") {
    updateOfficersList(data.data);
    
    const countElement = document.querySelector('.count');
    if (countElement && data.count !== undefined) {
      countElement.textContent = data.count;
      
      if (data.count === 0) {
        countElement.classList.add('no-officers');
      } else {
        countElement.classList.remove('no-officers');
      }
    }
  }
  
  if (data.type === "chatMessage") {
    addChatMessage(data.sender, data.message, false);
  }
  
  if (data.type === "officerTracked") {
    const officers = document.querySelectorAll('.radio-item');
    officers.forEach(officer => {
      if (officer.getAttribute('data-id') == data.id) {
        officer.classList.add('tracked');
        setTimeout(() => {
          officer.classList.remove('tracked');
        }, 3000);
      }
    });
  }
  
  if (data.type === "brakeStatus") {
    brakeActive = data.active;
    
    const brakeButton = document.getElementById('brakeButton');
    if (brakeButton) {
      if (brakeActive) {
        brakeButton.classList.add('active-brake');
      } else {
        brakeButton.classList.remove('active-brake');
      }
    }
  }
  
  if (data.type === "notification") {
    showNotification(data.message, data.style, data.duration);
  }

  if (data.type === "radioTalk") {
    showRadioTalk(data.officerId, data.duration || 3000);
  }
});

function sendData(name, data) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  });
}

function placeCamera(event) {
  const rect = event.target.getBoundingClientRect();
  const x = ((event.clientX - rect.left) / rect.width) * 100;
  const y = ((event.clientY - rect.top) / rect.height) * 100;
  
  const newCamera = document.createElement('div');
  newCamera.className = 'camera-marker';
  newCamera.style.top = y + '%';
  newCamera.style.left = x + '%';
  newCamera.setAttribute('data-type', 'security');
  
  document.querySelector('.map-container').appendChild(newCamera);
  
  const cameraName = prompt("Enter camera name:", "New Camera");
  if (cameraName) {
    const cameraDesc = prompt("Enter camera description:", "Security camera");
    
    sendData('placeCamera', {
      x: x,
      y: y,
      type: 'security',
      label: cameraName,
      description: cameraDesc
    });
    
    showNotification('New camera placed');
  } else {
    newCamera.remove();
  }
}

function closeMap() {
  document.getElementById('mapModal').classList.remove('show');
  if (activeCamera) {
    activeCamera.classList.remove('active');
    activeCamera = null;
  }
  document.getElementById('cameraInfo').style.display = 'none';
  
  sendData('closeMap', {});
}
