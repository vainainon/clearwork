CREATE TABLE IF NOT EXISTS `cw_inventory_state` (
  `character_id` INT NOT NULL,
  `revision` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cw_inventory_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `character_id` INT NOT NULL,
  `item_name` VARCHAR(64) NOT NULL,
  `amount` INT NOT NULL DEFAULT 1,
  `metadata` LONGTEXT NULL,
  `container_id` VARCHAR(64) NULL,
  `x` INT NULL,
  `y` INT NULL,
  `rotated` TINYINT(1) NOT NULL DEFAULT 0,
  `equip_slot` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cw_inv_character` (`character_id`),
  KEY `idx_cw_inv_location` (`character_id`, `container_id`),
  KEY `idx_cw_inv_equipment` (`character_id`, `equip_slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cw_inventory_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `character_id` INT NOT NULL,
  `account_id` INT NULL,
  `actor_source` INT NULL,
  `action` VARCHAR(64) NOT NULL,
  `item_id` INT NULL,
  `item_name` VARCHAR(64) NULL,
  `amount` INT NULL,
  `from_container` VARCHAR(64) NULL,
  `to_container` VARCHAR(64) NULL,
  `from_slot` VARCHAR(64) NULL,
  `to_slot` VARCHAR(64) NULL,
  `before_json` LONGTEXT NULL,
  `after_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cw_inv_logs_character` (`character_id`, `created_at`),
  KEY `idx_cw_inv_logs_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
