CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

-- scientific

CREATE or replace FUNCTION api.br_afacode_encode(
  p_lat float,
  p_lon float,
  p_u float
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.br_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        -- 'geometry', ST_AsGeoJSON(ST_Transform(afa.br_decode(hbig),4326),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.br_cell_area(L),
            'side', afa.br_cell_side(L),
            'base','base16h',
            'jurisd_base_id',76,
            'isolabel_ext', 'BR'
          )
      )))::jsonb
    FROM afa.br_cell_nearst_level(p_u) a(L), afa.br_encode(p_lat,p_lon,L) b(hbig)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.br_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode grid in Brazil. Returns a GeoJSON FeatureCollection with cell geometry and metadata.';
;

CREATE or replace FUNCTION api.cm_afacode_encode(
  p_lat float,
  p_lon float,
  p_u float
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.cm_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.cm_cell_area(L),
            'side', afa.cm_cell_side(L),
            'base','base16h',
            'jurisd_base_id',120,
            'isolabel_ext', 'CM'
          )
      )))::jsonb
    FROM afa.cm_cell_nearst_level(p_u) a(L), afa.cm_encode(p_lat,p_lon,L) b(hbig)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.cm_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode grid in Cameroon. Returns a GeoJSON FeatureCollection with cell geometry and metadata.';
;

CREATE or replace FUNCTION api.co_afacode_encode(
  p_lat float,
  p_lon float,
  p_u float
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.co_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
      'id', afa.hBig_to_hex(hbig),
      'properties', jsonb_build_object(
          'area', afa.co_cell_area(L),
          'side', afa.co_cell_side(L),
          'base','base16h',
          'jurisd_base_id',170,
          'isolabel_ext', 'CO'
        )
    )))::jsonb
  FROM afa.co_cell_nearst_level(p_u) a(L), afa.co_encode(p_lat,p_lon,L) b(hbig)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.co_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode grid in Colombia. Returns a GeoJSON FeatureCollection with cell geometry and metadata.';
;

CREATE or replace FUNCTION api.br_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry', ST_AsGeoJSON(ST_Transform_Resilient(geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id', id,
      'properties', jsonb_build_object(
          'area', afa.br_cell_area(xyL[3]),
          'side', afa.br_cell_side(xyL[3]),
          'base','base16h',
          'jurisd_base_id',76,
          'isolabel_ext', 'BR'
          'truncated_code',(CASE WHEN length(id) <> length(code) THEN TRUE ELSE FALSE END)
        )
    )))::jsonb
  FROM
  (
    SELECT code, hbig, afa.hBig_to_hex(hbig) AS id, afa.br_hBig_to_xyLRef(hbig) AS xyL, afa.br_decode(hbig) AS geom
    FROM
    (
      SELECT code, afa.br_hex_to_hBig(substring(code,1,11)) AS hbig
      FROM regexp_split_to_table(p_code,',') code
    ) a
  ) b
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.br_afacode_decode(text)
  IS 'Decodes a scientific AFAcode into a GeoJSON FeatureCollection for Brazil.';
;

CREATE or replace FUNCTION api.cm_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry', ST_AsGeoJSON(ST_Transform_Resilient(geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id', id,
      'properties', jsonb_build_object(
          'area', afa.cm_cell_area(xyL[3]),
          'side', afa.cm_cell_side(xyL[3]),
          'base','base16h',
          'jurisd_base_id',120,
          'isolabel_ext', 'CM'
          'truncated_code',(CASE WHEN length(id) <> length(code) THEN TRUE ELSE FALSE END)
        )
    )))::jsonb
  FROM
  (
    SELECT code, hbig, afa.hBig_to_hex(hbig) AS id, afa.cm_hBig_to_xyLRef(hbig) AS xyL, afa.cm_decode(hbig) AS geom
    FROM
    (
      SELECT code, afa.cm_hex_to_hBig(substring(code,1,10)) AS hbig
      FROM regexp_split_to_table(p_code,',') code
    ) a
  ) b
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.cm_afacode_decode(text)
  IS 'Decodes a scientific AFAcode into a GeoJSON FeatureCollection for Cameroon.';
;

CREATE or replace FUNCTION api.co_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry', ST_AsGeoJSON(ST_Transform_Resilient(geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id', id,
      'properties', jsonb_build_object(
          'area', afa.co_cell_area(xyL[3]),
          'side', afa.co_cell_side(xyL[3]),
          'base','base16h',
          'jurisd_base_id',170,
          'isolabel_ext', 'CO'
          'truncated_code',(CASE WHEN length(id) <> length(code) THEN TRUE ELSE FALSE END)
        )
    )))::jsonb
  FROM
  (
    SELECT code, hbig, afa.hBig_to_hex(hbig) AS id, afa.co_hBig_to_xyLRef(hbig) AS xyL, afa.co_decode(hbig) AS geom
    FROM
    (
      SELECT code, afa.co_hex_to_hBig(substring(code,1,11)) AS hbig
      FROM regexp_split_to_table(p_code,',') code
    ) a
  ) b
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.co_afacode_decode(text)
  IS 'Decodes a scientific AFAcode into a GeoJSON FeatureCollection for Colombia.';
;



CREATE or replace FUNCTION api.afacode_encode(
  p_uri  text,
  p_grid int  DEFAULT 0,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE p_iso
      WHEN 'BR' THEN api.br_afacode_encode(u[1],u[2],u[3])
      WHEN 'CM' THEN api.cm_afacode_encode(u[1],u[2],u[3])
      WHEN 'CO' THEN api.co_afacode_encode(u[1],u[2],u[3])
    END
  FROM str_geouri_decode_new(p_uri) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode(text,int,text)
  IS 'Wrapper for country-specific AFAcode encoders. Decodes a GeoURI and delegates encoding based on ISO country code.';
;

CREATE or replace FUNCTION api.afacode_decode(
  p_code text,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE p_iso
      WHEN 'BR' THEN api.br_afacode_decode(list)
      WHEN 'CM' THEN api.cm_afacode_decode(list)
      WHEN 'CO' THEN api.co_afacode_decode(list)
    END
  FROM natcod.reduxseq_to_list(p_code) u(list)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_decode(text,text)
  IS 'Wrapper for country-specific AFAcode decoder. Converts a AFAcode or compressed list and dispatches to the correct national decoder.';
;

CREATE or replace FUNCTION api.afacode_decode_with_prefix(
   p_code      text,
   p_separator text DEFAULT '\+'
) RETURNS jsonb AS $wrap$
  SELECT api.afacode_decode(REPLACE(u[2],'.',''),u[1])
  FROM regexp_split_to_array(p_code,p_separator) u
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_decode_with_prefix(text,text)
  IS 'Parses and decodes a prefixed AFAcode. Splits ISO prefix and code, and delegates to afacode_decode.';
;
-- EXPLAIN ANALYZE SELECT api.afacode_decode_with_prefix('BR+D1A');


-- logistics

CREATE or replace FUNCTION api.br_afacode_encode_log(
  p_lat float,
  p_lon float,
  p_u   float,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.br_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.br_cell_area(L),
            'side', afa.br_cell_side(L),
            'base','base32',
            'jurisd_base_id',76,
            'isolabel_ext', p_isolabel_ext,
            'isolabel_ext_abbrev', (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext)
            -- 'logistic_id', CASE p_type WHEN 2 THEN split_part(isolabel_ext,'-',1) || '-' || jurisd_local_id ELSE isolabel_ext END || '~' || short_code,
            -- 'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
    FROM afa.br_cell_nearst_level(p_u) a(L), afa.br_encode(p_lat,p_lon,L) b(hbig)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.br_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode Logistics in Brazil. Returns a GeoJSON FeatureCollection with cell geometry and metadata.';
;

CREATE or replace FUNCTION api.cm_afacode_encode_log(
  p_lat float,
  p_lon float,
  p_u   float,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.cm_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.cm_cell_area(L),
            'side', afa.cm_cell_side(L),
            'base','base32',
            'jurisd_base_id',120,
            'isolabel_ext', p_isolabel_ext,
            'isolabel_ext_abbrev', (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext)
            -- 'logistic_id', CASE p_type WHEN 2 THEN split_part(isolabel_ext,'-',1) || '-' || jurisd_local_id ELSE isolabel_ext END || '~' || short_code,
            -- 'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
    FROM afa.cm_cell_nearst_level(p_u) a(L), afa.cm_encode(p_lat,p_lon,L) b(hbig)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.cm_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode Logistics in Cameroon. Returns a GeoJSON FeatureCollection with cell geometry and metadata.';
;

CREATE or replace FUNCTION api.co_afacode_encode_log(
  p_lat float,
  p_lon float,
  p_u   float,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.co_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.co_cell_area(L),
            'side', afa.co_cell_side(L),
            'base','base32',
            'jurisd_base_id',170,
            'isolabel_ext', p_isolabel_ext,
            'isolabel_ext_abbrev', (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext)
            -- 'logistic_id', CASE p_type WHEN 2 THEN split_part(isolabel_ext,'-',1) || '-' || jurisd_local_id ELSE isolabel_ext END || '~' || short_code,
            -- 'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
    FROM afa.co_cell_nearst_level(p_u) a(L), afa.co_encode(p_lat,p_lon,L) b(hbig)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.co_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode Logistics in Colombia. Returns a GeoJSON FeatureCollection with cell geometry and metadata.';
;

CREATE or replace FUNCTION api.afacode_encode_log(
  p_uri  text,
  p_grid int  DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
      WHEN 'BR' THEN api.br_afacode_encode_log(u[1],u[2],u[3],p_isolabel_ext)
      WHEN 'CM' THEN api.cm_afacode_encode_log(u[1],u[2],u[3],p_isolabel_ext)
      WHEN 'CO' THEN api.co_afacode_encode_log(u[1],u[2],u[3],p_isolabel_ext)
    END
  FROM str_geouri_decode_new(p_uri) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.osmcode_encode_postal(text,int,text)
  IS 'Encodes Geo URI to Postal OSMcode. Wrap for osmcode_encode_postal.'
;

CREATE or replace FUNCTION api.afacode_encode_log(
  uri  text,
  grid int DEFAULT 0
) RETURNS jsonb AS $wrap$
  WITH
  b AS
  (
    SELECT ST_MakePoint(a.udec[2],a.udec[1]) AS pt FROM str_geouri_decode(uri) a(udec)
  ),
  c AS
  (
    SELECT id, jurisd_base_id, isolabel_ext, pt FROM optim.jurisdiction_bbox x, b WHERE b.pt && geom
  ),
  d AS
  (
    SELECT id, pt,
      CASE
      WHEN jurisd_base_id IS NULL THEN ( SELECT isolabel_ext FROM optim.jurisdiction_bbox_border WHERE bbox_id = c.id AND ( ST_intersects(geom,ST_SetSRID(c.pt,4326)) ) )
      ELSE isolabel_ext
      END AS isolabel_ext,
      CASE
      WHEN jurisd_base_id IS NULL THEN ( SELECT jurisd_base_id FROM optim.jurisdiction_bbox_border WHERE bbox_id = c.id AND ( ST_intersects(geom,ST_SetSRID(c.pt,4326)) ) )
      ELSE jurisd_base_id
      END AS jurisd_base_id
    FROM c
  ),
  e AS
  (
    SELECT id, jurisd_base_id, ST_Transform(ST_SetSRID(d.pt,4326),((('{"CM":32632, "CO":9377, "BR":952019, "UY":32721, "EC":32717}'::jsonb)->(isolabel_ext))::int)) AS pt, isolabel_ext
    FROM d
  )
  SELECT api.osmcode_encode_postal(uri,grid,g.isolabel_ext)
  FROM osmc.coverage g, e
  WHERE is_country IS FALSE AND osmc.extract_jurisdbits(cbits) = e.jurisd_base_id AND e.pt && g.geom AND (is_contained IS TRUE OR ST_intersects(e.pt,g.geom))
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.afacode_encode_log(text,int)
  IS 'Encodes Geo URI (no context) to logistic OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.afacode_encode_log('geo:-15.5,-47.8',0,'BR-GO-Planaltina');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:3.461,-76.577');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:-15.5,-47.8');





CREATE or replace FUNCTION osmc.encode_short_code(
  p_hbig           bigint,
  p_isolabel_ext   text,
) RETURNS TABLE(isolabel_ext text, jurisd_local_id int, short_code text) AS $f$
    SELECT t.isolabel_ext, s.jurisd_local_id, t.short_code
    FROM
    (
        SELECT isolabel_ext, cindex, kx_prefix
        FROM osmc.coverage r
        WHERE is_country IS FALSE
              AND (CASE WHEN p_isolabel_ext IS NULL THEN TRUE ELSE isolabel_ext = p_isolabel_ext END)
              AND cbits # substring(p_hbig FROM 1 FOR (cbits::bit(6))::int = substring(0::bit(58) FROM 1 FOR (cbits::bit(6))::int)
        ORDER BY cbits DESC
        LIMIT 1
    ) t
    LEFT JOIN optim.jurisdiction s
    ON s.isolabel_ext = t.isolabel_ext
    ;
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION osmc.encode_short_code(bigint,text)
  IS ''
;




CREATE or replace FUNCTION api.br_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.br_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.br_cell_area((hbig::bit(6))::int-8),
            'side', afa.br_cell_side((hbig::bit(6))::int-8),
            'base','base32',
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext', p_isolabel_ext,
            'isolabel_ext_abbrev', abbrev,
            'logistic_id', abbrev || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.br_hex_to_hBig( kx_prefix || natcod.vbit_to_baseh(natcod.b32nvu_to_vbit(upper(substring(p_code,2))),16) ) AS hbig
    FROM osmc.coverage c
    LEFT JOIN optim.jurisdiction j
      ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x
      ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(upper(p_code),1,1)
  ) c
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.br_afacode_decode_log(text,text)
  IS ''
;

CREATE or replace FUNCTION api.cm_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.cm_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.br_cell_area((hbig::bit(6))::int-8),
            'side', afa.br_cell_side((hbig::bit(6))::int-8),
            'base','base32',
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext', p_isolabel_ext,
            'isolabel_ext_abbrev', abbrev,
            'logistic_id', abbrev || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.cm_hex_to_hBig( kx_prefix || natcod.vbit_to_baseh(natcod.b32nvu_to_vbit(upper(substring(p_code,2))),16) ) AS hbig
    FROM osmc.coverage c
    LEFT JOIN optim.jurisdiction j
      ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x
      ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(upper(p_code),1,1)
  ) c
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.cm_afacode_decode_log(text,text)
  IS ''
;

CREATE or replace FUNCTION api.co_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features', jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(ST_Transform_Resilient(afa.co_decode(hbig),4326,0.005,0.00000005),8,0)::jsonb,
        'id', afa.hBig_to_hex(hbig),
        'properties', jsonb_build_object(
            'area', afa.br_cell_area((hbig::bit(6))::int-8),
            'side', afa.br_cell_side((hbig::bit(6))::int-8),
            'base','base32',
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext', p_isolabel_ext,
            'isolabel_ext_abbrev', abbrev,
            'logistic_id', abbrev || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.co_hex_to_hBig( kx_prefix || natcod.vbit_to_baseh(natcod.b32nvu_to_vbit(upper(substring(p_code,2))),16) ) AS hbig
    FROM osmc.coverage c
    LEFT JOIN optim.jurisdiction j
      ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x
      ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(upper(p_code),1,1)
  ) c
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.co_afacode_decode_log(text,text)
  IS ''
;

CREATE or replace FUNCTION api.afacode_decode_log(
   p_code text
) RETURNS jsonb AS $wrap$
  SELECT
    CASE l[2]
      WHEN 'BR' THEN api.br_afacode_decode_log( REPLACE(u[2],'.',''), l[1] )
      WHEN 'CM' THEN api.cm_afacode_decode_log( REPLACE(u[2],'.',''), l[1] )
      WHEN 'CO' THEN api.co_afacode_decode_log( REPLACE(u[2],'.',''), l[1] )
    END
  FROM regexp_split_to_array(p_code,'~') u,
  LATERAL str_geocodeiso_decode(u[1]) l
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.afacode_decode_log(text)
  IS 'Decode Postal OSMcode. Wrap for afacode_decode_log.'
;
-- EXPLAIN ANALYZE SELECT api.afacode_decode_log('CO-BOY-Tunja~44QZNW');


------------------
-- api jurisdiction coverage:

CREATE or replace FUNCTION api.jurisdiction_coverage(
   p_iso  text,
   p_base int     DEFAULT 32
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
      'type', 'FeatureCollection',
      'features', (coalesce(jsonb_agg(
        ST_AsGeoJSONb((ST_Transform(geom,4326)),7,0,null,
            jsonb_build_object(
                'code',
                  CASE
                  WHEN is_country IS FALSE THEN kx_prefix
                  WHEN p_base IN (16,17) THEN                                  natcod.vbit_to_baseh(osmc.extract_L0bits(cbits),16,true)
                  WHEN p_base IN (18) AND x[2] IN('BR') THEN osmc.encode_16h1c(natcod.vbit_to_baseh(osmc.extract_L0bits(cbits),16,true),1)
                  WHEN p_base IN (18) AND x[2] IN('UY') THEN osmc.encode_16h1c(natcod.vbit_to_baseh(osmc.extract_L0bits(cbits),16,true),4)
                  ELSE                               natcod.vbit_to_strstd(osmc.cbits_16h_to_b32nvu(osmc.extract_L0bits(cbits),osmc.extract_jurisdbits(cbits)),'32nvu')
                  END
                ,
                'area', ST_Area(ggeohash.draw_cell_bybox(bbox,false,ST_SRID(geom))),
                'side', SQRT(ST_Area(ggeohash.draw_cell_bybox(bbox,false,ST_SRID(geom)))),
                'base', osmc.string_base(p_base),
                'index',
                  CASE
                  WHEN is_country IS FALSE THEN cindex
                  ELSE null
                  END
                ,
                'is_country', is_country,
                'is_contained', is_contained,
                'is_overlay', is_overlay,
                'level', length(kx_prefix)
                )
            )),'[]'::jsonb))
      )
  FROM osmc.coverage, str_geocodeiso_decode(p_iso) t(x)
  WHERE isolabel_ext = x[1]

$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_coverage(text,int)
  IS 'Returns jurisdiction coverage.'
;
-- EXPLAIN ANALYZE SELECT api.jurisdiction_coverage('BR-SP-Campinas');

-- Add size_shortestprefix in https://github.com/digital-guard/preserv/src/optim-step4-api.sql[api.jurisdiction_geojson_from_isolabel]
CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel(
   p_code text
) RETURNS jsonb AS $f$
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features',
            (
                jsonb_agg(ST_AsGeoJSONb(
                    geom,
                    8,0,null,
                    jsonb_build_object(
                        'osm_id', osm_id,
                        'jurisd_base_id', jurisd_base_id,
                        'jurisd_local_id', jurisd_local_id,
                        'parent_id', parent_id,
                        'admin_level', admin_level,
                        'name', name,
                        'parent_abbrev', parent_abbrev,
                        'abbrev', abbrev,
                        'wikidata_id', wikidata_id,
                        'lexlabel', lexlabel,
                        'isolabel_ext', isolabel_ext,
                        'lex_urn', lex_urn,
                        'name_en', name_en,
                        'isolevel', isolevel,
                        --'area', ST_Area(geom,true),
                        'area', info->'area_km2',
                        'shares_border_with', info->'shares_border_with',
                        --'is_multipolygon', CASE WHEN GeometryType(geom) IN ('MULTIPOLYGON') THEN TRUE ELSE FALSE END,
                        'size_shortestprefix', size_shortestprefix,
                        'canonical_pathname', CASE WHEN jurisd_base_id=170 THEN 'CO-'|| jurisd_local_id ELSE isolabel_ext END
                        )
                    )::jsonb)
            )
        )
    FROM optim.vw01full_jurisdiction_geom g,

    LATERAL
    (
      SELECT MIN(LENGTH(kx_prefix)) AS size_shortestprefix
      FROM osmc.coverage
      WHERE isolabel_ext = g.isolabel_ext AND is_overlay IS FALSE
    ) s

    WHERE g.isolabel_ext = (SELECT (str_geocodeiso_decode(p_code))[1])
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_geojson_from_isolabel(text)
  IS 'Return jurisdiction geojson from isolabel_ext. With size_shortestprefix.'
;
/*
SELECT api.jurisdiction_geojson_from_isolabel('BR-SP-Campinas');
SELECT api.jurisdiction_geojson_from_isolabel('CO-ANT-Itagui');
SELECT api.jurisdiction_geojson_from_isolabel('CO-A-Itagui');
SELECT api.jurisdiction_geojson_from_isolabel('CO-Itagui');
*/

CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel2(
   p_code text
) RETURNS jsonb AS $f$
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features',
            (
                jsonb_agg(ST_AsGeoJSONb(
                    geom,
                    8,0,null,
                    jsonb_build_object(
                        'osm_id', osm_id,
                        'jurisd_base_id', jurisd_base_id,
                        'jurisd_local_id', jurisd_local_id,
                        'parent_id', parent_id,
                        'admin_level', admin_level,
                        'name', name,
                        'parent_abbrev', parent_abbrev,
                        'abbrev', abbrev,
                        'wikidata_id', wikidata_id,
                        'lexlabel', lexlabel,
                        'isolabel_ext', isolabel_ext,
                        'lex_urn', lex_urn,
                        'name_en', name_en,
                        'isolevel', isolevel,
                        'area', info->'area_km2'
                        )
                    )::jsonb)
            )
        )
    FROM
    (
      SELECT j.*, g.geom
      FROM optim.jurisdiction j
      LEFT JOIN osmc.jurisdiction_geom_buffer_clipped g
      ON j.isolabel_ext = g.isolabel_ext
    ) g

    WHERE g.isolabel_ext = (SELECT (str_geocodeiso_decode(p_code))[1])
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_geojson_from_isolabel2(text)
  IS 'Return jurisdiction geojson from isolabel_ext. With size_shortestprefix.'
;
/*
SELECT api.jurisdiction_geojson_from_isolabel2('BR-SP-Campinas');
*/

------------------
-- api hbig:

CREATE or replace VIEW api.consolidated_data AS
SELECT afa_id, split_part(isolabel_ext,'-',1) AS iso1, split_part(isolabel_ext,'-',2) AS iso2, name AS city_name, via_type, via_name, house_number, postcode,
       license_data->>'family' AS license_family,
       ST_X(geom) AS latitude, ST_Y(geom) AS longitude,
       osmc.hBig_to_afa_sci(afa_id) AS afacodes_scientific,
       -- AS afacodes_logistic,
       geom_frontparcel, score
FROM optim.consolidated_data p
LEFT JOIN optim.vw01full_donated_packcomponent q
ON p.id = q.id_component
;
COMMENT ON COLUMN api.consolidated_data.afa_id              IS 'AFAcodes scientific. 64bits format.';
COMMENT ON COLUMN api.consolidated_data.iso1                IS 'ISO 3166-1 country code.';
COMMENT ON COLUMN api.consolidated_data.iso2                IS 'ISO 3166-2 country subdivision code.';
COMMENT ON COLUMN api.consolidated_data.city_name           IS 'City name';
COMMENT ON COLUMN api.consolidated_data.via_type            IS 'Via type.';
COMMENT ON COLUMN api.consolidated_data.via_name            IS 'Via name.';
COMMENT ON COLUMN api.consolidated_data.house_number        IS 'House number.';
COMMENT ON COLUMN api.consolidated_data.postcode            IS 'Postal code.';
COMMENT ON COLUMN api.consolidated_data.license_family      IS 'License family.';
COMMENT ON COLUMN api.consolidated_data.latitude            IS 'Feature latitude.';
COMMENT ON COLUMN api.consolidated_data.longitude           IS 'Feature longitude.';
COMMENT ON COLUMN api.consolidated_data.afacodes_scientific IS 'AFAcodes scientific.';
-- COMMENT ON COLUMN api.consolidated_data.afacodes_logistic   IS 'AFAcodes logistic.';
COMMENT ON COLUMN api.consolidated_data.geom_frontparcel    IS 'Flag. Indicates if geometry is in front of the parcel.';
COMMENT ON COLUMN api.consolidated_data.score               IS '...';

COMMENT ON VIEW api.consolidated_data
  IS 'Returns consolidated data.'
;
