-- Alpha Wings System Database Structure
-- Created for QBCore Framework
-- Version: 1.0

-- Create wings table
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

-- Create wing members table (allows multiple wing memberships)
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
    FOREIGN KEY (`wing_id`) REFERENCES `police_wings`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Remove old unique constraint to allow multiple wing memberships
ALTER TABLE `police_wing_members` DROP INDEX IF EXISTS `wing_member`;

-- Create wing activity table
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

-- Create wing grades table
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

-- Insert default wing grades for existing wings (ignore duplicates)
INSERT IGNORE INTO `police_wing_grades` (`wing_id`, `grade_name`, `grade_level`, `grade_description`, `permissions`)
SELECT
    w.id as wing_id,
    'Recruit' as grade_name,
    0 as grade_level,
    'New wing member' as grade_description,
    '{}' as permissions
FROM `police_wings` w
WHERE w.is_active = 1
AND NOT EXISTS (
    SELECT 1 FROM `police_wing_grades` wg
    WHERE wg.wing_id = w.id AND wg.grade_level = 0
);

INSERT IGNORE INTO `police_wing_grades` (`wing_id`, `grade_name`, `grade_level`, `grade_description`, `permissions`)
SELECT
    w.id as wing_id,
    'Officer' as grade_name,
    1 as grade_level,
    'Standard wing officer' as grade_description,
    '{}' as permissions
FROM `police_wings` w
WHERE w.is_active = 1
AND NOT EXISTS (
    SELECT 1 FROM `police_wing_grades` wg
    WHERE wg.wing_id = w.id AND wg.grade_level = 1
);

INSERT IGNORE INTO `police_wing_grades` (`wing_id`, `grade_name`, `grade_level`, `grade_description`, `permissions`)
SELECT
    w.id as wing_id,
    'Senior Officer' as grade_name,
    2 as grade_level,
    'Experienced wing officer' as grade_description,
    '{}' as permissions
FROM `police_wings` w
WHERE w.is_active = 1
AND NOT EXISTS (
    SELECT 1 FROM `police_wing_grades` wg
    WHERE wg.wing_id = w.id AND wg.grade_level = 2
);

INSERT IGNORE INTO `police_wing_grades` (`wing_id`, `grade_name`, `grade_level`, `grade_description`, `permissions`)
SELECT
    w.id as wing_id,
    'Sergeant' as grade_name,
    3 as grade_level,
    'Wing supervisor' as grade_description,
    '{}' as permissions
FROM `police_wings` w
WHERE w.is_active = 1
AND NOT EXISTS (
    SELECT 1 FROM `police_wing_grades` wg
    WHERE wg.wing_id = w.id AND wg.grade_level = 3
);

INSERT IGNORE INTO `police_wing_grades` (`wing_id`, `grade_name`, `grade_level`, `grade_description`, `permissions`)
SELECT
    w.id as wing_id,
    'Lieutenant' as grade_name,
    4 as grade_level,
    'Wing commander' as grade_description,
    '{}' as permissions
FROM `police_wings` w
WHERE w.is_active = 1
AND NOT EXISTS (
    SELECT 1 FROM `police_wing_grades` wg
    WHERE wg.wing_id = w.id AND wg.grade_level = 4
);

INSERT IGNORE INTO `police_wing_grades` (`wing_id`, `grade_name`, `grade_level`, `grade_description`, `permissions`)
SELECT
    w.id as wing_id,
    'Leader' as grade_name,
    5 as grade_level,
    'Wing leader' as grade_description,
    '{}' as permissions
FROM `police_wings` w
WHERE w.is_active = 1
AND NOT EXISTS (
    SELECT 1 FROM `police_wing_grades` wg
    WHERE wg.wing_id = w.id AND wg.grade_level = 5
);

-- Insert default wing grades for existing wings (if any)
-- This will be handled by the script automatically when wings are created

-- Add indexes for better performance
CREATE INDEX `idx_wing_members_citizenid` ON `police_wing_members` (`citizenid`);
CREATE INDEX `idx_wing_members_wing_id` ON `police_wing_members` (`wing_id`);
CREATE INDEX `idx_wing_activity_wing_id` ON `police_wing_activity` (`wing_id`);
CREATE INDEX `idx_wing_activity_citizenid` ON `police_wing_activity` (`citizenid`);
CREATE INDEX `idx_wing_grades_wing_id` ON `police_wing_grades` (`wing_id`);
CREATE INDEX `idx_wing_grades_level` ON `police_wing_grades` (`grade_level`);

-- Migration: Remove rank column and ensure wing_grade_level exists
ALTER TABLE `police_wing_members` 
ADD COLUMN IF NOT EXISTS `wing_grade_level` int(11) NOT NULL DEFAULT 0;

-- Remove rank column if it exists (migration from rank-based to grade-only system)
ALTER TABLE `police_wing_members` 
DROP COLUMN IF EXISTS `rank`;

-- Update existing police_wings table to add radio_frequency column if it doesn't exist
ALTER TABLE `police_wings` 
ADD COLUMN IF NOT EXISTS `radio_frequency` varchar(20) DEFAULT NULL AFTER `leader_name`;

-- Comments for documentation
ALTER TABLE `police_wings` COMMENT = 'Police wings/departments table';
ALTER TABLE `police_wing_members` COMMENT = 'Wing members with grade-based permissions';
ALTER TABLE `police_wing_activity` COMMENT = 'Activity log for wing members';
ALTER TABLE `police_wing_grades` COMMENT = 'Wing-specific grade structure';