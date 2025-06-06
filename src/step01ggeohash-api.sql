CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

-- scientific

CREATE or replace FUNCTION api.br_afacode_encode(
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
COMMENT ON FUNCTION api.br_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode grid scientific for Brazil.';

CREATE or replace FUNCTION api.cm_afacode_encode(
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
COMMENT ON FUNCTION api.cm_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode grid scientific for Cameroon.';

CREATE or replace FUNCTION api.co_afacode_encode(
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
COMMENT ON FUNCTION api.co_afacode_encode(float,float,float)
  IS 'Encodes lat/lon to AFAcode grid scientific for Colombia.';

CREATE or replace FUNCTION api.afacode_encode(
  p_uri  text,
  p_grid int  DEFAULT 0,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE p_iso
      WHEN 'BR' THEN api.br_afacode_encode(u[1],u[2],COALESCE(afa.br_cell_nearst_level(u[3]),40))
      WHEN 'CM' THEN api.cm_afacode_encode(u[1],u[2],COALESCE(afa.cm_cell_nearst_level(u[3]),36))
      WHEN 'CO' THEN api.co_afacode_encode(u[1],u[2],COALESCE(afa.co_cell_nearst_level(u[3]),38))
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM str_geouri_decode_new(p_uri) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode(text,int,text)
  IS 'Wrapper for country-specific AFAcode encoders. Decodes a GeoURI string and dispatches to the corresponding national encoder based on ISO country code.';

CREATE or replace FUNCTION api.br_afacode_decode(
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
COMMENT ON FUNCTION api.br_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for Brazil.';

CREATE or replace FUNCTION api.cm_afacode_decode(
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
COMMENT ON FUNCTION api.cm_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for Cameroon.';

CREATE or replace FUNCTION api.co_afacode_decode(
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
COMMENT ON FUNCTION api.co_afacode_decode(text)
  IS 'Decodes a scientific AFAcode for Colombia.';

CREATE or replace FUNCTION api.afacode_decode(
  p_code text,
  p_iso  text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE p_iso
      WHEN 'BR' THEN api.br_afacode_decode(list)
      WHEN 'CM' THEN api.cm_afacode_decode(list)
      WHEN 'CO' THEN api.co_afacode_decode(list)
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

CREATE or replace FUNCTION osmc.encode_short_code(
  p_hbig           bigint,
  p_isolabel_ext   text
) RETURNS TABLE(cindex text, cbits bigint) AS $f$
  SELECT cindex, cbits
  FROM osmc.coverage r,
  LATERAL (SELECT afa.hBig_to_vbit(p_hbig) AS hbitstr) v,
  LATERAL (SELECT (cbits::bit(6))::int AS prefixlen) l
  WHERE isolabel_ext = p_isolabel_ext
    AND afa.hBig_to_vbit(cbits) = substring(v.hbitstr FROM 1 FOR l.prefixlen)
  ;
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.encode_short_code(bigint,text)
  IS 'Computes the short code representation of a hierarchical grid cell for a given jurisdiction.';

CREATE or replace FUNCTION api.br_afacode_encode_log(
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
    LATERAL (SELECT cindex, cbits FROM osmc.encode_short_code(hbig,p_isolabel_ext)) d(cindex, cbits),
    LATERAL (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = p_isolabel_ext) c(default_abbrev)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.br_afacode_encode_log(float,float,float,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for Brazil.';

CREATE or replace FUNCTION api.cm_afacode_encode_log(
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
COMMENT ON FUNCTION api.cm_afacode_encode_log(float,float,float,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for Cameroon.';

CREATE or replace FUNCTION api.co_afacode_encode_log(
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
COMMENT ON FUNCTION api.co_afacode_encode_log(float,float,float,text)
  IS 'Encodes lat/lon to a Logistics AFAcode for Colombia.';

CREATE or replace FUNCTION api.afacode_encode_log(
  p_uri  text,
  p_grid int  DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
      WHEN 'BR' THEN api.br_afacode_encode_log(u[1],u[2],COALESCE(ROUND((      (afa.br_cell_nearst_level(u[3])  )    /5)*5),35),p_isolabel_ext)
      WHEN 'CM' THEN api.cm_afacode_encode_log(u[1],u[2],COALESCE(ROUND((LEAST((afa.cm_cell_nearst_level(u[3])+1),36)/5)*5),31),p_isolabel_ext)
      WHEN 'CO' THEN api.co_afacode_encode_log(u[1],u[2],COALESCE(ROUND((LEAST((afa.co_cell_nearst_level(u[3])+3),38)/5)*5),33),p_isolabel_ext)
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM str_geouri_decode_new(p_uri) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.osmcode_encode_postal(text,int,text)
  IS 'Wrapper for country-specific Logistics AFAcode encoders. Includes logic for rounding and bounding grid levels per country.';

--DROP TABLE osmc.jurisdiction_bbox CASCADE;
CREATE TABLE osmc.jurisdiction_bbox (
  id             int PRIMARY KEY,
  jurisd_base_id int,
  isolabel_ext   text,
  geom           Geometry
);
COMMENT ON COLUMN osmc.jurisdiction_bbox.id             IS 'Gid.';
COMMENT ON COLUMN osmc.jurisdiction_bbox.jurisd_base_id IS 'Numeric official ID.';
COMMENT ON COLUMN osmc.jurisdiction_bbox.isolabel_ext   IS 'ISO code';
COMMENT ON COLUMN osmc.jurisdiction_bbox.geom           IS 'Box2D for id identifier';
COMMENT ON TABLE  osmc.jurisdiction_bbox                IS 'BStores geographic bounding boxes (BBOX) for national jurisdictions. Used as a preliminary filter to identify the potential jurisdiction of a given point geometry. Entries with NULL in `jurisd_base_id` represent undefined or shared regions (e.g., border areas like BR/UY, BR/CO).';
CREATE INDEX idx_jbbox_geom ON osmc.jurisdiction_bbox USING GiST (geom);

-- DELETE FROM osmc.jurisdiction_bbox;
INSERT INTO osmc.jurisdiction_bbox(id,jurisd_base_id,isolabel_ext,geom) VALUES
( 1,  1,  'BR', ST_SetSRID(ST_MakeBox2D(ST_POINT(-53.0755833,-33.8689056),        ST_POINT(-28.6289646,  5.2695808)),4326)),
( 2,  1,  'BR', ST_SetSRID(ST_MakeBox2D(ST_POINT(-66.8511571,-30.0853962),        ST_POINT(-53.0755833,  5.2695808)),4326)),
( 3,  1,  'BR', ST_SetSRID(ST_MakeBox2D(ST_POINT(-73.9830625,-11.1473716),        ST_POINT(-66.8511571, -4.2316872)),4326)),
( 4,null, null, ST_SetSRID(ST_MakeBox2D(ST_POINT(-70.8479308, -4.2316872),        ST_POINT(-66.8511571,  2.23011  )),4326)), -- bbox BR/CO
( 5,null, null, ST_SetSRID(ST_MakeBox2D(ST_POINT(-57.6489299,-33.8689056),        ST_POINT(-53.0755833,-30.0853962)),4326)), -- bbox BR/UY
( 6, 2,   'CO', ST_SetSRID(ST_MakeBox2D(ST_POINT(-84.8098028,  1.4683015),        ST_POINT(-70.8479308, 16.1694444)),4326)),
( 7, 2,   'CO', ST_SetSRID(ST_MakeBox2D(ST_POINT(-75.192504,  -4.2316872),        ST_POINT(-70.8479308,  1.4695853)),4326)),
( 8, 2,   'CO', ST_SetSRID(ST_MakeBox2D(ST_POINT(-70.8479308,  2.23011  ),        ST_POINT(-66.8511571, 16.1694444)),4326)),
( 9,null, null, ST_SetSRID(ST_MakeBox2D(ST_POINT(-79.2430285, -0.1251374),        ST_POINT(-75.192504 ,  1.4695853)),4326)), -- bbox CO/EC
(10, 3,   'CM', ST_SetSRID(ST_MakeBox2D(ST_POINT(  8.4994544,  1.6522670),        ST_POINT( 16.1910457, 13.0773906)),4326)), -- bbox CM
(11, 4,   'UY', ST_SetSRID(ST_MakeBox2D(ST_POINT(-58.42871924608347,-35.7824481), ST_POINT(-53.1810897,-33.8689056)),4326)),
(12, 4,   'UY', ST_SetSRID(ST_MakeBox2D(ST_POINT(-58.4947729,-33.8689056),        ST_POINT(-57.6489115,-30.1932302)),4326)),
(13, 5,   'EC', ST_SetSRID(ST_MakeBox2D(ST_POINT(-92.2072392, -1.6122316),        ST_POINT(-89.038249,   1.8835964)),4326)),
(14, 5,   'EC', ST_SetSRID(ST_MakeBox2D(ST_POINT(-81.3443465, -5.0159314),        ST_POINT(-75.192504,  -0.1251374)),4326)),
(15, 5,   'EC', ST_SetSRID(ST_MakeBox2D(ST_POINT(-81.3443465, -0.1251374),        ST_POINT(-79.2430285,  1.4695853)),4326)),
(16, 6,   'SV', ST_SetSRID(ST_MakeBox2D(ST_POINT(-90.2209042, 12.9518017),        ST_POINT(-87.5971467, 14.4510488)),4326));

--DROP TABLE osmc.jurisdiction_bbox_border;
CREATE TABLE osmc.jurisdiction_bbox_border (
  id             int PRIMARY KEY,
  bbox_id        int NOT NULL REFERENCES osmc.jurisdiction_bbox(id),
  jurisd_base_id int,
  isolabel_ext   text NOT NULL,
  geom           Geometry
);
COMMENT ON COLUMN osmc.jurisdiction_bbox_border.id             IS 'Gid.';
COMMENT ON COLUMN osmc.jurisdiction_bbox_border.bbox_id        IS 'id of osmc.jurisdiction_bbox.';
COMMENT ON COLUMN osmc.jurisdiction_bbox_border.jurisd_base_id IS 'Numeric official ID.';
COMMENT ON COLUMN osmc.jurisdiction_bbox_border.isolabel_ext   IS 'ISO code';
COMMENT ON COLUMN osmc.jurisdiction_bbox_border.geom           IS 'Geometry of intersection of box with country.';
COMMENT ON TABLE  osmc.jurisdiction_bbox_border                IS 'Stores actual geographic intersections between undefined/shared BBOX regions (from `jurisdiction_bbox`) and countries, using their official jurisdiction geometry. This table helps resolve ambiguous or shared BBOX areas by mapping them to one or more valid countries.';

-- DELETE FROM osmc.jurisdiction_bbox_border;
INSERT INTO osmc.jurisdiction_bbox_border
SELECT ROW_NUMBER() OVER() as id, b.id AS bbox_id, g.jurisd_base_id AS jurisd_base_id, g.isolabel_ext AS isolabel_ext, ST_Intersection(b.geom,g.geom)
FROM osmc.jurisdiction_bbox b
LEFT JOIN optim.vw01full_jurisdiction_geom g
ON ST_Intersects(b.geom,g.geom) IS TRUE
WHERE b.jurisd_base_id IS NULL
  AND g.isolabel_ext IN ('CM','CO','BR','UY','EC')
;
ANALYZE osmc.jurisdiction_bbox_border;

CREATE or replace FUNCTION api.afacode_encode_log_no_context(
  p_uri  text,
  p_grid int  DEFAULT 0
) RETURNS jsonb AS $wrap$
  WITH
  decoded_point AS
  (
    SELECT ST_SetSRID(ST_MakePoint(a.udec[2],a.udec[1]),4326) AS pt
    FROM str_geouri_decode(p_uri) a(udec)
  ),
  candidate_bbox AS
  (
    SELECT bbox.id, bbox.jurisd_base_id, bbox.isolabel_ext, dp.pt
    FROM optim.jurisdiction_bbox bbox
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
      FROM optim.jurisdiction_bbox_border b
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
          WHEN 'BR' THEN ST_Transform(rj.pt,952019)
          WHEN 'CM' THEN ST_Transform(rj.pt,32632)
          WHEN 'CO' THEN ST_Transform(rj.pt,9377)
          WHEN 'UY' THEN ST_Transform(rj.pt,32721)
          WHEN 'EC' THEN ST_Transform(rj.pt,32717)
          WHEN 'SV' THEN ST_Transform(rj.pt,5399)
        END AS pt
    FROM resolved_jurisdiction rj
  )
  SELECT api.afacode_encode_log(p_uri,p_grid,g.isolabel_ext)
  FROM osmc.coverage g
  JOIN transformed_point e
  ON e.pt && g.geom
     AND g.isolabel_ext LIKE split_part(e.isolabel_ext,'-',1) || '%'
     AND (is_contained IS TRUE OR ST_intersects(e.pt,g.geom))
  WHERE g.is_country IS FALSE
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.afacode_encode_log_no_context(text,int)
  IS 'Encodes a GeoURI into a logistic AFAcode, without requiring prior jurisdictional context.';

CREATE or replace FUNCTION api.br_afacode_decode_log(
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
    FROM osmc.coverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.br_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.br_cell_area(v.id_length), afa.br_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.br_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for Brazil. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION api.cm_afacode_decode_log(
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
    FROM osmc.coverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.cm_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.cm_cell_area(v.id_length), afa.cm_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.cm_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for Cameroon. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION api.co_afacode_decode_log(
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
    FROM osmc.coverage c
    LEFT JOIN optim.jurisdiction j                     ON c.isolabel_ext = j.isolabel_ext
    LEFT JOIN mvwjurisdiction_synonym_default_abbrev x ON c.isolabel_ext = x.isolabel_ext
    WHERE is_country IS FALSE
      AND c.isolabel_ext = p_isolabel_ext
      AND cindex = substring(p_code,1,1)
  ) j,
  LATERAL (SELECT afa.hBig_to_hex(j.hbig), afa.co_decode(j.hbig), ((j.hbig)::bit(6))::int - 12) v(id,geom,id_length),
  LATERAL (SELECT afa.co_cell_area(v.id_length), afa.co_cell_side(v.id_length)) l(area,side)
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.co_afacode_decode_log(text,text)
  IS 'Decodes a logistic AFAcode for Colombia. Requiring prior jurisdictional context.';

CREATE or replace FUNCTION api.afacode_decode_log(
   p_code text
) RETURNS jsonb AS $wrap$
  SELECT
    CASE l[2]
      WHEN 'BR' THEN api.br_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
      WHEN 'CM' THEN api.cm_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
      WHEN 'CO' THEN api.co_afacode_decode_log( upper(REPLACE(u[2],'.','')), l[1] )
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

CREATE or replace FUNCTION api.br_jurisdiction_coverage(
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

  FROM osmc.coverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.br_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.br_cell_area(v.id_length), afa.br_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.br_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.'
;
-- EXPLAIN ANALYZE SELECT api.br_jurisdiction_coverage('BR-SP-Campinas');

CREATE or replace FUNCTION api.cm_jurisdiction_coverage(
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

  FROM osmc.coverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.cm_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.cm_cell_area(v.id_length), afa.cm_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.cm_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.'
;

CREATE or replace FUNCTION api.co_jurisdiction_coverage(
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

  FROM osmc.coverage c,
  LATERAL (SELECT afa.hBig_to_hex(c.cbits), afa.co_decode(c.cbits), ((c.cbits)::bit(6))::int - 12 ) v(id,geom,id_length),
  LATERAL (SELECT afa.co_cell_area(v.id_length), afa.co_cell_side(v.id_length)) l(area,side)
  WHERE isolabel_ext = p_iso
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.co_jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.'
;

CREATE or replace FUNCTION api.jurisdiction_coverage(
   p_iso  text
) RETURNS jsonb AS $wrap$
  SELECT
    CASE l[2]
      WHEN 'BR' THEN api.br_jurisdiction_coverage( l[1] )
      WHEN 'CM' THEN api.cm_jurisdiction_coverage( l[1] )
      WHEN 'CO' THEN api.co_jurisdiction_coverage( l[1] )
      ELSE jsonb_build_object('error', 'Jurisdiction not supported.')
    END
  FROM str_geocodeiso_decode(p_iso) l
$wrap$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION api.jurisdiction_coverage(text)
  IS 'Returns jurisdiction coverage.'
;

------------------

-- Add size_shortestprefix in https://github.com/digital-guard/preserv/src/optim-step4-api.sql[api.jurisdiction_geojson_from_isolabel]
CREATE or replace FUNCTION api.jurisdiction_geojson_from_isolabel(
   p_code text
) RETURNS jsonb AS $f$
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features',
            (
                jsonb_agg(ST_AsGeoJSONb(
                    geom,8,0,null,
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
                        'area', info->'area_km2',
                        'shares_border_with', info->'shares_border_with',
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
