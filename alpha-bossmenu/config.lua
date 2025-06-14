Config = {}

-- Banking System Selection
Config.BankingSystem = "qb-banking"  -- Options: "dw-banking", "qb-banking", "renewed-banking"

-- Interact System Selection
Config.InteractSystem = "interact"  -- Using interact export system

-- Minimum rank requirements for boss menu access
-- Set the minimum grade level required to access the boss menu for each job
-- Grade levels start from 0 (lowest) and go up. Set to 0 to allow all ranks.
-- Only applies to non-boss players (bosses always have access)
Config.MinimumRank = {
    ["police"] = 3,        -- Minimum grade 3 for police (e.g., Sergeant and above)
    ["ambulance"] = 2,     -- Minimum grade 2 for EMS (e.g., Paramedic and above)
    ["mechanic"] = 1,      -- Minimum grade 1 for mechanic (e.g., Experienced Mechanic and above)
    -- Add more jobs as needed with their minimum grade requirements
    -- ["jobname"] = minimumGradeLevel,
}

-- Management access locations
Config.Locations = {
    ["police"] = {
        label = "Police Department",
        logoImage = "police.png",
        locations = {
            {
                coords = vector3(433.78, -983.64, 30.94), -- Main Police Station
                width = 1.0,
                length = 1.0,
                heading = 0,
                minZ = 30.0,
                maxZ = 31.0,
            },
            {
                coords = vector3(1853.82, 3689.82, 34.27), -- Sandy Shores Sheriff
                width = 1.0,
                length = 1.0,
                heading = 0,
                minZ = 34.0,
                maxZ = 35.0,
            }
        }
    },
    ["ambulance"] = {
        label = "EMS Department",
        logoImage = "ems.png",
        locations = {
            {
                coords = vector3(307.45, -595.47, 43.28), -- Main Hospital
                width = 1.0,
                length = 1.0,
                heading = 0,
                minZ = 43.0,
                maxZ = 44.0,
            },
            {
                coords = vector3(1839.32, 3673.26, 34.28), -- Sandy Shores Hospital
                width = 1.0,
                length = 1.0,
                heading = 0,
                minZ = 34.0,
                maxZ = 35.0,
            }
        }
    },
    ["mechanic"] = {
        label = "Mechanic Shop",
        logoImage = "mechanic.png",
        locations = {
            {
                coords = vector3(832.92, -909.54, 25.25), -- Mechanic Shop
                width = 1.0,
                length = 1.0,
                heading = 0,
                minZ = 25.0,
                maxZ = 26.0,
            }
        }
    }
    -- Add more jobs as needed
}





-- Default settings
Config.DefaultSettings = {
    darkMode = true,
    showAnimations = true,
    compactView = false,
    notificationSound = "default",
    themeColor = "orange",
    refreshInterval = 60,
    showPlaytime = true,
    showLocation = true
}
