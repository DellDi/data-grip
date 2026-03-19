	-- 100017 宜昌金色华府
	-- 当期应收b
	select a.enterpriseID,a.precinctID,'9120017' as targetId,3 as dateType,"2026-02" as yearMonth,null as numerator,null as denominator,SUM(IFNULL(a.chargeSum,0)) as targetValue,0 as layer
	from `newsee-datacenter`.dws_chargedetail_precinct_accountbook a
	left join dw_datacenter_chargeitem c on a.chargeItemID = c.chargeitemID
	where c.chargeItemClass = 2 and a.calcStartYear = "2026" and a.calcEndYear = "2026"
	and a.precinctID = 100017
	GROUP BY a.precinctID;

	-- 当期减免 a1
	select a.enterpriseID,a.precinctID,'9120018' as targetId,5 as dateType,"2026-03-15" as yearMonth,null as numerator,null as denominator,SUM(IFNULL(a.DiscountMoney,0)) as targetValue,0 as layer
	from `newsee-datacenter`.dws_discount_precinct a
	left join dw_datacenter_chargeitem c on a.chargeItemID=c.chargeItemID
	where c.chargeItemClass=2 and YEAR(a.calcStartDate) = "2026" and YEAR(a.CalcEndDate) = "2026"
	and a.DiscountDate < DATE_FORMAT("2026-03-15",'%Y%m%d') + INTERVAL 1 DAY
	and a.precinctID = 100017
	group by a.precinctID;

	-- 当期冻结	a2
	select a.enterpriseID,a.precinctID,'9120019' as targetId,5 as dateType,"2026-03-15" as yearMonth,null as numerator,null as denominator,SUM(a.arrears) as targetValue,0 as layer
  from `newsee-datacenter`.dws_chargedetail_precinct_accountbook a
  left join dw_datacenter_chargeitem c on a.chargeItemID=c.chargeItemID
	where c.chargeItemClass=2 and a.calcStartYear = "2026" and a.CalcEndYear = "2026"
	and a.FreezeTime < DATE_FORMAT("2026-03-15",'%Y%m%d') + INTERVAL 1 DAY and a.IsFreezed =1
	and a.precinctID = 100017
	group by a.precinctID;

	-- 当期收缴当年累计日已收 c
	select b.enterpriseID,b.precinctID,'9120040' as targetId,5 as dateType,"2026-03-15" as yearMonth,null as numerator,null as denominator,SUM(IFNULL(b.chargePaid,0)) as targetValue,0 as layer
	from `newsee-datacenter`.dws_payment_precinct_operatordate_jsc b
	left join dw_datacenter_chargeitem ch on b.chargeItemID = ch.chargeitemID
	where b.operatorDate < DATE_FORMAT("2026-03-15",'%Y-%m-%d') + INTERVAL 1 day
	and (b.RefundStatus is null or b.RefundStatus !='待退款') and b.precinct_collection_type != 1
	and b.subjectCode in ('已缴款','临时缴款','红冲','退款','预收款结转','预收款结转红冲','退款转预收','押金类转红冲','押金类转') and b.isAccount in (0,3)
	and ch.chargeItemClass = 2 and b.calcStartYear = "2026" and b.calcEndYear = "2026"
	and b.precinctID = 100017
	GROUP BY b.precinctID;

# 	-- datacenter
#  咸宁福星城 SELECT 10804378.08 - 3522425.57 - 339364.89;
#  宜昌金色华府  select  5011614.96 -  2208150.05 -  210560.60
# 	-- charge
#  咸宁福星城	SELECT 10804378.08 - 3522425.57 - 339364.89;
#  宜昌金色华府 SELECT 5011614.96 - 2208150.05 - 210560.60


  -- 待收（欠费）b-a1-a2-c
	delete from dws_target_charge where currentDate = "2026-03-15" and targetId = '9120056' and layer = 0 and dateType = 5;
	insert into dws_target_charge(enterpriseID,organizationID,precinctID,stewardID,targetId,dateType,currentDate,targetValue,targetItemName,layer,createDateTime)
	select enterpriseID,organizationID,precinctID,stewardID,'9120056',dateType,currentDate,denominator - numerator,targetItemName,layer,NOW()
	from dws_target_charge
	where currentDate = "2026-03-15" and targetId = '9120046' and layer = 0 and dateType = 5;

	-- 当期实际完成率
	delete from dws_target_charge where currentDate = "2026-03-15" and targetId = '9120046' and layer = 0 and dateType = 5;
	insert into dws_target_charge(enterpriseID,organizationID,precinctID,stewardID,targetId,dateType,currentDate,numerator,denominator,targetValue,targetItemName,layer,createDateTime)
	select enterpriseID,organizationID,a.precinctID,stewardID,'9120046',dateType,currentDate,a.targetValue,b.targetValue-ifnull(c.targetValue,0),null,targetItemName,layer,createDateTime from dws_target_charge a
	inner join (select precinctId,sum(targetValue) targetValue from dws_target_charge where targetId = '9120017' and currentDate = "2026-02" and layer = 0 and dateType = 3 group by precinctId) b on a.precinctId = b.precinctId
	left join (select precinctId,sum(targetValue) targetValue from dws_target_charge where targetId in ('9120018','9120019') and currentDate = "2026-03-15" and layer = 0 and dateType = 5 group by precinctId) c on a.precinctId = c.precinctId
	where currentDate = "2026-03-15" and targetId = '9120040' and layer = 0 and dateType = 5;




