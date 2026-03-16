-- SQL schema for lsrp_economy
-- Amounts are stored as whole LS$ dollars only.

CREATE TABLE IF NOT EXISTS `lsrp_economy_balances` (
    `license` varchar(64) NOT NULL,
    `balance` bigint unsigned NOT NULL DEFAULT 0,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lsrp_economy_transactions` (
    `id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `license` varchar(64) NOT NULL,
    `delta` bigint NOT NULL,
    `balance_after` bigint unsigned NOT NULL,
    `reason` varchar(100) NOT NULL DEFAULT 'system',
    `metadata` longtext DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_license_created_at` (`license`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;