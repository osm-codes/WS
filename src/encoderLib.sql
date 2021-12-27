--
-- Logic that encodes LatLong into well-known object
-- 

DROP SCHEMA IF EXISTS encoder CASCADE;
CREATE SCHEMA encoder;
create extension IF NOT EXISTS unaccent

CREATE TABLE encoder.ghs_jurisdiction(
  ghs   text,
  level integer,
  isolabels_ext text[]
);
 
CREATE VIEW encoder.vw01ghs_countries AS
 SELECT iso_a2, st_geohash(geom) as ghs, round(st_area(geom,true)/1000000.0)::int area_km2, geom
 FROM countries c  INNER JOIN  optim.jurisdiction j
   ON j.admin_level=2 AND c.iso_a2=j.abbrev
;

--- LIXO?
CREATE VIEW encoder.vw01intoghs_ghs_jurisdiction AS
 SELECT 2 AS level, ghs, array_agg(iso_a2 ORDER BY iso_a2) as isolabels_ext
 FROM encoder.vw01ghs_countries
 WHERE ghs>''
 GROUP BY 1, ghs ORDER BY ghs
 
 UNION 
 
 SELECT 6 AS level, ghs, array_agg(iso_a2 ORDER BY iso_a2) as isolabels_ext
 FROM encoder.vw01ghs_countries
 WHERE ghs>''
 GROUP BY 1, ghs ORDER BY ghs
; 
-- SELECT string_agg(ghs order by leNght(ghs) DESC, '|') FROM encoder.vw01intoghs_ghs_jurisdiction;

-- lixo
CREATE VIEW encoder.vw02intersects_ghs_jurisdiction AS
  SELECT g.ghs, array_agg(c.iso_a2 order by c.iso_a2) as isolabels_ext
  FROM geohash_GeomsFromPrefix() g INNER JOIN encoder.vw01ghs_countries c
    ON ST_Intersects(c.geom,g.geom) AND not(c.ghs>'')
  GROUP BY 1 ORDER BY 1
;

-- select jurisd_local_id, isolabel_ext, name FROM optim.jurisdiction where admin_level=4 AND jurisd_base_id=170
-----------------------------

UPDATE osm_city set inGeohash=st_geohash(geom); -- '' quando vazio

--- Geohash intersects:
UPDATE osm_city 
  SET ghs1_intersects=t.ghs1
FROM (
  SELECT c2.osm_id, array_agg(g.ghs ORDER BY g.ghs) as ghs1
  FROM geohash_GeomsFromPrefix() g INNER JOIN osm_city c2
    ON ST_Intersects(c2.geom,g.geom)
  GROUP BY 1
) t WHERE t.osm_id=osm_city.osm_id
;
UPDATE osm_city 
  SET ghs2_intersects=t.ghs1
FROM (
  SELECT c2.osm_id, array_agg(g2.ghs ORDER BY g2.ghs) as ghs1
  FROM (
    SELECT g.*
    FROM (SELECT DISTINCT unnest(ghs1_intersects) FROM osm_city) t0(ghs1), 
    LATERAL geohash_GeomsFromPrefix(ghs1) g
  ) g2
  INNER JOIN osm_city c2
  ON ST_Intersects(c2.geom,g2.geom)
  GROUP BY 1
) t WHERE t.osm_id=osm_city.osm_id
;
