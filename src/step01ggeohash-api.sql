CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

-- scientific

CREATE or replace FUNCTION osmc.br_afacode_encode(
  p_lat   float,
  p_lon   float,
  p_level int
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',76,
        'properties', jsonb_build_object(
            'area',l.area,
            'side',l.side))))::jsonb
    FROM (SELECT afa.br_encode(p_lat,p_lon,p_level), afa.br_cell_area(p_level), afa.br_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.br_decode(hbig)) v(id,geom)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.br_afacode_encode(float,float,int)
  IS 'Encodes lat/lon to AFAcode grid scientific for Brazil.';

CREATE or replace FUNCTION osmc.cm_afacode_encode(
  p_lat   float,
  p_lon   float,
  p_level int
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',120,
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side))))::jsonb
    FROM (SELECT afa.cm_encode(p_lat,p_lon,p_level), afa.cm_cell_area(p_level), afa.cm_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.cm_decode(hbig)) v(id,geom)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.cm_afacode_encode(float,float,int)
  IS 'Encodes lat/lon to AFAcode grid scientific for Cameroon.';

CREATE or replace FUNCTION osmc.co_afacode_encode(
  p_lat   float,
  p_lon   float,
  p_level int
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'jurisd_base_id',170,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side))))::jsonb
    FROM (SELECT afa.co_encode(p_lat,p_lon,p_level), afa.co_cell_area(p_level), afa.co_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.co_decode(hbig)) v(id,geom)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.co_afacode_encode(float,float,int)
  IS 'Encodes lat/lon to AFAcode grid scientific for Colombia.';

CREATE or replace FUNCTION osmc.sv_afacode_encode(
  p_lat   float,
  p_lon   float,
  p_level int
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'jurisd_base_id',222,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side))))::jsonb
    FROM (SELECT afa.sv_encode(p_lat,p_lon,p_level), afa.sv_cell_area(p_level), afa.sv_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.sv_decode(hbig)) v(id,geom)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_encode(float,float,int)
  IS 'Encodes lat/lon to AFAcode grid scientific for El Salvador.';

CREATE OR REPLACE FUNCTION api.afacode_encode(
  p_uri  text,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  WITH
  params AS (
    SELECT
      u[1]::float AS lat,
      u[2]::float AS lon,
      u[3]::float AS scale
    FROM osmc.str_geouri_decode(p_uri) t(u)
  ),
  levels AS (
    SELECT
      lat, lon, scale,
      CASE p_iso
        WHEN 'BR' THEN COALESCE(afa.br_cell_nearst_level(scale), 40)
        WHEN 'CM' THEN COALESCE(afa.cm_cell_nearst_level(scale), 36)
        WHEN 'CO' THEN COALESCE(afa.co_cell_nearst_level(scale), 38)
        WHEN 'SV' THEN COALESCE(afa.sv_cell_nearst_level(scale), 32)
        ELSE NULL
      END AS level
    FROM params
  ),
  raw_result AS (
    SELECT *,
      CASE p_iso
        WHEN 'BR' THEN osmc.br_afacode_encode(lat, lon, level)
        WHEN 'CM' THEN osmc.cm_afacode_encode(lat, lon, level)
        WHEN 'CO' THEN osmc.co_afacode_encode(lat, lon, level)
        WHEN 'SV' THEN osmc.sv_afacode_encode(lat, lon, level)
        ELSE NULL
      END AS result
    FROM levels
  )
  SELECT
    CASE
      WHEN (result IS NULL)                                 THEN jsonb_build_object('error','Jurisdiction not supported.','code',1)
      WHEN (result #> '{features,0}') IS NULL               THEN jsonb_build_object('error','No feature returned.','code',2)
      WHEN (result #> '{features,0,geometry}') IS NULL
           OR (result #>> '{features,0,geometry}') = 'null' THEN jsonb_build_object('error','Invalid geometry.','code',3)
      WHEN (result #>> '{features,0,id}') IS NULL
           OR (result #>> '{features,0,id}') = 'null'       THEN jsonb_build_object('error','Invalid ID.','code',4)
      ELSE result
    END
  FROM raw_result
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode(text, text)
  IS 'Encodes a GeoURI into a scientific AFAcode. Jurisdictional context is required.';

CREATE or replace FUNCTION osmc.br_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'jurisd_base_id',76,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'truncated',(CASE WHEN length(v.id) - length(code) <> 3 THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.br_hex_to_hBig(substring(code,1,11))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.br_decode(hbig), afa.br_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
  LATERAL (SELECT afa.br_cell_area(xyL[3]), afa.br_cell_side(xyL[3])) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.br_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for Brazil.';

CREATE or replace FUNCTION osmc.cm_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'jurisd_base_id',120,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'truncated',(CASE WHEN length(v.id) - length(code) <> 3 THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.cm_hex_to_hBig(substring(code,1,10))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.cm_decode(hbig), afa.cm_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
  LATERAL (SELECT afa.cm_cell_area(xyL[3]), afa.cm_cell_side(xyL[3])) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.cm_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for Cameroon.';

CREATE or replace FUNCTION osmc.co_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'jurisd_base_id',170,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'truncated',(CASE WHEN length(v.id) - length(code) <> 3 THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.co_hex_to_hBig(substring(code,1,11))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.co_decode(hbig), afa.co_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
  LATERAL (SELECT afa.co_cell_area(xyL[3]), afa.co_cell_side(xyL[3])) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.co_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for Colombia.';

CREATE or replace FUNCTION osmc.sv_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'jurisd_base_id',222,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'truncated',(CASE WHEN length(v.id) - length(code) <> 3 THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.sv_hex_to_hBig(substring(code,1,9))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.sv_decode(hbig), afa.sv_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
  LATERAL (SELECT afa.sv_cell_area(xyL[3]), afa.sv_cell_side(xyL[3])) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for El Salvador.';

CREATE OR REPLACE FUNCTION api.afacode_decode(
  p_code text,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  WITH
  input_validated AS (
    SELECT
      list,
      --list IS NOT NULL AND array_length(list, 1) > 0 AS is_valid
      TRUE AS is_valid
    FROM natcod.reduxseq_to_list(p_code) u(list)
  ),
  decoded AS (
    SELECT *,
      CASE p_iso
        WHEN 'BR' THEN osmc.br_afacode_decode(list)
        WHEN 'CM' THEN osmc.cm_afacode_decode(list)
        WHEN 'CO' THEN osmc.co_afacode_decode(list)
        WHEN 'SV' THEN osmc.sv_afacode_decode(list)
        ELSE NULL
      END AS result
    FROM input_validated
  )
  SELECT
    CASE
      WHEN NOT is_valid                                   THEN jsonb_build_object('error','Invalid or empty AFAcode input.','code',1)
      WHEN p_iso NOT IN ('BR', 'CM', 'CO', 'SV')          THEN jsonb_build_object('error','Jurisdiction not supported.','code',2)
      WHEN (result #> '{features,0}') IS NULL             THEN jsonb_build_object('error','No feature returned.','code',3)
      WHEN (result #> '{features,0,geometry}') IS NULL    THEN jsonb_build_object('error','Invalid geometry.','code',4)
      WHEN (result #>> '{features,0,id}') IS NULL
           OR (result #>> '{features,0,id}') = 'null'     THEN jsonb_build_object('error','Invalid ID.','code',5)
      ELSE result
    END
  FROM decoded
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_decode(text, text)
  IS 'Decodes a scientific AFAcode. Jurisdictional context is required. Returns GeoJSON or structured error.';

-- logistics
CREATE or replace FUNCTION osmc.br_afacode_encode_log(
  p_lat   float,
  p_lon   float,
  p_level int,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',76,
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id', canonical_prefix_with_cindex || COALESCE(natcod.vbit_to_strstd(substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1),'32nvu'),''),
            'jurisd_local_id', jurisd_local_id))))::jsonb
    FROM (SELECT afa.br_encode(p_lat,p_lon,p_level), afa.br_cell_area(p_level), afa.br_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.br_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.br_afacode_encode_log(float,float,int,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for Brazil.';

CREATE or replace FUNCTION osmc.cm_afacode_encode_log(
  p_lat   float,
  p_lon   float,
  p_level int,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',120,
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id',canonical_prefix_with_cindex || COALESCE(natcod.vbit_to_strstd(substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1),'32nvu'),''),
            'jurisd_local_id', jurisd_local_id))))::jsonb
    FROM (SELECT afa.cm_encode(p_lat,p_lon,p_level), afa.cm_cell_area(p_level), afa.cm_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.cm_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.cm_afacode_encode_log(float,float,int,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for Cameroon.';

CREATE or replace FUNCTION osmc.co_afacode_encode_log(
  p_lat   float,
  p_lon   float,
  p_level int,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',170,
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id', canonical_prefix_with_cindex || COALESCE(natcod.vbit_to_strstd(substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1),'32nvu'),''),
            'jurisd_local_id', jurisd_local_id))))::jsonb
    FROM (SELECT afa.co_encode(p_lat,p_lon,p_level), afa.co_cell_area(p_level), afa.co_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.co_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.co_afacode_encode_log(float,float,int,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for Colombia.';

CREATE or replace FUNCTION osmc.sv_afacode_encode_log(
  p_lat   float,
  p_lon   float,
  p_level int,
  p_isolabel_ext text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',222,
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id', canonical_prefix_with_cindex || COALESCE(natcod.vbit_to_baseh(substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1) ,'16'),''),
            'jurisd_local_id', jurisd_local_id))))::jsonb
    FROM (SELECT afa.sv_encode(p_lat,p_lon,p_level), afa.sv_cell_area(p_level), afa.sv_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig,true), afa.sv_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_encode_log(float,float,int,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for El Savador.';

CREATE OR REPLACE FUNCTION api.afacode_encode_log(
  p_uri  text,
  p_iso  text
) RETURNS jsonb AS $wrap$
  WITH
  parsed AS (
    SELECT u[1]::float AS lat, u[2]::float AS lon, u[3] AS lvl
    FROM osmc.str_geouri_decode(p_uri) t(u)
  ),
  resolved_level AS (
    SELECT *,
      CASE split_part(p_iso,'-',1)
        WHEN 'BR' THEN COALESCE(ROUND((afa.br_cell_nearst_level(lvl)/5)*5)::int, 35)
        WHEN 'CM' THEN COALESCE(ROUND((LEAST(afa.cm_cell_nearst_level(lvl),36)/5)*5 + 1)::int, 31)
        WHEN 'CO' THEN COALESCE(ROUND((LEAST(afa.co_cell_nearst_level(lvl),38)/5)*5 + 3)::int, 33)
        WHEN 'SV' THEN COALESCE(ROUND((LEAST(afa.sv_cell_nearst_level(lvl),32)/4)*4)::int, 28)
        ELSE NULL
      END AS level
    FROM parsed
  ),
  encoded AS (
    SELECT *,
      CASE split_part(p_iso,'-',1)
        WHEN 'BR' THEN osmc.br_afacode_encode_log(lat,lon,level,p_iso)
        WHEN 'CM' THEN osmc.cm_afacode_encode_log(lat,lon,level,p_iso)
        WHEN 'CO' THEN osmc.co_afacode_encode_log(lat,lon,level,p_iso)
        WHEN 'SV' THEN osmc.sv_afacode_encode_log(lat,lon,level,p_iso)
        ELSE NULL
      END AS result
    FROM resolved_level
  )
  SELECT
    CASE
      WHEN split_part(p_iso,'-',1) NOT IN ('BR','CM','CO','SV') THEN jsonb_build_object('error','Jurisdiction not supported.','code',1)
      WHEN (result #> '{features,0}') IS NULL                   THEN jsonb_build_object('error','No feature returned.','code',2)
      WHEN (result #> '{features,0,geometry}') IS NULL
           OR (result #>> '{features,0,geometry}') = 'null'     THEN jsonb_build_object('error','Invalid geometry.','code',3)
      WHEN (result #>> '{features,0,id}') IS NULL               THEN jsonb_build_object('error','Invalid ID.','code',4)
      ELSE result
    END
  FROM encoded
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode_log(text,text)
  IS 'Encodes a GeoURI into a logistic AFAcode. Jurisdictional context is required.';

CREATE or replace FUNCTION api.afacode_encode_log_no_context(
  p_uri  text
) RETURNS jsonb AS $wrap$
  WITH
  decoded_point AS
  (
    SELECT ST_SetSRID(ST_MakePoint(a.udec[2],a.udec[1]),4326) AS pt
    FROM osmc.str_geouri_decode(p_uri) a(udec)
  ),
  candidate_bbox AS
  (
    SELECT bbox.id, bbox.jurisd_base_id, bbox.isolabel_ext, dp.pt
    FROM osmc.jurisdiction_bbox bbox
    JOIN decoded_point dp
    ON dp.pt && bbox.geom
  ),
  resolved_jurisdiction AS (
    SELECT
      cb.id,
      cb.pt,
      COALESCE(cb.jurisd_base_id, border.jurisd_base_id) AS jurisd_base_id,
      COALESCE(cb.isolabel_ext, border.isolabel_ext) AS isolabel_ext
    FROM candidate_bbox cb
    LEFT JOIN LATERAL
    (
      SELECT b.jurisd_base_id, b.isolabel_ext
      FROM osmc.mvjurisdiction_bbox_border b
      WHERE b.bbox_id = cb.id
        AND ST_Intersects(b.geom,cb.pt)
      LIMIT 1
    ) border
    ON cb.jurisd_base_id IS NULL
  ),
  transformed_point AS
  (
    SELECT id, jurisd_base_id, isolabel_ext,
        CASE isolabel_ext
          WHEN 'BR' THEN ST_Transform(rj.pt,10857)
          WHEN 'CM' THEN ST_Transform(rj.pt,32632)
          WHEN 'CO' THEN ST_Transform(rj.pt,9377)
          WHEN 'UY' THEN ST_Transform(rj.pt,32721)
          WHEN 'EC' THEN ST_Transform(rj.pt,32717)
          WHEN 'SV' THEN ST_Transform(rj.pt,5399)
        END AS pt
    FROM resolved_jurisdiction rj
  ),
  matched_coverage AS (
    SELECT g.isolabel_ext
    FROM osmc.mvwcoverage g
    JOIN transformed_point e
    ON e.pt && g.geom
      AND g.isolabel_ext LIKE split_part(e.isolabel_ext,'-',1) || '%'
      AND (is_contained IS TRUE OR ST_intersects(e.pt,g.geom))
    WHERE g.is_country IS FALSE
  ),
  encoded AS (
    SELECT api.afacode_encode_log(p_uri,mc.isolabel_ext) AS result
    FROM matched_coverage mc
  )
  SELECT
    CASE
      WHEN NOT EXISTS (SELECT 1 FROM decoded_point)         THEN jsonb_build_object('error','Invalid GeoURI.','code',1)
      WHEN NOT EXISTS (SELECT 1 FROM resolved_jurisdiction) THEN jsonb_build_object('error','Jurisdiction not found.','code',2)
      WHEN NOT EXISTS (SELECT 1 FROM matched_coverage)      THEN jsonb_build_object('error','Jurisdiction coverage not found.','code',3)
      WHEN (encoded.result #> '{features,0}') IS NULL       THEN jsonb_build_object('error','No feature returned.','code',4)
      ELSE encoded.result
    END
  FROM encoded
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode_log_no_context(text)
  IS 'Encodes a GeoURI into a logistic AFAcode. No jurisdictional context is required.';

CREATE or replace FUNCTION osmc.br_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',jurisd_base_id,
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id',canonical_prefix_with_separator || p_code,
            -- 'truncated',truncated,
            'jurisd_local_id',jurisd_local_id))))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, abbreviations, canonical_prefix_with_separator, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.b32nvu_to_vbit(substring(p_code,2)) ) AS hbig
    FROM osmc.mvwcoverage c
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig,true), afa.br_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.br_cell_area(v.id_length), afa.br_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.br_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for Brazil. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION osmc.cm_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',jurisd_base_id,
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id', canonical_prefix_with_separator || p_code,
            -- 'truncated',truncated,
            'jurisd_local_id', jurisd_local_id))))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, abbreviations, canonical_prefix_with_separator, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.b32nvu_to_vbit(substring(p_code,2)) ) AS hbig
    FROM osmc.mvwcoverage c
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig,true), afa.cm_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.cm_cell_area(v.id_length), afa.cm_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.cm_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for Cameroon. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION osmc.co_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',jurisd_base_id,
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id', canonical_prefix_with_separator || p_code,
            -- 'truncated',truncated,
            'jurisd_local_id', jurisd_local_id))))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, abbreviations, canonical_prefix_with_separator, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.b32nvu_to_vbit(substring(p_code,2)) ) AS hbig
    FROM osmc.mvwcoverage c
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig,true), afa.co_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.co_cell_area(v.id_length), afa.co_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.co_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for Colombia. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION osmc.sv_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'jurisd_base_id',jurisd_base_id,
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbreviations,
            'logistic_id', canonical_prefix_with_separator || p_code,
            -- 'truncated',truncated,
            'jurisd_local_id', jurisd_local_id))))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, abbreviations, canonical_prefix_with_separator, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.baseh_to_vbit(substring(lower(p_code),2),'16') ) AS hbig, cbits
    FROM osmc.mvwcoverage c
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig,true), afa.sv_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.sv_cell_area(v.id_length), afa.sv_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for El Salvador. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION api.afacode_decode_log(
   p_code text
) RETURNS jsonb AS $wrap$
  WITH
  split_parts AS (
    SELECT regexp_split_to_array(p_code, '~') AS u
  ),
  parts AS (
    SELECT
      u[1] AS geo_part,
      u[2] AS code_part
    FROM split_parts
    WHERE array_length(u,1) = 2
  ),
  decoded_iso AS (
    SELECT
      str_geocodeiso_decode(geo_part) AS l,
      code_part
    FROM parts
  ),
  encoded AS (
    SELECT *,
      CASE l[2]
        WHEN 'BR' THEN osmc.br_afacode_decode_log( upper(REPLACE(code_part,'.','')), l[1] )
        WHEN 'CM' THEN osmc.cm_afacode_decode_log( upper(REPLACE(code_part,'.','')), l[1] )
        WHEN 'CO' THEN osmc.co_afacode_decode_log( upper(REPLACE(code_part,'.','')), l[1] )
        WHEN 'SV' THEN osmc.sv_afacode_decode_log( upper(REPLACE(code_part,'.','')), l[1] )
        ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
      END AS result
    FROM decoded_iso
  )
  SELECT
    CASE
      WHEN NOT EXISTS (SELECT 1 FROM split_parts) OR array_length((SELECT u FROM split_parts), 1) != 2 THEN jsonb_build_object('error','Invalid AFAcode format.','code',1)
      WHEN (SELECT code_part FROM parts) IS NULL THEN jsonb_build_object('error','Missing code component after jurisdiction.','code',2)
      WHEN l[2] NOT IN ('BR','CM','CO','SV') THEN jsonb_build_object('error','Jurisdiction not supported.','code',3)
      ELSE result
    END
  FROM encoded
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode_log(text,text)
  IS 'Encodes a GeoURI into a logistic AFAcode. Jurisdictional context is required.';

------------------
-- jurisdiction coverage

CREATE or replace FUNCTION osmc.br_jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform(c.geom,4326),8,0)::jsonb,
        'id', v.id,
        'properties',jsonb_build_object(
                'area', area,
                'side', side,
                'index', cindex,
                'is_country', is_country,
                'is_contained', is_contained,
                'is_overlay', is_overlay,
                'level', id_length))))::jsonb
  FROM osmc.mvwcoverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.br_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.br_cell_area(v.id_length), afa.br_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION osmc.br_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';
-- EXPLAIN ANALYZE SELECT osmc.br_jurisdiction_coverage('BR-SP-Campinas');

CREATE or replace FUNCTION osmc.cm_jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform(c.geom,4326),8,0)::jsonb,
        'id', v.id,
        'properties',jsonb_build_object(
                'area', area,
                'side', side,
                'index', cindex,
                'is_country', is_country,
                'is_contained', is_contained,
                'is_overlay', is_overlay,
                'level', id_length))))::jsonb
  FROM osmc.mvwcoverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.cm_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.cm_cell_area(v.id_length), afa.cm_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION osmc.cm_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';

CREATE or replace FUNCTION osmc.co_jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform(c.geom,4326),8,0)::jsonb,
        'id', v.id,
        'properties',jsonb_build_object(
                'area', area,
                'side', side,
                'index', cindex,
                'is_country', is_country,
                'is_contained', is_contained,
                'is_overlay', is_overlay,
                'level', id_length))))::jsonb
  FROM osmc.mvwcoverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.co_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.co_cell_area(v.id_length), afa.co_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION osmc.co_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';

CREATE or replace FUNCTION osmc.sv_jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform(c.geom,4326),8,0)::jsonb,
        'id', v.id,
        'properties',jsonb_build_object(
                'area', area,
                'side', side,
                'index', cindex,
                'is_country', is_country,
                'is_contained', is_contained,
                'is_overlay', is_overlay,
                'level', id_length))))::jsonb
  FROM osmc.mvwcoverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.sv_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.sv_cell_area(v.id_length), afa.sv_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION osmc.sv_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';

CREATE MATERIALIZED VIEW osmc.mvwjurisdiction_coverage AS
  SELECT isolabel_ext,
          CASE split_part(isolabel_ext,'-',1)
            WHEN 'BR' THEN osmc.br_jurisdiction_coverage(isolabel_ext)
            WHEN 'CM' THEN osmc.cm_jurisdiction_coverage(isolabel_ext)
            WHEN 'CO' THEN osmc.co_jurisdiction_coverage(isolabel_ext)
            WHEN 'SV' THEN osmc.sv_jurisdiction_coverage(isolabel_ext)
          END AS json
  FROM
  (
    SELECT DISTINCT isolabel_ext
    FROM osmc.mvwcoverage
  ) c;
COMMENT ON COLUMN osmc.mvwjurisdiction_coverage.isolabel_ext IS 'ISO and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwjurisdiction_coverage.json         IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON MATERIALIZED VIEW osmc.mvwjurisdiction_coverage   IS 'Synonymous default abbrev names of jurisdictions.';
CREATE UNIQUE INDEX mvwjurisdiction_coverage_isolabel_ext ON osmc.mvwjurisdiction_coverage (isolabel_ext);

CREATE or replace FUNCTION api.jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT json
  FROM osmc.mvwjurisdiction_coverage
  WHERE isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';

------------------

-- DROP MATERIALIZED VIEW IF EXISTS osmc.mvwjurisdiction_geojson_from_isolabel;
CREATE MATERIALIZED VIEW osmc.mvwjurisdiction_geojson_from_isolabel AS
  SELECT j.isolabel_ext,
        jsonb_build_object(
          'type','Feature',
          'geometry',ST_AsGeoJSON(g.geom,8,0)::jsonb,
          'properties',jsonb_build_object(
            'osm_id', g.osm_id,
            'jurisd_base_id', jurisd_base_id,
            'jurisd_local_id', jurisd_local_id,
            'parent_id', parent_id,
            'admin_level', admin_level,
            'name', name,
            'parent_abbrev', parent_abbrev,
            'abbrev', abbrev,
            'wikidata_id', wikidata_id,
            'lexlabel', lexlabel,
            'isolabel_ext', g.isolabel_ext,
            'lex_urn', lex_urn,
            'name_en', name_en,
            'isolevel', isolevel,
            'area', info->'area_km2',
            'shares_border_with', info->'shares_border_with',
            'min_level', min_level,
            'canonical_pathname', CASE WHEN jurisd_base_id=170 THEN 'CO-'|| jurisd_local_id ELSE g.isolabel_ext END))::jsonb AS json_nonbuffer,

      jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(b.geom,8,0)::jsonb,
        'properties',jsonb_build_object(
          'osm_id', j.osm_id,
          'jurisd_base_id', jurisd_base_id,
          'jurisd_local_id', jurisd_local_id,
          'parent_id', parent_id,
          'admin_level', admin_level,
          'name', name,
          'parent_abbrev', parent_abbrev,
          'abbrev', abbrev,
          'wikidata_id', wikidata_id,
          'lexlabel', lexlabel,
          'isolabel_ext', b.isolabel_ext,
          'lex_urn', lex_urn,
          'name_en', name_en,
          'isolevel', isolevel,
          'area', info->'area_km2'))::jsonb AS json_buffer

  FROM optim.jurisdiction j
  LEFT JOIN optim.jurisdiction_geom g
    ON j.osm_id = g.osm_id
  LEFT JOIN osmc.mvwjurisdiction_geom_buffer_clipped b
    ON j.isolabel_ext = b.isolabel_ext,
  LATERAL
  (
    SELECT MIN(((cbits)::bit(6))::int - 12) AS min_level
    FROM osmc.mvwcoverage
    WHERE isolabel_ext = j.isolabel_ext AND is_overlay IS FALSE
  ) s;
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel.isolabel_ext   IS 'ISO and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel.json_nonbuffer IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel.json_buffer    IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON MATERIALIZED VIEW osmc.mvwjurisdiction_geojson_from_isolabel     IS 'Synonymous default abbrev names of jurisdictions.';
CREATE UNIQUE INDEX mvwjurisdiction_geojson_from_isolabel_isolabel_ext ON osmc.mvwjurisdiction_geojson_from_isolabel (isolabel_ext);
/*
SELECT osmc.mvwjurisdiction_geojson_from_isolabel('BR-SP-Campinas');
SELECT osmc.mvwjurisdiction_geojson_from_isolabel('CO-ANT-Itagui');
SELECT osmc.mvwjurisdiction_geojson_from_isolabel('CO-A-Itagui');
SELECT osmc.mvwjurisdiction_geojson_from_isolabel('CO-Itagui');
*/

CREATE or replace FUNCTION api.jurisdiction_geojson(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT json_nonbuffer AS json
  FROM osmc.mvwjurisdiction_geojson_from_isolabel
  WHERE isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_geojson(text)
  IS 'Returns the jurisdiction geometry.';

CREATE or replace FUNCTION api.jurisdiction_buffer(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT json_buffer AS json
  FROM osmc.mvwjurisdiction_geojson_from_isolabel
  WHERE isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_buffer(text)
  IS 'Returns the jurisdiction geometry with a 50 meter buffer.';

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
ON p.id = q.id_component;
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
  IS 'Returns consolidated data.';
