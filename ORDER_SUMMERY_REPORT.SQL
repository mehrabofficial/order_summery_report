SELECT 
    lc.COMPANY_SHORT_NAME AS SBU,
    lb.SHORT_NAME AS BUYER,
    bb.BRAND_NAME AS BUYER_BRAND,  
    wpdm.JOB_NO,
    
    CASE 
    WHEN lb.ID = 21 THEN TO_CHAR(wpcsb.COUNTRY_SHIP_DATE, 'YYYY-MM-DD') 
    ELSE TO_CHAR(wpbd.PUB_SHIPMENT_DATE, 'YYYY-MM-DD') 
    END AS SHIPMENT_DATE,

    
    SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) AS ORDER_QTY,   
     
    ('$' || (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE)) AS FOB_VALUE,
    
    -- Conditional SMV calculation for COMPANY_ID = 5
    CASE 
        WHEN lc.ID = 5 THEN 
            (wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * 
            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
        WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
            (wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY) * 
            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
        ELSE 0
    END AS TOTAL_SMV,  

    -- CM VALUE calculation (CONTRIBUTION_MARGIN * ORDER_QTY)
    ('$' || (pc.CONTRIBUTION_MARGIN * 
        SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
    )) AS CM_VALUE,

    -- New column for ORDER_QTY_PERCENT
    ROUND(
        (SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) /
         SUM(SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) OVER ()) * 100, 2
    ) AS ORDER_QTY_PERCENT

FROM 
    WO_PO_DETAILS_MASTER wpdm
JOIN 
    WO_PO_BREAK_DOWN wpbd ON wpdm.JOB_NO = wpbd.JOB_NO_MST
JOIN 
    LIB_BUYER lb ON wpdm.BUYER_NAME = lb.ID
JOIN 
    LIB_COMPANY lc ON wpdm.COMPANY_NAME = lc.ID
LEFT JOIN 
    WO_PRE_COST_DTLS pc ON wpdm.JOB_NO = pc.JOB_NO  
LEFT JOIN 
    LIB_BUYER_BRAND bb ON wpdm.BRAND_ID = bb.ID  
LEFT JOIN 
    WO_PO_DETAILS_MAS_SET_DETAILS wpmds ON wpdm.JOB_NO = wpmds.JOB_NO  

LEFT JOIN 
    WO_PO_COLOR_SIZE_BREAKDOWN wpcsb ON wpdm.JOB_NO = wpcsb.JOB_NO_MST
    AND lb.ID = 21
    AND wpcsb.STATUS_ACTIVE = 1
    
WHERE 
    wpdm.Is_deleted = 0
    AND wpdm.status_active = 1
    AND wpbd.Is_deleted = 0
    AND wpbd.status_active = 1

GROUP BY 
    lc.COMPANY_SHORT_NAME, 
    lb.SHORT_NAME,
    lb.ID, 
    bb.BRAND_NAME, 
    wpdm.JOB_NO, 
    wpdm.TOTAL_SET_QNTY,
    wpbd.PUB_SHIPMENT_DATE,
    wpcsb.COUNTRY_SHIP_DATE,
    wpbd.PO_QUANTITY,
    wpbd.UNIT_PRICE,
    wpdm.SET_SMV,
    lc.ID,  
    wpmds.SMV_PCS,  
    wpmds.CUTSMV_PCS,
    wpmds.FINSMV_PCS,
    pc.CONTRIBUTION_MARGIN
    
ORDER BY 
    wpdm.JOB_NO;
