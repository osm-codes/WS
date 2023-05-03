--
-- Library for extended Geo URI protocol
--

-- Pendente testar as geometrias !  


DROP SCHEMA IF EXISTS geouri_ext CASCADE; -- se the
CREATE SCHEMA geouri_ext;

-- ABBREVIATIONS:
--  OLC = Open Location Code (used by Google PlusCodes)
--  GHS = Geohash, the classic
--  S2 = S2 Geometry (original)
--  S2H = S2 Geometry (adaptaed to be hierarchical)
--  {country}_PC = postal code of the country, e.g. BR_PC

--------------------
--------------------
-- OLC (Open Location Code) FUNCTIONS
-- By https://github.com/google/open-location-code/blob/main/plpgsql/pluscode_functions.sql
-- functions changed by rationale:
-- * add schema to isolate GeoURI_extended from other functions.
-- * remove "cost 100" as https://stackoverflow.com/a/23953107/287948
-- * reformat as OSMcodes strandard PG format.
-- * remover "OR REPLACE" because has a DROP before.

--
-- Open Location Code implementation for PostgreSQL
--
-- Licensed under the Apache License, Version 2.0 (the 'License');
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an 'AS IS' BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--


CREATE FUNCTION geouri_ext.olc_cliplatitude(lat float)
RETURNS float AS $f$
  SELECT CASE
    WHEN lat < -90 THEN -90
    WHEN lat > 90  THEN 90
    ELSE lat
  END;
$f$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_cliplatitude(float)
  IS 'Clip latitude between -90 and 90 degrees.'
;
-- select geouri_ext.olc_cliplatitude(149.18);


CREATE FUNCTION geouri_ext.olc_computeLatitudePrecision(
    codeLength int -- How long must be the OLC code
) RETURNS float AS $f$
DECLARE
    CODE_ALPHABET_ text := '23456789CFGHJMPQRVWX';
    ENCODING_BASE_ int := char_length(CODE_ALPHABET_);
    PAIR_CODE_LENGTH_ int := 10;
    GRID_ROWS_ int := 5;
BEGIN
    IF (codeLength <= PAIR_CODE_LENGTH_) THEN
        RETURN power(ENCODING_BASE_, floor((codeLength / (-2)) + 2));
    ELSE
        RETURN power(ENCODING_BASE_, -3) / power(GRID_ROWS_, codeLength - PAIR_CODE_LENGTH_);
    END IF;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_computeLatitudePrecision(int)
  IS 'Compute the latitude precision value for a given code length.'
;
-- select geouri_ext.olc_computeLatitudePrecision(11);


CREATE FUNCTION geouri_ext.olc_normalizelongitude(
    lng float  -- longitude to use for the reference location
) RETURNS float AS $f$
BEGIN
    WHILE (lng < -180) LOOP
      lng := lng + 360;
    END LOOP;
    WHILE (lng >= 180) LOOP
      lng := lng - 360;
    END LOOP;
    return lng;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_normalizelongitude(float)
  IS 'Normalize a longitude between -180 and 180 degrees (180 excluded).'
;
-- select geouri_ext.olc_normalizelongitude(188.18);

--


CREATE FUNCTION geouri_ext.olc_isvalid(
    code text -- a OLC code
) RETURNS boolean AS $f$
DECLARE
separator_ text := '+';
separator_position int := 8;
padding_char text:= '0';
padding_int_pos integer:=0;
padding_one_int_pos integer:=0;
stripped_code text := replace(replace(code,'0',''),'+','');
code_alphabet_ text := '23456789CFGHJMPQRVWX';
idx int := 1;
BEGIN
code := code::text;
--Code Without "+" char
IF (POSITION(separator_ in code) = 0) THEN
    RETURN FALSE;
END IF;
--Code beginning with "+" char
IF (POSITION(separator_ in code) = 1) THEN
    RETURN FALSE;
END IF;
--Code with illegal position separator
IF ( (POSITION(separator_ in code) > separator_position+1) OR ((POSITION(separator_ in code)-1) % 2 = 1)  ) THEN
      RETURN FALSE;
END IF;
--Code contains padding characters "0"
IF (POSITION(padding_char in code) > 0) THEN
    IF (POSITION(separator_ in code) < 9) THEN
        RETURN FALSE;
    END IF;
    IF (POSITION(separator_ in code) = 1) THEN
        RETURN FALSE;
    END IF;
    --Check if there are many "00" groups (only one is legal)
    padding_int_pos := (select ROW_NUMBER() OVER( ORDER BY REGEXP_MATCHES(code,'('||padding_char||'+)' ,'g') ) order by 1 DESC limit 1);
    padding_one_int_pos := char_length( (select REGEXP_MATCHES(code,'('||padding_char||'+)' ,'g')  limit 1)[1] );
    IF (padding_int_pos > 1 ) THEN
        RETURN FALSE;
    END IF;
    --Check if the first group is % 2 = 0
    IF ((padding_one_int_pos % 2) = 1 ) THEN
        RETURN FALSE;
    END IF;
    --Lastchar is a separator
    IF (RIGHT(code,1) <> separator_) THEN
        RETURN FALSE;
    END IF;
END IF;
--If there is just one char after '+'
IF (char_length(code) - POSITION(separator_ in code) = 1 ) THEN
    RETURN FALSE;
END IF;
--Check if each char is in code_alphabet_
FOR i IN 1..char_length(stripped_code) LOOP
    IF (POSITION( UPPER(substring(stripped_code from i for 1)) in code_alphabet_ ) = 0) THEN
        RETURN FALSE;
    END IF;
END LOOP;
RETURN TRUE;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_isvalid(text)
  IS 'Check if the code is valid.'
;
-- select geouri_ext.olc_isvalid('XX5JJC23+00');


CREATE FUNCTION geouri_ext.olc_codearea(
    latitudelo float,   -- lattitude low of the OLC code
    longitudelo float,  -- longitude low of the OLC code
    latitudehi float,   -- lattitude high of the OLC code
    longitudehi float,  -- longitude high of the OLC code
    codelength integer    -- length of the OLC code
) RETURNS float[] -- lat_lo, lng_lo, lat_hi, lng_hi, code_length, lat_center, lng_center
AS $f$
DECLARE
    rlatitudeLo float:= latitudeLo;
    rlongitudeLo float:= longitudeLo;
    rlatitudeHi float:= latitudeHi;
    rlongitudeHi float:= longitudeHi;
    rcodeLength float:= codeLength;
    rlatitudeCenter float:= 0;
    rlongitudeCenter float:= 0;
    latitude_max_ int:= 90;
    longitude_max_ int:= 180;
BEGIN
    --calculate the latitude center
    IF (((latitudeLo + (latitudeHi - latitudeLo))/ 2) > latitude_max_) THEN
        rlatitudeCenter := latitude_max_;
    ELSE
        rlatitudeCenter := (latitudeLo + (latitudeHi - latitudeLo)/ 2);
    END IF;
    --calculate the longitude center
    IF (((longitudeLo + (longitudeHi - longitudeLo))/ 2) > longitude_max_) THEN
        rlongitudeCenter := longitude_max_;
    ELSE
        rlongitudeCenter := (longitudeLo + (longitudeHi - longitudeLo)/ 2);
    END IF;
    RETURN array[
        rlatitudeLo,  -- lat_lo
        rlongitudeLo, -- lng_lo
        rlatitudeHi,  -- lat_hi
        rlongitudeHi, -- lng_hi
        rcodeLength,  -- code_length
        rlatitudeCenter,
        rlongitudeCenter
    ];
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION geouri_ext.olc_codearea
  IS 'Coordinates of a decoded OLC code. Returns [lat_lo, lng_lo, lat_hi, lng_hi, code_length, rlatCenter, rlongCenter].'
;
-- select geouri_ext.olc_codearea(49.1805,-0.378625,49.180625,-0.3785,10::int);


CREATE FUNCTION geouri_ext.olc_isshort(
    code text -- a valid OLC code
) RETURNS boolean AS $f$
DECLARE
separator_ text := '+';
separator_position int := 9;
BEGIN
    -- the OLC code is valid ?
    IF (geouri_ext.olc_isvalid(code)) is FALSE THEN
        RETURN FALSE;
    END IF;
    -- the OLC code contain a '+' at a correct place
    IF ((POSITION(separator_ in code)>0) AND (POSITION(separator_ in code)< separator_position)) THEN
        RETURN TRUE;
    END IF;
RETURN FALSE;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_isshort(text)
  IS 'Check if the code is a short version of a OLC code.'
;
-- select geouri_ext.olc_isshort('XX5JJC+');


CREATE FUNCTION geouri_ext.olc_isfull(
    code text  -- OLC code
) RETURNS boolean AS $f$
DECLARE
code_alphabet text := '23456789CFGHJMPQRVWX';
first_lat_val int:= 0;
first_lng_val int:= 0;
encoding_base_ int := char_length(code_alphabet);
latitude_max_ int := 90;
longitude_max_ int := 180;
BEGIN
    IF (geouri_ext.olc_isvalid(code)) is FALSE THEN
        RETURN FALSE;
    END IF;
    -- If is short --> not full.
    IF (geouri_ext.olc_isshort(code)) is TRUE THEN
        RETURN FALSE;
    END IF;
    --Check latitude for first lat char
    first_lat_val := (POSITION( UPPER(LEFT(code,1)) IN  code_alphabet  )-1) * encoding_base_;
    IF (first_lat_val >= latitude_max_ * 2) THEN
        RETURN FALSE;
    END IF;
    IF (char_length(code) > 1) THEN
        --Check longitude for first lng char
        first_lng_val := (POSITION( UPPER(SUBSTRING(code FROM 2 FOR 1)) IN  code_alphabet)-1) * encoding_base_;
        IF (first_lng_val >= longitude_max_ *2) THEN
            RETURN FALSE;
        END IF;
    END IF;
    RETURN TRUE;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_isfull(text)
  IS 'Is the codeplus a full code.'
;
-- select geouri_ext.olc_isfull('cccccc+')


CREATE FUNCTION geouri_ext.olc_encode(
    latitude float,          -- latitude ref
    longitude float,         -- longitude ref
    codeLength int DEFAULT 10  -- How long must be the OLC code
) RETURNS text AS $f$
DECLARE
    SEPARATOR_ text := '+';
    SEPARATOR_POSITION_ int := 8;
    PADDING_CHARACTER_ text := '0';
    CODE_ALPHABET_ text := '23456789CFGHJMPQRVWX';
    ENCODING_BASE_ int := char_length(CODE_ALPHABET_);
    LATITUDE_MAX_ int := 90;
    LONGITUDE_MAX_ int := 180;
    MAX_DIGIT_COUNT_ int := 15;
    PAIR_CODE_LENGTH_ int := 10;
    PAIR_PRECISION_ decimal := power(ENCODING_BASE_, 3);
    GRID_CODE_LENGTH_ int := MAX_DIGIT_COUNT_ - PAIR_CODE_LENGTH_;
    GRID_COLUMNS_ int := 4;
    GRID_ROWS_ int := 5;
    FINAL_LAT_PRECISION_ decimal := PAIR_PRECISION_ * power(GRID_ROWS_, MAX_DIGIT_COUNT_ - PAIR_CODE_LENGTH_);
    FINAL_LNG_PRECISION_ decimal := PAIR_PRECISION_ * power(GRID_COLUMNS_, MAX_DIGIT_COUNT_ - PAIR_CODE_LENGTH_);
    code text := '';
    latVal decimal := 0;
    lngVal decimal := 0;
    latDigit smallint;
    lngDigit smallint;
    ndx smallint;
    i_ smallint;
BEGIN
    IF ((codeLength < 2) OR ((codeLength < PAIR_CODE_LENGTH_) AND (codeLength % 2 = 1))) THEN
        RAISE EXCEPTION 'Invalid Open Location Code length - %', codeLength
        USING HINT = 'The Open Location Code length must be 2, 4, 6, 8, 10, 11, 12, 13, 14, or 15.';
    END IF;

    codeLength := LEAST(codeLength, MAX_DIGIT_COUNT_);

    latitude := geouri_ext.olc_cliplatitude(latitude);
    longitude := geouri_ext.olc_normalizelongitude(longitude);

    IF (latitude = 90) THEN
        latitude := latitude - geouri_ext.olc_computeLatitudePrecision(codeLength);
    END IF;

    latVal := floor(round((latitude + LATITUDE_MAX_) * FINAL_LAT_PRECISION_, 6));
    lngVal := floor(round((longitude + LONGITUDE_MAX_) * FINAL_LNG_PRECISION_, 6));

    IF (codeLength > PAIR_CODE_LENGTH_) THEN
        i_ := 0;
        WHILE (i_ < (MAX_DIGIT_COUNT_ - PAIR_CODE_LENGTH_)) LOOP
            latDigit := latVal % GRID_ROWS_;
            lngDigit := lngVal % GRID_COLUMNS_;
            ndx := (latDigit * GRID_COLUMNS_) + lngDigit;
            code := substr(CODE_ALPHABET_, ndx + 1, 1) || code;
            latVal := div(latVal, GRID_ROWS_);
            lngVal := div(lngVal, GRID_COLUMNS_);
            i_ := i_ + 1;
        END LOOP;
    ELSE
        latVal := div(latVal, power(GRID_ROWS_, GRID_CODE_LENGTH_)::integer);
        lngVal := div(lngVal, power(GRID_COLUMNS_, GRID_CODE_LENGTH_)::integer);
    END IF;

    i_ := 0;
    WHILE (i_ < (PAIR_CODE_LENGTH_ / 2)) LOOP
        code := substr(CODE_ALPHABET_, (lngVal % ENCODING_BASE_)::integer + 1, 1) || code;
        code := substr(CODE_ALPHABET_, (latVal % ENCODING_BASE_)::integer + 1, 1) || code;
        latVal := div(latVal, ENCODING_BASE_);
        lngVal := div(lngVal, ENCODING_BASE_);
        i_ := i_ + 1;
    END LOOP;

    code := substr(code, 1, SEPARATOR_POSITION_) || SEPARATOR_ || substr(code, SEPARATOR_POSITION_ + 1);

    IF (codeLength >= SEPARATOR_POSITION_) THEN
        RETURN substr(code, 1, codeLength + 1);
    ELSE
        RETURN rpad(substr(code, 1, codeLength), SEPARATOR_POSITION_, PADDING_CHARACTER_) || SEPARATOR_;
    END IF;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_encode(float,float,int)
  IS 'Encode lat lng to get OLC code.'
;
-- select geouri_ext.olc_encode(49.05,-0.108,12);


CREATE FUNCTION geouri_ext.olc_decode(
    code text  -- the OLC code to decode
) RETURNS float[] AS $f$
DECLARE
lat_out float := 0;
lng_out float := 0;
latitude_max_ int := 90;
longitude_max_ int := 180;
lat_precision float := 0;
lng_precision float := 0;
code_alphabet text := '23456789CFGHJMPQRVWX';
stripped_code text := UPPER(replace(replace(code,'0',''),'+',''));
encoding_base_ int := char_length(code_alphabet);
pair_precision_ float := power(encoding_base_::float, 3::float);
normal_lat float:= -latitude_max_ * pair_precision_;
normal_lng float:= -longitude_max_ * pair_precision_;
grid_lat_ float:= 0;
grid_lng_ float:= 0;
max_digit_count_ int:= 15;
pair_code_length_ int:=10;
digits int:= 0;
pair_first_place_value_ float:= power(encoding_base_, (pair_code_length_/2)-1);
pv int:= 0;
iterator int:=0;
iterator_d int:=0;
digit_val int := 0;
row_ float := 0;
col_ float := 0;
return_record record;
grid_code_length_ int:= max_digit_count_ - pair_code_length_;
grid_columns_ int := 4;
grid_rows_  int := 5;
grid_lat_first_place_value_ int := power(grid_rows_, (grid_code_length_ - 1));
grid_lng_first_place_value_ int := power(grid_columns_, (grid_code_length_ - 1));
final_lat_precision_ float := pair_precision_ * power(grid_rows_, (max_digit_count_ - pair_code_length_));
final_lng_precision_ float := pair_precision_ * power(grid_columns_, (max_digit_count_ - pair_code_length_));
rowpv float := grid_lat_first_place_value_;
colpv float := grid_lng_first_place_value_;

BEGIN
    IF (geouri_ext.olc_isfull(code)) is FALSE THEN
        RAISE EXCEPTION 'NOT A VALID FULL CODE: %', code;
    END IF;
    --strip 0 and + chars
    code:= stripped_code;
    normal_lat := -latitude_max_ * pair_precision_;
    normal_lng := -longitude_max_ * pair_precision_;

    --how many digits must be used
    IF (char_length(code) > pair_code_length_) THEN
        digits := pair_code_length_;
    ELSE
        digits := char_length(code);
    END IF;
    pv := pair_first_place_value_;
    WHILE iterator < digits
        LOOP
            normal_lat := normal_lat + (POSITION( SUBSTRING(code FROM iterator+1 FOR 1) IN code_alphabet)-1 )* pv;
            normal_lng := normal_lng + (POSITION( SUBSTRING(code FROM iterator+1+1 FOR 1) IN code_alphabet)-1  ) * pv;
            IF (iterator < (digits -2)) THEN
                pv := pv/encoding_base_;
            END IF;
            iterator := iterator + 2;

        END LOOP;

    --convert values to degrees
    lat_precision := pv/ pair_precision_;
    lng_precision := pv/ pair_precision_;

    IF (char_length(code) > pair_code_length_) THEN
        IF (char_length(code) > max_digit_count_) THEN
            digits := max_digit_count_;
        ELSE
            digits := char_length(code);
        END IF;
        iterator_d := pair_code_length_;
        WHILE iterator_d < digits
        LOOP
            digit_val := (POSITION( SUBSTRING(code FROM iterator_d+1 FOR 1) IN code_alphabet)-1);
            row_ := ceil(digit_val/grid_columns_);
            col_ := digit_val % grid_columns_;
            grid_lat_ := grid_lat_ +(row_*rowpv);
            grid_lng_ := grid_lng_ +(col_*colpv);
            IF ( iterator_d < (digits -1) ) THEN
                rowpv := rowpv / grid_rows_;
                colpv := colpv / grid_columns_;
            END IF;
            iterator_d := iterator_d + 1;
        END LOOP;
        --adjust precision
        lat_precision := rowpv / final_lat_precision_;
        lng_precision := colpv / final_lng_precision_;
    END IF;

    --merge the normal and extra precision of the code
    lat_out := normal_lat / pair_precision_ + grid_lat_ / final_lat_precision_;
    lng_out := normal_lng / pair_precision_ + grid_lng_ / final_lng_precision_;

    IF (char_length(code) > max_digit_count_ ) THEN
        digits := max_digit_count_;
        RAISE NOTICE 'lat_out max_digit_count_ %', lat_out;
    ELSE
        digits := char_length(code);
        RAISE NOTICE 'digits char_length%', digits;
    END IF ;

    RETURN geouri_ext.olc_codearea(
            lat_out,
            lng_out,
            (lat_out+lat_precision),
            (lng_out+lng_precision),
            digits::int
    );
END;
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION geouri_ext.olc_decode(text)
  IS 'Decode a OLC code to get the corresponding bounding box and the center. Returns [1=lat_lo, 2=lng_lo, 3=lat_hi, 4=lng_hi, 5=code_length, 6=rlatCenter, 7=rlongCenter].'
;
-- select geouri_ext.olc_decode('CCCCCCCC+');


CREATE FUNCTION geouri_ext.olc_shorten(
    code text,       --full code
    latitude float,  --latitude to use for the reference location
    longitude float  --longitude to use for the reference location
) RETURNS text AS $f$
DECLARE
padding_character text :='0';
code_area float[];
min_trimmable_code_len int:= 6;
range_ float:= 0;
lat_dif float:= 0;
lng_dif float:= 0;
pair_resolutions_ FLOAT[] := ARRAY[20.0, 1.0, 0.05, 0.0025, 0.000125]::FLOAT[];
iterator int:= 0;
BEGIN
    IF (geouri_ext.olc_isfull(code)) is FALSE THEN
        RAISE EXCEPTION 'Code is not full and valid: %', code;
    END IF;

    IF (POSITION(padding_character IN code) > 0) THEN
      RAISE EXCEPTION 'Code contains 0 character(s), not valid : %', code;
    END IF;

    code := UPPER(code);
    code_area := geouri_ext.olc_decode(code);
    -- Returns [1=lat_lo, 2=lng_lo, 3=lat_hi, 4=lng_hi, 5=code_length, 6=rlatCenter, 7=rlongCenter]

    IF (code_area[5] < min_trimmable_code_len ) THEN
        RAISE EXCEPTION 'Code must contain more than 6 character(s) : %',code;
    END IF;

    --Are the latitude and longitude valid
    IF (pg_typeof(latitude) NOT IN ('float','real','double precision','integer','bigint','float')) OR (pg_typeof(longitude) NOT IN ('float','real','double precision','integer','bigint','float')) THEN
        RAISE EXCEPTION 'LAT || LNG are not numbers % !',pg_typeof(latitude)||' || '||pg_typeof(longitude);
    END IF;

    latitude := geouri_ext.olc_cliplatitude(latitude);
    longitude := geouri_ext.olc_normalizelongitude(longitude);

    lat_dif := ABS(code_area[6] - latitude);
    lng_dif := ABS(code_area[7] - longitude);

    --calculate max distance with the center
    IF (lat_dif > lng_dif) THEN
        range_ := lat_dif;
    ELSE
        range_ := lng_dif;
    END IF;

    iterator := ARRAY_LENGTH( pair_resolutions_, 1)-2;

    WHILE ( iterator >= 1 )
    LOOP
        --is it close enough to shortent the code ?
        --use 0.3 for safety instead of 0.5
        IF ( range_ < (pair_resolutions_[ iterator ]*0.3) ) THEN
            RETURN SUBSTRING( code , ((iterator+1)*2)-1 );
        END IF;
        iterator := iterator - 1;
    END LOOP;
RETURN code;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_shorten(text,float,float)
  IS 'Remove characters from the start of an OLC code.'
;
-- select geouri_ext.olc_shorten('8CXX5JJC+6H6H6H',49.18,-0.37);


CREATE FUNCTION geouri_ext.olc_recovernearest(
    short_code text,             -- a valid shortcode
    reference_latitude float,  -- a valid latitude
    reference_longitude float  -- a valid longitude
) RETURNS text AS $f$
DECLARE
padding_length int :=0;
separator_position_ int := 8;
separator_ text := '+';
resolution int := 0;
half_resolution float := 0;
code_area float[];
latitude_max int := 90;
code_out text := '';
BEGIN

    IF (geouri_ext.olc_isshort(short_code)) is FALSE THEN
        IF (geouri_ext.olc_isfull(short_code)) THEN
            RETURN UPPER(short_code);
        ELSE
            RAISE EXCEPTION 'Short code is not valid: %', short_code;
        END IF;
        RAISE EXCEPTION 'NOT A VALID FULL CODE: %', code;
    END IF;

    -- Only make sense for Javascript:
    --Are the latitude and longitude valid.
    --IF (pg_typeof(reference_latitude) NOT IN ('float','real','double precision','integer','bigint','float')) OR (pg_typeof(reference_longitude) NOT IN ('float','real','double precision','integer','bigint','float')) THEN
    --    RAISE EXCEPTION 'LAT || LNG are not numbers % !',pg_typeof(latitude)||' || '||pg_typeof(longitude);
    --END IF;

    reference_latitude := geouri_ext.olc_cliplatitude(reference_latitude);
    reference_longitude := geouri_ext.olc_normalizelongitude(reference_longitude);

    short_code := UPPER(short_code);
    -- Calculate the number of digits to recover.
    padding_length := separator_position_ - POSITION(separator_ in short_code)+1;
    -- Calculate the resolution of the padded area in degrees.
    resolution := power(20, 2 - (padding_length / 2));
    -- Half resolution for difference with the center
    half_resolution := resolution / 2.0;

    -- Concatenate short_code and the calculated value --> encode(lat,lng)
    code_area := geouri_ext.olc_decode(SUBSTRING(geouri_ext.olc_encode(reference_latitude, reference_longitude) , 1 , padding_length) || short_code);
    -- Returns [1=lat_lo, 2=lng_lo, 3=lat_hi, 4=lng_hi, 5=code_length, 6=rlatCenter, 7=rlongCenter]

    --Check if difference with the center is more than half_resolution
    --Keep value between -90 and 90
    IF (((reference_latitude + half_resolution) < code_area[6]) AND ((code_area[6] - resolution) >= -latitude_max)) THEN
        code_area[6] := code_area[6] - resolution;
    ELSIF (((reference_latitude - half_resolution) > code_area[6]) AND ((code_area[6] + resolution) <= latitude_max)) THEN
      code_area[6] := code_area[6] + resolution;
    END IF;

    -- difference with the longitude reference
    IF (reference_longitude + half_resolution < code_area[7] ) THEN
      code_area[7] := code_area[7] - resolution;
    ELSIF (reference_longitude - half_resolution > code_area[7]) THEN
      code_area[7] := code_area[7] + resolution;
    END IF;

    code_out := geouri_ext.olc_encode(code_area[6], code_area[7], code_area[5]::integer);

RETURN code_out;
END;
$f$ LANGUAGE 'plpgsql' IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_recovernearest(text,float,float)
  IS 'Retrieve a valid full code (the nearest from lat/lng).'
;
-- select geouri_ext.olc_recovernearest('XX5JJC+', 49.1805,-0.3786);


-- see: https://github.com/google/open-location-code/blob/main/docs/specification.md#code-precision
CREATE or replace FUNCTION geouri_ext.uncertain_olc(u float) RETURNS int AS $f$
  -- GeoURI's uncertainty value "is the radius of the disk that represents uncertainty geometrically."
  SELECT CASE -- discretization by "snap to code length."
    WHEN s < 0.02 THEN 15
    WHEN s < 0.09 THEN 14
    WHEN s < 0.43 THEN 13
    WHEN s < 1.91 THEN 12
    WHEN s < 8.52 THEN 11
    WHEN s < 145 THEN 10
    WHEN s < 2922 THEN 8
    WHEN s < 58443 THEN 6
    WHEN s < 1168660 THEN 4
    ELSE 2
    END
  FROM (SELECT CASE WHEN u > 9 THEN (ROUND(u,0))*2 ELSE (ROUND(u,1))*2 END) t(s)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geouri_ext.uncertain_olc(float)
  IS 'Converts uncertainty to OLC code size.'
;

-- see: https://www.movable-type.co.uk/scripts/geohash.html
CREATE or replace FUNCTION geouri_ext.uncertain_ghs(u float) RETURNS int AS $f$
  -- GeoURI's uncertainty value "is the radius of the disk that represents uncertainty geometrically."
  SELECT CASE -- discretization by "snap to code length."
    WHEN s < 0.09 THEN 12
    WHEN s < 0.5 THEN 11
    WHEN s < 2.81 THEN 10
    WHEN s < 15 THEN 9
    WHEN s < 90 THEN 8
    WHEN s < 4389 THEN 7
    WHEN s < 28763 THEN 6
    WHEN s < 68109 THEN 5
    WHEN s < 121659 THEN 4
    WHEN s < 519941 THEN 3
    WHEN s < 2941941 THEN 2
    ELSE 1
    END
  FROM (SELECT CASE WHEN u > 9 THEN (ROUND(u,0))*2 ELSE (ROUND(u,1))*2 END) t(s)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION geouri_ext.uncertain_ghs(float)
  IS 'Converts uncertainty to GHS code size.'
;

--------------------
--------------------
-- GEOHASH FUNCTIONS
-- By PostGIS or GGeohash.


-- GEOMETRY

CREATE EXTENSION IF NOT EXISTS postgis;

-- ST_GeoHash(geometry geom, integer maxchars=full_precision_of_point);
-- Return a GeoHash representation (http://en.wikipedia.org/wiki/Geohash) of the geometry

CREATE FUNCTION geouri_ext.ghs_geom(  -- byGeom
  geom geometry, digits integer DEFAULT 9
) RETURNS geometry AS $wrap$
  SELECT ST_GeomFromGeoHash(ST_GeoHash($1,$2),$2)
$wrap$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.ghs_geom(geometry,integer)
  IS 'Wrap for ST_GeomFromGeoHash(ST_GeoHash()). Return a geometry from a GeoHash of a point or geometry (in SRID 4326).'
;

CREATE FUNCTION geouri_ext.ghs_geom( -- byLatLon
  lat float, lon float,
  digits integer DEFAULT 9
) RETURNS geometry AS $wrap$
  SELECT geouri_ext.ghs_geom( ST_SetSRID(ST_Point($2,$1),4326), $3 )
$wrap$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.ghs_geom(float,float,integer)
  IS 'Wrap for ghs_geom(). Converts latLon into a point.'
;

CREATE FUNCTION geouri_ext.ghs_geom( -- byCode
  code text,
  digits integer DEFAULT NULL -- truncate when not null
) RETURNS geometry AS $wrap$
  SELECT ST_GeomFromGeoHash( $1, CASE WHEN $2 IS NULL THEN length($1) ELSE $2 END)
$wrap$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.ghs_geom(text,integer)
  IS 'Wrap for ST_GeomFromGeoHash(). Use digits to truncate the code.'
;

--------------------

CREATE FUNCTION geouri_ext.olc_geom( -- byLatLon
  code text
) RETURNS geometry AS $f$
  SELECT ST_MakeEnvelope(a[2], a[1], a[4], a[3], 4326)
                    --  xmin, ymin, xmax, ymax  (x=lon, y=lat)
  FROM ( SELECT geouri_ext.olc_decode($1) ) t(a)
  -- Returns [1=lat_lo, 2=lng_lo, 3=lat_hi, 4=lng_hi, 5=code_length, 6=rlatCenter, 7=rlongCenter].'
$f$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_geom(text)
  IS 'Returns OLC_center as complete cell geometry.'
;

CREATE FUNCTION geouri_ext.olc_geom( -- byLatLon
  lat float, lon float,
  maxchars integer DEFAULT 9
) RETURNS geometry AS $wrap$
  SELECT geouri_ext.olc_geom( geouri_ext.olc_encode($1,$2,$3) )
$wrap$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_geom(float,float,integer)
  IS 'Returns OLC_center as complete cell geometry. Wrap for olc_geom(olc_encode()).'
;

CREATE FUNCTION geouri_ext.olc_geom( -- byLatLon
  geom geometry,
  maxchars integer DEFAULT 9
) RETURNS geometry AS $wrap$
  SELECT geouri_ext.olc_geom( ST_Y(g), ST_X(g), $2 )
  FROM (SELECT CASE WHEN GeometryType($1)='POINT' THEN $1 ELSE ST_PointOnSurface($1) END) t(g)
$wrap$ LANGUAGE SQL IMMUTABLE
;
COMMENT ON FUNCTION geouri_ext.olc_geom(geometry,integer)
  IS 'Returns OLC_center as complete cell geometry. Wrap of olc_geom(float,float).'
;
