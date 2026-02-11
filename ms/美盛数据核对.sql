-- 1. 创建预聚合临时表 - 记录普通周期实收、旧欠实收、当年实收、来年预收 - 对应的的实收的汇总
CREATE TEMPORARY TABLE tmp_bill_aggregation AS
SELECT
    chargeDetailID,
    SUM(
        CASE
            WHEN isDelete = 0
            AND isEnterAccount = 1
            AND actualAccountBook <= ${accountBookDate}
            AND (
                RefundStatus IS NULL
                OR RefundStatus != '待退款'
            )
            AND precinct_collection_type != 1
            AND FIND_IN_SET(subjectCode, ${subjectStr}) THEN IFNULL (chargePaid, 0)
            ELSE 0
        END
    ) as before_this_month_chargePaid,
    SUM(
        CASE
            WHEN isDelete = 0
            AND isEnterAccount = 1
            AND actualAccountBook <= CONCAT(${searchYear}, '12')
            AND (
                RefundStatus IS NULL
                OR RefundStatus != '待退款'
            )
            AND precinct_collection_type != 1
            AND FIND_IN_SET(subjectCode, ${subjectStr}) THEN IFNULL (chargePaid, 0)
            ELSE 0
        END
    ) as before_end_year_chargePaid,
    SUM(
        CASE
            WHEN isDelete = 0
            AND isEnterAccount = 1
            AND actualAccountBook >= CONCAT(${searchYear}, '01') -- 优化日期比较
            AND actualAccountBook <= CONCAT(${searchYear}, '12')
            AND (
                RefundStatus IS NULL
                OR RefundStatus != '待退款'
            )
            AND precinct_collection_type != 1
            AND FIND_IN_SET(subjectCode, ${subjectStr}) THEN chargePaid
            ELSE 0
        END
    ) as current_year_period_month_chargePaid,
    SUM(
        CASE
            WHEN isDelete = 0
            AND isEnterAccount = 1
            AND actualAccountBook < CONCAT(${searchYear}, '01')
            AND (
                RefundStatus IS NULL
                OR RefundStatus != '待退款'
            )
            AND precinct_collection_type != 1
            AND FIND_IN_SET(subjectCode, ${subjectStr}) THEN chargePaid
            ELSE 0
        END
    ) as before_year_chargePaid
FROM
    dw_datacenter_bill
GROUP BY
    chargeDetailID;

-- 2.新增减免的相关的对应的的实收的汇总 - 实收减免、当年实收减免、旧欠实收减免、来年预收减免
CREATE TEMPORARY TABLE tmp_discount_aggregation AS
SELECT chargeDetailID,
SUM(
    CASE
        WHEN isDelete = 0
        AND discountDate <= LAST_DAY(STR_TO_DATE(${searchYearMonth},'%Y-%m'))
        THEN IFNULL(discount, 0)
        ELSE 0
    END
) as beforeInDiscountAmount,
SUM(
    CASE
        WHEN isDelete = 0
        AND discountDate <= CONCAT(${searchYear},'-12-31')
        THEN IFNULL(discount, 0)
        ELSE 0
    END
) as beforeEndDiscountAmount,
SUM(
    CASE
        WHEN isDelete = 0
        AND discountYear = ${searchYear}
        AND discountDate <= CONCAT(${searchYear},'-12-31')
        THEN IFNULL(discount, 0)
        ELSE 0
    END
) as thisYearDiscount
FROM
dw_datacenter_discount
GROUP BY chargeDetailID;

-- 4. 旧欠统计
SELECT
    0 as dateType,
    ${searchYear} as yearMonth,
    p.precinctName as "项目名称",
    SUM(IFNULL (b.current_year_period_month_chargePaid, 0) + IFNULL (d.thisYearDiscount, 0)) as “含减免的旧欠实收”,
    SUM(
        IFNULL(d.thisYearDiscount, 0) +
        IFNULL (a.actualChargeSum, 0) -
        IFNULL (b.before_year_chargePaid, 0)
    ) as "旧欠应收",
    NOW() as createDateTime
FROM
    dw_datacenter_charge a
    INNER JOIN dw_datacenter_chargeitem c ON a.chargeItemID = c.chargeItemID
    AND c.chargeItemType = '1'
    LEFT JOIN tmp_bill_aggregation b ON a.chargeDetailID = b.chargeDetailID
    LEFT JOIN tmp_discount_aggregation d ON a.chargeDetailID = d.chargeDetailID
    LEFT JOIN dw_datacenter_precinct p ON  p.precinctID = a.precinctID
WHERE
    a.isDelete = 0
    AND a.isCheck = '审核通过'
    AND a.shouldAccountBook < CONCAT(${searchYear}, '01')
GROUP BY
    a.enterpriseID,
    a.organizationID,
    a.precinctID;


-- 9. 清理
DROP TABLE tmp_bill_aggregation;

DROP TABLE tmp_discount_aggregation;

# DROP TABLE dws_precinct_target_collection_usual;
