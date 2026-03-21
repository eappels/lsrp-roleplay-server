CREATE TABLE IF NOT EXISTS `apartments` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `apartment_number` VARCHAR(16) NOT NULL UNIQUE,
  `location_index` TINYINT NOT NULL,
  `bucket` INT NOT NULL DEFAULT 0,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `price` BIGINT NOT NULL DEFAULT 0,
  `rent_due` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_owner_identifier` (`owner_identifier`),
  KEY `idx_location_index` (`location_index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;