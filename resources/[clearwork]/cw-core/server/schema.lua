CreateThread(function()
    print('[cw-core] Checking database schema...')

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS accounts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            license VARCHAR(128) NOT NULL UNIQUE,
            steam VARCHAR(128) NULL,
            discord VARCHAR(128) NULL,
            fivem VARCHAR(128) NULL,
            name VARCHAR(100) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query.await([[
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
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

            UNIQUE KEY uniq_account_slot (account_id, slot),

            CONSTRAINT fk_characters_account
                FOREIGN KEY (account_id)
                REFERENCES accounts(id)
                ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    print('[cw-core] Database schema ready.')
end)