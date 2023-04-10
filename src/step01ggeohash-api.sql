CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA    IF NOT EXISTS api;

-- GGEOHASH
-- api encode:

CREATE or replace FUNCTION api.osmcode_encode_postal(
  uri    text,
  grid   int DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
    WHEN 'BR' THEN osmc.encode_postal_br(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),952019),u[4],grid,p_isolabel_ext)
    WHEN 'CO' THEN osmc.encode_postal_co(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),9377)  ,u[4],grid,p_isolabel_ext)
    WHEN 'UY' THEN osmc.encode_postal_uy(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),32721) ,u[4],grid,p_isolabel_ext)
    WHEN 'EC' THEN osmc.encode_postal_ec(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),32717) ,u[4],grid,p_isolabel_ext)
    END
  FROM (SELECT str_geouri_decode(uri) ) t(u)

$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode_postal(text,int,text)
  IS 'Encodes Geo URI to Postal OSMcode. Wrap for osmcode_encode_postal.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_postal('geo:-15.5,-47.8',0,'BR-GO-Planaltina');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:-15.5,-47.8',32,0);

CREATE or replace FUNCTION api.osmcode_encode_scientific(
  uri    text,
  grid   int DEFAULT 0,
  p_isolabel_ext text DEFAULT NULL
) RETURNS jsonb AS $wrap$
  SELECT
    CASE split_part(p_isolabel_ext,'-',1)
    WHEN 'BR' THEN osmc.encode_scientific_br(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),952019),u[4],grid)
    WHEN 'CO' THEN osmc.encode_scientific_co(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326),  9377),u[4],grid)
    WHEN 'UY' THEN osmc.encode_scientific_uy(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32721),u[4],grid)
    WHEN 'EC' THEN osmc.encode_scientific_ec(ST_Transform(ST_SetSRID(ST_MakePoint(u[2],u[1]),4326), 32717),u[4],grid)
    END
  FROM ( SELECT str_geouri_decode(uri) ) t(u)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode_scientific(text,int,text)
  IS 'Encodes Geo URI to OSMcode. Wrap for osmcode_encode_context(geometry)'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_scientific('geo:-15.5,-47.8;u=600000',18,'0','BR');

CREATE or replace FUNCTION api.osmcode_encode(
  uri    text,
  grid   int DEFAULT 0
) RETURNS jsonb AS $wrap$
  SELECT
  (
    SELECT api.osmcode_encode_scientific(uri,grid,isolabel_ext)
    FROM
    (
      SELECT isolabel_ext, geom
      FROM optim.jurisdiction_geom
      WHERE isolabel_ext IN ('BR','CO','UY','EC')

      UNION

      SELECT isolabel_ext, geom
      FROM optim.jurisdiction_eez
      WHERE isolabel_ext IN ('BR','CO','UY','EC')
    ) x
    WHERE ST_Contains(geom,ST_SetSRID(ST_MakePoint(latLon[2],latLon[1]),4326))
  )
  FROM ( SELECT str_geouri_decode(uri) ) t(latLon)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode(text,int)
  IS 'Encodes Geo URI to OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:3.461,-76.577');
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:-15.5,-47.8');


------------------
-- api decode:

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
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', code_tru,
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
                WHEN p_base =  18 AND length(code)    > 11 AND up_iso IN ('BR')           THEN substring(code,1,11)
                WHEN p_base =  18 AND length(code)    > 10 AND up_iso IN ('UY')           THEN substring(code,1,10)
                ELSE (CASE WHEN p_base=18 THEN code ELSE code16h END)
              END AS code_tru,

              -- flag
              CASE
                WHEN p_base <> 18 AND length(code16h) > 12 AND up_iso IN ('BR')           THEN TRUE
                WHEN p_base <> 18 AND length(code16h) > 11 AND up_iso IN ('EC','CO','UY') THEN TRUE
                WHEN p_base =  18 AND length(code)    > 11 AND up_iso IN ('BR')           THEN TRUE
                WHEN p_base =  18 AND length(code)    > 10 AND up_iso IN ('UY')           THEN TRUE
                ELSE NULL
              END AS truncated_code,

              -- vbit code16h
              CASE
                WHEN length(code16h) > 12 AND up_iso IN ('BR')           THEN natcod.baseh_to_vbit(substring(code16h,1,12),16)
                WHEN length(code16h) > 11 AND up_iso IN ('EC','CO','UY') THEN natcod.baseh_to_vbit(substring(code16h,1,11),16)
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
              SELECT ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0(codebits,c.up_iso,p_base),bbox, CASE WHEN c.up_iso='EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
              FROM osmc.coverage
              WHERE is_country IS TRUE AND isolabel_ext = c.up_iso -- cobertura nacional apenas
                AND
                CASE
                WHEN up_iso = 'CO' THEN ( ( osmc.extract_L0bits(cbits,'CO')   # codebits::bit(4) ) = 0::bit(4) ) -- 1 dígitos base16h
                ELSE                    ( ( osmc.extract_L0bits(cbits,up_iso) # codebits::bit(8) ) = 0::bit(8) ) -- 2 dígitos base16h
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
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', code,
                        'area', ST_Area(v.geom),
                        'side', SQRT(ST_Area(v.geom)),
                        'base', '32nvu',
                        'jurisd_local_id', t.jurisd_local_id,
                        'short_code', t.short_code,
                        'scientic_code', CASE
                                          WHEN upper_p_iso IN ('BR','UY') THEN osmc.encode_16h1c(natcod.vbit_to_baseh(osmc.vbit_from_b32nvu_to_vbit_16h(codebits,jurisd_base_id),16),jurisd_base_id)
                                          ELSE                                                   natcod.vbit_to_baseh(osmc.vbit_from_b32nvu_to_vbit_16h(codebits,jurisd_base_id),16)
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
              SELECT (cbits::bit(10))::int AS jurisd_base_id, cbits,
                ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0(codebits,c.upper_p_iso,32),bbox, CASE WHEN c.upper_p_iso='EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
              FROM osmc.coverage
              WHERE is_country IS TRUE AND isolabel_ext = c.upper_p_iso AND ( ( osmc.extract_L0bits32(cbits,c.upper_p_iso) # codebits::bit(5) ) = 0::bit(5) )
            ) v
             ON TRUE

            -- responsável pelo código logístico
            LEFT JOIN LATERAL ( SELECT * FROM osmc.encode_short_code(c.code,v.cbits::bit(10)||c.codebits,null,ST_Centroid(v.geom)) ) t ON TRUE

            WHERE
            CASE WHEN upper_p_iso = 'UY' THEN natcod.vbit_to_baseh(osmc.vbit_from_b32nvu_to_vbit_16h(codebits,v.jurisd_base_id),16) NOT IN ('0eg','10g','12g','00r','12r','0eh','05q','11q') ELSE TRUE END
          )
      )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_decode_postal_absolute(text,text)
  IS 'Decode absolute postal OSMcode.'
;
-- EXPLAIN ANALYZE SELECT api.osmcode_decode_postal_absolute('D6MCY0','CO');

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
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', code,
                        'short_code', short_code,
                        'area', ST_Area(v.geom),
                        'side', SQRT(ST_Area(v.geom)),
                        'base', '32nvu',
                        'jurisd_local_id', jurisd_local_id,
                        'truncated_code',truncated_code,
                        'scientic_code', CASE
                                          WHEN country_iso IN ('BR','UY') THEN osmc.encode_16h1c(natcod.vbit_to_baseh(osmc.vbit_from_b32nvu_to_vbit_16h(codebits,jurisd_base_id),16),jurisd_base_id)
                                          ELSE                                                   natcod.vbit_to_baseh(osmc.vbit_from_b32nvu_to_vbit_16h(codebits,jurisd_base_id),16)
                                         END
                        ))
                    )::jsonb) AS gj
            FROM
            (
              SELECT jurisd_local_id, jurisd_base_id, isolabel_ext, country_iso,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR')      THEN substring(code,1,9)
                WHEN length(code) > 8 AND country_iso IN ('EC','CO') THEN substring(code,1,8)
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN substring(code,1,7)
                ELSE code
              END AS code,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR')      THEN TRUE
                WHEN length(code) > 8 AND country_iso IN ('EC','CO') THEN TRUE
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN TRUE
                ELSE NULL
              END AS truncated_code,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR')      THEN natcod.b32nvu_to_vbit(substring(code,1,9))
                WHEN length(code) > 8 AND country_iso IN ('EC','CO') THEN natcod.b32nvu_to_vbit(substring(code,1,8))
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN natcod.b32nvu_to_vbit(substring(code,1,7))
                ELSE natcod.b32nvu_to_vbit(code)
              END AS codebits,
              isolabel_ext || '~' ||
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR')      THEN substring(upper(p_code),1,length(p_code)-length(code)+9)
                WHEN length(code) > 8 AND country_iso IN ('EC','CO') THEN substring(upper(p_code),1,length(p_code)-length(code)+8)
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN substring(upper(p_code),1,length(p_code)-length(code)+7)
                ELSE upper(p_code)
              END AS short_code
              FROM
              (
                  SELECT jurisd_local_id, jurisd_base_id, co.isolabel_ext,
                         split_part(co.isolabel_ext,'-',1) AS country_iso,
                         natcod.vbit_to_strstd(osmc.vbit_from_16h_to_vbit_b32nvu(osmc.extract_cellbits(cbits),jurisd_base_id),'32nvu') || upper(substring(p_code,2)) AS code
                  FROM osmc.coverage co
                  LEFT JOIN optim.jurisdiction ju
                  ON co.isolabel_ext = ju.isolabel_ext
                  WHERE is_country IS FALSE AND co.isolabel_ext = (osmc.str_geocodeiso_decode(p_iso))[1]
                   AND  cindex = substring(upper(p_code),1,1)
              ) u
            ) c,
            LATERAL
            (
              SELECT ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0(codebits,c.country_iso,32),bbox, CASE WHEN country_iso = 'EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
              FROM osmc.coverage
              WHERE is_country IS TRUE AND cbits::bit(10) = c.jurisd_base_id::bit(10) AND ( ( osmc.extract_L0bits32(cbits,isolabel_ext) # codebits::bit(5) ) = 0::bit(5) ) -- 1 dígito  base 32nvu
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
    'features',
      (
        SELECT coalesce(jsonb_agg(
          ST_AsGeoJSONb(ST_Transform_resilient(geom,4326,0.005),8,0,null,
              jsonb_strip_nulls(jsonb_build_object(
                  'code',
                      CASE
                        WHEN p_base = 18 THEN osmc.encode_16h1c(code,(('{"CO":170, "BR":76, "UY":858, "EC":218}'::jsonb)->( (osmc.str_geocodeiso_decode(p_iso))[2]  ))::int)
                        ELSE code
                      END
                  ,
                  'area', s.area,
                  'side', SQRT(s.area),
                  'base', osmc.string_base(p_base),
                  'index', index
                  ))
              )::jsonb),'[]'::jsonb)
        FROM
        (
          SELECT geom, bbox,
            CASE
            WHEN (osmc.str_geocodeiso_decode(p_iso))[1] LIKE '%-%-%'
            THEN kx_prefix
            ELSE
              (
                CASE
                WHEN p_base IN (16,17,18) THEN natcod.vbit_to_baseh( osmc.extract_L0bits(cbits,(osmc.str_geocodeiso_decode(p_iso))[2]),16)
                ELSE                           natcod.vbit_to_strstd(osmc.extract_L0bits32(cbits,(osmc.str_geocodeiso_decode(p_iso))[2]),'32nvu')
                END
              )
            END AS code,

            CASE
            WHEN (osmc.str_geocodeiso_decode(p_iso))[1] LIKE '%-%-%'
            THEN cindex
            ELSE null
            END AS index

            FROM osmc.coverage
            WHERE isolabel_ext = (osmc.str_geocodeiso_decode(p_iso))[1]
        ) t
        -- area geom
        LEFT JOIN LATERAL
        (
          SELECT ST_Area(ggeohash.draw_cell_bybox(t.bbox,false,ST_SRID(t.geom))) AS area,
                 (osmc.str_geocodeiso_decode(p_iso)) AS isodecoded
        ) s
        ON TRUE
      )
    )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_coverage(text,int)
  IS 'Return l0cover.'
;
-- EXPLAIN ANALYZE SELECT api.jurisdiction_coverage('BR-SP-SaoCaetanoSul');