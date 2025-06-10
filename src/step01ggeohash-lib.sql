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


CREATE TABLE osmc.coverage (
  cbits          bigint,
  isolabel_ext   text,
  cindex         text,
  bbox           int[],
  status         smallint DEFAULT 0 CHECK (status IN (0,1,2)), -- 0: generated, 1: revised, 2: homologated
  is_country     boolean  DEFAULT FALSE,
  is_contained   boolean  DEFAULT FALSE,
  is_overlay     boolean  DEFAULT FALSE,
  kx_prefix      text,
  geom           geometry,
  geom_srid4326  geometry
);
CREATE INDEX osm_coverage_geom_idx1              ON osmc.coverage USING gist (geom);
CREATE INDEX osm_coverage_geom4326_idx1          ON osmc.coverage USING gist (geom_srid4326);
CREATE INDEX osm_coverage_isolabel_ext_idx1      ON osmc.coverage USING btree (isolabel_ext);
CREATE INDEX osm_coverage_cbits10true_idx        ON osmc.coverage ((cbits::bit(8))) WHERE is_country IS TRUE;
CREATE INDEX osm_coverage_isolabel_ext_true_idx  ON osmc.coverage (isolabel_ext) WHERE is_country IS TRUE;
CREATE INDEX osm_coverage_isolabel_ext_false_idx ON osmc.coverage (isolabel_ext) WHERE is_country IS FALSE;
CREATE INDEX osm_coverage_cbits15false_idx       ON osmc.coverage ((cbits::bit(12)),isolabel_ext) WHERE is_country IS FALSE;

COMMENT ON COLUMN osmc.coverage.cbits            IS 'Coverage cell identifier.';
COMMENT ON COLUMN osmc.coverage.isolabel_ext     IS 'ISO 3166-1 alpha-2 code and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.coverage.cindex           IS 'Coverage cell prefix index. Used only case is_country=false.';
COMMENT ON COLUMN osmc.coverage.bbox             IS 'Coverage cell bbox.';
COMMENT ON COLUMN osmc.coverage.status           IS 'Coverage status. Convention: 0: generated, 1: revised, 2: homologated.';
COMMENT ON COLUMN osmc.coverage.is_country       IS 'True if it is a cell of national coverage..';
COMMENT ON COLUMN osmc.coverage.is_contained     IS 'True if it is a cell contained in the jurisdiction..';
COMMENT ON COLUMN osmc.coverage.is_overlay       IS 'True if it is an overlay cell.';
COMMENT ON COLUMN osmc.coverage.geom             IS 'Coverage cell geometry on default srid.';
COMMENT ON COLUMN osmc.coverage.geom_srid4326    IS 'Coverage cell geometry on 4326 srid. Used only case is_country=true.';
COMMENT ON TABLE  osmc.coverage IS 'Jurisdictional coverage.';


CREATE TABLE osmc.jurisdiction_geom_buffer_clipped (
  isolabel_ext text PRIMARY KEY,
  geom geometry(Geometry,4326)
);
COMMENT ON COLUMN osmc.jurisdiction_geom_buffer_clipped.isolabel_ext       IS 'ISO 3166-1 alpha-2 code and name (camel case); e.g. BR-SP-SaoPaulo.';
COMMENT ON COLUMN osmc.jurisdiction_geom_buffer_clipped.geom               IS 'Geometry for osm_id identifier';
CREATE INDEX osmc_jurisdiction_geom_buffer_clipped_idx1     ON osmc.jurisdiction_geom_buffer_clipped USING gist (geom);
CREATE INDEX osmc_jurisdiction_geom_buffer_clipped_isolabel_ext_idx1 ON osmc.jurisdiction_geom_buffer_clipped USING btree (isolabel_ext);
COMMENT ON TABLE osmc.jurisdiction_geom_buffer_clipped IS 'OpenStreetMap geometries for optim.jurisdiction.';


CREATE OR REPLACE FUNCTION osmc.str_geouri_decode(uri TEXT) RETURNS float[] AS $f$
  SELECT regexp_match(uri,'^geo:(?:olc:|ghs:)?([-0-9\.]+),([-0-9\.]+)(?:;u=([-0-9\.]+))?','i')::float[]
$f$ LANGUAGE SQL IMMUTABLE PARALLEL SAFE;
COMMENT ON FUNCTION str_geouri_decode(text)
  IS 'Decodes standard GeoURI of latitude and longitude into float array.'
;

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


CREATE or replace FUNCTION osmc.upsert_coverage(
  p_isolabel_ext text,
  p_status       smallint, -- 0: generated, 1: revised, 2: homologated, 3: official
  p_cover        text[],
  p_overlay      text[] DEFAULT array[]::text[]
) RETURNS text AS $f$
  DELETE FROM osmc.coverage WHERE isolabel_ext = p_isolabel_ext;
  INSERT INTO osmc.coverage(cbits,isolabel_ext,cindex,status,is_country,is_contained,is_overlay,kx_prefix,geom,geom_srid4326)

  SELECT cbits, isolabel_ext, cindex, status, is_country, is_contained, is_overlay, kx_prefix, geom, ST_Transform(geom,4326) AS geom_srid4326
  FROM
  (
    SELECT
          hBig AS cbits, p_isolabel_ext AS isolabel_ext,

          CASE split_part(p_isolabel_ext,'-',1)
          WHEN 'SV' THEN natcod.vbit_to_baseh((ROW_NUMBER() OVER (ORDER BY is_overlay ASC, hBig ASC) - (CASE WHEN array_position(p_cover, NULL) = 1 THEN 0 ELSE 1 END))::bit(4),16)
          ELSE natcod.vbit_to_strstd((ROW_NUMBER() OVER (ORDER BY is_overlay ASC, hBig ASC) - (CASE WHEN array_position(p_cover, NULL) = 1 THEN 0 ELSE 1 END))::bit(5),'32nvu') END AS cindex,

          p_status AS status, (CASE WHEN p_isolabel_ext IN ('BR','CM','CO','SV') THEN TRUE ELSE FALSE END) AS is_country,
          ST_ContainsProperly(ST_Transform(geom_isolabel,ST_SRID(geom_cell)),geom_cell) AS is_contained,
          is_overlay AS is_overlay, prefix AS kx_prefix,
          ST_Intersection(ST_Transform(geom_isolabel,ST_SRID(geom_cell)),geom_cell) AS geom
    FROM
    (
      SELECT is_overlay, prefix, hBig,
          CASE split_part(p_isolabel_ext,'-',1)
            WHEN 'BR' THEN afa.br_decode(hbig)
            WHEN 'CM' THEN afa.cm_decode(hbig)
            WHEN 'CO' THEN afa.co_decode(hbig)
            WHEN 'SV' THEN afa.sv_decode(hbig)
          END AS geom_cell
      FROM
      (
        SELECT FALSE AS is_overlay, prefix,
          CASE split_part(p_isolabel_ext,'-',1)
            WHEN 'BR' THEN afa.br_hex_to_hBig(prefix)
            WHEN 'CM' THEN afa.cm_hex_to_hBig(prefix)
            WHEN 'CO' THEN afa.co_hex_to_hBig(prefix)
            WHEN 'SV' THEN afa.sv_hex_to_hBig(prefix)
          END AS hBig
        FROM unnest(p_cover) t(prefix)
        WHERE prefix IS NOT NULL

        UNION

        SELECT TRUE  AS is_overlay, prefix_overlay AS prefix,
          CASE split_part(p_isolabel_ext,'-',1)
            WHEN 'BR' THEN afa.br_hex_to_hBig(prefix_overlay)
            WHEN 'CM' THEN afa.cm_hex_to_hBig(prefix_overlay)
            WHEN 'CO' THEN afa.co_hex_to_hBig(prefix_overlay)
            WHEN 'SV' THEN afa.sv_hex_to_hBig(prefix_overlay)
          END AS hBig
        FROM unnest(p_overlay) s(prefix_overlay)
      ) a
    ) p
    LEFT JOIN LATERAL
    (
      SELECT ST_UNION(geom) AS geom_isolabel
      FROM
      (
        SELECT geom
        FROM optim.jurisdiction_eez
        WHERE p_isolabel_ext IN ('CO','CO/JM')

        UNION

        SELECT geom
        FROM optim.vw01full_jurisdiction_geom
        WHERE isolabel_ext = p_isolabel_ext
      ) x
      WHERE
        (
          CASE
            WHEN p_isolabel_ext IN ('CO') THEN TRUE
            ELSE geom IS NOT NULL
          END
        )
    ) s
    ON TRUE

    ORDER BY cindex
  ) z
  RETURNING 'Ok.'
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION osmc.upsert_coverage(text,smallint,text[],text[])
  IS 'Upsert coverage.'
;
-- SELECT osmc.upsert_coverage('CO-BOY-Tunja',0::smallint,'{NULL,c347g,c347q,c34dg,c34dq,c352g,c352q,c358g,c358q,c359q,c35ag,c35bg}'::text[],'{c3581r,c3581v,c3583h,c3583m,c3583r,c3583v,c3589h,c3589m,c3589v,c358ch,c358cr}'::text[]);

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
          FROM osmc.coverage
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
          FROM osmc.coverage
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
  IS 'Generates json for select from AFA.codes website.'
;

CREATE or replace FUNCTION osmc.generate_cover_csv(
  p_isolabel_ext text,
  p_path text
) RETURNS text AS $f$
DECLARE
    q_copy text;
BEGIN
  q_copy := $$
    COPY (

    SELECT a.isolabel_ext, LEAST(a.status,b.status) AS status, a.cover, b.overlay
    FROM
    (
      SELECT isolabel_ext, MIN(status) AS status, string_agg(prefix,' ') AS cover
      FROM
      (
        SELECT isolabel_ext, status, kx_prefix AS prefix
        FROM osmc.coverage
        WHERE is_country IS FALSE -- isolevel3 cover
          AND is_overlay IS FALSE
          AND isolabel_ext = '%s'
        ORDER BY isolabel_ext, cbits ASC
      ) r
      GROUP BY isolabel_ext
      ORDER BY 1
    ) a
    LEFT JOIN
    (
      SELECT isolabel_ext, MIN(status) AS status, string_agg(prefix,' ') AS overlay
      FROM
      (
        SELECT isolabel_ext, status, kx_prefix AS prefix
        FROM osmc.coverage
        WHERE is_country IS FALSE -- isolevel3 cover
          AND is_overlay IS TRUE
          AND isolabel_ext = '%s'
        ORDER BY isolabel_ext, cbits ASC
      ) r
      GROUP BY isolabel_ext
      ORDER BY 1
    ) b
    ON a.isolabel_ext = b.isolabel_ext

    ) TO '%s' CSV HEADER
  $$;

  EXECUTE format(q_copy,p_isolabel_ext,p_isolabel_ext,p_path);

  RETURN 'Ok.';
END
$f$ LANGUAGE PLpgSQL;
COMMENT ON FUNCTION osmc.generate_cover_csv(text,text)
  IS 'Generate csv with isolevel=3 coverage and overlay in separate array.'
;
/*
SELECT osmc.generate_cover_csv('BR','/tmp/pg_io/coveragebr.csv');
SELECT osmc.generate_cover_csv('CO','/tmp/pg_io/coverageco.csv');
SELECT osmc.generate_cover_csv('UY','/tmp/pg_io/coverageuy.csv');
SELECT osmc.generate_cover_csv('CM','/tmp/pg_io/coveragecm.csv');
*/
