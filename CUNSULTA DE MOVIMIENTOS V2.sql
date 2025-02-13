WITH Partidas AS (
    SELECT
        tran.tsa_numtran AS "N° Documento",
        des.dst_usuario AS "Usuario",
        emp.emp_nombre AS "Nombre Usuario",
        CASE
            WHEN tran.tsa_tipo = 'D' THEN 'Débito'
            WHEN tran.tsa_tipo = 'C' THEN 'Crédito'
            ELSE 'Otro'
        END AS "Clase",
        tran.tsa_fechatran AS "Fecha Contabilización",
        tran.tsa_cuenta AS "Cuenta",
        cue.ccb_nombre AS "Cuenta Contable",
        des.dst_descripc AS "Texto",
        tran.tsa_glosa AS "Texto cabecera",
        tran.tsa_sucursal AS "Centro de costo",
        ROUND(CASE WHEN tran.tsa_tipo = 'D' THEN tran.tsa_valor ELSE 0 END, 2) AS "Debe",
        ROUND(CASE WHEN tran.tsa_tipo = 'C' THEN tran.tsa_valor ELSE 0 END, 2) AS "Haber"
    FROM tcon_transa tran
    JOIN tcon_destran des
        ON tran.tsa_fechatran = des.dst_fecha
        AND tran.tsa_numtran = des.dst_numtran
        AND tran.tsa_sucursal = des.dst_sucursal
    JOIN tcon_cuentas cue
        ON tran.tsa_cuenta = cue.ccb_codigo
    JOIN tgen_usuario usr
        ON des.dst_usuario = usr.usr_codigo
    JOIN tgen_empleado emp
        ON usr.usr_codemp = emp.emp_codigo
    WHERE tran.tsa_fechatran BETWEEN TO_DATE('01/01/2025', 'DD/MM/YYYY')
    AND TO_DATE('31/01/2025', 'DD/MM/YYYY')
      -- AND des.dst_usuario IN (9122)
      AND tran.tsa_cuenta IN (1101500002)
      -- AND tran.tsa_valor = 575000
      -- AND tran.tsa_numtran IN (3703407)
      -- AND tran.tsa_sucursal IN (15)
)
SELECT
    "N° Documento",
    "Usuario",
    "Nombre Usuario",
    "Clase",
    "Fecha Contabilización",
    "Días",
    "Cuenta",
    "Cuenta Contable",
    "Texto",
    "Texto cabecera",
    "Centro de costo",
    "Debe",
    "Haber"
FROM (
    SELECT
        "N° Documento",
        "Usuario",
        "Nombre Usuario",
        "Clase",
        TO_CHAR("Fecha Contabilización", 'DD-MM-YYYY') AS "Fecha Contabilización",
        TRUNC(SYSDATE - "Fecha Contabilización") AS "Días",
        "Cuenta",
        "Cuenta Contable",
        "Texto",
        "Texto cabecera",
        "Centro de costo",
        TO_CHAR("Debe", 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Debe",
        TO_CHAR(-"Haber", 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Haber",
        1 AS orden
    FROM Partidas

    UNION ALL

    SELECT
        NULL AS "N° Documento",
        NULL AS "Usuario",
        NULL AS "Nombre Usuario",
        'Saldo Total' AS "Clase",
        NULL AS "Fecha Contabilización",
        NULL AS "Días",
        NULL AS "Cuenta",
        NULL AS "Cuenta Contable",
        NULL AS "Texto",
        NULL AS "Texto cabecera",
        NULL AS "Centro de costo",
        TO_CHAR(SUM("Debe"), 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Debe",
        TO_CHAR(-SUM("Haber"), 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Haber",
        2 AS orden
    FROM Partidas

    UNION ALL

    SELECT
        NULL AS "N° Documento",
        NULL AS "Usuario",
        NULL AS "Nombre Usuario",
        'Saldo Final' AS "Clase",
        NULL AS "Fecha Contabilización",
        NULL AS "Días",
        NULL AS "Cuenta",
        NULL AS "Cuenta Contable",
        NULL AS "Texto",
        NULL AS "Texto cabecera",
        NULL AS "Centro de costo",
        TO_CHAR(SUM("Debe") - SUM("Haber"), 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Debe",
        NULL AS "Haber",
        3 AS orden
    FROM Partidas
) subquery
ORDER BY orden, "Fecha Contabilización" ASC NULLS LAST;
