CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

CREATE or replace FUNCTION api.olc_encode(
  uri text
) RETURNS jsonb AS $wrap$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features',
      (
        SELECT jsonb_agg(
          ST_AsGeoJSONb(geouri_ext.olc_geom(x),8,0,null,
              jsonb_build_object(
                  'olc', x
                  )
              )::jsonb)
        FROM (SELECT geouri_ext.olc_encode(u[1],u[2],u[4]::int)) t(x)
      )
    )
  FROM ( SELECT str_geouri_decode(uri) ) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.olc_encode(text)
  IS 'Encodes Geo URI to OSMcode. Wrap for osmcode_encode_context(geometry)'
;
-- EXPLAIN ANALYZE SELECT api.olc_encode('geo:olc:-23.550385,-46.633956;u=11');


CREATE or replace FUNCTION api.ghs_encode(
  uri text
) RETURNS jsonb AS $wrap$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features',
      (
        SELECT jsonb_agg(
          ST_AsGeoJSONb(ST_GeomFromGeoHash(x,u[4]::int),8,0,null,
              jsonb_build_object(
                  'olc', x
                  )
              )::jsonb)
        FROM (SELECT ST_GeoHash(ST_SetSRID(ST_Point(u[2],u[1]),4326),u[4]::int)) t(x)
      )
    )
  FROM ( SELECT str_geouri_decode(uri) ) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.ghs_encode(text)
  IS 'Encodes Geo URI to OSMcode. Wrap for osmcode_encode_context(geometry)'
;
-- EXPLAIN ANALYZE SELECT api.ghs_encode('geo:ghs:-23.550385,-46.633956;u=11');
