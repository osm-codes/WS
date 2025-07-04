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


  RAISE NOTICE '2. Testando Encode Sci geouri bbox';

  ASSERT (api.afacode_encode_log_no_context('geo:-23.55,-46.633333;u=0.5')->'features')[0]->>'id'='BR+dfc16b792fe', 'São Paulo/BR';
  ASSERT (api.afacode_encode_log_no_context('geo:-3.118889,-60.021667;u=0.5')->'features')[0]->>'id'='BR+140eef5c28d', 'Manaus/BR';
  ASSERT (api.afacode_encode_log_no_context('geo:-30.8775,-55.533056;u=0.5')->'features')[0]->>'id'='BR+d08486208d7', 'SantAna do Livramento/BR';
  ASSERT (api.afacode_encode_log_no_context('geo:-9.974722,-67.81;u=0.5')->'features')[0]->>'id'='BR+470a3c68650', 'Rio Branco/BR';
  ASSERT (api.afacode_encode_log_no_context('geo:-0.119167,-67.082778;u=0.5')->'features')[0]->>'id'='BR+072c810bdf3', 'São Gabriel da Cachoeira/BR';
  ASSERT (api.afacode_encode_log_no_context('geo:-0.193889,-74.780556;u=0.5')->'features')[0]->>'id'='CO+90630c8cf0V', 'Puerto Leguízamo/CO';
  ASSERT (api.afacode_encode_log_no_context('geo:6.190278,-67.483611;u=0.5')->'features')[0]->>'id'='CO+e6cfdc93e0V', 'Puerto Carreño/CO';
  ASSERT (api.afacode_encode_log_no_context('geo:4.711111,-74.072222;u=0.5')->'features')[0]->>'id'='CO+c12e72768eV', 'Bogotá/CO';
  ASSERT (api.afacode_encode_log_no_context('geo:1.207778,-77.277222;u=0.5')->'features')[0]->>'id'='CO+369507ac73R', 'Pasto/CO';
  ASSERT (api.afacode_encode_log_no_context('geo:4.365,11.44;u=0.5')->'features')[0]->>'id'='CM+91e2b65c8c', 'Saa/CM';

  -- ASSERT (api.afacode_encode_log_no_context('geo:-30.9025,-55.550556;u=0.5')->'features')[0]->>'id'='e0e79ce6a85', 'Rivera/UY';
  -- ASSERT (api.afacode_encode_log_no_context('geo:-31.383333,-57.95;u=0.5')->'features')[0]->>'id'='2b4fecc57a5', 'Salto/UY';
  -- ASSERT (api.afacode_encode_log_no_context('geo:0.811667,-77.718611;u=0.5')->'features')[0]->>'id'='0492a99c5670', 'Tulcán/EC';
  -- ASSERT (api.afacode_encode_log_no_context('geo:0.966667,-79.652778;u=0.5')->'features')[0]->>'id'='03b4a464c15a', 'Esmeraldas/EC';
  -- ASSERT (api.afacode_encode_log_no_context('geo:-0.22,-78.5125;u=0.5')->'features')[0]->>'id'='083484348487', 'Quito/EC';
  -- ASSERT (api.afacode_encode_log_no_context('geo:-0.5,-90.5;u=0.5')->'features')[0]->>'id'='060cb0b5e0c2', 'Galápagos/EC';

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
