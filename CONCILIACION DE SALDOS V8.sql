WITH Partidas AS (
    SELECT
        tran.tsa_numtran AS "N� Documento",
        des.dst_usuario AS "Usuario",
        emp.emp_nombre AS "Nombre Usuario",  -- Columna "Nombre Usuario"
        tran.tsa_fechatran AS "Fecha Contabilizaci�n",
        tran.tsa_cuenta AS "Cuenta",
        cue.ccb_nombre AS "Cuenta Contable",  -- Columna "Cuenta Contable"
        des.dst_descripc AS "Texto",
        tran.tsa_glosa AS "Texto cabecera",
        tran.tsa_sucursal AS "Centro de costo",
        'Pesos' AS "Moneda doc.",  -- Asumiendo que la moneda es 'Pesos'
        CASE
            WHEN tran.tsa_tipo = 'D' THEN 'D�bito'
            WHEN tran.tsa_tipo = 'C' THEN 'Cr�dito'
            ELSE 'Otro'
        END AS "Clase",  -- Columna "Clase" para la l�gica de conciliaci�n
        ROUND(CASE WHEN tran.tsa_tipo = 'D' THEN tran.tsa_valor ELSE 0 END, 2) AS "Debe",
        ROUND(CASE WHEN tran.tsa_tipo = 'C' THEN tran.tsa_valor ELSE 0 END, 2) AS "Haber"
    FROM tcon_transa tran
    JOIN tcon_destran des
        ON tran.tsa_fechatran = des.dst_fecha
        AND tran.tsa_numtran = des.dst_numtran
        AND tran.tsa_sucursal = des.dst_sucursal
    JOIN tcon_cuentas cue
        ON tran.tsa_cuenta = cue.ccb_codigo  -- Uni�n para obtener el nombre de la cuenta contable
    JOIN tgen_usuario usr
        ON des.dst_usuario = usr.usr_codigo  -- Uni�n para obtener el usuario
    JOIN tgen_empleado emp
        ON usr.usr_codemp = emp.emp_codigo  -- Uni�n para obtener el nombre del usuario
    WHERE tran.tsa_fechatran BETWEEN TO_DATE('01/01/2025', 'DD/MM/YYYY') AND TO_DATE('31/01/2025', 'DD/MM/YYYY')
        AND tran.tsa_cuenta = '1211000048'  -- Filtro por cuenta espec�fica
),
PartidasConRank AS (
    SELECT
        p1."N� Documento" AS "Comprobante_Debito",
        p2."N� Documento" AS "Comprobante_Credito",
        p1."Debe" AS "Valor_Debito",
        p2."Haber" AS "Valor_Credito",
        p1."Centro de costo" AS "Centro_Debito",
        p2."Centro de costo" AS "Centro_Credito",
        p1."Usuario" AS "Usuario_Debito",
        p2."Usuario" AS "Usuario_Credito",
        p1."Texto cabecera" AS "Texto_Debito",
        p2."Texto cabecera" AS "Texto_Credito",
        ROW_NUMBER() OVER (
            PARTITION BY p2."N� Documento"
            ORDER BY ABS(p1."Fecha Contabilizaci�n" - p2."Fecha Contabilizaci�n") ASC
        ) AS "Rank_Credito",
        ROW_NUMBER() OVER (
            PARTITION BY p1."N� Documento"
            ORDER BY ABS(p1."Fecha Contabilizaci�n" - p2."Fecha Contabilizaci�n") ASC
        ) AS "Rank_Debito"
    FROM Partidas p1
    JOIN Partidas p2
        ON p1."Centro de costo" = p2."Centro de costo"
        AND p1."Clase" = 'D�bito'  -- Usar la columna "Clase" para filtrar d�bitos
        AND p2."Clase" = 'Cr�dito'  -- Usar la columna "Clase" para filtrar cr�ditos
        AND ROUND(p1."Debe", 2) = ROUND(p2."Haber", 2)  -- Mantener la l�gica original de conciliaci�n
        AND ABS(p1."Fecha Contabilizaci�n" - p2."Fecha Contabilizaci�n") <= 7  -- Mantener la l�gica original de conciliaci�n
),
PartidasNeteadas AS (
    SELECT *
    FROM PartidasConRank
    WHERE "Rank_Credito" = 1 AND "Rank_Debito" = 1
),
PartidasFinal AS (
    SELECT
        p.*
    FROM Partidas p
    LEFT JOIN PartidasNeteadas n
        ON p."N� Documento" = n."Comprobante_Debito" OR p."N� Documento" = n."Comprobante_Credito"
    WHERE n."Comprobante_Debito" IS NULL AND n."Comprobante_Credito" IS NULL
)
-- Consulta principal: Partidas no conciliadas
SELECT
    "N� Documento",
    "Usuario",
    "Nombre Usuario",
    TO_CHAR("Fecha Contabilizaci�n", 'DD-MM-YYYY') AS "Fecha Contabilizaci�n",
    TRUNC(SYSDATE - "Fecha Contabilizaci�n") AS "Dias",  -- C�lculo de la columna "Dias"
    "Cuenta",
    "Cuenta Contable",
    "Texto",
    "Texto cabecera",
    "Centro de costo",
    "Moneda doc.",
    TO_CHAR("Debe", 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Debe",
    TO_CHAR(-"Haber", 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Haber"
FROM PartidasFinal

UNION ALL

SELECT
    NULL AS "N� Documento",
    NULL AS "Usuario",
    NULL AS "Nombre Usuario",
    NULL AS "Fecha Contabilizaci�n",
    NULL AS "Dias",  -- "Dias" es NULL para las filas de totales
    NULL AS "Cuenta",
    NULL AS "Cuenta Contable",
    NULL AS "Texto",
    NULL AS "Texto cabecera",
    NULL AS "Centro de costo",
    NULL AS "Moneda doc.",
    TO_CHAR(SUM("Debe"), 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Debe",
    TO_CHAR(-SUM("Haber"), 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Haber"
FROM PartidasFinal

UNION ALL

SELECT
    NULL AS "N� Documento",
    NULL AS "Usuario",
    NULL AS "Nombre Usuario",
    NULL AS "Fecha Contabilizaci�n",
    NULL AS "Dias",  -- "Dias" es NULL para las filas de totales
    NULL AS "Cuenta",
    NULL AS "Cuenta Contable",
    NULL AS "Texto",
    NULL AS "Texto cabecera",
    NULL AS "Centro de costo",
    NULL AS "Moneda doc.",
    TO_CHAR(SUM("Debe") - SUM("Haber"), 'FM999G999G999G999', 'NLS_NUMERIC_CHARACTERS='',.''') AS "Debe",
    NULL AS "Haber"
FROM PartidasFinal
ORDER BY "Fecha Contabilizaci�n" ASC NULLS LAST;
