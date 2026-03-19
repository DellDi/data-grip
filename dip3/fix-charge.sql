UPDATE charge_customerchargedetail
SET AccountBook = COALESCE(
    CASE
        WHEN AccountBook REGEXP '^[0-9]{6}$' THEN AccountBook
        WHEN AccountBook REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN DATE_FORMAT(STR_TO_DATE(AccountBook, '%Y-%m-%d'), '%Y%m')
        WHEN AccountBook REGEXP '^[0-9]{4}-[0-9]{2}$'
            THEN REPLACE(AccountBook, '-', '')
        ELSE NULL
    END,
    DATE_FORMAT(ShouldChargeDate, '%Y%m')
)
WHERE AccountBook IS NULL
   OR AccountBook NOT REGEXP '^[0-9]{6}$'
   OR AccountBook REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
   OR AccountBook REGEXP '^[0-9]{4}-[0-9]{2}$';