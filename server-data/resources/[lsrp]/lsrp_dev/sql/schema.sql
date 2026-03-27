-- SQL Schema for LSRP Dev admin persistence
-- Run this in your database to create the persistent dev admin table.

CREATE TABLE IF NOT EXISTS `dev_admins` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `state_id` int(11) DEFAULT NULL,
    `license` varchar(64) DEFAULT NULL,
    `name` varchar(100) DEFAULT NULL,
    `granted_by` varchar(100) DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_dev_admins_state_id` (`state_id`),
    UNIQUE KEY `uniq_dev_admins_license` (`license`),
    KEY `idx_dev_admins_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;