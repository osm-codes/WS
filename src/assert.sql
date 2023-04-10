--
-- TESTs by ASSERT clause
--

DO $tests$
begin
  RAISE NOTICE '1. Testando OLC (PlusCodes) ...';

  ASSERT geouri_ext.olc_cliplatitude(149.18) = 90, 'pluscode_cliplatitude';
  ASSERT geouri_ext.olc_computeLatitudePrecision(11) = 0.000025, 'pluscode_computeLatitudePrecision';
  ASSERT geouri_ext.olc_normalizelongitude(188.18) = -171.82, 'pluscode_normalizelongitude';
  ASSERT geouri_ext.olc_isvalid('XX5JJC23+00') = false, 'pluscode_isvalid';

  ASSERT geouri_ext.olc_codearea(49.1805,-0.378625,49.180625,-0.3785,10::int) = array[49.1805,-0.378625,49.180625,-0.3785,10,49.1805625,-0.3785625]::float[], 'pluscode_codearea';
  ASSERT geouri_ext.olc_isshort('XX5JJC+') = true, 'pluscode_isshort';
  ASSERT geouri_ext.olc_isfull('cccccc+') = false, 'pluscode_isfull';

  ASSERT geouri_ext.olc_encode(49.05,-0.108,12) = '8CXX3V2R+2R22', 'pluscode_encode';
  ASSERT geouri_ext.olc_decode('CCCCCCCC+') = array[78.42,-11.58,78.4225,-11.5775,8::float,78.42125,-11.57875], 'pluscode_decode';
  ASSERT geouri_ext.olc_shorten('8CXX5JJC+6H6H6H',49.18,-0.37) = 'JC+6H6H6H', 'pluscode_shorten';

  ASSERT geouri_ext.olc_recovernearest('XX5JJC+', 49.1805,-0.3786) = '8CXX5JJC+', 'pluscode_recovernearest';

  RAISE NOTICE '1. Locais homologados por PlusCodes...';

  ASSERT geouri_ext.olc_encode(-9.956563,-67.864938) = '672J24VP+92', 'BR-AC-RioBranco, Universidade Federal do Acre (UFAC)';
  ASSERT geouri_ext.olc_encode(-3.130278,-60.023333) = '678XVX9G+VM', 'BR-AM-Manaus, Teatro Amazonas';
  ASSERT geouri_ext.olc_encode(3.86139,-51.79611)    = '68MCV663+HH', 'BR-AP-Oiapoque, Aeroporto De Oiapoque';
  ASSERT geouri_ext.olc_encode(-13.002025,-38.53297) = '59R3XFX8+5R', 'BR-BA-Salvador, Marco da Fundação da Cidade do Salvador';
  ASSERT geouri_ext.olc_encode(-3.807267,-38.522481) = '69835FVH+32', 'BR-CE-Fortaleza, Arena Castelão';
  ASSERT geouri_ext.olc_encode(-15.79972,-47.864131) = '58PJ642P+48', 'BR-DF, Palácio Nereu Ramos (Congresso Nacional)';
  --
  ASSERT geouri_ext.olc_encode(-33.7417,-53.3736)= '48R87J5G+8H', 'BR-RS-SantaVitoriaPalmar, Farol da Barra do Chuí (proximo)';

  ASSERT geouri_ext.olc_encode(-23.550385,-46.633956)='588MC9X8+RC', 'BR-SP-SaoPaulo, Marco Zero de São Paulo, 10 digitos';
  ASSERT geouri_ext.olc_encode(-23.550385,-46.633956,11)='588MC9X8+RCV', 'BR-SP-SaoPaulo, Marco Zero de São Paulo, 11 digitos';
end;
$tests$

/* Homologar por PlusCodes:
SELECT geouri_ext.olc_encode(-20.292149,-40.28804);-- = 'yy', 'BR-ES-Vitoria, Píer de Iemanjá';
SELECT geouri_ext.olc_encode(-2.529028,-44.302476);-- = 'yy', 'BR-MA-SaoLuis, Teatro Arthur Azevedo';
SELECT geouri_ext.olc_encode(-15.603056,-56.120556);-- = 'yy', 'BR-MT-Cuiaba, Arena Pantanal';
SELECT geouri_ext.olc_encode(-1.43056,-48.4569);-- = 'yy', 'BR-PA-Belem, Bosque Rodrigues Alves';
SELECT geouri_ext.olc_encode(-3.854722,-32.428333);-- = 'yy', 'BR-PE-FernandoNoronha, Aeroporto de Fernando de Noronha';
SELECT geouri_ext.olc_encode(-25.5925,-54.593056);-- = 'yy', 'BR-PR-FozIguacu, Marco das Três Fronteiras';
SELECT geouri_ext.olc_encode(-22.952331,-43.210369);-- = 'yy', 'BR-RJ-RioJaneiro, Cristo Redentor';
SELECT geouri_ext.olc_encode(-5.756389,-35.194722); -- = 'yy', 'BR-RN-Natal, Fortaleza dos Reis Magos';
SELECT geouri_ext.olc_encode(2.84139,-60.69222); -- = 'yy', 'BR-RR-BoaVista, Aeroporto Internacional de Boa Vista';
SELECT geouri_ext.olc_encode(5.20194,-60.7369); -- = 'yy', 'BR-RR-Uiramuta, Parque Nacional do Monte Roraima';
SELECT geouri_ext.olc_encode(-33.7417,-53.3736); -- = 'yy', 'BR-RS-SantaVitoriaPalmar, Farol da Barra do Chuí (aproximado)';
SELECT geouri_ext.olc_encode(-29.78333,-57.03694); -- = 'yy', 'BR-RS-Uraguaiana, Aeroporto Internacional de Uruguaiana';
*/
