Config = {}

Config.PoliceJob = {
    jobName = "police",
    chiefGrade = 4,
    supervisorGrade = 3,
    allowedGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
}

Config.WingsSystem = {
    name = "Police Wings System",
    distance = 2.5,
    defaultMaxMembers = 15,
    enablePointsSystem = false,
    readOnlyMode = false,

    permissionSystem = {
        useAcePermissions = false,
        acePermission = "wings.view",
        fallbackToJobPermissions = true
    },

    jobPermissions = {
        minimumGrade = 0,
        allowedJobs = {"police"},
        restrictedGrades = {}
    },

    gradePermissions = {
        [0] = {
            canAddMembers = false,
            canRemoveMembers = false,
            canAssignGrades = false,
            canTransferLeadership = false,
            canSetRadio = false,
            canViewStatistics = false,
            canSendAnnouncements = false,
            canManageMembers = false,
            canViewAllMembers = false
        },
        [1] = {
            canAddMembers = false,
            canRemoveMembers = false,
            canAssignGrades = false,
            canTransferLeadership = false,
            canSetRadio = false,
            canViewStatistics = false,
            canSendAnnouncements = false,
            canManageMembers = false,
            canViewAllMembers = false
        },
        [2] = {
            canAddMembers = false,
            canRemoveMembers = false,
            canAssignGrades = false,
            canTransferLeadership = false,
            canSetRadio = false,
            canViewStatistics = true,
            canSendAnnouncements = false,
            canManageMembers = false,
            canViewAllMembers = false
        },
        [3] = {
            canAddMembers = true,
            canRemoveMembers = false,
            canAssignGrades = false,
            canTransferLeadership = false,
            canSetRadio = false,
            canViewStatistics = true,
            canSendAnnouncements = true,
            canManageMembers = true,
            canViewAllMembers = false
        },
        [4] = {
            canAddMembers = true,
            canRemoveMembers = true,
            canAssignGrades = true,
            canTransferLeadership = true,
            canSetRadio = true,
            canViewStatistics = true,
            canSendAnnouncements = true,
            canManageMembers = true,
            canViewAllMembers = true
        },
        [5] = {
            canAddMembers = true,
            canRemoveMembers = true,
            canAssignGrades = true,
            canTransferLeadership = true,
            canSetRadio = true,
            canViewStatistics = true,
            canSendAnnouncements = true,
            canManageMembers = true,
            canViewAllMembers = true
        }
    },
    defaultGrades = {
        {level = 0, name = "Recruit", description = "New wing member"},
        {level = 1, name = "Officer", description = "Basic wing officer"},
        {level = 2, name = "Senior Officer", description = "Experienced officer"},
        {level = 3, name = "Sergeant", description = "Wing supervisor"},
        {level = 4, name = "Lieutenant", description = "Wing commander"},
        {level = 5, name = "Captain", description = "Wing leader"}
    }
}

Config.WingsLocation = {
    x = 436.6,
    y = -994.42,
    z = 31.03,
    h = 1.33
}

Config.WingsInfoDisplay = {
    id = 'wings_info_display',
    title = 'Wings System - Information Display',
    position = 'top-right',
    showPlayerWingFirst = true,
    showAllWingsInfo = true,
    showStatistics = true,

    displaySections = {
        playerWingInfo = true,
        allWingsOverview = true,
        wingStatistics = true,
        systemInfo = true
    }
}

Config.WingsMenu = {
    id = 'wings_system_menu',
    title = 'Wings System',
    position = 'top-right',
    deprecated = true,
    options = {}
}

Config.AirShipNPC = {
    enabled = true,
    npcCoords = vector4(470.78, -993.21, 44.95, 278.49),
    npcModel = `s_m_y_pilot_01`,
    heliSpawnCoords = vector4(479.02, -986.72, 44.95, 335.28),
    interactLabel = "Talk to AirShip Pilot",
    requiredWingName = "AirShip",
    interactionDistance = 2.0,

    helicopters = {
        {
            id = "airship1",
            name = "AirShip 1",
            model = "polmav",
            description = "Spawn Police Maverick helicopter",
            icon = "fas fa-helicopter",
            livery = 0
        },
        {
            id = "airship2",
            name = "AirShip 2",
            model = "buzzard2",
            description = "Spawn Police Buzzard helicopter",
            icon = "fas fa-helicopter",
            livery = 0
        }
    },

    menu = {
        title = "AirShip Helicopter",
        headerIcon = "fas fa-helicopter",
        cancelText = "Close helicopter service menu",
        cancelIcon = "fas fa-times"
    },

    messages = {
        welcome = "Welcome to AirShip helicopter service! Choose your helicopter...",
        accessDenied = "Access denied. Only AirShip wing members can use this helicopter service.",
        policeOnly = "Access denied. Police personnel only.",
        spawnBlocked = "Helicopter spawn area is blocked. Please clear the area first.",
        spawnSuccess = " helicopter spawned successfully!",
        spawnFailed = "Failed to spawn helicopter. Please try again."
    },

    vehicleSettings = {
        autoEnterAsDriver = true,
        engineOn = false,
        setAsMissionEntity = true,
        setAsPlayerOwned = true,
        needsHotwiring = false,
        radioStation = "OFF"
    }
}
