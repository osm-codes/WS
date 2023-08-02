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
-- EXPLAIN ANALYZE SELECT api.osmcode_encode('geo:-15.5,-47.8',0);

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
-- EXPLAIN ANALYZE SELECT api.osmcode_encode_scientific('geo:-15.5,-47.8;u=6','0','BR');

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
    SELECT id, jurisd_base_id, ST_Transform(ST_SetSRID(d.pt,4326),((('{"CO":9377, "BR":952019, "UY":32721, "EC":32717}'::jsonb)->(isolabel_ext))::int)) AS pt, isolabel_ext
    FROM d
  )
  SELECT api.osmcode_encode_postal(uri,grid,g.isolabel_ext)
  FROM osmc.coverage g, e
  WHERE is_country IS FALSE AND cbits::bit(10) = e.jurisd_base_id::bit(10) AND e.pt && g.geom AND (is_contained IS TRUE OR ST_intersects(e.pt,g.geom))
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.osmcode_encode(text,int)
  IS 'Encodes Geo URI (no context) to logistic OSMcode.'
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
                        'jurisd_base_id', v.jurisd_base_id,
                        'isolabel_ext', t.isolabel_ext,
                        'short_code', CASE WHEN upper_p_iso IN ('CO') THEN upper_p_iso || '-' || t.jurisd_local_id ELSE t.isolabel_ext END || '~' || t.short_code,
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
                ST_AsGeoJSONb(ST_Transform_resilient(v.geom,4326,0.005),8,0,null,
                    jsonb_strip_nulls(jsonb_build_object(
                        'code', code,
                        'short_code', CASE WHEN country_iso IN ('CO') THEN country_iso || '-' || jurisd_local_id ELSE isolabel_ext END || '~' || short_code,
                        'area', ST_Area(v.geom),
                        'side', SQRT(ST_Area(v.geom)),
                        'base', '32nvu',
                        'jurisd_local_id', jurisd_local_id,
                        'jurisd_base_id', jurisd_base_id,
                        'isolabel_ext', isolabel_ext,
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
                WHEN length(code) > 9 AND country_iso IN ('BR','CO') THEN substring(code,1,9)
                WHEN length(code) > 8 AND country_iso IN ('EC')      THEN substring(code,1,8)
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN substring(code,1,7)
                ELSE code
              END AS code,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO') THEN TRUE
                WHEN length(code) > 8 AND country_iso IN ('EC')      THEN TRUE
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN TRUE
                ELSE NULL
              END AS truncated_code,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO') THEN natcod.b32nvu_to_vbit(substring(code,1,9))
                WHEN length(code) > 8 AND country_iso IN ('EC')      THEN natcod.b32nvu_to_vbit(substring(code,1,8))
                WHEN length(code) > 7 AND country_iso IN ('UY')      THEN natcod.b32nvu_to_vbit(substring(code,1,7))
                ELSE natcod.b32nvu_to_vbit(code)
              END AS codebits,
              CASE
                WHEN length(code) > 9 AND country_iso IN ('BR','CO') THEN substring(upper(p_code),1,length(p_code)-length(code)+9)
                WHEN length(code) > 8 AND country_iso IN ('EC')      THEN substring(upper(p_code),1,length(p_code)-length(code)+8)
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
              SELECT ggeohash.draw_cell_bybox(ggeohash.decode_box2(osmc.vbit_withoutL0((osmc.vbit_from_b32nvu_to_vbit_16h(codebits,c.jurisd_base_id)),c.country_iso,16),bbox, CASE WHEN country_iso = 'EC' THEN TRUE ELSE FALSE END),false,ST_SRID(geom)) AS geom
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
      'features', (coalesce(jsonb_agg(
        ST_AsGeoJSONb((ST_Transform(geom,4326)),7,0,null,
            jsonb_build_object(
                'code',
                  CASE
                  WHEN is_country IS FALSE THEN kx_prefix
                  WHEN p_base IN (16,17) THEN                                  natcod.vbit_to_baseh( osmc.extract_L0bits(cbits,x[2]),16)
                  WHEN p_base IN (18) AND x[2] IN('BR') THEN osmc.encode_16h1c(natcod.vbit_to_baseh( osmc.extract_L0bits(cbits,x[2]),16),76)
                  WHEN p_base IN (18) AND x[2] IN('UY') THEN osmc.encode_16h1c(natcod.vbit_to_baseh( osmc.extract_L0bits(cbits,x[2]),16),858)
                  ELSE                                          natcod.vbit_to_strstd(osmc.extract_L0bits32(cbits,x[2]),'32nvu')
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
  FROM osmc.coverage, osmc.str_geocodeiso_decode(p_iso) t(x)
  WHERE isolabel_ext = x[1]

$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION api.jurisdiction_coverage(text,int)
  IS 'Returns jurisdiction coverage.'
;
-- EXPLAIN ANALYZE SELECT api.jurisdiction_coverage('BR-SP-Campinas');
