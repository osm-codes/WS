CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

CREATE or replace FUNCTION api.olc_encode(
  p_uri text
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features',
      (
        SELECT jsonb_agg(
          ST_AsGeoJSONb(y,8,0,null,
              jsonb_build_object(
                  'code', x,
                  'type', 'olc',
                  'area', ST_Area(y,true),
                  'side', SQRT(ST_Area(y,true))
                  )
              )::jsonb)
        FROM (SELECT geouri_ext.olc_encode(u[1],u[2],geouri_ext.uncertain_olc( (CASE WHEN u[4] IS NULL THEN 10 ELSE u[4] END) ))) t(x),
        LATERAL (SELECT geouri_ext.olc_geom(x)) s(y)
      )
    )
  FROM ( SELECT str_geouri_decode(p_uri) ) t(u)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.olc_encode(text)
  IS 'Encodes GeoURI to OLC.'
;
-- EXPLAIN ANALYZE SELECT api.olc_encode('geo:olc:-23.550385,-46.633956;u=11');

CREATE or replace FUNCTION api.olc_decode(
  p_code text
) RETURNS jsonb AS $f$
BEGIN
  RETURN
  (
    SELECT
      CASE geouri_ext.olc_isfull(p_code)
        WHEN FALSE THEN jsonb_build_object('error', 'Not a valid full code.')
        WHEN TRUE THEN
        (
          jsonb_build_object(
            'type', 'FeatureCollection',
            'features', jsonb_agg(
                  ST_AsGeoJSONb(y,8,0,null,
                      jsonb_build_object(
                          'code', p_code,
                          'type', 'olc',
                          'area', ST_Area(y,true),
                          'side', SQRT(ST_Area(y,true))
                          )
                      )::jsonb)
            )
        )
        ELSE jsonb_build_object('error', 'Unknown.')
      END
    FROM (SELEcT geouri_ext.olc_geom(p_code)) s(y)
  );
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE;
COMMENT ON FUNCTION api.olc_decode(text)
  IS 'Decode OLC.'
;
-- EXPLAIN ANALYZE SELECT api.olc_decode('CCCCCCCC+');

--------------------

CREATE or replace FUNCTION api.ghs_encode(
  p_uri text
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features',
      (
        SELECT jsonb_agg(
          ST_AsGeoJSONb(y,8,0,null,
              jsonb_build_object(
                  'code', x,
                  'type', 'ghs',
                  'area', ST_Area(y,true),
                  'side', SQRT(ST_Area(y,true))
                  )
              )::jsonb)
        FROM (SELECT  ST_GeoHash(ST_SetSRID(ST_Point(u[2],u[1]),4326),geouri_ext.uncertain_ghs( (CASE WHEN u[4] IS NULL THEN 9 ELSE u[4] END) )) ) t(x),
        LATERAL (SELECT ST_GeomFromGeoHash(x)) s(y)
      )
    )
  FROM ( SELECT str_geouri_decode(p_uri) ) t(u)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.ghs_encode(text)
  IS 'Encodes GeoURI to GHS.'
;
-- EXPLAIN ANALYZE SELECT api.ghs_encode('geo:ghs:-23.550385,-46.633956;u=11');


CREATE or replace FUNCTION api.ghs_decode(
  p_code text,
  digits integer DEFAULT NULL -- truncate when not null
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features', jsonb_agg(
          ST_AsGeoJSONb(y,8,0,null,
              jsonb_build_object(
                  'code', p_code,
                  'type', 'ghs',
                  'area', ST_Area(y,true),
                  'side', SQRT(ST_Area(y,true))
                  )
              )::jsonb)
    )
    FROM (SELECT geouri_ext.ghs_geom(p_code)) s(y)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.ghs_decode(text,integer)
  IS 'Decodes GHS.'
;
-- EXPLAIN ANALYZE SELECT api.ghs_decode('01');
