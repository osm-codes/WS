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
        'properties', jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'jurisd_base_id',76,
            'isolabel_ext','BR'))))::jsonb
    FROM (SELECT afa.br_encode(p_lat,p_lon,p_level), afa.br_cell_area(p_level), afa.br_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.br_decode(hbig)) v(id,geom)
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
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'jurisd_base_id',120,
            'isolabel_ext','CM'))))::jsonb
    FROM (SELECT afa.cm_encode(p_lat,p_lon,p_level), afa.cm_cell_area(p_level), afa.cm_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.cm_decode(hbig)) v(id,geom)
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
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'jurisd_base_id',170,
          'isolabel_ext','CO'))))::jsonb
    FROM (SELECT afa.co_encode(p_lat,p_lon,p_level), afa.co_cell_area(p_level), afa.co_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.co_decode(hbig)) v(id,geom)
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
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'jurisd_base_id',222,
          'isolabel_ext','SV'))))::jsonb
    FROM (SELECT afa.sv_encode(p_lat,p_lon,p_level), afa.sv_cell_area(p_level), afa.sv_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.sv_decode(hbig)) v(id,geom)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_encode(float,float,int)
  IS 'Encodes lat/lon to AFAcode grid scientific for El Salvador.';

CREATE or replace FUNCTION api.afacode_encode(
  p_uri  text,
  p_grid int  DEFAULT 0,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE p_iso
      WHEN 'BR' THEN osmc.br_afacode_encode(u[1],u[2],COALESCE(afa.br_cell_nearst_level(u[3]),40))
      WHEN 'CM' THEN osmc.cm_afacode_encode(u[1],u[2],COALESCE(afa.cm_cell_nearst_level(u[3]),36))
      WHEN 'CO' THEN osmc.co_afacode_encode(u[1],u[2],COALESCE(afa.co_cell_nearst_level(u[3]),38))
      WHEN 'SV' THEN osmc.sv_afacode_encode(u[1],u[2],COALESCE(afa.sv_cell_nearst_level(u[3]),32))
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM osmc.str_geouri_decode(p_uri) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode(text,int,text)
  IS 'Wrapper for country-specific AFAcode encoders. Decodes a GeoURI string and dispatches to the corresponding national encoder based on ISO country code.';

CREATE or replace FUNCTION osmc.br_afacode_decode(
   p_code text
) RETURNS jsonb AS $f$
  SELECT
    jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
      'id',v.id,
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'jurisd_base_id',76,
          'isolabel_ext','BR',
          'truncated_code',(CASE WHEN length(v.id) <> length(code) THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.br_hex_to_hBig(substring(code,1,11))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig), afa.br_decode(hbig), afa.br_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
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
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'jurisd_base_id',120,
          'isolabel_ext', 'CM',
          'truncated_code',(CASE WHEN length(v.id) <> length(code) THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.cm_hex_to_hBig(substring(code,1,10))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig), afa.cm_decode(hbig), afa.cm_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
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
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'jurisd_base_id',170,
          'isolabel_ext', 'CO',
          'truncated_code',(CASE WHEN length(id) <> length(code) THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.co_hex_to_hBig(substring(code,1,11))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig), afa.co_decode(hbig), afa.co_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
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
      'properties',jsonb_build_object(
          'area',l.area,
          'side',l.side,
          'jurisd_base_id',222,
          'isolabel_ext', 'SV',
          'truncated_code',(CASE WHEN length(id) <> length(code) THEN TRUE ELSE FALSE END)))))::jsonb
  FROM regexp_split_to_table(p_code,',') code,
  LATERAL (SELECT afa.sv_hex_to_hBig(substring(code,1,9))) m(hbig),
  LATERAL (SELECT afa.hBig_to_hex(hbig), afa.sv_decode(hbig), afa.sv_hBig_to_xyLRef(hbig)) v(id,geom,xyL),
  LATERAL (SELECT afa.sv_cell_area(xyL[3]), afa.sv_cell_side(xyL[3])) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for El Salvador.';

CREATE or replace FUNCTION api.afacode_decode(
  p_code text,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE p_iso
      WHEN 'BR' THEN osmc.br_afacode_decode(list)
      WHEN 'CM' THEN osmc.cm_afacode_decode(list)
      WHEN 'CO' THEN osmc.co_afacode_decode(list)
      WHEN 'SV' THEN osmc.sv_afacode_decode(list)
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM natcod.reduxseq_to_list(p_code) u(list)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_decode(text,text)
  IS 'Wrapper for country-specific AFAcode decoders. Converts an AFAcode or compressed list and delegates decoding to the appropriate national function based on ISO country code.';

CREATE or replace FUNCTION api.afacode_decode_with_prefix(
   p_code      text,
   p_separator text DEFAULT '\+'
) RETURNS jsonb AS $wrap$
  SELECT api.afacode_decode(REPLACE(u[2],'.',''),u[1])
  FROM regexp_split_to_array(p_code,p_separator) u
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_decode_with_prefix(text,text)
  IS 'Parses and decodes a prefixed AFAcode. Splits the input code into ISO prefix and encoded string, then delegates to the standard AFAcode decoder.';
-- EXPLAIN ANALYZE SELECT api.afacode_decode_with_prefix('BR+D1A');


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
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'jurisd_base_id',76,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',default_abbrev,
            'logistic_id', p_isolabel_ext || '~' || cindex || natcod.vbit_to_strstd( substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1) ,'32nvu')
            -- 'jurisd_local_id', jurisd_local_id
          ))))::jsonb
    FROM (SELECT afa.br_encode(p_lat,p_lon,p_level), afa.br_cell_area(p_level), afa.br_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.br_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits)
    LEFT JOIN LATERAL (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext) c(default_abbrev) ON TRUE
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
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'jurisd_base_id',120,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',default_abbrev,
            'logistic_id',p_isolabel_ext || '~' || cindex || natcod.vbit_to_strstd( substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1) ,'32nvu')
            -- 'jurisd_local_id', jurisd_local_id
          ))))::jsonb
    FROM (SELECT afa.cm_encode(p_lat,p_lon,p_level), afa.cm_cell_area(p_level), afa.cm_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.cm_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits),
    LATERAL (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext) c(default_abbrev)
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
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'jurisd_base_id',170,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',default_abbrev,
            'logistic_id', p_isolabel_ext || '~' || cindex || natcod.vbit_to_strstd( substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1) ,'32nvu')
            -- 'jurisd_local_id', jurisd_local_id
          ))))::jsonb
    FROM (SELECT afa.co_encode(p_lat,p_lon,p_level), afa.co_cell_area(p_level), afa.co_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.co_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits),
    LATERAL (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext) c(default_abbrev)
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
        'properties',jsonb_build_object(
            'area',l.area,
            'side',l.side,
            'jurisd_base_id',170,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',default_abbrev,
            'logistic_id', p_isolabel_ext || '~' || cindex || natcod.vbit_to_baseh( substring(afa.hBig_to_vbit(hbig) FROM (cbits::bit(6))::int +1) ,'16')
            -- 'jurisd_local_id', jurisd_local_id
          ))))::jsonb
    FROM (SELECT afa.sv_encode(p_lat,p_lon,p_level), afa.sv_cell_area(p_level), afa.sv_cell_side(p_level)) l(hbig,area,side),
    LATERAL (SELECT afa.hBig_to_hex(hbig), afa.sv_decode(hbig)) v(id,geom),
    LATERAL (SELECT cindex, cbits FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits),
    LATERAL (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext) c(default_abbrev)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_encode_log(float,float,int,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for El Savador.';

CREATE or replace FUNCTION api.afacode_encode_log(
  p_uri  text,
  p_grid int  DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
      WHEN 'BR' THEN osmc.br_afacode_encode_log(u[1],u[2],COALESCE(ROUND((      (afa.br_cell_nearst_level(u[3])  )    /5)*5)::int,35),p_isolabel_ext)
      WHEN 'CM' THEN osmc.cm_afacode_encode_log(u[1],u[2],COALESCE(ROUND((LEAST((afa.cm_cell_nearst_level(u[3])+1),36)/5)*5)::int,31),p_isolabel_ext)
      WHEN 'CO' THEN osmc.co_afacode_encode_log(u[1],u[2],COALESCE(ROUND((LEAST((afa.co_cell_nearst_level(u[3])+3),38)/5)*5)::int,33),p_isolabel_ext)
      WHEN 'SV' THEN osmc.sv_afacode_encode_log(u[1],u[2],COALESCE(ROUND((LEAST((afa.sv_cell_nearst_level(u[3])  ),32)/4)*4)::int,28),p_isolabel_ext)
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM osmc.str_geouri_decode(p_uri) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode_log(text,int,text)
  IS 'Wrapper for country-specific Logistics AFAcode encoders. Includes logic for rounding and bounding grid levels per country.';

CREATE or replace FUNCTION api.afacode_encode_log_no_context(
  p_uri  text,
  p_grid int  DEFAULT 0
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
  )
  SELECT api.afacode_encode_log(p_uri,p_grid,g.isolabel_ext)
  FROM osmc.mvwcoverage g
  JOIN transformed_point e
  ON e.pt && g.geom
     AND g.isolabel_ext LIKE split_part(e.isolabel_ext,'-',1) || '%'
     AND (is_contained IS TRUE OR ST_intersects(e.pt,g.geom))
  WHERE g.is_country IS FALSE
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode_log_no_context(text,int)
  IS 'Encodes a GeoURI into a logistic AFAcode, without requiring prior jurisdictional context.';

CREATE or replace FUNCTION osmc.br_afacode_decode_log(
   p_code          text,
   p_isolabel_ext  text
) RETURNS jsonb AS $f$
  SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_agg(jsonb_build_object(
        'type','Feature',
        'geometry',ST_AsGeoJSON(ST_Transform_Resilient(v.geom,4326,0.005,0.00000005),8,0)::jsonb,
        'id',v.id,
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbrev,
            'logistic_id',p_isolabel_ext || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id',jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.b32nvu_to_vbit(substring(p_code,2)) ) AS hbig
    FROM osmc.mvwcoverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.br_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
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
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbrev,
            'logistic_id', p_isolabel_ext || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.b32nvu_to_vbit(substring(p_code,2)) ) AS hbig
    FROM osmc.mvwcoverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.cm_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
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
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbrev,
            'logistic_id', abbrev || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.b32nvu_to_vbit(substring(p_code,2)) ) AS hbig
    FROM osmc.mvwcoverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.co_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
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
        'properties',jsonb_build_object(
            'area',area,
            'side',side,
            'jurisd_base_id',jurisd_base_id,
            'isolabel_ext',p_isolabel_ext,
            'isolabel_ext_abbrev',abbrev,
            'logistic_id', p_isolabel_ext || '~' || p_code,
            -- 'truncated_code',truncated_code,
            'jurisd_local_id', jurisd_local_id
          )
      )))::jsonb
  FROM
  (
    SELECT jurisd_local_id, jurisd_base_id, x.abbrev, afa.vbit_to_hBig( afa.hBig_to_vbit(cbits) || natcod.baseh_to_vbit(substring(lower(p_code),2),'16') ) AS hbig, cbits
    FROM osmc.mvwcoverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.sv_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.sv_cell_area(v.id_length), afa.sv_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.sv_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for El Salvador. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION api.afacode_decode_log(
   p_code text
) RETURNS jsonb AS $wrap$
  SELECT
    CASE l[2]
      WHEN 'BR' THEN osmc.br_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
      WHEN 'CM' THEN osmc.cm_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
      WHEN 'CO' THEN osmc.co_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
      WHEN 'SV' THEN osmc.sv_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM regexp_split_to_array(p_code,'~') u,
  LATERAL str_geocodeiso_decode(u[1]) l
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_decode_log(text)
  IS 'Wrapper for country-specific Logistics AFAcode decoders.';
-- EXPLAIN ANALYZE SELECT api.afacode_decode_log('CO-BOY-Tunja~44QZNW');

------------------
-- api jurisdiction coverage:

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
                'level', id_length
          )
      )))::jsonb

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
                'level', id_length
          )
      )))::jsonb

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
                'level', id_length
          )
      )))::jsonb

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
                'level', id_length
          )
      )))::jsonb

  FROM osmc.mvwcoverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.sv_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.sv_cell_area(v.id_length), afa.sv_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION osmc.sv_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';

CREATE or replace FUNCTION api.jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT
    CASE l[2]
      WHEN 'BR' THEN osmc.br_jurisdiction_coverage( l[1] )
      WHEN 'CM' THEN osmc.cm_jurisdiction_coverage( l[1] )
      WHEN 'CO' THEN osmc.co_jurisdiction_coverage( l[1] )
      WHEN 'SV' THEN osmc.sv_jurisdiction_coverage( l[1] )
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM str_geocodeiso_decode(p_iso) l
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.';

DROP MATERIALIZED VIEW IF EXISTS osmc.mvwjurisdiction_coverage;
CREATE MATERIALIZED VIEW osmc.mvwjurisdiction_coverage AS
SELECT isolabel_ext, api.jurisdiction_coverage(isolabel_ext) AS json
FROM
(
  SELECT DISTINCT isolabel_ext
  FROM osmc.mvwcoverage
) c;
COMMENT ON COLUMN osmc.mvwjurisdiction_coverage.isolabel_ext IS 'ISO and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwjurisdiction_coverage.json         IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON MATERIALIZED VIEW osmc.mvwjurisdiction_coverage   IS 'Synonymous default abbrev names of jurisdictions.';
CREATE UNIQUE INDEX mvwjurisdiction_coverage_isolabel_ext ON osmc.mvwjurisdiction_coverage (isolabel_ext);

CREATE or replace FUNCTION api.jurisdiction_coverage_cached(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT json
  FROM osmc.mvwjurisdiction_coverage
  WHERE isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_coverage_cached(text)
  IS 'Returns jurisdiction coverage.';

------------------

-- Add size_shortestprefix in https://github.com/digital-guard/preserv/src/optim-step4-api.sql[api.jurisdiction_geojson_from_isolabel]
CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel(
   p_iso text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_build_object(
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
                'canonical_pathname', CASE WHEN jurisd_base_id=170 THEN 'CO-'|| jurisd_local_id ELSE g.isolabel_ext END
          )
      ))::jsonb
    FROM str_geocodeiso_decode(p_iso) l
    LEFT JOIN optim.jurisdiction j
    ON l[1] = j.isolabel_ext
    LEFT JOIN optim.jurisdiction_geom g
    ON j.osm_id = g.osm_id,
    LATERAL
    (
      SELECT MIN(((cbits)::bit(6))::int - 12) AS min_level
      FROM osmc.mvwcoverage
      WHERE isolabel_ext = l[1] AND is_overlay IS FALSE
    ) s
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_geojson_from_isolabel(text)
  IS 'Return jurisdiction geojson from isolabel_ext. With min_level.';
/*
SELECT api.jurisdiction_geojson_from_isolabel('BR-SP-Campinas');
SELECT api.jurisdiction_geojson_from_isolabel('CO-ANT-Itagui');
SELECT api.jurisdiction_geojson_from_isolabel('CO-A-Itagui');
SELECT api.jurisdiction_geojson_from_isolabel('CO-Itagui');
*/

DROP MATERIALIZED VIEW IF EXISTS osmc.mvwjurisdiction_geojson_from_isolabel;
CREATE MATERIALIZED VIEW osmc.mvwjurisdiction_geojson_from_isolabel AS
SELECT isolabel_ext, api.jurisdiction_geojson_from_isolabel(isolabel_ext) AS json
FROM
(
  SELECT DISTINCT isolabel_ext
  FROM optim.jurisdiction
) c;
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel.isolabel_ext IS 'ISO and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel.json         IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON MATERIALIZED VIEW osmc.mvwjurisdiction_geojson_from_isolabel   IS 'Synonymous default abbrev names of jurisdictions.';
CREATE UNIQUE INDEX mvwjurisdiction_geojson_from_isolabel_isolabel_ext ON osmc.mvwjurisdiction_geojson_from_isolabel (isolabel_ext);

CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel_cached(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT json
  FROM osmc.mvwjurisdiction_geojson_from_isolabel
  WHERE isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_geojson_from_isolabel_cached(text)
  IS 'Returns jurisdiction coverage.';


CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel2(
   p_iso text
) RETURNS jsonb AS $f$
    SELECT
      jsonb_build_object('type','FeatureCollection','features',jsonb_build_object(
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
                'area', info->'area_km2'
          )
      ))::jsonb
    FROM
    (
      SELECT j.*, g.geom
      FROM optim.jurisdiction j
      LEFT JOIN osmc.mvwjurisdiction_geom_buffer_clipped g
      ON j.isolabel_ext = g.isolabel_ext
    ) g
    WHERE g.isolabel_ext = (SELECT (str_geocodeiso_decode(p_iso))[1])
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_geojson_from_isolabel2(text)
  IS 'Return jurisdiction geojson from isolabel_ext. With size_shortestprefix.';
/*
SELECT api.jurisdiction_geojson_from_isolabel2('BR-SP-Campinas');
*/

DROP MATERIALIZED VIEW IF EXISTS osmc.mvwjurisdiction_geojson_from_isolabel2;
CREATE MATERIALIZED VIEW osmc.mvwjurisdiction_geojson_from_isolabel2 AS
SELECT isolabel_ext, api.jurisdiction_geojson_from_isolabel2(isolabel_ext) AS json
FROM
(
  SELECT DISTINCT isolabel_ext
  FROM optim.jurisdiction
) c;
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel2.isolabel_ext IS 'ISO and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwjurisdiction_geojson_from_isolabel2.json         IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON MATERIALIZED VIEW osmc.mvwjurisdiction_geojson_from_isolabel2   IS 'Synonymous default abbrev names of jurisdictions.';
CREATE UNIQUE INDEX mvwjurisdiction_geojson_from_isolabel2_isolabel_ext ON osmc.mvwjurisdiction_geojson_from_isolabel2 (isolabel_ext);

CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel2_cached(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT json
  FROM osmc.mvwjurisdiction_geojson_from_isolabel2
  WHERE isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_geojson_from_isolabel2_cached(text)
  IS 'Returns jurisdiction coverage.';

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
