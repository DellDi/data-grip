-- 按项目 ID 清理 newsee-datacenter.dws_discount_precinct 以及其他分库中的脏数据
-- 规则：
-- 1) 传入保留库名 keep_db
-- 2) 传入项目 ID precinct_id
-- 3) 只删除“除 keep_db 之外”的 newsee-charge-01 ~ newsee-charge-10 中该项目对应的脏行 pk
-- 4) 先删除这些脏行在各分库中的记录，再按相同 pk 删除 newsee-datacenter 中的汇总记录

DROP PROCEDURE IF EXISTS sp_cleanup_discount_precinct_dirty;

DELIMITER $$
CREATE PROCEDURE sp_cleanup_discount_precinct_dirty(
    IN p_keep_db VARCHAR(50),
    IN p_precinct_id BIGINT
)
BEGIN
    DECLARE v_keep_db VARCHAR(50);
    DECLARE v_precinct_id BIGINT;
    DECLARE v_db VARCHAR(50);
    DECLARE v_deleted_source_rows BIGINT DEFAULT 0;
    DECLARE v_deleted_target_rows BIGINT DEFAULT 0;
    DECLARE done INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT db_name
        FROM tmp_source_db_list;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SET v_keep_db = TRIM(p_keep_db);
    SET v_precinct_id = p_precinct_id;

    IF v_keep_db NOT IN (
        'newsee-charge-01', 'newsee-charge-02', 'newsee-charge-03', 'newsee-charge-04', 'newsee-charge-05',
        'newsee-charge-06', 'newsee-charge-07', 'newsee-charge-08', 'newsee-charge-09', 'newsee-charge-10'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_keep_db must be one of newsee-charge-01 ~ newsee-charge-10';
    END IF;

    IF v_precinct_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'p_precinct_id must not be NULL';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_source_db_list;
    CREATE TEMPORARY TABLE tmp_source_db_list (
        db_name VARCHAR(50) NOT NULL PRIMARY KEY
    ) ENGINE=InnoDB;

    DROP TEMPORARY TABLE IF EXISTS tmp_dirty_pk;
    CREATE TEMPORARY TABLE tmp_dirty_pk (
        pk VARCHAR(255) NOT NULL,
        PRIMARY KEY (pk)
    ) ENGINE=InnoDB;

    INSERT INTO tmp_source_db_list (db_name) VALUES
        ('newsee-charge-01'),
        ('newsee-charge-02'),
        ('newsee-charge-03'),
        ('newsee-charge-04'),
        ('newsee-charge-05'),
        ('newsee-charge-06'),
        ('newsee-charge-07'),
        ('newsee-charge-08'),
        ('newsee-charge-09'),
        ('newsee-charge-10');

    DELETE FROM tmp_source_db_list WHERE db_name = v_keep_db;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_db;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        SET @sql = CONCAT(
            'INSERT IGNORE INTO tmp_dirty_pk (pk) ',
            'SELECT pk FROM `', v_db, '`.dws_discount_precinct ',
            'WHERE precinctId = ', v_precinct_id
        );

        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE cur;

    SET done = 0;
    OPEN cur;

    read_loop_delete_source: LOOP
        FETCH cur INTO v_db;
        IF done = 1 THEN
            LEAVE read_loop_delete_source;
        END IF;

        SET @sql = CONCAT(
            'DELETE FROM `', v_db, '`.dws_discount_precinct ',
            'WHERE pk IN (SELECT pk FROM tmp_dirty_pk)'
        );

        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        SET v_deleted_source_rows = v_deleted_source_rows + ROW_COUNT();
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE cur;

    DELETE FROM `newsee-datacenter`.dws_discount_precinct
    WHERE pk IN (SELECT pk FROM tmp_dirty_pk);
    SET v_deleted_target_rows = ROW_COUNT();

    SELECT
        v_keep_db AS keep_db,
        v_precinct_id AS precinct_id,
        (SELECT COUNT(*) FROM tmp_dirty_pk) AS dirty_pk_count,
        v_deleted_source_rows AS deleted_source_rows,
        v_deleted_target_rows AS deleted_target_rows;

    DROP TEMPORARY TABLE IF EXISTS tmp_dirty_pk;
    DROP TEMPORARY TABLE IF EXISTS tmp_source_db_list;
END$$
DELIMITER ;

-- 执行示例：
-- CALL sp_cleanup_discount_precinct_dirty('newsee-charge-03', 100017);
