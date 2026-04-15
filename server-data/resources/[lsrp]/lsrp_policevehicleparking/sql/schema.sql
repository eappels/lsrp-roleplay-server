-- SQL Schema for Emergency Fleet Parking
-- Run this in your database to create the separate emergency fleet table.

CREATE TABLE IF NOT EXISTS `emergency_owned_vehicles` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `license` varchar(60) NOT NULL,
    `state_id` int(10) unsigned DEFAULT NULL,
    `vehicle_model` varchar(50) NOT NULL,
    `vehicle_plate` varchar(20) NOT NULL,
    `parking_zone` varchar(100) DEFAULT NULL,
    `vehicle_props` longtext NOT NULL,
    `status` varchar(20) NOT NULL DEFAULT 'parked',
    `purchased_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `stored_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
    `last_retrieved_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `vehicle_plate_unique` (`vehicle_plate`),
    KEY `license` (`license`),
    KEY `state_id` (`state_id`),
    KEY `status` (`status`),
    KEY `parking_zone` (`parking_zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
