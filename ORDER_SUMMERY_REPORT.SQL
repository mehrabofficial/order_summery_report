SELECT 
    lc.COMPANY_SHORT_NAME AS SBU,
    lb.SHORT_NAME AS BUYER,
    bb.BRAND_NAME AS BUYER_BRAND,  
    wpdm.JOB_NO,
    
    TO_CHAR(wpbd.PUB_SHIPMENT_DATE, 'YYYY-MM-DD') AS SHIPMENT_DATE,
    
    SUM(wpbd.PO_QUANTITY) AS ORDER_QTY,   
     
    ('$' || (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE)) AS FOB_VALUE,
    
    -- Conditional SMV calculation for COMPANY_ID = 5
    CASE 
        WHEN lc.ID = 5 THEN 
            (wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * SUM(wpbd.PO_QUANTITY)
        WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
            wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY
        ELSE 0
    END AS SMV,  

    -- CM VALUE calculation (CONTRIBUTION_MARGIN * ORDER_QTY)
    ('$' || (pc.CONTRIBUTION_MARGIN * SUM(wpbd.PO_QUANTITY))) AS CM_VALUE  

FROM 
    WO_PO_DETAILS_MASTER wpdm
JOIN 
    WO_PO_BREAK_DOWN wpbd ON wpdm.JOB_NO = wpbd.JOB_NO_MST
JOIN 
    LIB_BUYER lb ON wpdm.BUYER_NAME = lb.ID
JOIN 
    LIB_COMPANY lc ON wpdm.COMPANY_NAME = lc.ID
LEFT JOIN 
    WO_PRE_COST_DTLS pc ON wpdm.JOB_NO = pc.JOB_NO  -- Joining to get CONTRIBUTION_MARGIN for CM VALUE
LEFT JOIN 
    LIB_BUYER_BRAND bb ON wpdm.BRAND_ID = bb.ID  
LEFT JOIN 
    WO_PO_DETAILS_MAS_SET_DETAILS wpmds ON wpdm.JOB_NO = wpmds.JOB_NO  
 


WHERE 
    wpdm.Is_deleted = 0
    AND wpdm.status_active = 1
    AND wpbd.Is_deleted = 0
    AND wpbd.status_active = 1
GROUP BY 
    lc.COMPANY_SHORT_NAME, 
    lb.SHORT_NAME, 
    bb.BRAND_NAME, 
    wpdm.JOB_NO, 
    wpdm.TOTAL_SET_QNTY,
    wpbd.PUB_SHIPMENT_DATE,
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
