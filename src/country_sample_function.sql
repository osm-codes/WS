
CREATE VIEW optim.vw_lixo_summary_jurisdiction AS
  SELECT j.isolabel_ext as isolabel, t.* 
  FROM (
      SELECT jurisd_base_id,
             COUNT(*) FILTER (where isolevel=2) AS n_level2
             COUNT(*) FILTER (where isolevel=3) AS n_level3,
      FROM optim.jurisdiction group by 1 having count(*)>1
  ) t INNER JOIN optim.jurisdiction j ON j.isolevel=1 AND j.jurisd_base_id=t.jurisd_base_id
  ORDER BY 1
;

----------------
-- AMOSTRAGEM BR PARA TESTAR COBERTURAS

CREATE or replace FUNCTION osmc_country_sample(p_c text default 'BR') RETURNS table(
  citype text, -- label of group or type of geometry
  isolabel_ext text, 
  osm_id bigint,
  side float,     -- cell side size
  elongfact float  -- elongation factor
) AS $f$

WITH sizes AS (
  SELECT percentile_disc( array[0.1, 0.5, 0.9] ) WITHIN GROUP (ORDER BY (info->'side_estim_km')::float) as side
  FROM optim.jurisdiction WHERE isolabel_ext LIKE p_c||'-%-%' -- e.g.  {10.7,20.4,52.2}
),
elongation_factors AS (
  SELECT percentile_disc( array[0.2, 0.5, 0.8] ) WITHIN GROUP (ORDER BY (info->'elongation_factor')::float) as factor
  FROM optim.jurisdiction
  WHERE isolabel_ext LIKE p_c||'-%-%' AND  info->'elongation_factor'>to_jsonb(0)
  -- e.g. {1.68,2.06,2.5}
),
sample1 AS (
( -- Cidades pequenas (side<10.7) e não-alongadas (pctl_mix<1.68):
SELECT 'peq-nonalong' AS citype, *
FROM(
  SELECT isolabel_ext, osm_id,
    info->'side_estim_km' As side,  -- 3
    info->'elongation_factor' AS elongfact -- 4
  FROM optim.jurisdiction
  WHERE isolabel_ext like p_c||'-%-%'
    AND info->'side_estim_km'<=to_jsonb( (SELECT side[1] FROM sizes) )
    AND info->'elongation_factor'<to_jsonb(1.7)
  ORDER BY 4
  LIMIT 36
) t
ORDER BY side
LIMIT 6
)

UNION ALL

( -- Cidades pequenas (side<10.7) e alongadas (pctl_mix>=2.5):
SELECT 'peq-along', *
FROM(
  SELECT isolabel_ext, osm_id,
    info->'side_estim_km' As side,  -- 3
    info->'elongation_factor' AS elongfact -- 4
  FROM optim.jurisdiction
  WHERE isolabel_ext like p_c||'-%-%'
    AND info->'side_estim_km'<=to_jsonb((SELECT side[1] FROM sizes)) AND info->'elongation_factor'>=to_jsonb(2.5)
  ORDER BY 4 DESC
  LIMIT 36
) t
ORDER BY side
LIMIT 6
)

UNION ALL

( -- Cidades grandes (side>=52) e não-alongadas (pctl_mix<1.68):
SELECT 'gr-nonalong' AS citype, *
FROM(
  SELECT isolabel_ext, osm_id,
    info->'side_estim_km' As side,  -- 3
    info->'elongation_factor' AS elongfact -- 4
  FROM optim.jurisdiction
  WHERE isolabel_ext like p_c||'-%-%'
    AND info->'side_estim_km'>=to_jsonb((SELECT side[3] FROM sizes)) AND info->'elongation_factor'<to_jsonb(1.7)
  ORDER BY 4
  LIMIT 36
) t
ORDER BY side DESC
LIMIT 6
)

UNION ALL

( -- Cidades grandes (side>=52) e alongadas (pctl_mix>=2.5):
SELECT 'gr-along', *
FROM(
  SELECT isolabel_ext, osm_id,
    info->'side_estim_km' As side,  -- 3
    info->'elongation_factor' AS elongfact -- 4
  FROM optim.jurisdiction
  WHERE isolabel_ext like p_c||'-%-%'
    AND info->'side_estim_km'>=to_jsonb((SELECT side[3] FROM sizes)) AND info->'elongation_factor'>=to_jsonb(2.5)
  ORDER BY 4 DESC
  LIMIT 36
) t
ORDER BY side DESC
LIMIT 6
)
)

SELECT citype, isolabel_ext, osm_id, side::float, elongfact::float 
FROM (
  SELECT * FROM sample1

  UNION ALL

  ( -- Big 
  SELECT 'big', isolabel_ext, osm_id,
      info->'side_estim_km' As side,  -- 4
      info->'elongation_factor' AS elongfact -- 5
    FROM optim.jurisdiction
    WHERE isolabel_ext like p_c||'-%-%' AND isolabel_ext NOT IN (SELECT isolabel_ext FROM sample1)
      AND info->'side_estim_km'>to_jsonb((SELECT side[3] FROM sizes)) 
  ORDER BY 4 DESC
  LIMIT 3
  )

  UNION ALL

  ( -- Small
  SELECT 'small', isolabel_ext, osm_id,
      info->'side_estim_km' As side,  -- 4
      info->'elongation_factor' AS elongfact -- 5
   FROM optim.jurisdiction
   WHERE isolabel_ext like p_c||'-%-%' AND isolabel_ext NOT IN (SELECT isolabel_ext FROM sample1)
      AND info->'side_estim_km'<to_jsonb((SELECT side[1] FROM sizes)) 
  ORDER BY 4
  LIMIT 3
  )
) tfinal

$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION osmc_country_sample(float,int)
  IS 'for sample preparation on municipies-cover.'
;


