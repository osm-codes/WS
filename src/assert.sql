--
-- TESTs by ASSERT clause
--

DO $tests$
begin
  RAISE NOTICE '1. Testando OLC (PlusCodes) ...';

  ASSERT geouri_ext.pluscode_cliplatitude(149.18) = 90, 'pluscode_cliplatitude';
  ASSERT geouri_ext.pluscode_computeLatitudePrecision(11) = 0.000025, 'pluscode_computeLatitudePrecision';
  ASSERT geouri_ext.pluscode_normalizelongitude(188.18) = -171.82, 'pluscode_normalizelongitude';
  ASSERT geouri_ext.pluscode_isvalid('XX5JJC23+00') = false, 'pluscode_isvalid';

  -- bug on record comparison (numeric was ok)
  -- ASSERT geouri_ext.pluscode_codearea(49.1805,-0.378625,49.180625,-0.3785,10::int) = (49.1805,-0.378625,49.180625,-0.3785,10::float,49.1805625,-0.3785625), 'pluscode_codearea';
  ASSERT geouri_ext.pluscode_isshort('XX5JJC+') = true, 'pluscode_isshort';
  ASSERT geouri_ext.pluscode_isfull('cccccc+') = false, 'pluscode_isfull';

  ASSERT geouri_ext.pluscode_encode(49.05,-0.108,12) = '8CXX3V2R+2R22', 'pluscode_encode';
  -- ASSERT geouri_ext.pluscode_decode('CCCCCCCC+') = (78.42,-11.58,78.4225,-11.5775,8::float,78.42125,-11.57875), 'pluscode_decode';
  ASSERT geouri_ext.pluscode_shorten('8CXX5JJC+6H6H6H',49.18,-0.37) = 'JC+6H6H6H', 'pluscode_shorten';

  ASSERT geouri_ext.pluscode_recovernearest('XX5JJC+', 49.1805,-0.3786) = '8CXX5JJC+', 'pluscode_recovernearest';
end;
$tests$
