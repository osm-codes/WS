--
-- Logic that encodes LatLong into well-known object
-- 

DROP SCHEMA IF EXISTS encoder CASCADE;
CREATE SCHEMA encoder;

DROP VIEW encoder.vw01ghs_countries; -- level2
CREATE VIEW encoder.vw01ghs_countries AS
 SELECT iso_a2, st_geohash(geom) as ghs, round(st_area(geom,true)/1000000.0)::int area_km2, geom
 FROM countries c  INNER JOIN  optim.jurisdiction j
   ON j.admin_level=2 AND c.iso_a2=j.abbrev
;
-- confere SELECT ghs, iso_a2, area_km2 FROM encoder.vw01ghs_countries WHERE ghs>'' ORDER BY ghs,iso_a2;

CREATE TABLE encoder.ghs_jurisdiction AS
 SELECT 2 AS level, ghs, array_agg(iso_a2 ORDER BY iso_a2) as isolabels_ext
 FROM encoder.vw01ghs_countries
 WHERE ghs>''
 GROUP BY 1, ghs ORDER BY ghs
;
-- SELECT string_agg(ghs order by leNght(ghs) DESC, '|') FROM encoder.ghs_jurisdiction;

CREATE or replace FUNCTION encoder.ST_GeomsFromGeoHashPrefix(
  prefix text DEFAULT ''
) RETURNS TABLE(ghs text, geom geometry) AS $f$
  SELECT prefix||x, ST_SetSRID( ST_GeomFromGeoHash(prefix||x), 4326)
  FROM unnest('{0,1,2,3,4,5,6,7,8,9,b,c,d,e,f,g,h,j,k,m,n,p,q,r,s,t,u,v,w,x,y,z}'::text[]) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE VIEW  encoder.vw01_GeomsFromGeoHashPrefix AS
  SELECT g.ghs, array_agg(c.iso_a2 order by c.iso_a2) as countries
  FROM encoder.ST_GeomsFromGeoHashPrefix() g INNER JOIN encoder.vw01ghs_countries c
    ON ST_Intersects(c.geom,g.geom) AND not(c.ghs>'')
  GROUP BY 1 ORDER BY 1
;

