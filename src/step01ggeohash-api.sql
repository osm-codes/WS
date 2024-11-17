CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

-- GGEOHASH ENCODE:

CREATE or replace FUNCTION api.osmcode_encode_postal(
  uri    text,
  grid   int DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
    WHEN 'BR' THEN osmc.encode_postal_br(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),952019),u[4],grid,p_isolabel_ext)
    WHEN 'CM' THEN osmc.encode_postal_cm(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32632),u[4],grid,p_isolabel_ext)
    WHEN 'CO' THEN osmc.encode_postal_co(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),  9377),u[4],grid,p_isolabel_ext)
    WHEN 'UY' THEN osmc.encode_postal_uy(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32721),u[4],grid,p_isolabel_ext)
    WHEN 'EC' THEN osmc.encode_postal_ec(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32717),u[4],grid,p_isolabel_ext)
    END
  FROM (SELECT str_geouri_decode(uri) ) t(u)

$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode_postal(text,int,text)
  IS 'Encodes Geo URI to Postal OSMcode. Wrap for osmcode_encode_postal.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_postal('geo:-15.5,-47.8',0,'BR-GO-Planaltina');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:-15.5,-47.8',0);

CREATE or replace FUNCTION api.osmcode_encode_scientific(
  uri    text,
  grid   int DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
    WHEN 'BR' THEN osmc.encode_scientific_br(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),952019),u[4],grid)
    WHEN 'CM' THEN osmc.encode_scientific_cm(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32632),u[4],grid)
    WHEN 'CO' THEN osmc.encode_scientific_co(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),  9377),u[4],grid)
    WHEN 'UY' THEN osmc.encode_scientific_uy(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32721),u[4],grid)
    WHEN 'EC' THEN osmc.encode_scientific_ec(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32717),u[4],grid)
    END
  FROM ( SELECT str_geouri_decode(uri) ) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode_scientific(text,int,text)
  IS 'Encodes Geo URI to OSMcode. Wrap for osmcode_encode_context(geometry)'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_scientific('geo:-15.5,-47.8;u=6','0','BR');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_scientific('geo:5,13;u=6','0','CM');

CREATE or replace FUNCTION api.osmcode_encode_sci(
  uri    text,
  grid   int DEFAULT 0
) RETURNS jsonb AS $wrap$
  WITH
  b AS
  (
    SELECT ST_MakePoint(a.udec[2],a.udec[1]) AS pt FROM str_geouri_decode(uri) a(udec)
  ),
  c AS
  (
    SELECT id, jurisd_base_id, isolabel_ext, pt FROM optim.jurisdiction_bbox x, b WHERE b.pt && geom
  )
  SELECT api.osmcode_encode_scientific(uri,grid,
    CASE
    WHEN jurisd_base_id IS NULL THEN ( SELECT isolabel_ext FROM optim.jurisdiction_bbox_border WHERE bbox_id = c.id AND ( ST_intersects(geom,ST_SetSRID(c.pt,4326)) ) )
    ELSE isolabel_ext
    END)
  FROM c
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode_sci(text,int)
  IS 'Encodes Geo URI (no context) to scientific OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_sci('geo:3.461,-76.577');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_sci('geo:-15.5,-47.8');

CREATE or replace FUNCTION api.osmcode_encode(
  uri    text,
  grid   int DEFAULT 0
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
COMMENT ON FUNCTION api.osmcode_encode(text,int)
  IS 'Encodes Geo URI (no context) to logistic OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:3.461,-76.577');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:-15.5,-47.8');

------------------
-- GGEOHASH DECODE:

CREATE or replace FUNCTION api.osmcode_decode_scientific_absolute(
   p_code       text, -- e.g.: '645' or list '645,643' in 16h1c
   p_iso        text, -- e.g.: 'BR'
   p_base       int  DEFAULT 16
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
      'type', 'FeatureCollection',
      'features',
          (
            SELECT jsonb_agg(
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005,0.00000005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', TRANSLATE(code_tru,'gqhmrvjknpstzy','GQHMRVJKNPSTZY'),
                        'area', ST_Area(v.geom),
                        'side', SQRT(ST_Area(v.geom)),
                        'truncated_code',truncated_code,
                        'base', osmc.string_base(p_base)
                        ))
                    )::jsonb) AS gj
            FROM
            (
              SELECT DISTINCT code16h,

              -- trunca
              CASE
                WHEN p_base <> 18 AND length(code16h) > 12 AND up_iso IN ('BR')           THEN substring(code16h,1,12)
                WHEN p_base <> 18 AND length(code16h) > 11 AND up_iso IN ('EC','CO','UY') THEN substring(code16h,1,11)
                WHEN p_base <> 18 AND length(code16h) > 10 AND up_iso IN ('CM')           THEN substring(code16h,1,10)
                WHEN p_base =  18 AND length(code)    > 11 AND up_iso IN ('BR')           THEN substring(code,1,11)
                WHEN p_base =  18 AND length(code)    > 10 AND up_iso IN ('UY')           THEN substring(code,1,10)
                ELSE (CASE WHEN p_base=18 THEN code ELSE code16h END)
              END AS code_tru,

              -- flag
              CASE
                WHEN p_base <> 18 AND length(code16h) > 12 AND up_iso IN ('BR')           THEN TRUE
                WHEN p_base <> 18 AND length(code16h) > 11 AND up_iso IN ('EC','CO','UY') THEN TRUE
                WHEN p_base <> 18 AND length(code16h) > 10 AND up_iso IN ('CM')           THEN TRUE
                WHEN p_base =  18 AND length(code)    > 11 AND up_iso IN ('BR')           THEN TRUE
                WHEN p_base =  18 AND length(code)    > 10 AND up_iso IN ('UY')           THEN TRUE
                ELSE NULL
              END AS truncated_code,

              -- vbit code16h
              CASE
                WHEN length(code16h) > 12 AND up_iso IN ('BR')           THEN natcod.baseh_to_vbit(substring(code16h,1,12),16)
                WHEN length(code16h) > 11 AND up_iso IN ('EC','CO','UY') THEN natcod.baseh_to_vbit(substring(code16h,1,11),16)
                WHEN length(code16h) > 10 AND up_iso IN ('CM')           THEN natcod.baseh_to_vbit(substring(code16h,1,10),16)
                ELSE natcod.baseh_to_vbit(code16h,16)
              END AS codebits,

              code,up_iso

              FROM
              (
                SELECT code, upper(p_iso) AS up_iso,
                        CASE
                          WHEN p_base = 18 THEN osmc.decode_16h1c(code,upper(p_iso))
                          ELSE code
                        END AS code16h
                FROM regexp_split_to_table(lower(p_code),',') code
              ) u
            ) c,
            LATERAL
            (
              SELECT ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0(codebits,osmc.extract_jurisdbits(cbits)),bbox, CASE WHEN c.up_iso='EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
              FROM osmc.coverage
              WHERE is_country IS TRUE AND isolabel_ext = c.up_iso -- cobertura nacional apenas
                AND
                CASE
                WHEN up_iso IN ('CO','CM') THEN ( ( osmc.extract_L0bits(cbits) # codebits::bit(4) ) = 0::bit(4) ) -- 1 dígitos base16h
                ELSE                            ( ( osmc.extract_L0bits(cbits) # codebits::bit(8) ) = 0::bit(8) ) -- 2 dígitos base16h
                END
            ) v

            WHERE
            CASE WHEN up_iso = 'UY' THEN c.code16h NOT IN ('0eg','10g','12g','00r','12r','0eh','05q','11q') ELSE TRUE END
          )
      )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_scientific_absolute(text,text,int)
  IS 'Decode absolute scientific OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_scientific_absolute('D1A','BR',18);

CREATE or replace FUNCTION api.osmcode_decode_scientific_absolute(
   p_code      text,
   p_base      int  DEFAULT 16,
   p_separator text DEFAULT '\+'
) RETURNS jsonb AS $wrap$
  SELECT api.osmcode_decode_scientific_absolute(REPLACE(u[2],'.',''),u[1],p_base)
  FROM regexp_split_to_array(p_code,p_separator) u
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_scientific_absolute(text,int,text)
  IS 'Decode Scientific OSMcode. Wrap for osmcode_decode_scientific_absolute.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_scientific_absolute('BR+D1A',18);

CREATE or replace FUNCTION api.osmcode_decode_postal_absolute(
   p_code       text, -- e.g.: '645' in 16h1c
   p_iso        text  -- e.g.: 'BR'
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
      'type', 'FeatureCollection',
      'features',
          (
            SELECT jsonb_agg(
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005,0.00000005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', code,
                        'area', ST_Area(v.geom),
                        'side', SQRT(ST_Area(v.geom)),
                        'base', '32nvu',
                        'jurisd_local_id', t.jurisd_local_id,
                        'jurisd_base_id', v.jurisd_id, -- ***
                        'isolabel_ext', t.isolabel_ext,
                        'short_code', CASE WHEN upper_p_iso IN ('CO') THEN upper_p_iso || '-' || t.jurisd_local_id ELSE t.isolabel_ext END || '~' || t.short_code,
                        'scientic_code', CASE
                                          WHEN upper_p_iso IN ('BR','UY') THEN osmc.encode_16h1c(natcod.vbit_to_baseh(osmc.cbits_b32nvu_to_16h(codebits,jurisd_id),16,true),jurisd_id)
                                          ELSE                                                   natcod.vbit_to_baseh(osmc.cbits_b32nvu_to_16h(codebits,jurisd_id),16,true)
                                         END
                        ))
                    )::jsonb) AS gj
            FROM
            (
              SELECT DISTINCT upper(p_iso) AS upper_p_iso, code, natcod.b32nvu_to_vbit(code) AS codebits
              FROM regexp_split_to_table(upper(p_code),',') code
            ) c
            LEFT JOIN LATERAL
            (
              SELECT osmc.extract_jurisdbits(cbits) AS jurisd_id, cbits,
                ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0(osmc.vbit_withoutL0((osmc.cbits_b32nvu_to_16h(codebits,osmc.extract_jurisdbits(cbits))),osmc.extract_jurisdbits(cbits)),osmc.extract_jurisdbits(cbits)),bbox, CASE WHEN c.upper_p_iso='EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
              FROM osmc.coverage
              WHERE is_country IS TRUE AND isolabel_ext = c.upper_p_iso AND ( ( osmc.cbits_16h_to_b32nvu(osmc.extract_L0bits(cbits),osmc.extract_jurisdbits(cbits)) # codebits::bit(5) ) = 0::bit(5) )
            ) v
             ON TRUE

            -- responsável pelo código logístico
            LEFT JOIN LATERAL ( SELECT * FROM osmc.encode_short_code(c.code,v.jurisd_id::bit(8)||osmc.cbits_b32nvu_to_16h(c.codebits,v.jurisd_id),null,ST_Centroid(v.geom)) ) t ON TRUE

            WHERE
            CASE WHEN upper_p_iso = 'UY' THEN natcod.vbit_to_baseh(osmc.cbits_b32nvu_to_16h(codebits,v.jurisd_id),16,true) NOT IN ('0eg','10g','12g','00r','12r','0eh','05q','11q') ELSE TRUE END
          )
      )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_postal_absolute(text,text)
  IS 'Decode absolute postal OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_postal_absolute('6HRJ27TB','CO');

CREATE or replace FUNCTION api.osmcode_decode_postal_absolute(
   p_code text
) RETURNS jsonb AS $wrap$
  SELECT api.osmcode_decode_postal_absolute(REPLACE(u[2],'.',''),u[1])
  FROM regexp_split_to_array(p_code,'~') u
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_postal_absolute(text)
  IS 'Decode Postal OSMcode. Wrap for osmcode_decode_postal_absolute.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_postal_absolute('CO~D6MCY0');

CREATE or replace FUNCTION api.osmcode_decode_postal(
   p_code text,
   p_iso  text
) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
      'type', 'FeatureCollection',
      'features',
          (
            SELECT jsonb_agg(
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005,0.00000005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', code,
                        'short_code', CASE WHEN country_iso IN ('CO') THEN country_iso || '-' || jurisd_local_id ELSE isolabel_ext END || '~' || short_code,
                        'area', ST_Area(v.geom),
                        'side', SQRT(ST_Area(v.geom)),
                        'base', '32nvu',
                        'jurisd_local_id', jurisd_local_id,
                        'jurisd_base_id', jurisd_base_id,
                        'isolabel_ext', isolabel_ext,
                        'isolabel_ext_abbrev', (SELECT abbrev FROM mvwjurisdiction_synonym_default_abbrev x WHERE x.isolabel_ext = c.isolabel_ext),
                        'truncated_code',truncated_code,
                        'scientic_code', CASE
                                          WHEN country_iso IN ('BR','UY') THEN osmc.encode_16h1c(natcod.vbit_to_baseh(osmc.cbits_b32nvu_to_16h(codebits,int_country_id),16,true),int_country_id)
                                          ELSE                                                   natcod.vbit_to_baseh(osmc.cbits_b32nvu_to_16h(codebits,int_country_id),16,true)
                                         END
                        ))
                    )::jsonb) AS gj
            FROM
            (
              SELECT jurisd_local_id, jurisd_base_id, int_country_id, isolabel_ext, country_iso,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO','CM') THEN substring(code,1,9)
                WHEN length(code) > 8 AND country_iso IN ('EC') THEN substring(code,1,8)
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN substring(code,1,7)
                ELSE code
              END AS code,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO','CM') THEN TRUE
                WHEN length(code) > 8 AND country_iso IN ('EC') THEN TRUE
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN TRUE
                ELSE NULL
              END AS truncated_code,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO','CM') THEN natcod.b32nvu_to_vbit(substring(code,1,9))
                WHEN length(code) > 8 AND country_iso IN ('EC') THEN natcod.b32nvu_to_vbit(substring(code,1,8))
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN natcod.b32nvu_to_vbit(substring(code,1,7))
                ELSE natcod.b32nvu_to_vbit(code)
              END AS codebits,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO','CM') THEN substring(upper(p_code),1,length(p_code)-length(code)+9)
                WHEN length(code) > 8 AND country_iso IN ('EC') THEN substring(upper(p_code),1,length(p_code)-length(code)+8)
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN substring(upper(p_code),1,length(p_code)-length(code)+7)
                ELSE upper(p_code)
              END AS short_code
              FROM
              (
                  SELECT jurisd_local_id, jurisd_base_id, int_country_id, co.isolabel_ext,
                         split_part(co.isolabel_ext,'-',1) AS country_iso,
                         natcod.vbit_to_strstd(osmc.cbits_16h_to_b32nvu(osmc.extract_cellbits(cbits),int_country_id),'32nvu') || upper(substring(p_code,2)) AS code
                  FROM osmc.coverage co
                  LEFT JOIN optim.jurisdiction ju
                  ON co.isolabel_ext = ju.isolabel_ext
                  WHERE is_country IS FALSE AND co.isolabel_ext = (str_geocodeiso_decode(p_iso))[1]
                   AND  cindex = substring(upper(p_code),1,1)
              ) u
            ) c,
            LATERAL
            (
              SELECT ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0((osmc.cbits_b32nvu_to_16h(codebits,c.int_country_id)),c.int_country_id),bbox, CASE WHEN country_iso = 'EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
              FROM osmc.coverage
              WHERE is_country IS TRUE AND osmc.extract_jurisdbits(cbits) = c.int_country_id AND ( ( osmc.cbits_16h_to_b32nvu(osmc.extract_L0bits(cbits),int_country_id) # codebits::bit(5) ) = 0::bit(5) ) -- 1 dígito  base 32nvu
            ) v

            WHERE
            CASE WHEN country_iso = 'UY' THEN c.code NOT IN ('0eg','10g','12g','00r','12r','0eh','05q','11q') ELSE TRUE END
          )
      )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_postal(text,text)
  IS 'Decode Postal OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_postal('8HB','CO-Itagui');
-- EXPLAIN ANALYZE SELECT api.osmcode_decode('9JBBHB','CO',32);

CREATE or replace FUNCTION api.osmcode_decode_postal(
   p_code text
) RETURNS jsonb AS $wrap$
  SELECT api.osmcode_decode_postal(REPLACE(u[2],'.',''),u[1])
  FROM regexp_split_to_array(p_code,'~') u
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_postal(text)
  IS 'Decode Postal OSMcode. Wrap for osmcode_decode_postal.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_postal('CO-BOY-Tunja~44QZNW');


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
