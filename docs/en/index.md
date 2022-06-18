
The `osm.codes` domain name and its infrastructure (including this documentation and software) **is a patrimony**. The owner of the patrimony is a **condominium**: a contractual arrangement where ownership over the patrimony is collective, and its sole purpose is to establish the directives and share the costs of maintaining that patrimony. The collective is **a set of organizations** &mdash; government or local NGOs like OpenStreetMap's Chapters &mdash; with entitled to vote through their representatives. The main directive of the OSM-codes Condominium is to maintain a set of web-services as persistent URLs (preserved by decades), to *resolve* Geo URIs and geocodes.

In a [*geocode system*](https://en.wikipedia.org/wiki/Geocode#Geocode_system) context, the "resolution" is a disambiguating process, by providing an standard identifier (or a canonical name), and other optional informations about the geographic entity represented by its identifier.

## The OSM-codes technical proposal and offers

The website and API `osm.codes/{path}` can solve many different types of geocodes, URNs and [Geo URIs](https://inde.gov.br/images/inde/poster3/Expans%C3%A3o%20do%20protocolo%20GeoURI.pdf).

* **Website**: the URL and the *content negotiation* result in an HTML webpage. Through the website the geocodes (and/or use of the GeoURI protocol) can be disclosed to end users.

* **API**: returns JSON, by explicit request (a *path* termined by `.json` or at `api.osm.codes`) or *content negotiation*.


### Types of geocodes, URNs and Geo URIs

The `osm.codes` website is also a name and geocode resolution URL. As `doi.org` is committed to solving names in several ways,


1. Resolução do protocolo [**GeoURI expandido**](https://inde.gov.br/images/inde/poster3/Expans%C3%A3o%20do%20protocolo%20GeoURI.pdf). <br/>Exemplos: `/geo:-23.5504,-46.634`, `/geo:-23.55,-46.63;u=15`, `/geo:ghs:6gycex`, `/geo:olc:588MC8QV+C`, `geo:iso:br-sp`, `geo:iso_ext:br-sp-campinas`, `geo:lex:br;sao.paulo;campinas`.

    1.1. As opções de geocódigo no padrão GeoURI não são infinitas nem arbitrárias, uma **curadoria** irá posteriormente revisar e definir quais mais e quais os seus rótulos. Neste início de projeto fechamos as seguintes: `ghs` para [Geohash clássico](https://www.movable-type.co.uk/scripts/geohash.html) ([PostGIS](https://postgis.net/docs/ST_GeoHash.html)), `ghs-b64` para Geohash base64 do OSM, `ghs-b16h` para [Geohash base16h](http://osm.codes/_foundations/art1.pdf),  `olc` para  [Open Location Code](https://en.wikipedia.org/wiki/Open_Location_Code), `iso` para  [ISO&nbsp;3166-2](https://en.wikipedia.org/wiki/ISO_3166-2), `iso_ext` para ISO extendido das jurisdições, `lex`  para jurisdições LexML.

   1.2. Algumas variantes exóiticas só para exemplificar implementações que desenvolvemos: `br-cep` para o código postal  brasileiro vigente ainda em 2022, `br-ibge2020` para a Grade Estatística do IBGE ainda vigente em 2022. Exemplos: `geo:br-cep:04569-010`  (resolução hierárquica pelas jurisdições e pela  [base CRP](https://github.com/AddressForAll/CRP)) e  `geo:br-ibge2020:100KME4600N1095`  (ver [prj BR_IBGE](https://github.com/osm-codes/BR_IBGE/blob/main/data/grid_ibge100km.geojson))

3. Resolução dos **OSM-codes**:  convenção estabelecida pela "organização OSM-codes"  em consenso com repersentantes das jurisdições locais, que estabelece o geocódigo misto *OSMcode*.  A sintaxe canônica do OSMcode é `{pais2letras}[-{geocodigoNominal}]~{geocodigoDHG}`, onde a primeira parte é um nome, abreviação ou código mnemônico da jurisdição (tipicamente abreviações ISO), e a segunda, `geocodigoDHG`, o geocódigo gerado por sistema de [*Discrete Hierarchical Grid*](https://en.wikipedia.org/wiki/Geocode#Hierarchical_grids) (local ou global), tal como Geohash.

4. Resolução dos **Identificadores OSM**:  análogo à resolução de identificadores Wikidata, delega a resolução. Sintaxe: Prefixos `r` para *relation*, `w`  para *way* e `n` para *node*, seguido de 2 ou mais dígitos. Isso evita risco de conflito com códigos iso de país com 3 dígitos, que no futuro podem ser opção ao ISO-alpha2.   

4. Resolução de prefixos **URN Lex**: o  portal oficial https://www.lexml.gov.br faz uso de [URNs Lex](https://en.wikipedia.org/wiki/Lex_(URN)), cujo prefixo (jurisdição) é um *geocódigo nominal* (também resolvido por `geo:lex`). Exemplos: `/urn:lex:br;sao.paulo;campinas` (canônica),  `/urn:lex:br;sp;cam` (referência).

6. Resolução de identificadores **Wikidata** relativos a entidades geográficas: desde uma [padaria](https://www.wikidata.org/wiki/Q41796695)   ou [museu](https://www.wikidata.org/wiki/Q82941), até um [país](https://www.wikidata.org/wiki/Q739). A resolução final  de códigos válidos é feita consultando-se no server a API Wikidata.  Exemplo:  `Q739` para jurisdição Colômbia, `Q41796695` para um endereço comercial no Brasil. A sintaxe "prefixo `Q`" seguido de 2 ou mais dígitos não tem risco de ambiguidade.

<!-- On the website, the URL with this type of *path* must return a standardized information page, highlighting the geographic representation of the entity represented by the geocode.-->

### Generic endpoint syntax

To implement the different types (of geocodes, URNs and GeoURIs) in the same domain and guaranteeing short URLs, the following syntax was agreed in the webpages and API-endpoints:

<!--  https://bottlecaps.de/rr/ui
/* OSM.codes endpoint path
 * See http://osm.codes
 */

path
         ::= GeoIdentifier ('/' CommandPath)?  ('?' Variables)?

GeoIdentifier
         ::= ('geo:' GeoUri_expaned)
           | ( ('BR' | 'CO' | '...' )  '-' ((LocalAbbreviation '~' LocalGridCode) | LocalGeocode ) )
           | ('Q' Wikidata_ID)
           | ( ('r' | 'w' | 'n') OSM_ID )
           | ( 'urn:' ('lex'|'...') ':' UrnValue )
           | GeoUri_value
-->

Both, website and API, use the same `path` general endpoint syntax, to support the "many types" of geocodes and protocols:

![](../_assets/endpointSyntax_p0.png)

Examples: ...
<!--
Expanded GeoURI protocol resolution.
Examples: /geo:-23.5504,-46.634, /geo:-23.55,-46.63;u=15, /geo:ghs:6gycex, /geo:olc:588MC8QV+C, geo:iso:br-sp, geo: iso_ext:br-sp-campinas, geo:lex:br;sao.paulo;campinas.

-->
