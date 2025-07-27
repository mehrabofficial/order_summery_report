SELECT 
        lc.COMPANY_SHORT_NAME AS SBU,
        lb.SHORT_NAME AS BUYER,
        bb.BRAND_NAME AS BUYER_BRAND,  
        wpdm.JOB_NO,
        
        CASE 
          WHEN lb.ID = 21 THEN TO_CHAR(wpcsb.COUNTRY_SHIP_DATE, 'YYYY-MM-DD') 
          ELSE TO_CHAR(wpbd.SHIPMENT_DATE, 'YYYY-MM-DD') 
        END AS SHIPMENT_DATE,

        SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) AS ORDER_QTY,   

        -- ORDER_QTY_PERCENT calculation with NULLIF to prevent division by zero

        (SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) / 
            NULLIF(SUM(SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) 
            OVER (PARTITION BY lc.COMPANY_SHORT_NAME, lb.SHORT_NAME, bb.BRAND_NAME), 0)) * 100 AS ORDER_QTY_PERCENT,

        -- Calculating FOB_VALUE without concatenation
        (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE) AS FOB_VALUE,
        
        -- FOB_PERCENT calculation without concatenation
        (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE) / 
            NULLIF(SUM(SUM(wpbd.PO_QUANTITY * wpbd.UNIT_PRICE)) 
            OVER (PARTITION BY lc.COMPANY_SHORT_NAME, lb.SHORT_NAME, bb.BRAND_NAME), 0) * 100 AS FOB_PERCENT,  

        -- CM VALUE calculation (CONTRIBUTION_MARGIN * ORDER_QTY)
        (pc.CONTRIBUTION_MARGIN * 
            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
        ) AS CM_VALUE,

        -- CM_VALUE_PERCENT calculation
        (pc.CONTRIBUTION_MARGIN * 
            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
            NULLIF(SUM(SUM(pc.CONTRIBUTION_MARGIN * 
                CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) 
            OVER (PARTITION BY lc.COMPANY_SHORT_NAME, lb.SHORT_NAME, bb.BRAND_NAME), 0) * 100 AS CM_PERCENT,

        --  CM_FOB_PERCENT , CM_FOB_PERCENT = CM_VALUE / FOB_VALUE
        CASE 
            WHEN (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE) != 0 THEN
                (pc.CONTRIBUTION_MARGIN * 
                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE) * 100
            ELSE 0
        END AS CM_FOB_PERCENT,
        
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

        --  SMV Percent = TOTAL_SMV / SUM(TOTAL_SMV) 
        CASE 
            WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                (
                    CASE 
                        WHEN lc.ID = 5 THEN 
                            (wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * 
                            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                        WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
                            (wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY) * 
                            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                        ELSE 0
                    END
                ) / 
                NULLIF(
                    SUM(
                        CASE 
                            WHEN lc.ID = 5 THEN 
                                (wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * 
                                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                            WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
                                (wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY) * 
                                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                            ELSE 0
                        END
                    ) OVER (PARTITION BY lc.COMPANY_SHORT_NAME, lb.SHORT_NAME, bb.BRAND_NAME), 0
                ) * 100
            ELSE 0
        END AS TOTAL_SMV_PERCENT,
        

        --  AVG. FOB/PC = FOB_VALUE / ORDER_QTY
        CASE 
            WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                (SUM(wpbd.PO_QUANTITY) * wpbd.UNIT_PRICE) / 
                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
            ELSE 0
        END AS AVG_FOB_PER_PC,

        --  AVG. CM/PCS = Cm_VALUE / ORDER_QTY
        CASE 
            WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                (pc.CONTRIBUTION_MARGIN * 
                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
            ELSE 0
        END AS AVG_CM_PER_PC,

        --  Average SMV PER PCS = TOTAL_SMV Divided BY ORDER_QTY
        CASE 
            WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                CASE 
                    WHEN lc.ID = 5 THEN 
                        ((wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * 
                        SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                        SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                    WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
                        ((wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY) * 
                        SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                        SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                    ELSE 0
                END
            ELSE 0
        END AS AVG_SMV_PER_PC,

        -- EPM = AVG_CM_PER_PC / AVG_SMV_PER_PC
        CASE 
            WHEN (
                CASE 
                    WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                        CASE 
                            WHEN lc.ID = 5 THEN 
                                ((wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * 
                                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                            WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
                                ((wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY) * 
                                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                                SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                            ELSE 0
                        END
                    ELSE 0
                END
            ) != 0 THEN
                (
                    CASE 
                        WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                            (pc.CONTRIBUTION_MARGIN * 
                            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                            SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                        ELSE 0
                    END
                ) /
                (
                    CASE 
                        WHEN SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END) != 0 THEN
                            CASE 
                                WHEN lc.ID = 5 THEN 
                                    ((wpmds.SMV_PCS + wpmds.CUTSMV_PCS + wpmds.FINSMV_PCS) * 
                                    SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                                    SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                                WHEN wpdm.TOTAL_SET_QNTY != 0 THEN
                                    ((wpdm.SET_SMV / wpdm.TOTAL_SET_QNTY) * 
                                    SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)) / 
                                    SUM(CASE WHEN lb.ID = 21 THEN wpcsb.ORDER_QUANTITY ELSE wpbd.PO_QUANTITY END)
                                ELSE 0
                            END
                        ELSE 0
                    END
                )
            ELSE 0
        END AS EPM
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
        wpbd.SHIPMENT_DATE,
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
        wpdm.JOB_NO
