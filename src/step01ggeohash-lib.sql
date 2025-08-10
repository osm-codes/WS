DROP SCHEMA IF EXISTS osmc CASCADE;
CREATE SCHEMA osmc;

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

-- DROP MATERIALIZED VIEW IF EXISTS osmc.mvjurisdiction_bbox_border;
CREATE MATERIALIZED VIEW osmc.mvjurisdiction_bbox_border AS
  SELECT ROW_NUMBER() OVER() as id, b.id AS bbox_id, g.jurisd_base_id AS jurisd_base_id, g.isolabel_ext AS isolabel_ext, ST_Intersection(b.geom,g.geom) AS geom
  FROM osmc.jurisdiction_bbox b
  LEFT JOIN optim.vw01full_jurisdiction_geom g
  ON ST_Intersects(b.geom,g.geom) IS TRUE
  WHERE b.jurisd_base_id IS NULL
    AND g.isolabel_ext IN ('CM','CO','BR','UY','EC')
  ;
COMMENT ON COLUMN osmc.mvjurisdiction_bbox_border.id             IS 'Gid.';
COMMENT ON COLUMN osmc.mvjurisdiction_bbox_border.bbox_id        IS 'id of osmc.jurisdiction_bbox.';
COMMENT ON COLUMN osmc.mvjurisdiction_bbox_border.jurisd_base_id IS 'Numeric official ID.';
COMMENT ON COLUMN osmc.mvjurisdiction_bbox_border.isolabel_ext   IS 'ISO code';
COMMENT ON COLUMN osmc.mvjurisdiction_bbox_border.geom           IS 'Geometry of intersection of box with country.';
COMMENT ON MATERIALIZED VIEW  osmc.mvjurisdiction_bbox_border                IS 'Stores actual geographic intersections between undefined/shared BBOX regions (from `jurisdiction_bbox`) and countries, using their official jurisdiction geometry. This table helps resolve ambiguous or shared BBOX areas by mapping them to one or more valid countries.';
CREATE UNIQUE INDEX mvjurisdiction_bbox_border_id ON osmc.mvjurisdiction_bbox_border (id);

------------------------------------

CREATE TABLE osmc.citycover_raw (
  isolabel_ext text NOT NULL,
  status int NOT NULL,
  base_intlevel int,
  cover text NOT NULL,
  overlay text,
  cover_order text,
  overlay_order text,
  UNIQUE (isolabel_ext)
);

CREATE TABLE osmc.citycover_dust_raw (
  dust_b16h text NOT NULL, -- PK. from gid
  dust_city int NOT NULL,  -- PK. jurisd_local_id
  dust_city_label text,  -- redundant. isolabel_ext
  merge_score int,   -- redundant.
  receptor_b16h text NOT NULL, -- important
  receptor_city int NOT NULL, -- important
  UNIQUE (dust_b16h,dust_city)
);

-- DROP VIEW IF EXISTS osmc.vw_citycover_dust_cell;
CREATE VIEW osmc.vw_citycover_dust_cell AS
  WITH dust2 AS
  (
    SELECT d.*,
        g.isolabel_ext AS receptor_city_isolabel_ext,
        split_part(dust_city_label,'-',1),
        CASE split_part(dust_city_label,'-',1)
          WHEN 'BR' THEN afa.br_decode(afa.br_hex_to_hBig(dust_b16h))
          WHEN 'CM' THEN afa.cm_decode(afa.cm_hex_to_hBig(dust_b16h))
          WHEN 'CO' THEN afa.co_decode(afa.co_hex_to_hBig(dust_b16h))
          WHEN 'SV' THEN afa.sv_decode(afa.sv_hex_to_hBig(dust_b16h))
        END AS cell_geom,
        j.geom AS city_geom
    FROM osmc.citycover_dust_raw d
    LEFT JOIN optim.vw01full_jurisdiction_geom j
    ON d.dust_city=j.jurisd_local_id AND d.dust_city_label = j.isolabel_ext AND j.isolevel=3
    LEFT JOIN optim.vw01full_jurisdiction_geom g
    ON d.receptor_city=g.jurisd_local_id AND split_part(d.dust_city_label,'-',1)  = split_part(g.isolabel_ext,'-',1) AND g.isolevel=3
  )
  SELECT dust2.dust_b16h,
         dust2.dust_city,
         dust2.receptor_city,
         dust2.receptor_b16h,
         dust2.dust_city_label,
         dust2.receptor_city_isolabel_ext,
         cell_geom,
         ST_Intersection(dust2.cell_geom,ST_Transform(dust2.city_geom,ST_SRID(dust2.cell_geom))) as dust_geom
 FROM dust2
;

-- DROP MATERIALIZED VIEW IF EXISTS osmc.mvwcoverage CASCADE;
CREATE MATERIALIZED VIEW osmc.mvwcoverage AS
WITH raw_prefixes AS (
  SELECT *
  FROM
  (
    SELECT isolabel_ext, status, unnest(string_to_array(cover, ' ')) AS prefix, unnest(string_to_array(cover_order, ' ')) AS prefix_index, FALSE AS is_overlay,
           (CASE WHEN array_position(string_to_array(cover, ' '), 'NULL') = 1 THEN 0 ELSE 1 END) AS firts_null
    FROM osmc.citycover_raw
  ) x
  WHERE prefix IS NOT NULL

  UNION ALL

  SELECT  isolabel_ext, status, unnest(string_to_array(overlay, ' ')) AS prefix, unnest(string_to_array(overlay_order, ' ')) AS prefix_index,  TRUE AS is_overlay,
          (CASE WHEN array_position(string_to_array(cover, ' '), 'NULL') = 1 THEN 0 ELSE 1 END) AS firts_null
  FROM osmc.citycover_raw
),
prefix_hbig AS (
  SELECT
    isolabel_ext,status,prefix,prefix_index,is_overlay,
    split_part(isolabel_ext, '-', 1) AS country_code, firts_null,
    CASE split_part(isolabel_ext, '-', 1)
      WHEN 'BR' THEN afa.br_hex_to_hBig(prefix)
      WHEN 'CM' THEN afa.cm_hex_to_hBig(prefix)
      WHEN 'CO' THEN afa.co_hex_to_hBig(prefix)
      WHEN 'SV' THEN afa.sv_hex_to_hBig(prefix)
    END AS hBig
  FROM raw_prefixes
),
decoded_geom AS (
  SELECT isolabel_ext,status,prefix,prefix_index,is_overlay,hBig,country_code,
    (ROW_NUMBER() OVER (PARTITION BY isolabel_ext  ORDER BY is_overlay ASC, hBig ASC) - firts_null) AS order_id,
    CASE country_code
      WHEN 'BR' THEN afa.br_decode(hBig)
      WHEN 'CM' THEN afa.cm_decode(hBig)
      WHEN 'CO' THEN afa.co_decode(hBig)
      WHEN 'SV' THEN afa.sv_decode(hBig)
    END AS geom_cell
  FROM prefix_hBig
),
geom_isolabel AS (
  SELECT isolabel_ext, geom
  FROM optim.mvwjurisdiction_geomeez
  UNION
  SELECT isolabel_ext, geom
  FROM optim.vw01full_jurisdiction_geom
  WHERE isolabel_ext LIKE '%-%-%'
),
datas AS (
  SELECT
        d.hBig AS cbits,
        d.isolabel_ext,
          CASE
          WHEN country_code = 'SV' THEN natcod.vbit_to_baseh(order_id::bit(4),16)
          WHEN country_code = 'CM' THEN prefix_index
          WHEN country_code = 'BR' AND d.isolabel_ext like 'BR-693%' THEN prefix_index
          ELSE natcod.vbit_to_strstd(order_id::bit(5),'32nvu')
          END AS cindex,
        status,
        (CASE WHEN d.isolabel_ext IN ('BR','CM','CO','SV') THEN TRUE ELSE FALSE END) AS is_country,
        ST_ContainsProperly(ST_Transform(g.geom,ST_SRID(geom_cell)),geom_cell) AS is_contained,
        is_overlay AS is_overlay,
        prefix AS kx_prefix,
        ST_Intersection(ST_Transform(g.geom,ST_SRID(geom_cell)),geom_cell) AS geom
  FROM decoded_geom d
  LEFT JOIN geom_isolabel g ON g.isolabel_ext = d.isolabel_ext
),
dust AS (
  SELECT d.receptor_b16h, d.receptor_city_isolabel_ext, ST_Union(d.dust_geom) as dust_union
  FROM osmc.vw_citycover_dust_cell d
  GROUP BY receptor_city_isolabel_ext, receptor_b16h
),
final AS
(
  SELECT cbits, isolabel_ext, cindex, status, is_country, is_contained, is_overlay, kx_prefix, receptor_b16h,
        --ST_Union(r.geom, s.dust_union) AS geom
        CASE WHEN s.dust_union IS NULL THEN r.geom ELSE ST_Union(r.geom, s.dust_union) END AS geom
  FROM datas r
  LEFT JOIN dust s
  ON r.kx_prefix=s.receptor_b16h AND r.isolabel_ext=s.receptor_city_isolabel_ext
)
SELECT f.cbits, f.isolabel_ext, f.cindex, f.status, f.is_country, f.is_contained, f.is_overlay, f.kx_prefix,
       xx.abbreviations AS abbreviations,
       -- x.abbrev || '~' || cindex AS canonical_prefix_with_cindex,
       -- x.abbrev || '~'           AS canonical_prefix_with_separator,
       -- x.abbrev                  AS canonical_prefix,
       CASE WHEN x.abbrev IS NOT NULL THEN x.abbrev || '~' || cindex ELSE f.isolabel_ext || '~' || cindex END AS canonical_prefix_with_cindex,
       CASE WHEN x.abbrev IS NOT NULL THEN x.abbrev || '~'           ELSE f.isolabel_ext || '~'           END AS canonical_prefix_with_separator,
       CASE WHEN x.abbrev IS NOT NULL THEN x.abbrev                  ELSE f.isolabel_ext                  END AS canonical_prefix,
       j.jurisd_local_id, j.jurisd_base_id,
       f.geom, ST_Transform(f.geom,4326) AS geom_srid4326
FROM final f
LEFT JOIN
(
  SELECT DISTINCT abbrev, isolabel_ext
  FROM optim.jurisdiction_abbrev_option
  WHERE default_abbrev IS TRUE
) x(abbrev,isolabel_ext)
  ON x.isolabel_ext = f.isolabel_ext
LEFT JOIN optim.jurisdiction j
  ON j.isolabel_ext = f.isolabel_ext
LEFT JOIN
(
  SELECT isolabel_ext, array_agg(abbrev) AS abbreviations
  FROM optim.jurisdiction_abbrev_option
  WHERE isolabel_ext IN
  (
      SELECT MAX(isolabel_ext) AS isolabel_ext
      FROM optim.jurisdiction_abbrev_option
      WHERE selected IS TRUE
      GROUP BY abbrev
      HAVING count(*) = 1
  )
  AND abbrev NOT LIKE '%;%' AND default_abbrev IS FALSE
  AND (CASE WHEN isolabel_ext like 'CO%' THEN default_abbrev is false ELSE TRUE END)
  GROUP BY isolabel_ext
) xx
  ON xx.isolabel_ext = f.isolabel_ext
;
CREATE INDEX osmc_mvwcoverage_geom_idx1              ON osmc.mvwcoverage USING gist (geom);
CREATE INDEX osmc_mvwcoverage_geom4326_idx1          ON osmc.mvwcoverage USING gist (geom_srid4326);
CREATE INDEX osmc_mvwcoverage_isolabel_ext_idx1      ON osmc.mvwcoverage USING btree (isolabel_ext);
CREATE INDEX osmc_mvwcoverage_cbits10true_idx        ON osmc.mvwcoverage ((cbits::bit(8))) WHERE is_country IS TRUE;
CREATE INDEX osmc_mvwcoverage_isolabel_ext_true_idx  ON osmc.mvwcoverage (isolabel_ext) WHERE is_country IS TRUE;
CREATE INDEX osmc_mvwcoverage_isolabel_ext_false_idx ON osmc.mvwcoverage (isolabel_ext) WHERE is_country IS FALSE;
CREATE INDEX osmc_mvwcoverage_cbits15false_idx       ON osmc.mvwcoverage ((cbits::bit(12)),isolabel_ext) WHERE is_country IS FALSE;
COMMENT ON COLUMN osmc.mvwcoverage.cbits         IS 'Coverage cell identifier.';
COMMENT ON COLUMN osmc.mvwcoverage.isolabel_ext  IS 'ISO 3166-1 alpha-2 code and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwcoverage.cindex        IS 'Coverage cell prefix index. Used only case is_country=false.';
--COMMENT ON COLUMN osmc.mvwcoverage.bbox          IS 'Coverage cell bbox.';
COMMENT ON COLUMN osmc.mvwcoverage.status        IS 'Coverage status. Convention: 0: generated, 1: revised, 2: homologated.';
COMMENT ON COLUMN osmc.mvwcoverage.is_country    IS 'True if it is a cell of national coverage..';
COMMENT ON COLUMN osmc.mvwcoverage.is_contained  IS 'True if it is a cell contained in the jurisdiction..';
COMMENT ON COLUMN osmc.mvwcoverage.is_overlay    IS 'True if it is an overlay cell.';
COMMENT ON COLUMN osmc.mvwcoverage.kx_prefix     IS '';
COMMENT ON COLUMN osmc.mvwcoverage.geom          IS 'Coverage cell geometry on default srid.';
COMMENT ON COLUMN osmc.mvwcoverage.geom_srid4326 IS 'Coverage cell geometry on 4326 srid. Used only case is_country=true.';
COMMENT ON MATERIALIZED VIEW  osmc.mvwcoverage   IS 'Jurisdictional coverage.';

------------------------------------

-- DROP MATERIALIZED VIEW IF EXISTS osmc.mvwjurisdiction_geom_buffer_clipped;
CREATE MATERIALIZED VIEW osmc.mvwjurisdiction_geom_buffer_clipped AS
  SELECT r.isolabel_ext AS isolabel_ext,
         ST_Intersection(ST_Transform(s.geom,4326),r.geom) AS geom
  FROM optim.jurisdiction_geom_buffer r
  LEFT JOIN
  (
    SELECT isolabel_ext,
      ST_Union(CASE split_part(isolabel_ext,'-',1)
      WHEN 'BR' THEN afa.br_decode(cbits)
      WHEN 'CM' THEN afa.cm_decode(cbits)
      WHEN 'CO' THEN afa.co_decode(cbits)
      WHEN 'SV' THEN afa.sv_decode(cbits)
      END) AS geom
    FROM osmc.mvwcoverage
    GROUP BY isolabel_ext
  ) s
  ON r.isolabel_ext  = s.isolabel_ext
  ;
COMMENT ON COLUMN osmc.mvwjurisdiction_geom_buffer_clipped.isolabel_ext IS 'ISO 3166-1 alpha-2 code and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.mvwjurisdiction_geom_buffer_clipped.geom         IS 'Synonym for isolabel_ext, e.g. br;sao.paulo;sao.paulo br-saopaulo';
COMMENT ON MATERIALIZED VIEW osmc.mvwjurisdiction_geom_buffer_clipped   IS 'OpenStreetMap geometries for optim.jurisdiction.';
CREATE UNIQUE INDEX mvwjurisdiction_geom_buffer_clipped_isolabel_ext ON osmc.mvwjurisdiction_geom_buffer_clipped (isolabel_ext);

------------------------------------

CREATE OR REPLACE FUNCTION osmc.str_geouri_decode(uri TEXT) RETURNS float[] AS $f$
  SELECT regexp_match(uri,'^geo:(?:olc:|ghs:)?([-0-9\.]+),([-0-9\.]+)(?:;u=([-0-9\.]+))?','i')::float[]
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION str_geouri_decode(text)
  IS 'Decodes standard GeoURI of latitude and longitude into float array.';

CREATE or replace FUNCTION osmc.encode_short_code(
  p_hbig           bigint,
  p_isolabel_ext   text
) RETURNS TABLE(cindex text, cbits bigint, abbreviations text[], jurisd_local_id int, canonical_prefix_with_cindex text) AS $f$
  SELECT cindex, cbits, abbreviations, jurisd_local_id, canonical_prefix_with_cindex
  FROM osmc.mvwcoverage r,
  LATERAL (SELECT afa.hBig_to_vbit(p_hbig) AS hbitstr) v,
  LATERAL (SELECT (cbits::bit(6))::int AS prefixlen) l
  WHERE isolabel_ext = p_isolabel_ext
    AND afa.hBig_to_vbit(cbits) = substring(v.hbitstr FROM 1 FOR l.prefixlen)
  ;
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION osmc.encode_short_code(bigint,text)
  IS 'Computes the short code representation of a hierarchical grid cell for a given jurisdiction.';

CREATE or replace VIEW osmc.jurisdictions_select AS
  SELECT jsonb_object_agg(isolabel_ext,ll) AS gg
  FROM
  (
    SELECT split_part(z.isolabel_ext,'-',1) AS isolabel_ext, jsonb_object_agg(split_part(z.isolabel_ext,'-',2),jsonb_build_object('draft', draft, 'work', work, 'name', x.name)) AS ll
    FROM
    (
      SELECT CASE WHEN b.isolabel_ext IS NULL THEN c.isolabel_ext ELSE b.isolabel_ext END AS isolabel_ext, draft, work
      FROM
      (
        SELECT split_part(isolabel_ext,'-',1) || '-' || split_part(isolabel_ext,'-',2) AS isolabel_ext, jsonb_agg(split_part(isolabel_ext,'-',3)) AS work
        FROM
        (
          SELECT DISTINCT isolabel_ext, status
          FROM osmc.mvwcoverage
          WHERE is_country IS FALSE AND status <> 0
          ORDER BY 1
        ) a
        GROUP BY split_part(isolabel_ext,'-',1) || '-' || split_part(isolabel_ext,'-',2), status
        ORDER BY 1
      ) b
      FULL OUTER JOIN
      (
        SELECT split_part(isolabel_ext,'-',1) || '-' || split_part(isolabel_ext,'-',2) AS isolabel_ext, jsonb_agg(split_part(isolabel_ext,'-',3)) AS draft
        FROM
        (
          SELECT DISTINCT isolabel_ext, status
          FROM osmc.mvwcoverage
          WHERE is_country IS FALSE AND status = 0
          ORDER BY 1
        ) a
        GROUP BY split_part(isolabel_ext,'-',1) || '-' || split_part(isolabel_ext,'-',2), status
        ORDER BY 1
      ) c
      ON b.isolabel_ext = c.isolabel_ext
    ) z
    LEFT JOIN optim.jurisdiction x
    ON z.isolabel_ext = x.isolabel_ext
    GROUP BY split_part(z.isolabel_ext,'-',1)
  ) c
;
COMMENT ON VIEW osmc.jurisdictions_select
  IS 'Generates json for select from AFA.codes website.';

CREATE or replace FUNCTION osmc.generate_cover_csv(
  p_isolabel_ext text,
  p_path text
) RETURNS text AS $f$
DECLARE
    q_copy text;
BEGIN
  q_copy := $$
    COPY (

      WITH base AS (
        SELECT
          isolabel_ext,
          status,
          kx_prefix,
          is_overlay,
          cindex
        FROM osmc.mvwcoverage
        WHERE is_country IS FALSE
          AND isolabel_ext LIKE '%s%%'
      )
      SELECT
        isolabel_ext,
        MIN(status) AS status,
        NULL AS base_intlevel,
        STRING_AGG(kx_prefix, ' ') FILTER (WHERE is_overlay IS FALSE) AS cover,
        STRING_AGG(kx_prefix, ' ') FILTER (WHERE is_overlay IS TRUE) AS overlay,
        STRING_AGG(cindex,    ' ') FILTER (WHERE is_overlay IS FALSE) AS cover_order,
        STRING_AGG(cindex,    ' ') FILTER (WHERE is_overlay IS TRUE) AS overlay_order
      FROM base
      GROUP BY isolabel_ext
      ORDER BY isolabel_ext

    ) TO '%s' CSV HEADER
  $$;

  EXECUTE format(q_copy,p_isolabel_ext,p_path);

  RETURN 'Ok.';
END
$f$ LANGUAGE PLpgSQL;
COMMENT ON FUNCTION osmc.generate_cover_csv(text,text)
  IS 'Generate csv with isolevel=3 coverage and overlay in separate array.';
/*
SELECT osmc.generate_cover_csv('BR','/tmp/pg_io/coveragebr.csv');
SELECT osmc.generate_cover_csv('CO','/tmp/pg_io/coverageco.csv');
SELECT osmc.generate_cover_csv('UY','/tmp/pg_io/coverageuy.csv');
SELECT osmc.generate_cover_csv('CM','/tmp/pg_io/coveragecm.csv');
*/
