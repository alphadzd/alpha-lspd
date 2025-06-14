// Global information
let currentJobData = {};
let appSettings = {
    darkMode: true,
    showAnimations: true,
    compactView: false,
    notificationSound: 'default',
    themeColor: 'orange',
    refreshInterval: 60,
    showPlaytime: true,
    showLocation: true
};
let autoRefreshTimer = null;
let societyData = {
    balance: 0,
    name: '',
    transactions: []
};
let currentTransactionAction = null;
let isRefreshingJobData = false;
let currentApplications = [];
let currentApplicationDetails = null;
let currentApplicationQuestions = [];
let chartInstance = null;
let currentTimeframe = 'week';
let currentEmployeePermissions = {};
let selectedEmployeeForPermissions = null;
let currentJobGrades = {};
let playerTimeOffset = null;


// Helper Functions
function formatTime(minutes, showSession) {
    if (minutes === null || minutes === undefined || minutes === 0 || minutes === '') {
        return 'Loading...';  
    }
    minutes = parseInt(minutes);
    
    if (minutes < 60) {
        return `${minutes} min`;
    } else {
        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        return `${hours} hr${hours > 1 ? 's' : ''} ${mins > 0 ? mins + ' min' : ''}`;
    }
}



function getInitials(name) {
    if (!name) return '??';
    const parts = name.split(' ');
    if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return (parts[0][0] + (parts[0][1] || '')).toUpperCase();
}

function showNotification(message) {
    const notification = document.getElementById('notification');
    notification.textContent = message;
    notification.classList.add('show');
    
    // Play notification sound if enabled
    if (appSettings.notificationSound !== 'none') {
        // In a real system, we would play a sound here
    }
    
    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}

// Function to add Applications tab to sidebar
function addApplicationsTab() {
    // Function to create and add the tab
    function createApplicationsTab() {
        // Check if applications tab already exists to avoid duplicates
        if (document.querySelector('.nav-item[data-page="applications"]')) {
            return;
        }
        
        // Find the settings item in the sidebar
        const settingsItem = document.querySelector('.nav-item[data-page="settings"]');
        if (!settingsItem) {
            // If settings item not found yet, retry after a short delay
            setTimeout(createApplicationsTab, 500);
            return;
        }
        
        // Create the applications tab
        const applicationsItem = document.createElement('a');
        applicationsItem.className = 'nav-item';
        applicationsItem.setAttribute('data-page', 'applications');
        applicationsItem.innerHTML = `
            <i class="fas fa-file-alt"></i>
            <span>Applications</span>
        `;
        
        // Insert before settings
        settingsItem.parentNode.insertBefore(applicationsItem, settingsItem);        
        // Add click event to the new tab
        applicationsItem.addEventListener('click', function() {
            // Show applications page and hide other pages
            document.querySelectorAll('.page').forEach(page => {
                page.classList.remove('active');
            });
            document.getElementById('applications-page').classList.add('active');
            
            // Update active navigation
            document.querySelectorAll('.nav-item').forEach(navItem => {
                navItem.classList.remove('active');
            });
            this.classList.add('active');
            
            // Refresh applications data
            refreshApplications();
        });
    }
    
    // Start the process
    createApplicationsTab();
}

function setupHireEmployeeModal() {
    // Add event listener to the Hire Employee button
    const hireEmployeeBtn = document.getElementById('hire-employee-btn');
    if (hireEmployeeBtn) {
        hireEmployeeBtn.addEventListener('click', function() {
            openHireModal();
        });
    }

    // Add event listener to the confirm hire button
    const confirmHireBtn = document.getElementById('confirm-hire-btn');
    if (confirmHireBtn) {
        confirmHireBtn.addEventListener('click', function() {
            hireNewEmployee();
        });
    }
}

function openHireModal() {    
    // Clear previous values
    document.getElementById('hire-id').value = '';
    
    // Fill the rank dropdown with available ranks
    const rankSelect = document.getElementById('hire-rank');
    rankSelect.innerHTML = '';
    
    if (currentJobData && currentJobData.grades) {
        Object.keys(currentJobData.grades).forEach(grade => {
            const option = document.createElement('option');
            option.value = grade;
            option.textContent = `${currentJobData.grades[grade].name} (${grade})`;
            rankSelect.appendChild(option);
        });
    } else {
        console.error("No job grades available");
        // Add a default option if no grades are available
        const option = document.createElement('option');
        option.value = "0";
        option.textContent = "Default Grade (0)";
        rankSelect.appendChild(option);
    }
    
    // Show the modal
    const modal = document.getElementById('hire-employee-modal');
    if (modal) {
        modal.classList.add('show');
    } else {
        console.error("Hire employee modal not found");
    }
}

function hireNewEmployee() {
    const playerId = document.getElementById('hire-id').value;
    const rankValue = document.getElementById('hire-rank').value;
    
    if (!playerId || playerId === '') {
        showNotification('Please enter a player ID', 'error');
        return;
    }
    
    if (!rankValue) {
        showNotification('Please select a rank', 'error');
        return;
    }
    
    if (!currentJobData || !currentJobData.jobName) {
        showNotification('Job data not available', 'error');
        return;
    }
    
    // Send the hire request to the server
    fetch(`https://${GetParentResourceName()}/hireEmployee`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            targetId: playerId,
            jobName: currentJobData.jobName,
            grade: rankValue
        })
    })
    .then(resp => resp.json())
    .then(result => {
        if (result.success) {
            showNotification('Employee hired successfully', 'success');
            document.getElementById('hire-employee-modal').classList.remove('show');
            
            // Refresh job data after successful hire
            setTimeout(refreshJobData, 1000);
        } else {
            showNotification(result.message || 'Failed to hire employee', 'error');
        }
    })
    .catch(error => {
        console.error('Error hiring employee:', error);
        showNotification('Error hiring employee', 'error');
    });
}


// Function to ensure Applications tab exists after UI is opened
function ensureApplicationsTabExists() {
    // Check if the Applications tab exists
    if (!document.querySelector('.nav-item[data-page="applications"]')) {
        
        // Find the settings item
        const settingsItem = document.querySelector('.nav-item[data-page="settings"]');
        if (settingsItem) {
            // Create the applications tab
            const applicationsItem = document.createElement('a');
            applicationsItem.className = 'nav-item';
            applicationsItem.setAttribute('data-page', 'applications');
            applicationsItem.innerHTML = `
                <i class="fas fa-file-alt"></i>
                <span>Applications</span>
            `;
            
            // Insert before settings
            settingsItem.parentNode.insertBefore(applicationsItem, settingsItem);
            
            // Add click event to the new tab
            applicationsItem.addEventListener('click', function() {
                // Show applications page and hide other pages
                document.querySelectorAll('.page').forEach(page => {
                    page.classList.remove('active');
                });
                document.getElementById('applications-page').classList.add('active');
                
                // Update active navigation
                document.querySelectorAll('.nav-item').forEach(navItem => {
                    navItem.classList.remove('active');
                });
                this.classList.add('active');
                
                // Refresh applications data
                refreshApplications();
            });
        } else {
            console.log("Settings item not found during UI open");
        }
    }
}   


function refreshApplications() {
    if (!currentJobData || !currentJobData.jobName) {
        return;
    }
    
    console.log("Refreshing applications for job: " + currentJobData.jobName);
    
    fetch(`https://${GetParentResourceName()}/getApplications`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            jobName: currentJobData.jobName
        })
    })
    .then(resp => resp.json())
    .then(applications => {
        if (applications) {
            currentApplications = applications;
            updateApplicationsTable();
            updateApplicationsCount();
        }
    })
    .catch(err => {
        console.error('Error refreshing applications:', err);
    });
}

// Update applications table
function updateApplicationsTable() {
    const tableBody = document.getElementById('applications-table');
    if (!tableBody) {
        console.error("Applications table not found");
        return;
    }
    
    tableBody.innerHTML = '';
    
    if (!currentApplications || currentApplications.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="4" class="empty-table">No applications to display</td></tr>';
        return;
    }
    
    // Get active filter
    const activeFilterEl = document.querySelector('.applications-container .tab.active');
    if (!activeFilterEl) {
        console.error("No active filter tab found");
        return;
    }
    
    const activeFilter = activeFilterEl.getAttribute('data-filter');
    const searchEl = document.getElementById('search-application');
    if (!searchEl) {
        console.error("Search application input not found");
        return;
    }
    
    const searchTerm = searchEl.value.toLowerCase();
    
    // Filter applications
    const filteredApplications = currentApplications.filter(app => {
        const matchesFilter = activeFilter === 'all' || app.status === activeFilter;
        const matchesSearch = app.name.toLowerCase().includes(searchTerm);
        return matchesFilter && matchesSearch;
    });
    
    if (filteredApplications.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="4" class="empty-table">No matching applications</td></tr>';
        return;
    }
    
    filteredApplications.forEach(application => {
        const tr = document.createElement('tr');
        tr.setAttribute('data-id', application.id);
        tr.setAttribute('data-status', application.status);
        
        // Format date
        const submittedDate = new Date(application.date_submitted);
        const formattedDate = `${submittedDate.toLocaleDateString()} ${submittedDate.toLocaleTimeString()}`;
        
        // Status class
        let statusClass = '';
        let statusText = application.status;
        
        switch(application.status) {
            case 'pending':
                statusClass = 'status-warning';
                statusText = 'Pending';
                break;
            case 'accepted':
                statusClass = 'status-success';
                statusText = 'Accepted';
                break;
            case 'rejected':
                statusClass = 'status-danger';
                statusText = 'Rejected';
                break;
            case 'finish':
                statusClass = 'status-success';
                statusText = 'Finished';
                break;
        }
        
        tr.innerHTML = `
            <td>${application.name}</td>
            <td>${formattedDate}</td>
            <td><span class="status ${statusClass}">${statusText}</span></td>
            <td>
                <div class="employee-actions">
                    <div class="action-btn view-application" data-id="${application.id}"><i class="fas fa-eye"></i></div>
                </div>
            </td>
        `;
        
        tableBody.appendChild(tr);
    });
    
    // Add event listeners to view buttons
    document.querySelectorAll('.view-application').forEach(btn => {
        btn.addEventListener('click', function() {
            const applicationId = this.getAttribute('data-id');
            openApplicationDetails(applicationId);
        });
    });
}

// Update applications count
function updateApplicationsCount() {
    const countEl = document.getElementById('applications-count');
    if (!countEl) {
        console.error("Applications count element not found");
        return;
    }
    
    const pendingCount = currentApplications.filter(app => app.status === 'pending').length;
    countEl.textContent = `${pendingCount} pending applications`;
}

// Open application details
function openApplicationDetails(applicationId) {
    const application = currentApplications.find(app => app.id == applicationId);
    if (!application) return;
    
    currentApplicationDetails = application;
    
    // Update details modal
    document.getElementById('applicant-name').textContent = application.name;
    
    const submittedDate = new Date(application.date_submitted);
    document.getElementById('application-date').textContent = `Submitted on: ${submittedDate.toLocaleDateString()} ${submittedDate.toLocaleTimeString()}`;
    
    // Handle status with proper class
    const statusElement = document.getElementById('application-status');
    let statusText = 'Unknown';
    let statusClass = '';
    
    switch(application.status) {
        case 'pending':
            statusText = 'Pending Review';
            statusClass = 'status-pending';
            break;
        case 'accepted':
            statusText = 'Accepted';
            statusClass = 'status-accepted';
            break;
        case 'rejected':
            statusText = 'Rejected';
            statusClass = 'status-rejected';
            break;
        case 'finish':
            statusText = 'Finished';
            statusClass = 'status-finished';
            break;
    }
    
    statusElement.textContent = `Status: ${statusText}`;
    
    // Reset all status classes then add the appropriate one
    statusElement.classList.remove('status-pending', 'status-accepted', 'status-rejected', 'status-finished');
    statusElement.classList.add(statusClass);
    
    // Update notes
    document.getElementById('application-notes').value = application.notes || '';

    document.getElementById('accept-application-btn').style.display = '';
    document.getElementById('reject-application-btn').style.display = '';
    document.getElementById('finish-application-btn').style.display = ''; 
    
    // Generate responses
    const responsesContainer = document.getElementById('application-responses-container');
    responsesContainer.innerHTML = '';
    
    application.answers.forEach((answer, index) => {
        const responseItem = document.createElement('div');
        responseItem.className = 'response-item';
        
        const question = document.createElement('div');
        question.className = 'response-question';
        question.textContent = answer.question;
        
        const answerElement = document.createElement('div');
        answerElement.className = 'response-answer';
        answerElement.textContent = answer.answer;
        
        responseItem.appendChild(question);
        responseItem.appendChild(answerElement);
        responsesContainer.appendChild(responseItem);
    });
    
    if (application.answers.length > 4) {
        responsesContainer.classList.add('many-responses');
    } else {
        responsesContainer.classList.remove('many-responses');
    }
    
    // Show modal with animation
    const modal = document.getElementById('application-details-modal');
    modal.classList.add('show');
    
    // Add animation if we're using showAnimations setting
    if (appSettings && appSettings.showAnimations) {
        modal.querySelector('.modal-content').style.animation = 'fadeInDown 0.3s ease forwards';
    }
    
    document.getElementById('accept-application-btn').onclick = function() {
        updateApplicationStatus('accepted');
    };
    
    document.getElementById('reject-application-btn').onclick = function() {
        updateApplicationStatus('rejected');
    };
    
    document.getElementById('finish-application-btn').onclick = function() {
        updateApplicationStatus('finish');
    };
    
    function updateApplicationStatus(status) {
        if (!currentApplicationDetails) return;
        
        const notes = document.getElementById('application-notes').value;
        
        fetch(`https://${GetParentResourceName()}/updateApplicationStatus`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                applicationId: currentApplicationDetails.id,
                status: status,
                notes: notes
            })
        })
        .then(response => {
            showNotification(`Application ${status} successfully`);
            document.getElementById('application-details-modal').classList.remove('show');
            setTimeout(refreshApplications, 1000);
        })
        .catch(error => {
            console.error(`Error ${status} application:`, error);
            showNotification(`Error updating application`, 'error');
        });
    }
}

// Apply theme color based on selection
function applyThemeColor(color) {
    // Define color values for each theme
    const themes = {
        'blue': {
            primary: '#4a6cfa',
            primaryDark: '#3a56c8',
            secondary: '#6c87fa',
            accent: '#fa4a6c'
        },
        'purple': {
            primary: '#a64afa',
            primaryDark: '#8438d8',
            secondary: '#c26cfa',
            accent: '#fa4a6c'
        },
        'green': {
            primary: '#4afa6c',
            primaryDark: '#38d854',
            secondary: '#6cfa87',
            accent: '#fa4a6c'
        },
        'red': {
            primary: '#fa4a4a',
            primaryDark: '#d83838',
            secondary: '#fa6c6c',
            accent: '#4a6cfa'
        },
        'orange': {
            primary: '#0cb9e4',
            primaryDark: '#0a9bc4',
            secondary: '#33c7ea',
            accent: '#4a6cfa'
        }
    };
    
    // Get theme values
    const theme = themes[color] || themes['orange']; // Default to blue if invalid color
    
    // Update CSS variables
    document.documentElement.style.setProperty('--primary', theme.primary);
    document.documentElement.style.setProperty('--primary-dark', theme.primaryDark);
    document.documentElement.style.setProperty('--secondary', theme.secondary);
    document.documentElement.style.setProperty('--accent', theme.accent);
    
    if (chartInstance && societyData && societyData.transactions) {
        createTransactionsChart(societyData.transactions);
    }
}

// Apply settings update
function applySettings(settings) {
    appSettings = {...appSettings, ...settings};
    
    // Update settings interface
    document.getElementById('darkMode').checked = appSettings.darkMode;
    document.getElementById('showAnimations').checked = appSettings.showAnimations;
    document.getElementById('compactView').checked = appSettings.compactView;
    document.getElementById('showPlaytime').checked = appSettings.showPlaytime;
    document.getElementById('showLocation').checked = appSettings.showLocation;
    document.getElementById('refreshInterval').value = appSettings.refreshInterval;
    document.getElementById('notificationSound').value = appSettings.notificationSound;
    
    // Update theme color
    document.querySelectorAll('.color-option').forEach(option => {
        option.classList.remove('active');
    });
    document.querySelector(`.color-option[data-color="${appSettings.themeColor}"]`)?.classList.add('active');
    
    // Apply theme color
    applyThemeColor(appSettings.themeColor);
    
    // Apply dark mode
    if (appSettings.darkMode) {
        document.body.classList.add('dark-mode');
        document.body.classList.remove('light-mode');
    } else {
        document.body.classList.add('light-mode');
        document.body.classList.remove('dark-mode');
    }
    
    // Apply animations
    if (appSettings.showAnimations) {
        document.body.classList.add('show-animations');
        document.body.classList.remove('hide-animations');
    } else {
        document.body.classList.add('hide-animations');
        document.body.classList.remove('show-animations');
    }

    if (chartInstance && societyData && societyData.transactions) {
        createTransactionsChart(societyData.transactions);
    }
    
    // Apply compact view
    if (appSettings.compactView) {
        document.body.classList.add('compact-view');
    } else {
        document.body.classList.remove('compact-view');
    }
    
    // Apply visibility settings
    if (appSettings.showPlaytime) {
        document.body.classList.add('show-playtime');
        document.body.classList.remove('hide-playtime');
    } else {
        document.body.classList.add('hide-playtime');
        document.body.classList.remove('show-playtime');
    }
    
    if (appSettings.showLocation) {
        document.body.classList.add('show-location');
        document.body.classList.remove('hide-location');
    } else {
        document.body.classList.add('hide-location');
        document.body.classList.remove('show-location');
    }
    
    // Set refresh timer
    setupAutoRefresh();
}

// Set up automatic refresh
function setupAutoRefresh() {
    
    if (autoRefreshTimer) {
        clearInterval(autoRefreshTimer);
        autoRefreshTimer = null;
    }
    
    if (window.playtimeUpdateTimer) {
        clearInterval(window.playtimeUpdateTimer);
        window.playtimeUpdateTimer = null;
    }
    
    const refreshTime = Math.max(appSettings.refreshInterval || 60, 10) * 1000;
    
    autoRefreshTimer = setInterval(() => {
        try {
            refreshJobData();
        } catch (error) {
            console.error("[ERROR] Error in refresh job data:", error);
        }
    }, refreshTime);
    
    if (appSettings.showPlaytime) {
        window.playtimeUpdateTimer = setInterval(() => {
            try {
                updatePlaytimeData();
            } catch (error) {
                console.error("[ERROR] Error in playtime update:", error);
            }
        }, 15000); // Update playtime every 15 seconds
    }
}

function updatePlaytimeData() {
    
    if (!currentJobData || !currentJobData.jobName) {
        return;
    }
    
    try {
        
        fetch(`https://${GetParentResourceName()}/getPlaytimeData`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                jobName: currentJobData.jobName
            })
        })
        .then(resp => {
            if (!resp.ok) {
                throw new Error(`Server responded with status: ${resp.status}`);
            }
            return resp.json();
        })
        .then(data => {
            
            if (!data) {
                return;
            }
            
            if (!data.employees || !Array.isArray(data.employees) || data.employees.length === 0) {
                return;
            }
            
            let updatesCount = 0;
            
            if (!currentJobData.employees || !Array.isArray(currentJobData.employees)) {
                console.error("[ERROR] Current job data has no valid employees array");
                return;
            }
            
            data.employees.forEach(updatedEmployee => {
                if (!updatedEmployee || !updatedEmployee.citizenid) {
                    return; 
                }
                
                currentJobData.employees.forEach(employee => {
                    if (employee.citizenid === updatedEmployee.citizenid) {
                        if (employee.playTime !== updatedEmployee.playTime) {
                            employee.playTime = updatedEmployee.playTime;
                            updatesCount++;
                        }
                    }
                });
            });
            
            
            if (updatesCount > 0) {
                try {
                    updateEmployeesTables();
                    updateDashboardStats();
                } catch (uiError) {
                    console.error("[ERROR] Error updating UI:", uiError);
                }
            } else {
            }
        })
        .catch(err => {
        });
    } catch (outerError) {
        console.error('[ERROR] Exception in playtime update:', outerError);
    }
}


function formatMoney(amount) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(amount);
}

function formatDateTime(timestamp) {
    const date = new Date(timestamp * 1000);
    
    const options = {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    };
    
    return date.toLocaleString('en-US', options);
}
function updateSocietyData(data) {
    if (!data) return;
    
    societyData = data;
    
    const balanceElement = document.getElementById('society-balance');
    const oldBalance = balanceElement.textContent;
    const newBalance = formatMoney(data.balance);
    
    if (oldBalance !== newBalance) {
        balanceElement.textContent = newBalance;
        balanceElement.classList.add('balance-update');
        
        setTimeout(() => {
            balanceElement.classList.remove('balance-update');
        }, 500);
    } else {
        balanceElement.textContent = newBalance;
    }
    
    document.getElementById('society-name').textContent = data.name;
    
    if (data.transactions && data.transactions.length > 0) {
        const lastTransaction = data.transactions[0];
        document.getElementById('last-transaction-amount').textContent = formatMoney(lastTransaction.amount);
        document.getElementById('last-transaction-time').textContent = formatDateTime(lastTransaction.timestamp);
        
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayTimestamp = Math.floor(today.getTime() / 1000);
        
        const todayTransactions = data.transactions.filter(t => t.timestamp >= todayTimestamp);
        document.getElementById('today-transactions').textContent = todayTransactions.length;
        
        let todayAmount = 0;
        todayTransactions.forEach(t => {
            if (t.type === 'deposit') {
                todayAmount += t.amount;
            } else if (t.type === 'withdraw' || t.type === 'transfer') {
                todayAmount -= t.amount;
            }
        });
        
        document.getElementById('today-transactions-amount').textContent = formatMoney(todayAmount);
    }
    
    updateTransactionsTable(data.transactions || []);
    createTransactionsChart(data.transactions || []);
    updateEmployeeDropdown();
}

function setupChartTimeframeListeners() {
    const timeframeSelector = document.getElementById('timeframe-selector');
    const dropdown = document.getElementById('timeframe-dropdown');
    const timeframeOptions = document.querySelectorAll('#timeframe-dropdown a');
    
    if (timeframeSelector) {
        timeframeSelector.addEventListener('click', function() {
            dropdown.classList.toggle('show');
        });
        
        window.addEventListener('click', function(event) {
            if (!event.target.matches('.dropdown-btn') && 
                !event.target.parentNode.matches('.dropdown-btn')) {
                dropdown.classList.remove('show');
            }
        });
    }
    
    timeframeOptions.forEach(option => {
        option.addEventListener('click', function(e) {
            e.preventDefault();
            const timeframe = this.getAttribute('data-timeframe');
            currentTimeframe = timeframe;
            
            const buttonText = timeframe === 'day' ? 'Today' : 
                              timeframe === 'week' ? 'Last 7 days' : 'Last 30 days';
            document.querySelector('#timeframe-selector span').textContent = buttonText;
            
            dropdown.classList.remove('show');
            
            if (societyData && societyData.transactions) {
                createTransactionsChart(societyData.transactions);
            }
        });
    });
}

function updateTransactionsTable(transactions) {
    const tableBody = document.getElementById('transactions-table');
    tableBody.innerHTML = '';
    
    if (transactions.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="5" class="empty-table">No transactions to display</td></tr>';
        return;
    }
    
    transactions.forEach(transaction => {
        const tr = document.createElement('tr');
        tr.className = `transaction-row-${transaction.type}`;
        
        let amountClass = '';
        if (transaction.type === 'deposit') {
            amountClass = 'positive';
        } else if (transaction.type === 'withdraw' || transaction.type === 'transfer') {
            amountClass = 'negative';
        }
        
        let amountPrefix = '';
        if (transaction.type === 'deposit') {
            amountPrefix = '+';
        } else if (transaction.type === 'withdraw' || transaction.type === 'transfer') {
            amountPrefix = '-';
        }
        
        let typeText = 'Unknown';
        let typeClass = '';
        let typeIcon = '';
        
        if (transaction.type === 'deposit') {
            typeText = 'Deposit';
            typeClass = 'transaction-type-deposit';
            typeIcon = '<i class="fas fa-arrow-circle-up"></i>';
        } else if (transaction.type === 'withdraw') {
            typeText = 'Withdraw';
            typeClass = 'transaction-type-withdraw';
            typeIcon = '<i class="fas fa-arrow-circle-down"></i>';
        } else if (transaction.type === 'transfer') {
            typeText = 'Transfer';
            typeClass = 'transaction-type-transfer';
            typeIcon = '<i class="fas fa-exchange-alt"></i>';
        }
        
        let employeeDisplay = transaction.employee || 'N/A';
        if (transaction.executor && transaction.type === 'transfer') {
            employeeDisplay = `<span title="Transferred by: ${transaction.executor}">${transaction.employee || 'N/A'}</span>`;
        }
        
        let noteDisplay = transaction.note || '';
        if (noteDisplay.length > 30) {
            noteDisplay = `<span title="${transaction.note}">${noteDisplay.substring(0, 27)}...</span>`;
        }
        
        tr.innerHTML = `
            <td>${formatDateTime(transaction.timestamp)}</td>
            <td><span class="transaction-type ${typeClass}">${typeIcon} ${typeText}</span></td>
            <td><span class="transaction-amount ${amountClass}">${amountPrefix}${formatMoney(transaction.amount)}</span></td>
            <td>${employeeDisplay}</td>
            <td>${noteDisplay}</td>
        `;
        
        tableBody.appendChild(tr);
    });
}

function updateEmployeeDropdown() {
    const dropdown = document.getElementById('transfer-employee');
    dropdown.innerHTML = '<option value="">Select an employee</option>';
    
    if (!currentJobData.employees || currentJobData.employees.length === 0) {
        return;
    }
    
    const sortedEmployees = [...currentJobData.employees].sort((a, b) => {
        return a.name.localeCompare(b.name);
    });
    
    sortedEmployees.forEach(employee => {
        const option = document.createElement('option');
        option.value = employee.citizenid;
        option.textContent = `${employee.name} (${employee.gradeName})`;
        dropdown.appendChild(option);
    });
}

function openTransferConfirmModal(employeeId, amount) {
    const employee = currentJobData.employees.find(emp => emp.citizenid === employeeId);
    if (!employee) return;
    
    document.getElementById('confirm-transfer-amount').textContent = formatMoney(amount);
    document.getElementById('confirm-transfer-employee').textContent = employee.name;
    document.getElementById('transfer-note').value = '';
    
    currentTransactionAction = {
        type: 'transfer',
        citizenid: employeeId,
        amount: amount
    };
    
    const modal = document.getElementById('transfer-confirm-modal');
    modal.classList.add('show');
    modal.querySelector('.modal-content').style.animation = 'fadeInDown 0.3s ease forwards';
}

function openMoneyActionModal(action, amount) {
    const actionTitle = action === 'deposit' ? 
        '<i class="fas fa-arrow-circle-up"></i> Deposit Funds' : 
        '<i class="fas fa-arrow-circle-down"></i> Withdraw Funds';
    
    const actionMessage = action === 'deposit' ? 
        `Are you sure you want to deposit <span class="transaction-amount positive">${formatMoney(amount)}</span> to the society account?` : 
        `Are you sure you want to withdraw <span class="transaction-amount negative">${formatMoney(amount)}</span> from the society account?`;
    
    document.getElementById('money-action-title').innerHTML = actionTitle;
    document.getElementById('money-action-message').innerHTML = actionMessage;
    document.getElementById('money-action-note').value = '';
    
    currentTransactionAction = {
        type: action,
        amount: amount
    };
    
    const modal = document.getElementById('money-action-modal');
    modal.classList.add('show');
    modal.querySelector('.modal-content').style.animation = 'fadeInDown 0.3s ease forwards';
}

function refreshSocietyData() {
    if (window.isRefreshingSociety) return;
    window.isRefreshingSociety = true;
    
    fetch(`https://${GetParentResourceName()}/getSocietyData`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            jobName: currentJobData.jobName
        })
    })
    .then(resp => resp.json())
    .then(data => {
        if (data) {
            updateSocietyData(data);
        }
        setTimeout(() => {
            window.isRefreshingSociety = false;
        }, 1000); 
    })
    .catch(err => {
        console.error('Error refreshing society data:', err);
        window.isRefreshingSociety = false;
    });
}


document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();          
    setupApplicationEventListeners(); 
    setupAdditionalEventListeners();  
    addApplicationsTab();            
    addPermissionsTab();
    setupPermissionsEventListeners();
    setupHireEmployeeModal();
    initializePlayerTimeOffset();
});

document.addEventListener('keydown', function(event) {
    if (event.keyCode === 27) {
        const fullscreenOverlay = document.querySelector('.fullscreen-overlay');
        if (fullscreenOverlay) {
            document.body.removeChild(fullscreenOverlay);
            return;
        }

        document.querySelectorAll('.modal.show').forEach(modal => {
            modal.classList.remove('show');
        });

        if (document.querySelectorAll('.modal.show').length === 0) {
            document.body.classList.remove('ui-active');
            document.getElementById("container").style.display = "none";

            if (window.playtimeUpdateTimer) {
                clearInterval(window.playtimeUpdateTimer);
                window.playtimeUpdateTimer = null;
            }

            if (autoRefreshTimer) {
                clearInterval(autoRefreshTimer);
                autoRefreshTimer = null;
            }

            fetch(`https://${GetParentResourceName()}/closeUI`, {
                method: 'POST'
            });
        }
    }
});

document.addEventListener('DOMContentLoaded', function() {
    const style = document.createElement('style');
    style.textContent = `
        @keyframes fadeInDown {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        
        .modal.show {
            animation: fadeIn 0.3s ease forwards;
        }
        
        .stat-card, .society-action-card, .table-container {
            opacity: 0;
            animation: fadeIn 0.5s ease forwards;
        }
        
        #society-page .stat-card:nth-child(1) { animation-delay: 0.1s; }
        #society-page .stat-card:nth-child(2) { animation-delay: 0.2s; }
        #society-page .stat-card:nth-child(3) { animation-delay: 0.3s; }
        
        #society-page .society-action-card:nth-child(1) { animation-delay: 0.4s; }
        #society-page .society-action-card:nth-child(2) { animation-delay: 0.5s; }
        #society-page .society-action-card:nth-child(3) { animation-delay: 0.6s; }
        
        #society-page .table-container { animation-delay: 0.7s; }
    `;
    document.head.appendChild(style);
    
    document.querySelectorAll('.btn').forEach(button => {
        button.addEventListener('mousedown', function() {
            this.style.transform = 'scale(0.95)';
        });
        
        button.addEventListener('mouseup', function() {
            this.style.transform = '';
        });
        
        button.addEventListener('mouseleave', function() {
            this.style.transform = '';
        });
    });
});

function setupPermissionsEventListeners() {
    // Employee selection change
    const employeeSelect = document.getElementById('permissions-employee-select');
    if (employeeSelect) {
        employeeSelect.addEventListener('change', function() {
            const citizenid = this.value;
            if (citizenid) {
                selectedEmployeeForPermissions = currentJobData.employees.find(emp => emp.citizenid === citizenid);
                loadEmployeePermissions(citizenid);
            } else {
                document.getElementById('permissions-content').style.display = 'none';
                selectedEmployeeForPermissions = null;
            }
        });
    }

    // Refresh permissions button
    const refreshBtn = document.getElementById('refresh-permissions-btn');
    if (refreshBtn) {
        refreshBtn.addEventListener('click', function() {
            populateEmployeePermissionsDropdown();
            if (selectedEmployeeForPermissions) {
                loadEmployeePermissions(selectedEmployeeForPermissions.citizenid);
            }
        });
    }

    // Save permissions button
    const saveBtn = document.getElementById('save-permissions-btn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function() {
            if (!selectedEmployeeForPermissions) return;
            openPermissionsConfirmModal();
        });
    }

    // Confirm permissions button
    const confirmBtn = document.getElementById('confirm-permissions-btn');
    if (confirmBtn) {
        confirmBtn.addEventListener('click', function() {
            saveEmployeePermissions();
        });
    }
}

function ensurePermissionsTabExists() {
    if (!document.querySelector('.nav-item[data-page="permissions"]')) {
        addPermissionsTab();
    }
}

function setupSocietyEventListeners() {
    const refreshBtn = document.getElementById('refresh-society-btn');
    if (refreshBtn) {
        const newRefreshBtn = refreshBtn.cloneNode(true);
        refreshBtn.parentNode.replaceChild(newRefreshBtn, refreshBtn);
        newRefreshBtn.addEventListener('click', refreshSocietyData);
    }
    
    const depositBtn = document.getElementById('deposit-btn');
    if (depositBtn) {
        const newDepositBtn = depositBtn.cloneNode(true);
        depositBtn.parentNode.replaceChild(newDepositBtn, depositBtn);
        newDepositBtn.addEventListener('click', function() {
            const amount = parseInt(document.getElementById('deposit-amount').value);
            if (!amount || amount <= 0) {
                showNotification('Please enter a valid amount', 'error');
                return;
            }
            
            openMoneyActionModal('deposit', amount);
        });
    }
    
    const withdrawBtn = document.getElementById('withdraw-btn');
    if (withdrawBtn) {
        const newWithdrawBtn = withdrawBtn.cloneNode(true);
        withdrawBtn.parentNode.replaceChild(newWithdrawBtn, withdrawBtn);
        newWithdrawBtn.addEventListener('click', function() {
            const amount = parseInt(document.getElementById('withdraw-amount').value);
            if (!amount || amount <= 0) {
                showNotification('Please enter a valid amount', 'error');
                return;
            }
            
            if (amount > societyData.balance) {
                showNotification('Not enough funds in society account', 'error');
                return;
            }
            
            openMoneyActionModal('withdraw', amount);
        });
    }
    
    const transferBtn = document.getElementById('transfer-btn');
    if (transferBtn) {
        const newTransferBtn = transferBtn.cloneNode(true);
        transferBtn.parentNode.replaceChild(newTransferBtn, transferBtn);
        newTransferBtn.addEventListener('click', function() {
            const employeeId = document.getElementById('transfer-employee').value;
            const amount = parseInt(document.getElementById('transfer-amount').value);
            
            if (!employeeId) {
                showNotification('Please select an employee', 'error');
                return;
            }
            
            if (!amount || amount <= 0) {
                showNotification('Please enter a valid amount', 'error');
                return;
            }
            
            if (amount > societyData.balance) {
                showNotification('Not enough funds in society account', 'error');
                return;
            }
            
            openTransferConfirmModal(employeeId, amount);
        });
    }
    
    const confirmTransferBtn = document.getElementById('confirm-transfer-btn');
    if (confirmTransferBtn) {
        const newConfirmTransferBtn = confirmTransferBtn.cloneNode(true);
        confirmTransferBtn.parentNode.replaceChild(newConfirmTransferBtn, confirmTransferBtn);
        newConfirmTransferBtn.addEventListener('click', function() {
            if (!currentTransactionAction || currentTransactionAction.type !== 'transfer') return;
            
            const { citizenid, amount } = currentTransactionAction;
            const note = document.getElementById('transfer-note').value;
            
            fetch(`https://${GetParentResourceName()}/transferMoney`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    citizenid: citizenid,
                    amount: amount,
                    note: note,
                    jobName: currentJobData.jobName
                })
            })
            .then(response => response.json())
            .then(result => {
                if (result.success) {
                    showNotification('Funds transferred successfully');
                    closeModal();
                    
                    document.getElementById('transfer-employee').value = '';
                    document.getElementById('transfer-amount').value = '';
                    document.getElementById('transfer-note').value = '';
                    
                    setTimeout(refreshSocietyData, 1000);
                } else {
                    showNotification(result.message || 'Error during transfer', 'error');
                }
            })
            .catch(error => {
                console.error('Error transferring money:', error);
                showNotification('Error during transfer', 'error');
            });
        });
    }
    
    const confirmMoneyBtn = document.getElementById('confirm-money-action-btn');
    if (confirmMoneyBtn) {
        const newConfirmMoneyBtn = confirmMoneyBtn.cloneNode(true);
        confirmMoneyBtn.parentNode.replaceChild(newConfirmMoneyBtn, confirmMoneyBtn);
        newConfirmMoneyBtn.addEventListener('click', function() {
            if (!currentTransactionAction) return;
            
            const { type, amount } = currentTransactionAction;
            const note = document.getElementById('money-action-note').value;
            
            let endpoint = type === 'deposit' ? 'depositMoney' : 'withdrawMoney';
            
            fetch(`https://${GetParentResourceName()}/${endpoint}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    amount: amount,
                    note: note,
                    jobName: currentJobData.jobName
                })
            })
            .then(response => response.json())
            .then(result => {
                if (result.success) {
                    showNotification(`Funds ${type === 'deposit' ? 'deposited' : 'withdrawn'} successfully`);
                    closeModal();
                    
                    document.getElementById(`${type}-amount`).value = '';
                    document.getElementById('money-action-note').value = '';
                    
                    setTimeout(refreshSocietyData, 1000);
                } else {
                    showNotification(result.message || `Error during ${type}`, 'error');
                }
            })
            .catch(error => {
                console.error(`Error ${type}ing money:`, error);
                showNotification(`Error during ${type}`, 'error');
            });
        });
    }
    
    const searchTransaction = document.getElementById('search-transaction');
    if (searchTransaction) {
        const newSearchTransaction = searchTransaction.cloneNode(true);
        searchTransaction.parentNode.replaceChild(newSearchTransaction, searchTransaction);
        newSearchTransaction.addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            
            const rows = document.querySelectorAll('#transactions-table tr:not(.empty-table)');
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                if (text.includes(searchTerm)) {
                    row.style.display = '';
                } else {
                    row.style.display = 'none';
                }
            });
        });
    }
    
    setupChartTimeframeListeners();
}


function populateEmployeePermissionsDropdown() {
    const dropdown = document.getElementById('permissions-employee-select');
    if (!dropdown) return;

    dropdown.innerHTML = '<option value="">-- Select an employee --</option>';

    if (!currentJobData || !currentJobData.employees || currentJobData.employees.length === 0) {
        console.log("No employee data available for permissions dropdown");
        return;
    }


    const sortedEmployees = [...currentJobData.employees].sort((a, b) => {
        return a.name.localeCompare(b.name);
    });

    sortedEmployees.forEach(employee => {
        const option = document.createElement('option');
        option.value = employee.citizenid;
        option.textContent = `${employee.name} (${employee.gradeName})`;
        dropdown.appendChild(option);
    });
}

function loadEmployeePermissions(citizenid) {
    if (!citizenid || !currentJobData || !currentJobData.jobName) {
        console.error("Missing required data for loading permissions");
        return;
    }
    fetch(`https://${GetParentResourceName()}/getEmployeePermissions`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            citizenid: citizenid,
            jobName: currentJobData.jobName
        })
    })
    .then(resp => resp.json())
    .then(permissions => {
        // Show permissions content
        const permissionsContent = document.getElementById('permissions-content');
        if (permissionsContent) {
            permissionsContent.style.display = 'block';
        }
        
        // Store current permissions
        currentEmployeePermissions = permissions || {
            dashboard: false,
            employees: false,
            society: false,
            applications: false,
            grades: false,
            hiringfiring: false
        };
        
        const permElements = {
            dashboard: document.getElementById('perm-dashboard'),
            employees: document.getElementById('perm-employees'),
            society: document.getElementById('perm-society'),
            applications: document.getElementById('perm-applications'),
            grades: document.getElementById('perm-grades'),
            hiringfiring: document.getElementById('perm-hiringfiring')
        };
        
        for (const [key, elem] of Object.entries(permElements)) {
            if (!elem) {
                console.warn(`Permission element 'perm-${key}' not found in HTML!`);
            }
        }
        
        // Update toggle buttons with null checks
        if (permElements.dashboard) permElements.dashboard.checked = !!currentEmployeePermissions.dashboard;
        if (permElements.employees) permElements.employees.checked = !!currentEmployeePermissions.employees;
        if (permElements.society) permElements.society.checked = !!currentEmployeePermissions.society;
        if (permElements.applications) permElements.applications.checked = !!currentEmployeePermissions.applications;
        if (permElements.grades) permElements.grades.checked = !!currentEmployeePermissions.grades;
        if (permElements.hiringfiring) permElements.hiringfiring.checked = !!currentEmployeePermissions.hiringfiring;
    })
    .catch(err => {
        console.error('Error loading employee permissions:', err);
        showNotification('Error loading permissions', 'error');
    });
}


// Open confirmation modal
function openPermissionsConfirmModal() {
    if (!selectedEmployeeForPermissions) return;
    
    const confirmElement = document.getElementById('confirm-permissions-employee');
    if (confirmElement) {
        confirmElement.textContent = selectedEmployeeForPermissions.name;
    }
    
    function getCheckboxState(id, defaultValue = false) {
        const element = document.getElementById(id);
        return element ? element.checked : defaultValue;
    }
    
    const permissionChanges = {
        dashboard: getCheckboxState('perm-dashboard'),
        employees: getCheckboxState('perm-employees'),
        society: getCheckboxState('perm-society'),
        applications: getCheckboxState('perm-applications'),
        grades: getCheckboxState('perm-grades'),
        hiringfiring: getCheckboxState('perm-hiringfiring')
    };
    
    // Build summary
    const summary = document.getElementById('permission-summary');
    if (summary) {
        summary.innerHTML = '';
    
        const permissions = [
            { key: 'dashboard', label: 'Dashboard Access' },
            { key: 'employees', label: 'Employee Management' },
            { key: 'society', label: 'Society Finances' },
            { key: 'applications', label: 'Application Review' },
            { key: 'hiringfiring', label: 'Hiring & Firing' }
        ];
    
        permissions.forEach(perm => {
            const item = document.createElement('div');
            item.className = 'permission-item';
        
            const label = document.createElement('span');
            label.textContent = perm.label;
        
            const status = document.createElement('span');
            if (permissionChanges[perm.key]) {
                status.className = 'permission-granted';
                status.textContent = 'Granted';
            } else {
                status.className = 'permission-denied';
                status.textContent = 'Denied';
            }
        
            item.appendChild(label);
            item.appendChild(status);
            summary.appendChild(item);
        });
    }
    
    const modal = document.getElementById('permissions-confirm-modal');
    if (modal) {
        modal.classList.add('show');
    }
}


// Save employee permissions
function saveEmployeePermissions() {
    if (!selectedEmployeeForPermissions) {
        console.error("No employee selected");
        showNotification('No employee selected', 'error');
        return;
    }
    
    function getCheckboxState(id, defaultValue = false) {
        const element = document.getElementById(id);
        return element ? element.checked : defaultValue;
    }

    
    const permissions = {
        dashboard: getCheckboxState('perm-dashboard'),
        employees: getCheckboxState('perm-employees'),
        society: getCheckboxState('perm-society'),
        applications: getCheckboxState('perm-applications'),
        grades: getCheckboxState('perm-grades'),
        hiringfiring: getCheckboxState('perm-hiringfiring')
    };
    
    
    fetch(`https://${GetParentResourceName()}/updateEmployeePermissions`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            citizenid: selectedEmployeeForPermissions.citizenid,
            jobName: currentJobData.jobName,
            permissions: permissions
        })
    })
    .then(resp => resp.json())
    .then(result => {
        
        if (result.success) {
            showNotification('Permissions updated successfully', 'success');
            document.getElementById('permissions-confirm-modal').classList.remove('show');
            
            // Update stored permissions
            currentEmployeePermissions = permissions;
        } else {
            console.error("Failed to update permissions:", result.message);
            showNotification(result.message || 'Failed to update permissions', 'error');
        }
    })
    .catch(error => {
        console.error('Error updating permissions:', error);
        showNotification('Error updating permissions', 'error');
    });
}

function addPermissionsTab() {
    // Check if permissions tab already exists to avoid duplicates
    if (document.querySelector('.nav-item[data-page="permissions"]')) {
        return;
    }
    
    // Find where to insert the permissions tab (before settings)
    const settingsItem = document.querySelector('.nav-item[data-page="settings"]');
    if (!settingsItem) {
        setTimeout(addPermissionsTab, 500);
        return;
    }
    
    // Create the permissions tab
    const permissionsItem = document.createElement('a');
    permissionsItem.className = 'nav-item';
    permissionsItem.setAttribute('data-page', 'permissions');
    permissionsItem.innerHTML = `
        <i class="fas fa-key"></i>
        <span>Permissions</span>
    `;
    
    // Insert before settings
    settingsItem.parentNode.insertBefore(permissionsItem, settingsItem);
    
    // Add click event to the new tab
    permissionsItem.addEventListener('click', function() {
        // Show permissions page and hide other pages
        document.querySelectorAll('.page').forEach(page => {
            page.classList.remove('active');
        });
        document.getElementById('permissions-page').classList.add('active');
        
        // Update active navigation
        document.querySelectorAll('.nav-item').forEach(navItem => {
            navItem.classList.remove('active');
        });
        this.classList.add('active');
        
        // Important: Check if employees data exists
        if (!currentJobData || !currentJobData.employees || currentJobData.employees.length === 0) {
            // If no employee data, refresh job data first
            refreshJobData();
            // Set a small timeout to let job data populate
            setTimeout(populateEmployeePermissionsDropdown, 300);
        } else {
            // Populate employee dropdown
            populateEmployeePermissionsDropdown();
        }
    });
}


function loadScript(url) {
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = url;
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
    });
}

function setupApplicationEventListeners() {
    document.getElementById('accept-application-btn').addEventListener('click', function() {
        if (!currentApplicationDetails) return;
        
        const applicationId = currentApplicationDetails.id;
        const notes = document.getElementById('application-notes').value;
        
        fetch(`https://${GetParentResourceName()}/updateApplicationStatus`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                applicationId: applicationId,
                status: 'accepted',
                notes: notes
            })
        })
        .then(response => {
            showNotification('Application accepted successfully');
            document.getElementById('application-details-modal').classList.remove('show');
            
            setTimeout(refreshApplications, 1000);
        })
        .catch(error => {
            console.error('Error accepting application:', error);
            showNotification('Error accepting application', 'error');
        });
    });    

    document.getElementById('reject-application-btn').addEventListener('click', function() {
        if (!currentApplicationDetails) return;
        
        const applicationId = currentApplicationDetails.id;
        const notes = document.getElementById('application-notes').value;
        
        fetch(`https://${GetParentResourceName()}/updateApplicationStatus`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                applicationId: applicationId,
                status: 'rejected',
                notes: notes
            })
        })
        .then(response => {
            showNotification('Application rejected successfully');
            document.getElementById('application-details-modal').classList.remove('show');
            
            setTimeout(refreshApplications, 1000);
        })
        .catch(error => {
            console.error('Error rejecting application:', error);
            showNotification('Error rejecting application', 'error');
        });
    });

    document.getElementById('refresh-applications-btn').addEventListener('click', refreshApplications);
}

// Set event listeners
function setupEventListeners() {
    // Navigation between pages
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', function() {
            const pageId = this.getAttribute('data-page');
            
            if (pageId) {
                // Hide all pages
                document.querySelectorAll('.page').forEach(page => {
                    page.classList.remove('active');
                });
                
                // Show selected page
                document.getElementById(pageId + '-page').classList.add('active');
                
                // Update active navigation
                document.querySelectorAll('.nav-item').forEach(navItem => {
                    navItem.classList.remove('active');
                });
                this.classList.add('active');
            }
        });
    });
    
    // Tabs in employees page
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', function() {
            const filter = this.getAttribute('data-filter');
            const tabsContainer = this.closest('.tabs');
            
            tabsContainer.querySelectorAll('.tab').forEach(t => {
                t.classList.remove('active');
            });
            this.classList.add('active');
            
            if (filter) {
                filterEmployees(filter);
            }
        });
    });
    
    // Employee search
    document.getElementById('search-employee').addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        filterEmployeesBySearch(searchTerm, 'employees-table');
    });
    
    document.getElementById('search-management-employee').addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        filterEmployeesBySearch(searchTerm, 'management-employees-table');
    });
    
    // Close modal
    document.querySelectorAll('.modal-close, .modal-close-btn').forEach(btn => {
        btn.addEventListener('click', closeModal);
    });
    
    // Save employee changes
    document.getElementById('save-employee-btn').addEventListener('click', function() {
        const citizenid = document.getElementById('edit-citizenid').value;
        const grade = document.getElementById('edit-rank').value;        
        // Send data to server
        fetch(`https://${GetParentResourceName()}/updateEmployee`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                citizenid: citizenid,
                grade: grade
            })
        })
        .then(response => {
            showNotification('Employee rank update sent');
            closeModal();
            
            // Refresh data after a second (to allow server to update)
            setTimeout(refreshJobData, 1000);
        })
        .catch(error => {
            console.error('Error updating employee:', error);
            showNotification('Error updating employee', 'error');
        });
    });
    
    // Fire employee
    document.getElementById('fire-employee-btn').addEventListener('click', function() {
        const citizenid = document.getElementById('edit-citizenid').value;
        const employeeName = document.getElementById('edit-name').value;
        
        fetch(`https://${GetParentResourceName()}/showFireConfirmMenu`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                citizenid: citizenid,
                name: employeeName
            })
        });
        
        closeModal();
    });
    
    
    // Save settings
    document.getElementById('save-settings-btn').addEventListener('click', function() {
        const settings = {
            darkMode: document.getElementById('darkMode').checked,
            showAnimations: document.getElementById('showAnimations').checked,
            compactView: document.getElementById('compactView').checked,
            showPlaytime: document.getElementById('showPlaytime').checked,
            showLocation: document.getElementById('showLocation').checked,
            refreshInterval: parseInt(document.getElementById('refreshInterval').value),
            notificationSound: document.getElementById('notificationSound').value,
            themeColor: document.querySelector('.color-option.active')?.getAttribute('data-color') || 'orange'
        };
        
        // Send settings to server
        fetch(`https://${GetParentResourceName()}/saveSettings`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(settings)
        });
        
        applySettings(settings);
        showNotification('Settings saved successfully');
    });
    
    // Reset settings
    document.getElementById('reset-settings-btn').addEventListener('click', function() {
        // Reset to default settings
        const defaultSettings = {
            darkMode: true,
            showAnimations: true,
            compactView: false,
            notificationSound: 'default',
            themeColor: 'orange',
            refreshInterval: 60,
            showPlaytime: true,
            showLocation: true
        };
        
        applySettings(defaultSettings);
        showNotification('Settings reset to defaults');
    });
    
    // Refresh data
    document.getElementById('refresh-data-btn').addEventListener('click', refreshJobData);
    document.getElementById('refresh-online').addEventListener('click', refreshJobData);
    
    // Theme color selection
    document.querySelectorAll('.color-option').forEach(option => {
        option.addEventListener('click', function() {
            document.querySelectorAll('.color-option').forEach(opt => {
                opt.classList.remove('active');
            });
            this.classList.add('active');
            
            const color = this.getAttribute('data-color');
            appSettings.themeColor = color;
            
            // Apply the theme color immediately
            applyThemeColor(color);
        });
    });
    
    // Close UI
    document.getElementById('close-ui').addEventListener('click', function() {
        closeUI();
    });
    
    setupSocietyEventListeners();
    setupActivityChartControls();
}


let currentEmployeeData = null;

function showCustomFireMenu(employeeName, citizenid) {
    document.getElementById('fire-message').textContent = `Are you sure you want to fire ${employeeName}?`;
    
    currentEmployeeData = {
        name: employeeName,
        citizenid: citizenid
    };
    
    document.getElementById('custom-fire-menu').style.display = 'block';
}

function hideCustomFireMenu() {
    document.getElementById('custom-fire-menu').style.display = 'none';
}

function setupAdditionalEventListeners() {
    document.getElementById('fire-confirm-btn').addEventListener('click', function() {
        if (!currentEmployeeData) return;
        
        fetch(`https://${GetParentResourceName()}/fireMenuResponse`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                confirmed: true,
                citizenid: currentEmployeeData.citizenid
            })
        });
        
        hideCustomFireMenu();
    });
    
    document.getElementById('fire-cancel-btn').addEventListener('click', function() {
        if (!currentEmployeeData) return;
        
        fetch(`https://${GetParentResourceName()}/fireMenuResponse`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                confirmed: false,
                citizenid: currentEmployeeData.citizenid
            })
        });
        
        hideCustomFireMenu();
    });
}


// Filter employees by status
function filterEmployees(filter) {
    const rows = document.querySelectorAll('#management-employees-table tr[data-status]');
    
    rows.forEach(row => {
        const status = row.getAttribute('data-status');
        
        if (filter === 'all' || filter === status) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    });
}

// Filter employees by search
function filterEmployeesBySearch(searchTerm, tableId) {
    const rows = document.querySelectorAll(`#${tableId} tr[data-name]`);
    
    rows.forEach(row => {
        const name = row.getAttribute('data-name').toLowerCase();
        const grade = row.getAttribute('data-grade-name').toLowerCase();
        
        if (name.includes(searchTerm) || grade.includes(searchTerm)) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    });
}

// Open edit employee modal
function openEditModal(citizenid) {
    const employee = currentJobData.employees.find(emp => emp.citizenid === citizenid);
    if (!employee) return;
    
    // Fill modal with employee data
    document.getElementById('edit-name').value = employee.name;
    document.getElementById('edit-citizenid').value = employee.citizenid;
    
    // Reset and fill rank list
    const rankSelect = document.getElementById('edit-rank');
    rankSelect.innerHTML = '';
    
    // Fill grades from received data
    Object.keys(currentJobData.grades).forEach(grade => {
        const option = document.createElement('option');
        
        option.value = String(grade);
        option.textContent = `${currentJobData.grades[grade].name} (${grade})`;
        
        if (String(grade) === String(employee.grade)) {
            option.selected = true;
        }
        
        rankSelect.appendChild(option);
    });
    
    // Show modal
    document.getElementById('edit-employee-modal').classList.add('show');
}

// Close modal
function closeModal() {
    document.querySelectorAll('.modal').forEach(modal => {
        modal.classList.remove('show');
    });
}

function adjustToLocalTime(hour) {
    // Get local timezone offset in hours
    const localOffset = new Date().getTimezoneOffset() / -60;
    
    // Apply the offset to convert server time to local time
    return (hour + localOffset) % 24;
}

function initializePlayerTimeOffset() {
    const localHour = new Date().getHours();
    
    playerTimeOffset = null;
}

// Update activity chart
function updateActivityChart() {
    if (!currentJobData.activityData || !Array.isArray(currentJobData.activityData) || currentJobData.activityData.length === 0) return;
    
    const activityChart = document.getElementById('activity-chart');
    if (!activityChart) return;
    
    activityChart.innerHTML = '';
    
    if (playerTimeOffset === null) {
        const localHour = new Date().getHours();

        let serverCurrentHourIndex = 0;
        let maxActivity = -1;
        
        for (let i = 0; i < currentJobData.activityData.length; i++) {
            if (currentJobData.activityData[i].count > maxActivity) {
                maxActivity = currentJobData.activityData[i].count;
                serverCurrentHourIndex = i;
            }
        }
        
        const serverCurrentHour = currentJobData.activityData[serverCurrentHourIndex].hour;
        
        playerTimeOffset = (localHour - serverCurrentHour + 24) % 24;
        
        console.log(`Player time offset calculated: ${playerTimeOffset} hours (Server: ${serverCurrentHour}, Local: ${localHour})`);
    }
    
    const maxCount = Math.max(...currentJobData.activityData.map(item => item.count), 1);
    
    currentJobData.activityData.forEach(item => {
        const hourBar = document.createElement('div');
        hourBar.className = 'hour-bar';
        
        const heightPercentage = Math.max((item.count / maxCount) * 95, 5);
        hourBar.style.height = `${heightPercentage}%`;
        
        const playerLocalHour = (item.hour + playerTimeOffset) % 24;
        const formattedHour = playerLocalHour.toString().padStart(2, '0');
        
        hourBar.setAttribute('data-hour', `${formattedHour}:00`);
        hourBar.setAttribute('data-count', item.count);
        hourBar.setAttribute('data-original-hour', item.hour);
        
        activityChart.appendChild(hourBar);
    });
}


document.addEventListener('DOMContentLoaded', function() {
    function hideDownloadButton() {
        const downloadBtn = document.getElementById('download-activity');
        if (downloadBtn) {
            downloadBtn.style.display = 'none';
        }
    }
    
    hideDownloadButton();
    
    window.addEventListener('message', function(event) {
        if (event.data.action === 'openUI' || event.data.action === 'refreshData') {
            setTimeout(hideDownloadButton, 100);
        }
    });
});


//Expand activity chart functionality
function setupActivityChartControls() {
    const expandBtn = document.getElementById('expand-activity');
    if (expandBtn) {
        expandBtn.addEventListener('click', function() {
            const chartContainer = document.getElementById('activity-chart');
            if (!chartContainer) return;
            
            // Get primary color
            const primaryColor = getComputedStyle(document.documentElement).getPropertyValue('--primary').trim() || '#4a6cfa';
            
            // Create a fullscreen overlay
            const overlay = document.createElement('div');
            overlay.className = 'fullscreen-overlay';
            overlay.style.position = 'fixed';
            overlay.style.top = '0';
            overlay.style.left = '0';
            overlay.style.width = '100%';
            overlay.style.height = '100%';
            overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.9)';
            overlay.style.zIndex = '9999';
            overlay.style.display = 'flex';
            overlay.style.justifyContent = 'center';
            overlay.style.alignItems = 'center';
            overlay.style.flexDirection = 'column';
            
            // Add a close button
            const closeBtn = document.createElement('div');
            closeBtn.innerHTML = '&times;';
            closeBtn.style.position = 'absolute';
            closeBtn.style.top = '20px';
            closeBtn.style.right = '30px';
            closeBtn.style.fontSize = '30px';
            closeBtn.style.color = 'white';
            closeBtn.style.cursor = 'pointer';
            closeBtn.onclick = function() {
                document.body.removeChild(overlay);
            };
            
            // Add a title
            const title = document.createElement('h2');
            title.textContent = 'Activity Overview - By Your Local Time';
            title.style.color = 'white';
            title.style.marginBottom = '20px';
            
            // Create an expanded version of the chart
            const expandedChart = document.createElement('div');
            expandedChart.style.width = '80%';
            expandedChart.style.height = '70%';
            expandedChart.style.display = 'flex';
            expandedChart.style.alignItems = 'flex-end';
            expandedChart.style.justifyContent = 'space-around';
            expandedChart.style.padding = '20px 0';
            
            // Get a sorted array of hours from 0-23
            const hours = Array.from({length: 24}, (_, i) => i);
            
            // For each hour, find matching data or use empty data
            hours.forEach(hour => {
                const hourData = chartContainer.querySelector(`.hour-bar[data-hour="${hour.toString().padStart(2, '0')}:00"]`);
                
                const clonedBar = document.createElement('div');
                clonedBar.className = 'hour-bar';
                
                if (hourData) {
                    clonedBar.style.height = hourData.style.height;
                } else {
                    clonedBar.style.height = '5%'; // Minimum height
                }
                
                clonedBar.style.width = '3%';
                clonedBar.style.backgroundColor = primaryColor;
                clonedBar.style.borderRadius = '3px 3px 0 0';
                clonedBar.style.position = 'relative';
                
                // Add hour label
                const hourLabel = document.createElement('div');
                hourLabel.style.position = 'absolute';
                hourLabel.style.bottom = '-25px';
                hourLabel.style.left = '50%';
                hourLabel.style.transform = 'translateX(-50%)';
                hourLabel.style.fontSize = '12px';
                hourLabel.style.color = 'white';
                hourLabel.textContent = hour.toString().padStart(2, '0') + ':00';
                
                // Add count label
                const countLabel = document.createElement('div');
                countLabel.style.position = 'absolute';
                countLabel.style.top = '-25px';
                countLabel.style.left = '50%';
                countLabel.style.transform = 'translateX(-50%)';
                countLabel.style.fontSize = '12px';
                countLabel.style.color = 'white';
                countLabel.textContent = hourData ? (hourData.getAttribute('data-count') || '0') : '0';
                
                clonedBar.appendChild(hourLabel);
                clonedBar.appendChild(countLabel);
                expandedChart.appendChild(clonedBar);
            });
            
            // Add elements to the overlay
            overlay.appendChild(closeBtn);
            overlay.appendChild(title);
            overlay.appendChild(expandedChart);
            
            // Add the overlay to the body
            document.body.appendChild(overlay);
        });
    }
}

// Update online employees list
function updateOnlineEmployees() {
    const onlineEmployeesList = document.getElementById('online-employees');
    onlineEmployeesList.innerHTML = '';
    
    const onlineEmployees = currentJobData.employees.filter(emp => emp.isOnline);
    
    if (onlineEmployees.length === 0) {
        const emptyMessage = document.createElement('div');
        emptyMessage.className = 'empty-list';
        emptyMessage.textContent = 'No employees currently online';
        onlineEmployeesList.appendChild(emptyMessage);
        return;
    }
    
    onlineEmployees.forEach(employee => {
        const employeeItem = document.createElement('div');
        employeeItem.className = 'employee-item';
        
        const initials = getInitials(employee.name);
        
        employeeItem.innerHTML = `
            <div class="employee-info">
                <div class="employee-avatar">${initials}</div>
                <div>
                    ${employee.name} (${employee.gradeName})
                </div>
            </div>
            <span class="status status-online">Online</span>
        `;
        
        onlineEmployeesList.appendChild(employeeItem);
    });
}

// Update employees tables
function updateEmployeesTables() {
    if (!currentJobData.employees) return;
    
    const employeesTable = document.getElementById('employees-table');
    const managementTable = document.getElementById('management-employees-table');
    
    
    employeesTable.innerHTML = '';
    managementTable.innerHTML = '';
    
    if (currentJobData.employees.length === 0) {
        employeesTable.innerHTML = '<tr><td colspan="6" class="empty-table">No employees to display</td></tr>';
        managementTable.innerHTML = '<tr><td colspan="5" class="empty-table">No employees to display</td></tr>';
        return;
    }
    
    // Sort employees by grade (highest to lowest)
    const sortedEmployees = [...currentJobData.employees].sort((a, b) => b.grade - a.grade);
    
    // Fill employees table on home page
    sortedEmployees.forEach(employee => {
        const tr = document.createElement('tr');
        tr.setAttribute('data-name', employee.name);
        tr.setAttribute('data-grade-name', employee.gradeName);
        
        // Employee status
        let statusClass = 'status-offline';
        let statusText = 'Offline';
        if (employee.isOnline) {
            statusClass = 'status-online';
            statusText = 'Online';
        }
        
        const playTimeText = employee.isOnline ? 
    (employee.playTime ? formatTime(employee.playTime) : 'Updating...') : 
    (employee.playTime ? formatTime(employee.playTime) : 'N/A');
        
        tr.innerHTML = `
            <td>
                <div class="employee-info">
                    <div class="employee-avatar">${getInitials(employee.name)}</div>
                    <div class="employee-details">
                        <h3>${employee.name}</h3>
                        <p>${employee.citizenid}</p>
                    </div>
                </div>
            </td>
            <td>
                <div class="grade-info">
                    <span class="grade-badge">${employee.grade}</span>
                    ${employee.gradeName}
                </div>
            </td>
            <td><span class="status ${statusClass}">${statusText}</span></td>
            <td>${employee.isOnline ? employee.location : 'Not available'}</td>
            <td>${playTimeText}</td>
            <td>
                <div class="employee-actions">
                    <div class="action-btn edit-employee" data-citizenid="${employee.citizenid}"><i class="fas fa-pen"></i></div>
                </div>
            </td>
        `;
        
        employeesTable.appendChild(tr);
    });
    
    // Fill employees table on management page
    sortedEmployees.forEach(employee => {
        const tr = document.createElement('tr');
        tr.setAttribute('data-name', employee.name);
        tr.setAttribute('data-grade-name', employee.gradeName);
        
        // Set status for filtering
        let status = 'offline';
        let statusClass = 'status-offline';
        let statusText = 'Offline';
        
        if (employee.isOnline) {
            status = 'online';
            statusClass = 'status-online';
            statusText = 'Online';
        }
        
        // Check if employee is in management (grade 3+ for example)
        if (employee.isManagement) {
            status += ' management';
        }
        
        tr.setAttribute('data-status', status);
        
        const playTimeText = employee.isOnline ? 
    (employee.playTime ? formatTime(employee.playTime) : 'Updating...') : 
    (employee.playTime ? formatTime(employee.playTime) : 'N/A');
        
        tr.innerHTML = `
            <td>
                <div class="employee-info">
                    <div class="employee-avatar">${getInitials(employee.name)}</div>
                    <div class="employee-details">
                        <h3>${employee.name}</h3>
                        <p>${employee.citizenid}</p>
                    </div>
                </div>
            </td>
            <td>
                <div class="grade-info">
                    <span class="grade-badge">${employee.grade}</span>
                    ${employee.gradeName}
                </div>
            </td>
            <td><span class="status ${statusClass}">${statusText}</span></td>
            <td>${playTimeText}</td>
            <td>
                <div class="employee-actions">
                    <div class="action-btn edit-employee" data-citizenid="${employee.citizenid}"><i class="fas fa-pen"></i></div>
                </div>
            </td>
        `;
        
        managementTable.appendChild(tr);
    });
    
    // Add event listeners for edit buttons
    document.querySelectorAll('.edit-employee').forEach(btn => {
        btn.addEventListener('click', function() {
            const citizenid = this.getAttribute('data-citizenid');
            openEditModal(citizenid);
        });
    });
}

// Update dashboard stats
function updateDashboardStats() {
    if (!currentJobData.employees) return;
    
    // Total employees
    document.getElementById('total-employees').textContent = currentJobData.employees.length;
    document.getElementById('employees-count').textContent = `Managing ${currentJobData.employees.length} employees`;
    document.getElementById('employees-management-count').textContent = `Managing ${currentJobData.employees.length} employees`;
    
    // Online employees
    document.getElementById('status-online').textContent = currentJobData.onlineCount;
    
    // Calculate average hours (example)
    const onlineEmployees = currentJobData.employees.filter(emp => emp.isOnline);
    let avgPlaytime = 0;
    if (onlineEmployees.length > 0) {
        avgPlaytime = Math.floor(onlineEmployees.reduce((sum, emp) => sum + emp.playTime, 0) / onlineEmployees.length);
    }
    document.getElementById('avg-hours').textContent = formatTime(avgPlaytime);
    
    // Calculate highest and most common grade
    const gradeData = {};
    currentJobData.employees.forEach(emp => {
        if (!gradeData[emp.grade]) {
            gradeData[emp.grade] = {
                count: 0,
                name: emp.gradeName
            };
        }
        gradeData[emp.grade].count++;
    });
    
    let highestGrade = 0;
    let commonGrade = 0;
    let maxCount = 0;
    
    Object.keys(gradeData).forEach(grade => {
        const numGrade = parseInt(grade);
        
        // Update highest grade
        if (numGrade > highestGrade) {
            highestGrade = numGrade;
        }
        
        // Update most common grade
        if (gradeData[grade].count > maxCount) {
            maxCount = gradeData[grade].count;
            commonGrade = numGrade;
        }
    });
    
    // Update interface
    if (gradeData[highestGrade]) {
        document.getElementById('highest-grade').textContent = gradeData[highestGrade].name;
        document.getElementById('highest-grade-count').textContent = gradeData[highestGrade].count;
    }
    
    if (gradeData[commonGrade]) {
        document.getElementById('common-grade').textContent = gradeData[commonGrade].name;
        document.getElementById('common-grade-count').textContent = gradeData[commonGrade].count;
    }
}

function refreshJobGrades() {    
    if (!currentJobData || !currentJobData.jobName) {
        console.error("Cannot refresh job grades: No job data available");
        return;
    }
    
    fetch(`https://${GetParentResourceName()}/getJobGrades`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            jobName: currentJobData.jobName
        })
    })
    .then(resp => {
        if (!resp.ok) {
            throw new Error(`Server responded with status: ${resp.status}`);
        }
        return resp.json();
    })
    .then(gradesData => {
        if (!gradesData) {
            console.error("No job grades data received from server");
            return;
        }
        
        currentJobGrades = gradesData;
        
        try {
            updateGradesTable();
        } catch (e) {
        }
    })
    .catch(err => {
    });
}

// Refresh job data
function refreshJobData() {
    if (isRefreshingJobData) return;
    isRefreshingJobData = true;
    
    fetch(`https://${GetParentResourceName()}/refreshData`, {
        method: 'POST'
    })
    .then(resp => resp.json())
    .then(jobData => {
        if (jobData) {
            currentJobData = jobData;
            
            // Update department name
            document.getElementById('department-title').textContent = `${jobData.jobLabel} - Dashboard`;
            
            // Update all parts of the interface
            updateDashboardStats();
            updateActivityChart();
            updateOnlineEmployees();
            updateEmployeesTables();
        }
        
        setTimeout(() => {
            isRefreshingJobData = false;
        }, 1000);
    })
    .catch(err => {
        console.error('Error refreshing job data:', err);
        isRefreshingJobData = false;
    });
}

// Initialize interface on receiving data from server
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'openUI') {
        document.body.classList.add('ui-active');
        document.getElementById('container').style.display = 'flex';
        // Store job data
        currentJobData = data.jobData;

        // Update logo with job image if available
        const sidebarLogo = document.querySelector('.sidebar-logo');
        if (currentJobData && currentJobData.logoImage) {
            const baseUrl = window.location.href.split('/html/')[0];
            const imgPath = `${baseUrl}/html/images/${currentJobData.logoImage}`;
            
            // Create new image element
            const img = new Image();
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.objectFit = 'contain';
            img.style.padding = '2px';
            
            img.onload = function() {
                sidebarLogo.innerHTML = '';
                sidebarLogo.appendChild(img);
            };
            img.onerror = function() {
                sidebarLogo.textContent = 'DW';
            };
            img.src = imgPath;
            img.alt = `${currentJobData.jobLabel || ''} Logo`;
        } else {
            sidebarLogo.textContent = 'DW';
        }

        playerTimeOffset = null;
        
        // Apply user settings
        applySettings(data.settings);
        
        // Update department name
        document.getElementById("container").style.display = "flex";
        document.getElementById('department-title').textContent = `${data.jobData.jobLabel || data.jobData.jobName || jobName || "Job"} - Dashboard`;
        
        // Update all parts of the interface
        updateDashboardStats();
        updateActivityChart();
        updateOnlineEmployees();
        updateEmployeesTables();
        
        // Set automatic refresh timer
        setupAutoRefresh();
        setTimeout(updatePlaytimeData, 1000);
        // IMPORTANT: Make sure Applications tab exists
        ensureApplicationsTabExists();
        ensurePermissionsTabExists();
        
        // Get permissions and isBoss from data properly
        const permissions = data.permissions;
        const isBoss = data.playerJob && data.playerJob.isboss;
        //Perms Update in real time
        if (data.action === 'updatePermissionToggles') {
            // Update toggle buttons with the new permissions
            const permissions = data.permissions;
            
            if (permissions) {
                document.getElementById('perm-dashboard').checked = permissions.dashboard;
                document.getElementById('perm-employees').checked = permissions.employees;
                document.getElementById('perm-society').checked = permissions.society;
                document.getElementById('perm-applications').checked = permissions.applications;
                document.getElementById('perm-grades').checked = permissions.grades;
                document.getElementById('perm-hiringfiring').checked = permissions.hiringfiring;
                
                // Store the updated permissions
                currentEmployeePermissions = permissions;
            }
        }
        if (data.jobData && data.jobData.employees) {
            // Pre-populate permissions employee dropdown for later use
            setTimeout(populateEmployeePermissionsDropdown, 100);
        }
        // Handle permissions visibility
        if (!isBoss) {
            // Permissions tab is always hidden for non-bosses
            const permissionsTab = document.querySelector('.nav-item[data-page="permissions"]');
            if (permissionsTab) permissionsTab.style.display = 'none';
            
            // Hide tabs based on specific permissions
            if (!permissions || !permissions.dashboard) {
                const dashboardTab = document.querySelector('.nav-item[data-page="dashboard"]');
                if (dashboardTab) dashboardTab.style.display = 'none';
            }
            
            if (!permissions || !permissions.employees) {
                const employeesTab = document.querySelector('.nav-item[data-page="employees"]');
                if (employeesTab) employeesTab.style.display = 'none';
            }
            
            if (!permissions || !permissions.society) {
                const societyTab = document.querySelector('.nav-item[data-page="society"]');
                if (societyTab) societyTab.style.display = 'none';
            }
            
            if (!permissions || !permissions.applications) {
                const applicationsTab = document.querySelector('.nav-item[data-page="applications"]');
                if (applicationsTab) applicationsTab.style.display = 'none';
            }
            
            if (!permissions || !permissions.grades) {
                const gradesTab = document.querySelector('.nav-item[data-page="grades"]');
                if (gradesTab) gradesTab.style.display = 'none';
            }
            
            // Show first available tab
            let firstAvailableTab = null;
            document.querySelectorAll('.nav-item').forEach(tab => {
                if (tab.style.display !== 'none' && !firstAvailableTab) {
                    firstAvailableTab = tab;
                }
            });
            
            if (firstAvailableTab) {
                firstAvailableTab.click();
            }
        }
        
        // Handle society data
        if (data.societyData) {
            updateSocietyData(data.societyData);
        } else {
            refreshSocietyData();
        }
        setTimeout(refreshJobGrades, 1000);
    }
    else if (data.action === 'updatePermissions') {
        const permissions = data.permissions;
        
        // Update UI based on permissions
        if (!permissions.dashboard) {
            const dashboardTab = document.querySelector('.nav-item[data-page="dashboard"]');
            if (dashboardTab) dashboardTab.style.display = 'none';
        } else {
            const dashboardTab = document.querySelector('.nav-item[data-page="dashboard"]');
            if (dashboardTab) dashboardTab.style.display = '';
        }
        
        if (!permissions.employees) {
            const employeesTab = document.querySelector('.nav-item[data-page="employees"]');
            if (employeesTab) employeesTab.style.display = 'none';
        } else {
            const employeesTab = document.querySelector('.nav-item[data-page="employees"]');
            if (employeesTab) employeesTab.style.display = '';
        }
        
        if (!permissions.society) {
            const societyTab = document.querySelector('.nav-item[data-page="society"]');
            if (societyTab) societyTab.style.display = 'none';
        } else {
            const societyTab = document.querySelector('.nav-item[data-page="society"]');
            if (societyTab) societyTab.style.display = '';
        }
        
        if (!permissions.applications) {
            const applicationsTab = document.querySelector('.nav-item[data-page="applications"]');
            if (applicationsTab) applicationsTab.style.display = 'none';
        } else {
            const applicationsTab = document.querySelector('.nav-item[data-page="applications"]');
            if (applicationsTab) applicationsTab.style.display = '';
        }
        
        if (!permissions.grades) {
            const gradesTab = document.querySelector('.nav-item[data-page="grades"]');
            if (gradesTab) gradesTab.style.display = 'none';
        } else {
            const gradesTab = document.querySelector('.nav-item[data-page="grades"]');
            if (gradesTab) gradesTab.style.display = '';
        }
    }
    else if (data.action === 'fireEmployeeResponse') {
        if (data.confirmed) {
            fetch(`https://${GetParentResourceName()}/removeEmployee`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    citizenid: data.citizenid
                })
            });
            
            showNotification('Employee fired successfully');
            
            setTimeout(refreshJobData, 1000);
        } else {
            showNotification('Employee firing cancelled');
        }
    }
    else if (data.action === 'refreshData') {
        // Update job data
        currentJobData = data.jobData;

        playerTimeOffset = null;
        
        // Update all parts of the interface
        updateDashboardStats();
        updateActivityChart();
        updateOnlineEmployees();
        updateEmployeesTables();
    }
    else if (data.action === 'showCustomFireMenu') {
        showCustomFireMenu(data.name, data.citizenid);
    }
    else if (data.action === 'openApplicationForm') {
        openApplication(data.data);
    }
});

/**
 * @param {{question: string, type: "text" | "number" | "select", required: boolean, options: string[], min: number, max: number}} currentQuestion
 */

const validateInput = (currentQuestion) => {
    let isValid = true;
    let value;
    switch(currentQuestion.type) {
        case "text":
            value = document.getElementById("application-input_text").value;
            // Check if required and empty
            if (currentQuestion.required && (!value || value.trim() === "")) {
                isValid = false;
            }
            break;
        case "number":
            value = document.getElementById("application-input_number").value;
            // Check if required and empty
            if (currentQuestion.required && (!value || value === "")) {
                isValid = false;
            }
            break;
        case "select":
            const select = document.getElementById("application-input_select");
            value = select.options[select.selectedIndex].value;
            // Check if required and no selection was made (empty value)
            if (currentQuestion.required && (!value || value === "")) {
                isValid = false;
            }
            break;
    }
    
    return { isValid };
};
const formatCurrentQuestion = (currentQuestion) => {
    document.getElementById("application-question").innerText = currentQuestion.question;
    
    // Uncomment and fix the required indicator
    const requiredElement = document.getElementById("application-question-required");
    if (requiredElement) {
        if (currentQuestion.required) {
            requiredElement.textContent = " *"; // Add asterisk for required fields
            requiredElement.className = "application-question-required";
        } else {
            requiredElement.textContent = ""; // Clear for non-required fields
            requiredElement.className = "";
        }
    }

    switch(currentQuestion.type) {
        case "number":
            document.getElementById("application-input_text").style.display = "none";
            document.getElementById("application-input_select").style.display = "none";
            document.getElementById("application-input_number").style.display = "block";
            document.getElementById("application-input_number").max = currentQuestion.max;
            document.getElementById("application-input_number").min = currentQuestion.min ?? 0;
            currentQuestion.min && (document.getElementById("application-input_number").value = currentQuestion.min);
            break;
        case "text":
            document.getElementById("application-input_number").style.display = "none";
            document.getElementById("application-input_select").style.display = "none";
            document.getElementById("application-input_text").style.display = "block";
            document.getElementById("application-input_text").maxLength = currentQuestion.max;
            // Clear any previous value
            document.getElementById("application-input_text").value = "";
            break;
        case "select":
            document.getElementById("application-input_number").style.display = "none";
            document.getElementById("application-input_text").style.display = "none";
            document.getElementById("application-input_select").style.display = "block";

            // Add empty default option first
            let optionsHtml = "<option value=''>-- Select an option --</option>";
            
            for(let i = 0; i < currentQuestion.options.length; i++) {
                optionsHtml += "<option value=\"" + currentQuestion.options[i] + "\">" + currentQuestion.options[i] + "</option>";
            } 

            document.getElementById("application-input_select").innerHTML = optionsHtml;
            break;
    }
};



/**
 * @param {{question: string, type: "text" | "number" | "select", required: boolean, options: string[], min: number, max: number}} currentQuestion
 */
const getElementValueAndClear = (currentQuestion) => {
    let element;
    let value;

    switch(currentQuestion.type) {
        case "text":
            element = document.getElementById("application-input_" + currentQuestion.type);
            value = element.value;
            element.value = ""
            break;
        case "number":
            element = document.getElementById("application-input_" + currentQuestion.type);
            value = element.value;
            element.value = ""
            break;
        case "select":
            element = document.getElementById("application-input_" + currentQuestion.type);
            value = element.options[element.selectedIndex].value;
            element.innerHTML = ""
            break;
    }

    console.log(value)
    return value;
}

/**
 * @param {boolean} isLast
 */
const formatButton = (isLast) => {
    isLast ? document.getElementById("finish_task").innerText = "Sumbit" : document.getElementById("finish_task").innerText = "Next"
}

const updateProgressBar = (currentStep, totalSteps) => {
    const progressBar = document.querySelector('.progress-bar');
    if (!progressBar) return;
    
    if (currentStep === 0) {
        progressBar.style.width = '0%';
        return;
    }
    const remainingSteps = totalSteps - 1;
    const progressPercentage = (currentStep / remainingSteps) * 100;
    
    progressBar.style.width = `${progressPercentage}%`;
};

/**
 * @param {{job: {name: string, label: string}, applicationData: {question: string, type: "text" | "number" | "select", required: boolean, options: string[], min: number, max: number}[]}} data
*/
const openApplication = (data) => {
    let step = 0;
    let answers = [];
    const totalSteps = data.applicationData.length;    
    updateProgressBar(step, totalSteps);
    
    formatCurrentQuestion(data.applicationData[step]);
    formatButton(step + 1 == totalSteps);

    document.getElementById("cancel_app").addEventListener("click", () => {
        document.getElementById('application-container').style.display = "none";
        fetch(`https://${GetParentResourceName()}/closeUI`, {
            method: 'POST'
        });
    });

    document.getElementById("finish_task").addEventListener("click", () => {
        // Validate current question before proceeding
        const validationResult = validateInput(data.applicationData[step]);
        
        if (!validationResult.isValid) {
            return; // Prevent proceeding - notification is already shown in validateInput
        }
        
        if(step + 1 == totalSteps) {
            answers[step] = {
                question: data.applicationData[step].question,
                answer: getElementValueAndClear(data.applicationData[step])
            };

            document.getElementById('application-container').style.display = "none";
            fetch(`https://${GetParentResourceName()}/submitApplication`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    jobName: data.job.name,
                    answers: answers
                })
            });

            step = 0;
            answers = [];
            return;
        }

        answers[step] = {
            question: data.applicationData[step].question,
            answer: getElementValueAndClear(data.applicationData[step])
        };

        step++;        
        updateProgressBar(step, totalSteps);
        
        formatCurrentQuestion(data.applicationData[step]);
        formatButton(step + 1 == totalSteps);
    });

    document.getElementById('application-container').style.display = "block";
};

// Helper function for FiveM framework
function GetParentResourceName() {
    try {
        return window.GetParentResourceName();
    } catch (error) {
        return 'alpha-bossmenu'; // Default for testing in browser
    }
}

function updatePermissionsVisibility(permissions, isBoss) {
    if (!permissions) return;
    
    // Show/hide tabs based on permissions
    if (!isBoss) {
        // Permissions tab is always hidden for non-bosses
        const permissionsTab = document.querySelector('.nav-item[data-page="permissions"]');
        if (permissionsTab) permissionsTab.style.display = 'none';
        
        // Hide tabs based on specific permissions
        if (!permissions.dashboard) {
            const dashboardTab = document.querySelector('.nav-item[data-page="dashboard"]');
            if (dashboardTab) dashboardTab.style.display = 'none';
        } else {
            const dashboardTab = document.querySelector('.nav-item[data-page="dashboard"]');
            if (dashboardTab) dashboardTab.style.display = '';
        }
        
        if (!permissions.employees) {
            const employeesTab = document.querySelector('.nav-item[data-page="employees"]');
            if (employeesTab) employeesTab.style.display = 'none';
        } else {
            const employeesTab = document.querySelector('.nav-item[data-page="employees"]');
            if (employeesTab) employeesTab.style.display = '';
        }
        
        if (!permissions.society) {
            const societyTab = document.querySelector('.nav-item[data-page="society"]');
            if (societyTab) societyTab.style.display = 'none';
        } else {
            const societyTab = document.querySelector('.nav-item[data-page="society"]');
            if (societyTab) societyTab.style.display = '';
        }
        
        if (!permissions.applications) {
            const applicationsTab = document.querySelector('.nav-item[data-page="applications"]');
            if (applicationsTab) applicationsTab.style.display = 'none';
        } else {
            const applicationsTab = document.querySelector('.nav-item[data-page="applications"]');
            if (applicationsTab) applicationsTab.style.display = '';
        }
        
        if (!permissions.grades) {
            const gradesTab = document.querySelector('.nav-item[data-page="grades"]');
            if (gradesTab) gradesTab.style.display = 'none';
        } else {
            const gradesTab = document.querySelector('.nav-item[data-page="grades"]');
            if (gradesTab) gradesTab.style.display = '';
        }
        
        // Show first available tab
        let firstAvailableTab = null;
        document.querySelectorAll('.nav-item').forEach(tab => {
            if (tab.style.display !== 'none' && !firstAvailableTab) {
                firstAvailableTab = tab;
            }
        });
        
        if (firstAvailableTab) {
            firstAvailableTab.click();
        }
    }
}

function checkPermission(permissionType, callback) {
    fetch(`https://${GetParentResourceName()}/checkPermission`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ permissionType: permissionType })
    })
    .then(resp => resp.json())
    .then(hasPermission => {
        if (hasPermission) {
            callback();
        } else {
            showNotification("You don't have permission for this action", "error");
        }
    })
    .catch(error => {
        console.error('Error checking permission:', error);
        showNotification("Error checking permissions", "error");
    });
}

function OpenJobManager(jobName) {
    if (!jobName) {
        console.error("No job name provided to OpenJobManager");
        return;
    }
    
    
    currentJobGrades = {};
    
    fetch(`https://${GetParentResourceName()}/getJobGrades`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            jobName: jobName
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data) {
            currentJobGrades = data;
            updateGradesTable();
            
        } else {
            console.error("Failed to load job grades - no data returned");  
            const gradesTable = document.getElementById('grades-table');
            if (gradesTable) {
                gradesTable.innerHTML = '<tr><td colspan="5" class="empty-table">Failed to load job grades</td></tr>';
            }
        }
    })
    .catch(error => {
        console.error("Error loading job grades:", error);
        showNotification("Error loading job grades", "error");
        
        const gradesTable = document.getElementById('grades-table');
        if (gradesTable) {
            gradesTable.innerHTML = '<tr><td colspan="5" class="empty-table">Error: Failed to load job grades</td></tr>';
        }
    });
}

//Graph

function createTransactionsChart(transactions) {
    if (!transactions || transactions.length === 0) {
        return;
    }

    if (chartInstance) {
        chartInstance.destroy();
    }

    const chartContainer = document.getElementById('transactions-chart');
    if (!chartContainer) return;

    const chartData = prepareChartData(transactions, currentTimeframe);
    
    const primaryColor = getComputedStyle(document.documentElement).getPropertyValue('--primary').trim();
    const primaryDarkColor = getComputedStyle(document.documentElement).getPropertyValue('--primary-dark').trim();

    const ctx = document.createElement('canvas');
    ctx.width = chartContainer.offsetWidth;
    ctx.height = chartContainer.offsetHeight;
    chartContainer.innerHTML = '';
    chartContainer.appendChild(ctx);

    chartInstance = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: chartData.labels,
            datasets: [{
                label: 'Transaction Amount',
                data: chartData.values,
                backgroundColor: primaryColor || '#4a6cfa',   
                borderColor: primaryDarkColor || '#3a56c8',  
                borderWidth: 1,
                borderRadius: 4,
                barThickness: 'flex',
                maxBarThickness: 30
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    grid: {
                        color: 'rgba(255, 255, 255, 0.1)'
                    },
                    ticks: {
                        color: 'rgba(255, 255, 255, 0.7)',
                        callback: function(value) {
                            return '$' + value;
                        }
                    }
                },
                x: {
                    grid: {
                        display: false
                    },
                    ticks: {
                        color: 'rgba(255, 255, 255, 0.7)'
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.7)',
                    titleColor: '#ffffff',
                    bodyColor: '#ffffff',
                    displayColors: false,
                    callbacks: {
                        label: function(context) {
                            return '$' + context.raw;
                        }
                    }
                }
            }
        }
    });
}

function prepareChartData(transactions, timeframe) {
    const labels = [];
    const values = [];
    const now = new Date();
    
    if (timeframe === 'day') {
        for (let i = 0; i < 24; i++) {
            const hour = i < 10 ? '0' + i : i;
            labels.push(hour + ':00');
            
            const hourAmount = transactions
                .filter(t => {
                    const txDate = new Date(t.timestamp * 1000);
                    return txDate.getHours() === i && 
                           txDate.getDate() === now.getDate() &&
                           txDate.getMonth() === now.getMonth() &&
                           txDate.getFullYear() === now.getFullYear();
                })
                .reduce((sum, t) => {
                    if (t.type === 'deposit') {
                        return sum + t.amount;
                    } else if (t.type === 'withdraw' || t.type === 'transfer') {
                        return sum - t.amount;
                    }
                    return sum;
                }, 0);
            
            values.push(hourAmount || 0);
        }
    } else if (timeframe === 'week') {
        const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        
        const today = new Date();
        const currentDay = today.getDay(); 
        
        const lastSunday = new Date(today);
        lastSunday.setDate(today.getDate() - currentDay);
        
        const weekValues = Array(7).fill(0);
        
        for (let i = 0; i < 7; i++) {
            const currentDate = new Date(lastSunday);
            currentDate.setDate(lastSunday.getDate() + i);
            
            transactions.forEach(t => {
                const txDate = new Date(t.timestamp * 1000);
                if (txDate.getDate() === currentDate.getDate() && 
                    txDate.getMonth() === currentDate.getMonth() && 
                    txDate.getFullYear() === currentDate.getFullYear()) {
                    
                    if (t.type === 'deposit') {
                        weekValues[i] += t.amount;
                    } else if (t.type === 'withdraw' || t.type === 'transfer') {
                        weekValues[i] -= t.amount;
                    }
                }
            });
        }
        
        return { labels: dayLabels, values: weekValues };
    } else if (timeframe === 'month') {
        for (let i = 29; i >= 0; i--) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            labels.push(d.getDate());
            
            const dayAmount = transactions
                .filter(t => {
                    const txDate = new Date(t.timestamp * 1000);
                    return txDate.getDate() === d.getDate() && 
                           txDate.getMonth() === d.getMonth() && 
                           txDate.getFullYear() === d.getFullYear();
                })
                .reduce((sum, t) => {
                    if (t.type === 'deposit') {
                        return sum + t.amount;
                    } else if (t.type === 'withdraw' || t.type === 'transfer') {
                        return sum - t.amount;
                    }
                    return sum;
                }, 0);
            
            values.push(dayAmount || 0);
        }
    }
    
    return { labels, values };
}



// Add this function after the global variables
function closeUI() {
    document.body.classList.remove('ui-active');
    document.getElementById('container').style.display = 'none';
    
    if (window.playtimeUpdateTimer) {
        clearInterval(window.playtimeUpdateTimer);
        window.playtimeUpdateTimer = null;
    }
    
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}





// Update the message handler for closeUI action
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'closeUI') {
        closeUI();
    }
    // ... rest of the message handling code ...
});
