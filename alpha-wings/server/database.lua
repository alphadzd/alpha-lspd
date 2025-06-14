local QBCore = exports['qb-core']:GetCoreObject()

local Database = {}

function Database.InitializeDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_wings` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(100) NOT NULL,
            `description` text NOT NULL,
            `max_members` int(11) NOT NULL DEFAULT 15,
            `leader_citizenid` varchar(50) NOT NULL,
            `leader_name` varchar(100) NOT NULL,
            `radio_frequency` varchar(20) DEFAULT NULL,
            `created_by` varchar(50) NOT NULL,
            `created_by_name` varchar(100) NOT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `is_active` tinyint(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            UNIQUE KEY `name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_wing_members` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `wing_id` int(11) NOT NULL,
            `citizenid` varchar(50) NOT NULL,
            `player_name` varchar(100) NOT NULL,
            `wing_grade_level` int(11) NOT NULL DEFAULT 0,
            `joined_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `is_active` tinyint(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            UNIQUE KEY `wing_member_unique` (`wing_id`, `citizenid`),
            FOREIGN KEY (`wing_id`) REFERENCES `police_wings`(`id`) ON DELETE CASCADE,
            INDEX `idx_citizenid` (`citizenid`),
            INDEX `idx_wing_id` (`wing_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        ALTER TABLE `police_wing_members`
        DROP INDEX IF EXISTS `wing_member`
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_wing_activity` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `wing_id` int(11) NOT NULL,
            `citizenid` varchar(50) NOT NULL,
            `activity_type` varchar(50) NOT NULL,
            `description` text NOT NULL,
            `points` int(11) NOT NULL DEFAULT 0,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            FOREIGN KEY (`wing_id`) REFERENCES `police_wings`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_wing_grades` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `wing_id` int(11) NOT NULL,
            `grade_name` varchar(50) NOT NULL,
            `grade_level` int(11) NOT NULL,
            `grade_description` text DEFAULT NULL,
            `permissions` text DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `is_active` tinyint(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            UNIQUE KEY `wing_grade_level` (`wing_id`, `grade_level`),
            FOREIGN KEY (`wing_id`) REFERENCES `police_wings`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_wing_announcements` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `wing_id` int(11) NOT NULL,
            `sender_citizenid` varchar(50) NOT NULL,
            `sender_name` varchar(100) NOT NULL,
            `message` text NOT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            FOREIGN KEY (`wing_id`) REFERENCES `police_wings`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        ALTER TABLE `police_wings` 
        ADD COLUMN IF NOT EXISTS `radio_frequency` varchar(20) DEFAULT NULL AFTER `leader_name`;
    ]])

    MySQL.query([[
        ALTER TABLE `police_wing_members` 
        ADD COLUMN IF NOT EXISTS `wing_grade_level` int(11) NOT NULL DEFAULT 0;
    ]])
    
    MySQL.query([[
        ALTER TABLE `police_wing_members` 
        DROP COLUMN IF EXISTS `rank`;
    ]])

    MySQL.query([[
        INSERT IGNORE INTO police_wing_grades (wing_id, grade_name, grade_level, grade_description, permissions)
        SELECT
            w.id as wing_id,
            CASE grades.grade_level
                WHEN 0 THEN 'Recruit'
                WHEN 1 THEN 'Officer'
                WHEN 2 THEN 'Senior Officer'
                WHEN 3 THEN 'Sergeant'
                WHEN 4 THEN 'Lieutenant'
                WHEN 5 THEN 'Leader'
            END as grade_name,
            grades.grade_level,
            CASE grades.grade_level
                WHEN 0 THEN 'New wing member'
                WHEN 1 THEN 'Standard wing officer'
                WHEN 2 THEN 'Experienced wing officer'
                WHEN 3 THEN 'Wing supervisor'
                WHEN 4 THEN 'Wing commander'
                WHEN 5 THEN 'Wing leader'
            END as grade_description,
            '{}' as permissions
        FROM police_wings w
        CROSS JOIN (
            SELECT 0 as grade_level UNION ALL
            SELECT 1 UNION ALL
            SELECT 2 UNION ALL
            SELECT 3 UNION ALL
            SELECT 4 UNION ALL
            SELECT 5
        ) grades
        WHERE w.is_active = 1
        AND NOT EXISTS (
            SELECT 1 FROM police_wing_grades wg
            WHERE wg.wing_id = w.id AND wg.grade_level = grades.grade_level
        )
    ]])

    print("^2[Alpha Wings]^7 Database tables initialized successfully!")
end

function Database.CreateWing(wingData, callback)
    print("^1[Alpha Wings Debug]^7 === NEW CreateWing function called! ===")
    print(string.format("^3[Alpha Wings Debug]^7 Checking if wing name '%s' already exists...", wingData.name))
    
    MySQL.query('SELECT id FROM police_wings WHERE name = ? AND is_active = 1', {wingData.name}, function(result)
        print(string.format("^3[Alpha Wings Debug]^7 Query result for wing name check: %s", json.encode(result)))
        
        if result and #result > 0 then
            print(string.format("^1[Alpha Wings Debug]^7 Wing name '%s' already exists! Found %d matching wings.", wingData.name, #result))
            callback(nil, "A wing with this name already exists!")
            return
        end
        
        print(string.format("^2[Alpha Wings Debug]^7 Wing name '%s' is available, proceeding with creation...", wingData.name))
        
        MySQL.query('INSERT IGNORE INTO police_wings (name, description, max_members, leader_citizenid, leader_name, created_by, created_by_name) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            wingData.name,
            wingData.description,
            wingData.maxMembers,
            wingData.leaderCitizenId,
            wingData.leaderName,
            wingData.createdBy,
            wingData.createdByName
        }, function(result)
            print(string.format("^3[Alpha Wings Debug]^7 INSERT result: %s", json.encode(result)))
            
            if result and result.affectedRows and result.affectedRows > 0 then
                local wingId = result.insertId
                print(string.format("^2[Alpha Wings Debug]^7 Wing created successfully with ID: %s", wingId))
                
                Database.InitializeDefaultWingGrades(wingId, function(gradesCreated)
                    if gradesCreated then
                        Database.AddWingMember(wingId, {
                            citizenid = wingData.createdBy,
                            playerName = wingData.createdByName,
                            gradeLevel = 5
                        })

                        if wingData.leaderCitizenId ~= wingData.createdBy then
                            Database.AddWingMember(wingId, {
                                citizenid = wingData.leaderCitizenId,
                                playerName = wingData.leaderName,
                                gradeLevel = 5
                            })
                        end
                    end
                end)
                callback(wingId, nil)
            else
                print("^1[Alpha Wings Debug]^7 Wing creation failed - likely duplicate name!")
                callback(nil, "A wing with this name already exists!")
            end
        end)
    end)
end

function Database.GetAllWings(callback)
    MySQL.query('SELECT w.*, COUNT(wm.id) as current_members FROM police_wings w LEFT JOIN police_wing_members wm ON w.id = wm.wing_id AND wm.is_active = 1 WHERE w.is_active = 1 GROUP BY w.id ORDER BY w.created_at DESC', {}, callback)
end

function Database.GetWingById(wingId, callback)
    MySQL.query('SELECT w.*, COUNT(wm.id) as current_members FROM police_wings w LEFT JOIN police_wing_members wm ON w.id = wm.wing_id AND wm.is_active = 1 WHERE w.id = ? AND w.is_active = 1 GROUP BY w.id', {wingId}, callback)
end

function Database.UpdateWing(wingId, updateData, callback)
    local setClause = {}
    local values = {}
    
    for key, value in pairs(updateData) do
        table.insert(setClause, key .. ' = ?')
        table.insert(values, value)
    end
    
    table.insert(values, wingId)
    
    MySQL.update('UPDATE police_wings SET ' .. table.concat(setClause, ', ') .. ', updated_at = CURRENT_TIMESTAMP WHERE id = ?', values, callback)
end

function Database.DeleteWing(wingId, callback)
    MySQL.update('UPDATE police_wings SET is_active = 0 WHERE id = ?', {wingId}, callback)
end

function Database.AddWingMember(wingId, memberData, callback)
    local gradeLevel = memberData.gradeLevel or 0
    MySQL.insert('INSERT INTO police_wing_members (wing_id, citizenid, player_name, wing_grade_level) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE is_active = 1, wing_grade_level = VALUES(wing_grade_level)', {
        wingId,
        memberData.citizenid,
        memberData.playerName,
        gradeLevel
    }, callback)
end

function Database.GetWingMembers(wingId, callback)
    MySQL.query('SELECT * FROM police_wing_members WHERE wing_id = ? AND is_active = 1 ORDER BY joined_at ASC', {wingId}, callback)
end

function Database.RemoveWingMember(wingId, citizenid, callback)
    MySQL.update('UPDATE police_wing_members SET is_active = 0 WHERE wing_id = ? AND citizenid = ?', {wingId, citizenid}, callback)
end

function Database.GetPlayerWingInfo(citizenid, callback)
    MySQL.query([[
        SELECT w.*, wm.wing_grade_level, wm.joined_at
        FROM police_wings w
        JOIN police_wing_members wm ON w.id = wm.wing_id
        WHERE wm.citizenid = ? AND w.is_active = 1 AND wm.is_active = 1
        ORDER BY wm.joined_at DESC
    ]], {citizenid}, function(result)
        callback(result or {})
    end)
end

function Database.GetPlayerAllWingMemberships(citizenid, callback)
    MySQL.query([[
        SELECT
            w.*,
            wm.wing_grade_level,
            wm.joined_at,
            wg.grade_name,
            wg.permissions
        FROM police_wings w
        JOIN police_wing_members wm ON w.id = wm.wing_id
        LEFT JOIN police_wing_grades wg ON wm.wing_id = wg.wing_id AND wm.wing_grade_level = wg.grade_level
        WHERE wm.citizenid = ? AND w.is_active = 1 AND wm.is_active = 1
        ORDER BY wm.wing_grade_level DESC, wm.joined_at DESC
    ]], {citizenid}, function(result)
        callback(result or {})
    end)
end

function Database.GetPlayerPrimaryWingInfo(citizenid, callback)
    MySQL.query([[
        SELECT w.*, wm.wing_grade_level, wm.joined_at
        FROM police_wings w
        JOIN police_wing_members wm ON w.id = wm.wing_id
        WHERE wm.citizenid = ? AND w.is_active = 1 AND wm.is_active = 1
        ORDER BY wm.wing_grade_level DESC, wm.joined_at DESC
        LIMIT 1
    ]], {citizenid}, function(result)
        callback(result and result[1] or nil)
    end)
end

function Database.UpdateWingRadio(wingId, radioFrequency, callback)
    MySQL.update('UPDATE police_wings SET radio_frequency = ? WHERE id = ?', {radioFrequency, wingId}, callback)
end

function Database.LogActivity(wingId, citizenid, activityType, description, points, callback)
    MySQL.insert('INSERT INTO police_wing_activity (wing_id, citizenid, activity_type, description, points) VALUES (?, ?, ?, ?, ?)', {
        wingId, citizenid, activityType, description, points or 0
    }, callback)
end

function Database.GetWingPoints(callback)
    MySQL.query('SELECT wing_id, SUM(points) as total_points FROM police_wing_activity GROUP BY wing_id', {}, callback)
end

function Database.GetWingStatistics(callback)
    MySQL.query([[
        SELECT
            w.id,
            w.name,
            w.created_at,
            w.created_by_name,
            COUNT(wm.id) as total_members,
            SUM(CASE WHEN wm.is_active = 1 THEN 1 ELSE 0 END) as active_members
        FROM police_wings w
        LEFT JOIN police_wing_members wm ON w.id = wm.wing_id
        WHERE w.is_active = 1
        GROUP BY w.id
    ]], {}, callback)
end

function Database.GetWingsStatistics(callback)
    MySQL.query([[
        SELECT
            COUNT(DISTINCT w.id) as totalWings,
            COUNT(DISTINCT CASE WHEN w.is_active = 1 THEN w.id END) as activeWings,
            COUNT(DISTINCT wm.citizenid) as totalMembers,
            COUNT(DISTINCT CASE WHEN wm.is_active = 1 THEN wm.citizenid END) as activeMembers
        FROM police_wings w
        LEFT JOIN police_wing_members wm ON w.id = wm.wing_id
    ]], {}, function(result)
        if result and result[1] then
            callback(result[1])
        else
            callback({
                totalWings = 0,
                activeWings = 0,
                totalMembers = 0,
                activeMembers = 0
            })
        end
    end)
end

function Database.UpdateMemberGrade(wingId, citizenid, gradeLevel, callback)
    MySQL.update('UPDATE police_wing_members SET wing_grade_level = ? WHERE wing_id = ? AND citizenid = ? AND is_active = 1', {
        gradeLevel, wingId, citizenid
    }, function(affectedRows)
        if affectedRows > 0 then
            callback(true, "Member grade updated successfully!")
        else
            callback(false, "Failed to update member grade!")
        end
    end)
end

function Database.SendWingAnnouncement(wingId, senderCitizenid, senderName, message, callback)
    MySQL.insert('INSERT INTO police_wing_announcements (wing_id, sender_citizenid, sender_name, message) VALUES (?, ?, ?, ?)', {
        wingId, senderCitizenid, senderName, message
    }, function(insertId)
        callback(insertId ~= nil)
    end)
end

function Database.GetWingDetailedStatistics(wingId, callback)
    MySQL.query([[
        SELECT
            w.name as wing_name,
            w.description,
            w.max_members,
            w.created_at,
            w.created_by_name,
            COUNT(DISTINCT wm.citizenid) as total_members,
            COUNT(DISTINCT CASE WHEN wm.is_active = 1 THEN wm.citizenid END) as active_members,
            COUNT(DISTINCT CASE WHEN wm.wing_grade_level >= 4 THEN wm.citizenid END) as leaders_count,
            COUNT(DISTINCT wa.id) as total_announcements
        FROM police_wings w
        LEFT JOIN police_wing_members wm ON w.id = wm.wing_id
        LEFT JOIN police_wing_announcements wa ON w.id = wa.wing_id
        WHERE w.id = ? AND w.is_active = 1
        GROUP BY w.id
    ]], {wingId}, function(result)
        if result and result[1] then
            callback(result[1])
        else
            callback(nil)
        end
    end)
end

function Database.UpdateWingRadio(wingId, radioFrequency, callback)
    MySQL.update('UPDATE police_wings SET radio_frequency = ? WHERE id = ? AND is_active = 1', {
        radioFrequency, wingId
    }, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

function Database.UpdateWingDescription(wingId, description, callback)
    MySQL.update('UPDATE police_wings SET description = ? WHERE id = ? AND is_active = 1', {
        description, wingId
    }, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

function Database.UpdateWingMaxMembers(wingId, maxMembers, callback)
    MySQL.update('UPDATE police_wings SET max_members = ? WHERE id = ? AND is_active = 1', {
        maxMembers, wingId
    }, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

function Database.UpdateWingLeader(wingId, leaderCitizenId, leaderName, callback)
    MySQL.update('UPDATE police_wings SET leader_citizenid = ?, leader_name = ? WHERE id = ?', {
        leaderCitizenId, leaderName, wingId
    }, callback)
end

function Database.CanAddPlayerToWing(citizenid, wingId, callback)
    MySQL.query('SELECT COUNT(*) as count FROM police_wing_members WHERE citizenid = ? AND wing_id = ? AND is_active = 1', {citizenid, wingId}, function(result)
        local isAlreadyInThisWing = result and result[1] and result[1].count > 0
        callback(not isAlreadyInThisWing)
    end)
end

function Database.GetWingCapacity(wingId, callback)
    MySQL.query([[
        SELECT 
            w.max_members,
            COUNT(wm.id) as current_members
        FROM police_wings w 
        LEFT JOIN police_wing_members wm ON w.id = wm.wing_id AND wm.is_active = 1
        WHERE w.id = ? AND w.is_active = 1
        GROUP BY w.id
    ]], {wingId}, callback)
end

function Database.CreateWingGrade(wingId, gradeData, callback)
    MySQL.query('INSERT IGNORE INTO police_wing_grades (wing_id, grade_name, grade_level, grade_description, permissions) VALUES (?, ?, ?, ?, ?)', {
        wingId,
        gradeData.name,
        gradeData.level,
        gradeData.description,
        json.encode(gradeData.permissions or {})
    }, function(result)
        if callback then
            callback(true)
        end
    end)
end

function Database.GetWingGrades(wingId, callback)
    MySQL.query('SELECT * FROM police_wing_grades WHERE wing_id = ? AND is_active = 1 ORDER BY grade_level ASC', {wingId}, callback)
end

function Database.UpdateWingGrade(gradeId, gradeData, callback)
    local setClause = {}
    local values = {}
    
    for key, value in pairs(gradeData) do
        if key == 'permissions' then
            table.insert(setClause, key .. ' = ?')
            table.insert(values, json.encode(value))
        else
            table.insert(setClause, key .. ' = ?')
            table.insert(values, value)
        end
    end
    
    table.insert(values, gradeId)
    
    MySQL.update('UPDATE police_wing_grades SET ' .. table.concat(setClause, ', ') .. ' WHERE id = ?', values, callback)
end

function Database.DeleteWingGrade(gradeId, callback)
    MySQL.update('UPDATE police_wing_grades SET is_active = 0 WHERE id = ?', {gradeId}, callback)
end

function Database.CreateOrUpdateWingGrade(wingId, gradeData, callback)
    MySQL.query([[
        INSERT INTO police_wing_grades (wing_id, grade_name, grade_level, grade_description, permissions)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            grade_name = VALUES(grade_name),
            grade_description = VALUES(grade_description),
            permissions = VALUES(permissions),
            is_active = 1
    ]], {
        wingId,
        gradeData.name,
        gradeData.level,
        gradeData.description,
        json.encode(gradeData.permissions or {})
    }, function(result)
        if callback then
            callback(result ~= nil)
        end
    end)
end

function Database.GetMemberWithGrade(wingId, citizenid, callback)
    MySQL.query([[
        SELECT 
            wm.*,
            wg.grade_name,
            wg.grade_description,
            wg.permissions
        FROM police_wing_members wm
        LEFT JOIN police_wing_grades wg ON wm.wing_id = wg.wing_id AND wm.wing_grade_level = wg.grade_level
        WHERE wm.wing_id = ? AND wm.citizenid = ? AND wm.is_active = 1
    ]], {wingId, citizenid}, function(result)
        callback(result and result[1] or nil)
    end)
end

function Database.GetWingMembersWithGrades(wingId, callback)
    MySQL.query([[
        SELECT 
            wm.*,
            wg.grade_name,
            wg.grade_description,
            wg.permissions
        FROM police_wing_members wm
        LEFT JOIN police_wing_grades wg ON wm.wing_id = wg.wing_id AND wm.wing_grade_level = wg.grade_level
        WHERE wm.wing_id = ? AND wm.is_active = 1
        ORDER BY wm.wing_grade_level DESC, wm.joined_at ASC
    ]], {wingId}, callback)
end

function Database.InitializeDefaultWingGrades(wingId, callback)
    Database.GetWingGrades(wingId, function(existingGrades)
        if existingGrades and #existingGrades > 0 then
            print(string.format("^3[Alpha Wings]^7 Wing %d already has %d grades, skipping initialization", wingId, #existingGrades))
            if callback then callback(true) end
            return
        end

        local defaultGrades = {
            {name = "Recruit", level = 0, description = "New wing member"},
            {name = "Officer", level = 1, description = "Standard wing officer"},
            {name = "Senior Officer", level = 2, description = "Experienced wing officer"},
            {name = "Sergeant", level = 3, description = "Wing supervisor"},
            {name = "Lieutenant", level = 4, description = "Wing commander"},
            {name = "Leader", level = 5, description = "Wing leader"}
        }

        local completed = 0
        local total = #defaultGrades

        print(string.format("^2[Alpha Wings]^7 Initializing %d default grades for wing %d", total, wingId))

        for _, grade in ipairs(defaultGrades) do
            Database.CreateWingGrade(wingId, grade, function(success)
                completed = completed + 1
                if completed == total then
                    print(string.format("^2[Alpha Wings]^7 Successfully initialized %d grades for wing %d", total, wingId))
                    if callback then callback(true) end
                end
            end)
        end
    end)
end

CreateThread(function()
    Wait(1000)
    Database.InitializeDatabase()
end)

function Database.RemoveMemberFromWing(wingId, citizenid, callback)
    MySQL.update('UPDATE police_wing_members SET is_active = 0 WHERE wing_id = ? AND citizenid = ?', {
        wingId, citizenid
    }, function(affectedRows)
        if callback then
            callback(affectedRows > 0)
        end
    end)
end

function Database.SetWingRadio(wingId, radioFrequency, callback)
    MySQL.update('UPDATE police_wings SET radio_frequency = ? WHERE id = ?', {
        radioFrequency, wingId
    }, function(affectedRows)
        if callback then
            callback(affectedRows > 0)
        end
    end)
end

function Database.StoreAnnouncement(wingId, senderCitizenid, message, callback)
    MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', {senderCitizenid}, function(result)
        local senderName = "Unknown"
        if result[1] then
            local charinfo = json.decode(result[1].charinfo)
            senderName = charinfo.firstname .. " " .. charinfo.lastname
        end
        
        MySQL.insert('INSERT INTO police_wing_announcements (wing_id, sender_citizenid, sender_name, message) VALUES (?, ?, ?, ?)', {
            wingId, senderCitizenid, senderName, message
        }, function(insertId)
            if callback then
                callback(insertId ~= nil)
            end
        end)
    end)
end

function Database.GetWingAnnouncements(wingId, callback)
    MySQL.query([[
        SELECT 
            a.*,
            w.name as wing_name
        FROM police_wing_announcements a
        JOIN police_wings w ON a.wing_id = w.id
        WHERE a.wing_id = ?
        ORDER BY a.created_at DESC
        LIMIT 50
    ]], {wingId}, function(result)
        if callback then
            callback(result)
        end
    end)
end

function Database.HasWingPermission(citizenid, wingId, permission, callback)
    MySQL.query([[
        SELECT 
            wm.*,
            wg.permissions,
            w.leader_citizenid
        FROM police_wing_members wm
        LEFT JOIN police_wing_grades wg ON wm.wing_id = wg.wing_id AND wm.wing_grade_level = wg.grade_level
        LEFT JOIN police_wings w ON wm.wing_id = w.id
        WHERE wm.citizenid = ? AND wm.wing_id = ? AND wm.is_active = 1
    ]], {citizenid, wingId}, function(result)
        if result and result[1] then
            local member = result[1]
            local hasPermission = false
            
            local gradeLevel = member.wing_grade_level or 0

            if gradeLevel >= 5 or member.citizenid == member.leader_citizenid then
                hasPermission = true
            elseif member.permissions then
                local permissions = json.decode(member.permissions)
                hasPermission = permissions[permission] == true
            else
                local gradePerms = Config.WingsSystem.gradePermissions[gradeLevel]
                if gradePerms then
                    hasPermission = gradePerms[permission] == true
                end
            end
            
            callback(hasPermission, member)
        else
            callback(false, nil)
        end
    end)
end

function Database.GetWingMemberWithPermissions(citizenid, callback)
    MySQL.query([[
        SELECT
            wm.*,
            wg.permissions,
            wg.grade_name,
            w.name as wing_name,
            w.leader_citizenid,
            w.id as wing_id
        FROM police_wing_members wm
        LEFT JOIN police_wing_grades wg ON wm.wing_id = wg.wing_id AND wm.wing_grade_level = wg.grade_level
        LEFT JOIN police_wings w ON wm.wing_id = w.id
        WHERE wm.citizenid = ? AND wm.is_active = 1 AND w.is_active = 1
        ORDER BY wm.wing_grade_level DESC, wm.joined_at DESC
        LIMIT 1
    ]], {citizenid}, function(result)
        if result and result[1] then
            local member = result[1]
            local permissions = {}
            
            local gradeLevel = member.wing_grade_level or 0

            if gradeLevel >= 5 or member.citizenid == member.leader_citizenid then
                permissions = {
                    manage_members = true,
                    manage_wing = true,
                    send_announcements = true,
                    view_management = true,
                    leadership = true,
                    view_all_members = true,
                    can_add_members = true,
                    can_remove_members = true,
                    can_assign_grades = true,
                    can_transfer_leadership = true,
                    can_set_radio = true,
                    can_view_statistics = true,
                    can_manage_members = true
                }
            elseif member.permissions then
                permissions = json.decode(member.permissions)
            else
                local gradePerms = Config.WingsSystem.gradePermissions[gradeLevel]
                if gradePerms then
                    permissions = {
                        manage_members = gradePerms.canManageMembers,
                        manage_wing = gradePerms.canManageMembers,
                        send_announcements = gradePerms.canSendAnnouncements,
                        view_management = gradePerms.canViewStatistics,
                        leadership = gradePerms.canTransferLeadership,
                        view_all_members = gradePerms.canViewAllMembers
                    }
                end
            end
            
            member.parsed_permissions = permissions
            callback(member)
        else
            callback(nil)
        end
    end)
end

function Database.UpdateWingGradePermissions(wingId, gradeLevel, permissions, callback)
    MySQL.update('UPDATE police_wing_grades SET permissions = ? WHERE wing_id = ? AND grade_level = ?', {
        json.encode(permissions), wingId, gradeLevel
    }, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

function Database.GetWingGradesForPermissionManagement(wingId, callback)
    MySQL.query([[
        SELECT 
            wg.*,
            COUNT(wm.id) as member_count
        FROM police_wing_grades wg
        LEFT JOIN police_wing_members wm ON wg.wing_id = wm.wing_id AND wg.grade_level = wm.wing_grade_level AND wm.is_active = 1
        WHERE wg.wing_id = ? AND wg.is_active = 1
        GROUP BY wg.id
        ORDER BY wg.grade_level DESC
    ]], {wingId}, function(result)
        if result then
            for _, grade in pairs(result) do
                if grade.permissions then
                    grade.parsed_permissions = json.decode(grade.permissions)
                else
                    grade.parsed_permissions = {}
                end
            end
        end
        callback(result or {})
    end)
end

function Database.IsWingLeader(citizenid, wingId, callback)
    MySQL.query([[
        SELECT
            wm.*,
            wg.permissions,
            wg.grade_name,
            w.created_by as wing_creator
        FROM police_wing_members wm
        LEFT JOIN police_wing_grades wg ON wm.wing_id = wg.wing_id AND wm.wing_grade_level = wg.grade_level
        LEFT JOIN police_wings w ON wm.wing_id = w.id
        WHERE wm.citizenid = ? AND wm.wing_id = ? AND wm.is_active = 1
    ]], {citizenid, wingId}, function(result)
        if result and result[1] then
            local member = result[1]

            local isLeader = (member.wing_grade_level >= 5) or (member.citizenid == member.wing_creator)
            local hasLeadershipPerms = false
            
            if member.permissions then
                local permissions = json.decode(member.permissions)
                hasLeadershipPerms = permissions.manage_members or permissions.manage_wing or permissions.leadership
            end
            
            callback(isLeader or hasLeadershipPerms, member)
        else
            callback(false, nil)
        end
    end)
end

function Database.GetAllPoliceOfficers(callback)
    MySQL.query([[
        SELECT 
            p.citizenid,
            p.charinfo,
            p.job,
            CASE 
                WHEN wm.citizenid IS NOT NULL THEN 1 
                ELSE 0 
            END as in_wing,
            w.name as wing_name
        FROM players p
        LEFT JOIN police_wing_members wm ON p.citizenid = wm.citizenid AND wm.is_active = 1
        LEFT JOIN police_wings w ON wm.wing_id = w.id AND w.is_active = 1
        WHERE JSON_EXTRACT(p.job, '$.name') = 'police'
        ORDER BY JSON_EXTRACT(p.charinfo, '$.firstname'), JSON_EXTRACT(p.charinfo, '$.lastname')
    ]], {}, function(result)
        local officers = {}
        if result then
            for _, officer in pairs(result) do
                local charinfo = json.decode(officer.charinfo)
                local job = json.decode(officer.job)
                
                table.insert(officers, {
                    citizenid = officer.citizenid,
                    name = charinfo.firstname .. " " .. charinfo.lastname,
                    grade = job.grade.name or "Officer",
                    in_wing = officer.in_wing == 1,
                    wing_name = officer.wing_name
                })
            end
        end
        callback(officers)
    end)
end

function Database.AddMemberToWingByLeader(wingId, citizenid, playerName, gradeLevel, callback)
    MySQL.query('SELECT wing_id FROM police_wing_members WHERE citizenid = ? AND wing_id = ? AND is_active = 1', {citizenid, wingId}, function(result)
        if result and #result > 0 then
            callback(false, "Player is already in this wing!")
            return
        end
        
        Database.GetWingCapacity(wingId, function(capacity)
            if capacity and capacity[1] then
                local current = capacity[1].current_members or 0
                local max = capacity[1].max_members or 15
                
                if current >= max then
                    callback(false, "Wing is at maximum capacity!")
                    return
                end
            end
            
            MySQL.insert('INSERT INTO police_wing_members (wing_id, citizenid, player_name, wing_grade_level) VALUES (?, ?, ?, ?)', {
                wingId, citizenid, playerName, gradeLevel or 0
            }, function(insertId)
                callback(insertId ~= nil, insertId and "Member added successfully!" or "Failed to add member!")
            end)
        end)
    end)
end

function Database.UpdateWingByLeader(wingId, updateData, callback)
    local setClause = {}
    local values = {}
    
    local allowedFields = {
        'description', 'max_members', 'radio_frequency'
    }
    
    for key, value in pairs(updateData) do
        if table.contains(allowedFields, key) then
            table.insert(setClause, key .. ' = ?')
            table.insert(values, value)
        end
    end
    
    if #setClause == 0 then
        callback(false, "No valid fields to update!")
        return
    end
    
    table.insert(values, wingId)
    
    MySQL.update('UPDATE police_wings SET ' .. table.concat(setClause, ', ') .. ' WHERE id = ?', values, function(affectedRows)
        callback(affectedRows > 0, affectedRows > 0 and "Wing updated successfully!" or "Failed to update wing!")
    end)
end

function Database.DisbandWingByLeader(wingId, callback)
    MySQL.update('UPDATE police_wing_members SET is_active = 0 WHERE wing_id = ?', {wingId}, function()
        MySQL.update('UPDATE police_wings SET is_active = 0 WHERE id = ?', {wingId}, function(affectedRows)
            callback(affectedRows > 0, affectedRows > 0 and "Wing disbanded successfully!" or "Failed to disband wing!")
        end)
    end)
end

function Database.PromoteToLeadership(wingId, citizenid, gradeLevel, callback)
    MySQL.update('UPDATE police_wing_members SET wing_grade_level = ? WHERE wing_id = ? AND citizenid = ?', {
        gradeLevel or 5, wingId, citizenid
    }, function(affectedRows)
        callback(affectedRows > 0, affectedRows > 0 and "Member promoted to leadership!" or "Failed to promote member!")
    end)
end

function Database.IsWingCreator(citizenid, callback)
    MySQL.query('SELECT COUNT(*) as count FROM police_wings WHERE created_by = ? AND is_active = 1', {citizenid}, function(result)
        if result and result[1] then
            callback(result[1].count > 0)
        else
            callback(false)
        end
    end)
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

_G.Database = Database

print("^1[Alpha Wings Debug]^7 === Database.lua loaded with NEW CreateWing function! ===")