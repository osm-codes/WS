# WS
Genral WebServices of the OSM.codes 

(**Draft** and review)

## GET Endpoints

All HTTP or HTTPS,  GET. See NGINX implementation.

URI template  | description
--------------|--------------
`osm.codes` | the domain presentation, home page. 
`osm.codes/{countryCode}` |  Any [ISO&nbsp;3166-1&nbsp;alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) or [alpha-3](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-3) country code. Defines an *OSMcodes jurisdiction*, as provided for in the [Geo URI expansion](https://inde.gov.br/images/inde/poster3/Expans%C3%A3o%20do%20protocolo%20GeoURI.pdf). <br/>Exemples: https://osm.codes/BR for Brazil or https://osm.codes/CO for Colombia.
`osm.codes/{countryCode}-{localGeocode}` | An *OSMcodes jurisdiction* local **geocode resolution**.<br/>Exemples: https://osm.codes/BR-SP for São Paulo/Brazil or https://osm.codes/BR-SP-Campinas-2345 for postal geocode, http://osm.codes/CO-66170-15NTJ for Colombian's one.
`{countryCode}.osm.codes` | An *OSMcodes jurisdiction* "hotpage", Country-community's private property in the context of the OSMcodes Condominium. <br/>Exemple: future https://CO.osm.codes

## API services

Using PostgREST with NGINX to run  PostgreSQL functions at SQL-schema `API`.

endpoint | PostgreSQL function and constant parameters
---------|----------
`api.osm.codes/jurisdiction_autocomplete` | Returns countries.
`api.osm.codes/jurisdiction_autocomplete/{code}` | Returns the next subdivision of `{code}`. Any [ISO&nbsp;3166-1&nbsp;alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) country code **OR** any [ISO&nbsp;3166-2](https://en.wikipedia.org/wiki/ISO_3166-2) subdivision code.
`api.osm.codes/jurisdiction_autocomplete/{code}/{language}` | Any [ISO&nbsp;3166-1&nbsp;alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) country code **OR** any [ISO&nbsp;3166-2](https://en.wikipedia.org/wiki/ISO_3166-2) subdivision code. `{language}` can be: `en`, `es`, `fr` or `pt`. However, `name` is always returned in the official language of the country.
....|....

endpoint | PostgreSQL VIEW and query examples
---------|----------
....|....
