CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

CREATE or replace FUNCTION api.olc_encode(
  uri text
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features',
      (
        SELECT jsonb_agg(
          ST_AsGeoJSONb(geouri_ext.olc_geom(x),8,0,null,
              jsonb_build_object(
                  'code', x,
                  'type', 'olc'
                  )
              )::jsonb)
        FROM (SELECT geouri_ext.olc_encode(u[1],u[2],geouri_ext.uncertain_olc(u[4]))) t(x)
      )
    )
  FROM ( SELECT str_geouri_decode(uri) ) t(u)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.olc_encode(text)
  IS 'Encodes Geo URI to OLC.'
;
-- EXPLAIN ANALYZE SELECT api.olc_encode('geo:olc:-23.550385,-46.633956;u=11');

CREATE or replace FUNCTION api.olc_decode(
  code text
) RETURNS jsonb AS $f$
BEGIN
  RETURN
  (
    SELECT
      CASE geouri_ext.olc_isfull(code)
        WHEN FALSE THEN jsonb_build_object('error', 'Not a valid full code.')
        WHEN TRUE THEN
        (
          jsonb_build_object(
            'type', 'FeatureCollection',
            'features', jsonb_agg(
                  ST_AsGeoJSONb(geouri_ext.olc_geom(code),8,0,null,
                      jsonb_build_object(
                          'code', code,
                          'type', 'olc'
                          )
                      )::jsonb)
            )
        )
        ELSE jsonb_build_object('error', 'Unknown.')
      END
  );
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE;
COMMENT ON FUNCTION api.olc_decode(text)
  IS 'Decode OLC.'
;
-- EXPLAIN ANALYZE SELECT api.olc_decode('CCCCCCCC+');

--------------------

CREATE or replace FUNCTION api.ghs_encode(
  uri text
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features',
      (
        SELECT jsonb_agg(
          ST_AsGeoJSONb(ST_GeomFromGeoHash(x),8,0,null,
              jsonb_build_object(
                  'code', x,
                  'type', 'ghs',
                  'area', ST_Area(ST_GeomFromGeoHash(x)),
                  'side', SQRT(ST_Area(ST_GeomFromGeoHash(x)))
                  )
              )::jsonb)
        FROM (SELECT  ST_GeoHash(ST_SetSRID(ST_Point(u[2],u[1]),4326),geouri_ext.uncertain_ghs(u[4])) ) t(x)
      )
    )
  FROM ( SELECT str_geouri_decode(uri) ) t(u)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.ghs_encode(text)
  IS 'Encodes Geo URI to GHS.'
;
-- EXPLAIN ANALYZE SELECT api.ghs_encode('geo:ghs:-23.550385,-46.633956;u=11');


CREATE or replace FUNCTION api.ghs_decode(
  code text,
  digits integer DEFAULT NULL -- truncate when not null
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features', jsonb_agg(
          ST_AsGeoJSONb(geouri_ext.ghs_geom(code),8,0,null,
              jsonb_build_object(
                  'code', code,
                  'type', 'ghs'
                  )
              )::jsonb)
    )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.ghs_decode(text,integer)
  IS 'Decodes GHS.'
;
-- EXPLAIN ANALYZE SELECT api.ghs_decode('01');
