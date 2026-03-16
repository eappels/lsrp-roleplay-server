-- SQL Schema for LSRP Phonebook
-- Phone numbers are assigned as 555-0001 style values and stored in this table.

CREATE TABLE IF NOT EXISTS `phonebook_entries` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `license` varchar(64) NOT NULL,
    `phone_number` varchar(16) DEFAULT NULL,
    `display_name` varchar(100) NOT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_phonebook_license` (`license`),
    UNIQUE KEY `uniq_phonebook_number` (`phone_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;