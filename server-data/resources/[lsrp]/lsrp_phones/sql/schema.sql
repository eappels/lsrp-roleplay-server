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

CREATE TABLE IF NOT EXISTS `phone_messages` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `sender_number` varchar(16) NOT NULL,
    `recipient_number` varchar(16) NOT NULL,
    `message_body` text NOT NULL,
    `sent_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `read_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_phone_messages_sender` (`sender_number`, `sent_at`),
    KEY `idx_phone_messages_recipient` (`recipient_number`, `sent_at`),
    KEY `idx_phone_messages_read` (`recipient_number`, `sender_number`, `read_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;