CW = CW or {}

local function SafeQuery(sql, params)
    local ok, result = pcall(function()
        return MySQL.query.await(sql, params or {})
    end)

    if not ok then
        print(('[cw-core] SQL query failed: %s | %s'):format(tostring(result), tostring(sql)))
        return nil
    end

    return result
end

local function SafeUpdate(sql, params)
    local ok, result = pcall(function()
        return MySQL.update.await(sql, params or {})
    end)

    if not ok then
        print(('[cw-core] SQL update failed: %s | %s'):format(tostring(result), tostring(sql)))
        return nil
    end

    return result
end

local function ColumnExists(tableName, columnName)
    local rows = SafeQuery([[ 
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
    ]], { tableName, columnName })

    local row = rows and rows[1]
    return tonumber(row and row.count or 0) > 0
end

local function EnsureColumn(tableName, columnName, definition)
    if ColumnExists(tableName, columnName) then
        return
    end

    local sql = ('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, definition)
    print(('[cw-core] Applying migration: %s'):format(sql))
    SafeQuery(sql)
end

CreateThread(function()
    print('[cw-core] Checking database schema...')

    SafeQuery([[
        CREATE TABLE IF NOT EXISTS accounts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            license VARCHAR(128) NOT NULL UNIQUE,
            steam VARCHAR(128) NULL,
            discord VARCHAR(128) NULL,
            fivem VARCHAR(128) NULL,
            name VARCHAR(100) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    SafeQuery([[
        CREATE TABLE IF NOT EXISTS characters (
            id INT AUTO_INCREMENT PRIMARY KEY,
            account_id INT NOT NULL,
            slot INT NOT NULL DEFAULT 1,
            firstname VARCHAR(50) NOT NULL,
            lastname VARCHAR(50) NOT NULL,
            gender VARCHAR(20) NOT NULL,
            age INT NOT NULL,
            cash DECIMAL(10,2) NOT NULL DEFAULT 0,
            bank DECIMAL(10,2) NOT NULL DEFAULT 0,
            pos_x DOUBLE NULL,
            pos_y DOUBLE NULL,
            pos_z DOUBLE NULL,
            heading DOUBLE NULL,
            skin LONGTEXT NULL,
            is_dead TINYINT(1) NOT NULL DEFAULT 0,
            revived_at DATETIME NULL,
            delete_requested_at DATETIME NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_account_slot (account_id, slot),
            KEY idx_characters_account_id (account_id),
            KEY idx_characters_delete_requested_at (delete_requested_at),
            CONSTRAINT fk_characters_account
                FOREIGN KEY (account_id) REFERENCES accounts(id)
                ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    EnsureColumn('accounts', 'updated_at', 'updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
    EnsureColumn('characters', 'delete_requested_at', 'delete_requested_at DATETIME NULL')
    EnsureColumn('characters', 'is_dead', 'is_dead TINYINT(1) NOT NULL DEFAULT 0')
    EnsureColumn('characters', 'revived_at', 'revived_at DATETIME NULL')
    EnsureColumn('characters', 'updated_at', 'updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')

    SafeQuery([[
        CREATE TABLE IF NOT EXISTS cw_settings (
            `key` VARCHAR(64) NOT NULL,
            `value` LONGTEXT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    SafeUpdate([[ INSERT IGNORE INTO cw_settings (`key`, `value`) VALUES ('permadeath_chance', '15') ]])

    SafeQuery([[
        CREATE TABLE IF NOT EXISTS admin_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            actor_license VARCHAR(128) NULL,
            actor_name VARCHAR(100) NULL,
            action VARCHAR(100) NOT NULL,
            target_license VARCHAR(128) NULL,
            target_name VARCHAR(100) NULL,
            details LONGTEXT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    print('[cw-core] Database schema ready.')
end)
