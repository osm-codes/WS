var uri_base = "https://osm.codes"

var osmUrl = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
var osmAttrib = '&copy; <a href="https://osm.org/copyright">OpenStreetMap contributors</a>';
var mapboxUrl = 'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token=pk.eyJ1IjoibWFwYm94IiwiYSI6ImNpejY4NXVycTA2emYycXBndHRqcmZ3N3gifQ.rJcFIG214AriISLbB6B5aw';
var mapboxAttr = 'Tiles from <a href="https://www.mapbox.com">Mapbox</a>';
var osmAndMapboxAttr = osmAttrib + '. ' + mapboxAttr;

var openstreetmap = L.tileLayer(osmUrl,   {attribution: osmAttrib,detectRetina: true,minZoom: 0,maxNativeZoom: 19,maxZoom: 25 }),
    grayscale = L.tileLayer(mapboxUrl,{id:'mapbox/light-v10',attribution: osmAndMapboxAttr,detectRetina: true,maxNativeZoom: 22,maxZoom: 25 }),
    streets = L.tileLayer(mapboxUrl,{id:'mapbox/streets-v11',attribution: osmAndMapboxAttr,detectRetina: true,maxNativeZoom: 22,maxZoom: 25 }),
    satellite = L.tileLayer(mapboxUrl,{id:'mapbox/satellite-v9',attribution: mapboxAttr,detectRetina: true,maxNativeZoom: 22,maxZoom: 25 }),
    satellitestreet = L.tileLayer(mapboxUrl,{id:'mapbox/satellite-streets-v11',attribution: mapboxAttr,detectRetina: true,maxNativeZoom: 22,maxZoom: 25 });

var baseLayers = {
    'Grayscale': grayscale,
    'OpenStreetMap': openstreetmap,
    'Streets': streets,
    'Satellite': satellite,
    'Satellite and street': satellitestreet };

var layerPolygonCurrent = new L.geoJSON(null, {
            style: style,
            onEachFeature: onEachFeature,
            pointToLayer: pointToLayer,
        });
var layerPolygonAll = new L.geoJSON(null,{
            style: style,
            onEachFeature: onEachFeature,
            pointToLayer: pointToLayer,
        });
var layerMarkerCurrent = new L.featureGroup();
var layerMarkerAll = new L.featureGroup();

var overlays = {
    'Current polygon': layerPolygonCurrent,
    'All polygon': layerPolygonAll,
    'Current marker': layerMarkerCurrent,
    'All markers': layerMarkerAll };


var selectCountries = '<option value="BR">Brasil</option><option value="CO" selected>Colombia</option><option value="EC">Equador</option><option value="UY">Uruguai</option>';

var countries = {
    BR:
    {
        center: [-15.796,-47.880],
        zoom: 4,
        current_zoom: 4,
        defaultBase: 'base32',
        scientificBase: 'base16h',
        postalcodeBase: 'base32',
        isocode: 'BR',
        jurisdictionPlaceholder: 'BR-SP-SaoPaulo',
        selectBases: '<option value="base32">base32</option><option value="base16h">base16h</option>',
        bases:
        {
            base32:
            {
                symbol: '~',
                placeholderDecode: 'BR~42',
                placeholderEncode: '-15.7,-47.8;u=10',
                placeholderList: '3,5,7,A',
                selectGrid: '<option></option><option value="grid32">grid32</option><option value="grid33">grid32 (points)</option>',
                selectLevel: '<option value="600000">0 (1d) (1048km)</option>\
<option value="100000">2.5 (2d) (185,36km)</option>\
<option value="20000">5 (3d) (32,76km)</option>\
<option value="3500">7.5 (4d) (5,79km)</option>\
<option value="600">10 (5d) (1,024km)</option>\
<option value="100">12.5 (6d) (181m)</option>\
<option value="20">15 (7d) (32m)</option>\
<option value="3">17.5 (8d) (5,7m)</option>\
<option value="0">20 (9d) (1m)</option>'
            },
            base16h:
            {
                symbol: '+',
                placeholderDecode: 'BR+3F',
                placeholderEncode: '-15.7,-47.8;u=10',
                placeholderList: '3,5,7,B',
                selectGrid: '<option></option><option value="grid2">grid2</option><option value="grid4">grid4</option><option value="grid8">grid8</option><option value="grid16">grid16</option><option value="grid3">grid2 (points)</option><option value="grid5">grid4 (points)</option><option value="grid9">grid8 (points)</option><option value="grid17">grid16 (points)</option>',
                selectLevel: '<option value="600000">0 (1d) (1048,57km)</option>\
<option value="400000">0.5 (2d) (741,45km)</option>\
<option value="300000">1 (2d) (524,28km)</option>\
<option value="200000">1.5 (2d) (370,72km)</option>\
<option value="150000">2 (2d) (262,14km)</option>\
<option value="100000">2.5 (3d) (185,54km)</option>\
<option value="75000">3 (3d) (131,07km)</option>\
<option value="50000">3.5 (3d) (92,68km)</option>\
<option value="40000">4 (3d) (65,54km)</option>\
<option value="25000">4.5 (4d) (46,34km)</option>\
<option value="20000">5 (4d) (32,78km)</option>\
<option value="15000">5.5 (4d) (23,17km)</option>\
<option value="10000">6 (4d) (16,38km)</option>\
<option value="6000">6.5 (5d) (11,58km)</option>\
<option value="5000">7 (5d) (8,192km)</option>\
<option value="3500">7.5 (5d) (5,7926km)</option>\
<option value="2500">8 (5d) (4,096km)</option>\
<option value="1500">8.5 (6d) (2,8963km)</option>\
<option value="1250">9 (6d) (2,048km)</option>\
<option value="750">9.5 (6d) (1,4482km)</option>\
<option value="600">10 (6d) (1,024km)</option>\
<option value="450">10.5 (7d) (724,1m)</option>\
<option value="300">11 (7d) (512m)</option>\
<option value="225">11.5 (7d) (362m)</option>\
<option value="150">12 (7d) (256m)</option>\
<option value="100">12.5 (8d) (181m)</option>\
<option value="75">13 (8d) (128m)</option>\
<option value="50">13.5 (8d) (90,5m)</option>\
<option value="40">14 (8d) (64m)</option>\
<option value="25">14.5 (9d) (45,3m)</option>\
<option value="20">15 (9d) (32m)</option>\
<option value="15">15.5 (9d) (22,6m)</option>\
<option value="8">16 (9d) (16m)</option>\
<option value="7">16.5 (10d) (11,3m)</option>\
<option value="5">17 (10d) (8m)</option>\
<option value="3">17.5 (10d) (5,7m)</option>\
<option value="2">18 (10d) (4m)</option>\
<option value="1.4">18.5 (11d) (2,8)</option>\
<option value="1">19 (11d) (2m)</option>\
<option value="0.7">19.5 (11d) (1,4m)</option>\
<option value="0">20 (11d) (1m)</option>'
            }
        }
    },
    CO:
    {
        center: [3.5,-72.3],
        zoom: 6,
        current_zoom: 6,
        defaultBase: 'base32',
        scientificBase: 'base16h',
        postalcodeBase: 'base32',
        isocode: 'CO',
        jurisdictionPlaceholder: 'CO-ANT-Itagui',
        selectBases: '<option value="base32">base32</option><option value="base16h">base16h</option>',
        bases:
        {
            base32:
            {
                symbol: '~',
                placeholderDecode: 'CO~3D5',
                placeholderEncode: '3.5,-72.3;u=10',
                placeholderList: '3D5,3D4,2',
                selectGrid: '<option></option><option value="grid32">grid32</option><option value="grid33">grid32 (points)</option>',
                selectLevel: '<option value="150000">0 (1d) (262,14km)</option>\
<option value="25000">2.5 (2d) (46,34km)</option>\
<option value="5000">5 (3d) (8,192km)</option>\
<option value="750">7.5 (4d) (1,45km)</option>\
<option value="150">10 (5d) (256m)</option>\
<option value="25">12.5 (6d) (45m)</option>\
<option value="5">15 (7d) (8m)</option>\
<option value="0">17.5 (8d) (1,4m)</option>'
            },
            base16h:
            {
                symbol: '+',
                placeholderDecode: '0A2',
                placeholderEncode: '3.5,-72.3;u=10',
                placeholderList: '0A,0B,0C',
                selectGrid: '<option></option><option value="grid2">grid2</option><option value="grid4">grid4</option><option value="grid8">grid8</option><option value="grid16">grid16</option><option value="grid3">grid2 (points)</option><option value="grid5">grid4 (points)</option><option value="grid9">grid8 (points)</option><option value="grid17">grid16 (points)</option>',
                selectLevel: '<option value="150000">0 (2d) (262,14km)</option>\
<option value="100000">0.5 (3d) (185,54km)</option>\
<option value="75000">1 (3d) (131,07km)</option>\
<option value="50000">1.5 (3d) (92,68km)</option>\
<option value="40000">2 (3d) (65,54km)</option>\
<option value="25000">2.5 (4d) (46,34km)</option>\
<option value="20000">3 (4d) (32,78km)</option>\
<option value="15000">3.5 (4d) (23,17km)</option>\
<option value="10000">4 (4d) (16,38km)</option>\
<option value="6000">4.5 (5d) (11,58km)</option>\
<option value="5000">5 (5d) (8,192km)</option>\
<option value="3500">5.5 (5d) (5,7926km)</option>\
<option value="2500">6 (5d) (4,096km)</option>\
<option value="1500">6.5 (6d) (2,8963km)</option>\
<option value="1250">7 (6d) (2,048km)</option>\
<option value="750">7.5 (6d) (1,4482km)</option>\
<option value="600">8 (6d) (1,024km)</option>\
<option value="450">8.5 (7d) (724,1m)</option>\
<option value="300">9 (7d) (512m)</option>\
<option value="225">9.5 (7d) (362m)</option>\
<option value="150">10 (7d) (256m)</option>\
<option value="100">10.5 (8d) (181m)</option>\
<option value="75">11 (8d) (128m)</option>\
<option value="50">11.5 (8d) (90,5m)</option>\
<option value="40">12 (8d) (64m)</option>\
<option value="25">12.5 (9d) (45,3m)</option>\
<option value="20">13 (9d) (32m)</option>\
<option value="15">13.5 (9d) (22,6m)</option>\
<option value="8">14 (9d) (16m)</option>\
<option value="7">14.5 (10d) (11,3m)</option>\
<option value="5">15 (10d) (8m)</option>\
<option value="3">15.5 (10d) (5,7m)</option>\
<option value="2">16 (10d) (4m)</option>\
<option value="1.4">16.5 (11d) (2,8)</option>\
<option value="1">17 (11d) (2m)</option>\
<option value="0.7">17.5 (11d) (1,4m)</option>\
<option value="0">18 (11d) (1m)</option>'
            }
        }
    },
    EC:
    {
        center: [-0.944,-83.895],
        zoom: 6,
        current_zoom: 6,
        defaultBase: 'base32',
        scientificBase: 'base16h',
        postalcodeBase: 'base32',
        isocode: 'EC',
        jurisdictionPlaceholder: 'EC-L-Loja',
        selectBases: '<option value="base32">base32</option><option value="base16h">base16h</option>',
        bases:
        {
            base32:
            {
                symbol: '~',
                placeholderDecode: 'EC~5P',
                placeholderEncode: '-1.1,-78.4;u=10',
                placeholderList: '5P,FL,J9',
                selectGrid: '<option></option><option value="grid32">grid32</option><option value="grid33">grid32 (points)</option>',
                selectLevel: '<option value="100000">0 (1d) (185,54km)</option>\
<option value="20000">2.5 (2) (32,78km)</option>\
<option value="3500">5 (3d) (5,7926km)</option>\
<option value="600">7.5 (4d) (1,024km)</option>\
<option value="100">10 (5d) (181m)</option>\
<option value="20">12.5 (6d) (32m)</option>\
<option value="3">15 (7d) (5,7m)</option>\
<option value="0">17.5 (8d) (1m)</option>'
            },
            base16h:
            {
                symbol: '+',
                placeholderDecode: 'EC+0E',
                placeholderEncode: '-1.1,-78.4;u=10',
                placeholderList: '0E,0A,05',
                selectGrid: '<option></option><option value="grid2">grid2</option><option value="grid4">grid4</option><option value="grid8">grid8</option><option value="grid16">grid16</option><option value="grid3">grid2 (points)</option><option value="grid5">grid4 (points)</option><option value="grid9">grid8 (points)</option><option value="grid17">grid16 (points)</option>',
                selectLevel: '<option value="100000">0 (2d) (185,54km)</option>\
<option value="75000">0.5 (3d) (131,07km)</option>\
<option value="50000">1 (3d) (92,68km)</option>\
<option value="40000">1.5 (3d) (65,54km)</option>\
<option value="25000">2 (3d) (46,34km)</option>\
<option value="20000">2.5 (4) (32,78km)</option>\
<option value="15000">3 (4d) (23,17km)</option>\
<option value="10000">3.5 (4d) (16,38km)</option>\
<option value="6000">4 (4d) (11,58km)</option>\
<option value="5000">4.5 (5d) (8,192km)</option>\
<option value="3500">5 (5d) (5,7926km)</option>\
<option value="2500">5.5 (5d) (4,096km)</option>\
<option value="1500">6 (5d) (2,8963km)</option>\
<option value="1250">6.5 (6d) (2,048km)</option>\
<option value="750">7 (6d) (1,4482km)</option>\
<option value="600">7.5 (6d) (1,024km)</option>\
<option value="450">8 (6d) (724,1m)</option>\
<option value="300">8.5 (7d) (512m)</option>\
<option value="225">9 (7d) (362m)</option>\
<option value="150">9.5 (7d) (256m)</option>\
<option value="100">10 (7d) (181m)</option>\
<option value="75">10.5 (8d) (128m)</option>\
<option value="50">11 (8d) (90,5m)</option>\
<option value="40">11.5 (8d) (64m)</option>\
<option value="25">12 (8d) (45,3m)</option>\
<option value="20">12.5 (9d) (32m)</option>\
<option value="15">13 (9d) (22,6m)</option>\
<option value="8">13.5 (9d) (16m)</option>\
<option value="7">14 (9d) (11,3m)</option>\
<option value="5">14.5 (10d) (8m)</option>\
<option value="3">15 (10d) (5,7m)</option>\
<option value="2">15.5 (10d) (4m)</option>\
<option value="1.4">16 (10d) (2,8)</option>\
<option value="1">16.5 (11d) (2m)</option>\
<option value="0.7">17 (11d) (1,4m)</option>\
<option value="0">17.5 (11d) (1m)</option>',
            }
        }
    },
    UY:
    {
        center: [-32.981,-55.921],
        zoom: 7,
        current_zoom: 7,
        defaultBase: 'base16',
        scientificBase: 'base16h',
        postalcodeBase: 'base16',
        isocode: 'UY',
        jurisdictionPlaceholder: 'UY-CA-LasPiedras',
        selectBases: '<option value="base16">base16</option><option value="base16h">base16h</option>',
        bases:
        {
            base32:
            {
                symbol: '~',
                placeholderDecode: 'UY~3',
                placeholderEncode: '-32.9,-55.9;u=10',
                placeholderList: '3,2C,4F',
                selectGrid: '<option></option><option value="grid32">grid32</option><option value="grid33">grid32 (points)</option>',
                selectLevel: '<option value="150000">0 (1d) (262,14km)</option>\
<option value="25000">2.5 (2d) (46,34km)</option>\
<option value="5000">5 (3d) (8,192km)</option>\
<option value="750">7.5 (4d) (1,45km)</option>\
<option value="150">10 (5d) (256m)</option>\
<option value="25">12.5 (6d) (45m)</option>\
<option value="5">15 (7d) (8m)</option>\
<option value="0">17.5 (8d) (1,4m)</option>'
            },
            base16h:
            {
                symbol: '+',
                placeholderDecode: 'UY+2',
                placeholderEncode: '-32.9,-55.9;u=10',
                placeholderList: '2G,3A,01',
                selectGrid: '<option></option><option value="grid2">grid2</option><option value="grid4">grid4</option><option value="grid8">grid8</option><option value="grid16">grid16</option><option value="grid3">grid2 (points)</option><option value="grid5">grid4 (points)</option><option value="grid9">grid8 (points)</option><option value="grid17">grid16 (points)</option>',
                selectLevel: '<option value="150000">0 (1d) (262,14km)</option>\
<option value="100000">0.5 (2d) (185,54km)</option>\
<option value="75000">1 (2d) (131,07km)</option>\
<option value="50000">1.5 (2d) (92,68km)</option>\
<option value="40000">2 (2d) (65,54km)</option>\
<option value="25000">2.5 (3d) (46,34km)</option>\
<option value="20000">3 (3d) (32,78km)</option>\
<option value="15000">3.5 (3d) (23,17km)</option>\
<option value="10000">4 (3d) (16,38km)</option>\
<option value="6000">4.5 (4d) (11,58km)</option>\
<option value="5000">5 (4d) (8,192km)</option>\
<option value="3500">5.5 (4d) (5,7926km)</option>\
<option value="2500">6 (4d) (4,096km)</option>\
<option value="1500">6.5 (5d) (2,8963km)</option>\
<option value="1250">7 (5d) (2,048km)</option>\
<option value="750">7.5 (5d) (1,4482km)</option>\
<option value="600">8 (5d) (1,024km)</option>\
<option value="450">8.5 (6d) (724,1m)</option>\
<option value="300">9 (6d) (512m)</option>\
<option value="225">9.5 (6d) (362m)</option>\
<option value="150">10 (6d) (256m)</option>\
<option value="100">10.5 (7d) (181m)</option>\
<option value="75">11 (7d) (128m)</option>\
<option value="50">11.5 (7d) (90,5m)</option>\
<option value="40">12 (7d) (64m)</option>\
<option value="25">12.5 (8d) (45,3m)</option>\
<option value="20">13 (8d) (32m)</option>\
<option value="15">13.5 (8d) (22,6m)</option>\
<option value="8">14 (8d) (16m)</option>\
<option value="7">14.5 (9d) (11,3m)</option>\
<option value="5">15 (9d) (8m)</option>\
<option value="3">15.5 (9d) (5,7m)</option>\
<option value="2">16 (9d) (4m)</option>\
<option value="1.4">16.5 (10d) (2,8)</option>\
<option value="1">17 (10d) (2m)</option>\
<option value="0.7">17.5 (10d) (1,4m)</option>\
<option value="0">18 (10d) (1m)</option>',
            },
            base16:
            {
                symbol: '~',
                placeholderDecode: 'UY~2',
                placeholderEncode: '-32.9,-55.9;u=10',
                placeholderList: '3B,3A,01',
                selectGrid: '<option></option><option value="grid16">grid16</option><option value="grid17">grid16 (points)</option>',
                selectLevel: '<option value="150000">0 (1d) (262,14km)</option>\
<option value="40000">2 (2d) (65,54km)</option>\
<option value="10000">4 (3d) (16,38km)</option>\
<option value="2500">6 (4d) (4,096km)</option>\
<option value="600">8 (5d) (1,024km)</option>\
<option value="150">10 (6d) (256m)</option>\
<option value="40">12 (7d) (64m)</option>\
<option value="8">14 (8d) (16m)</option>\
<option value="2">16 (9d) (4m)</option>\
<option value="0">18 (10d) (1m)</option>'
            }
        }
    }
};

var defaultMap = countries['CO'];

var map = L.map('map',{
    center: defaultMap.center,
    zoom:   defaultMap.zoom,
    zoomControl: false,
    renderer: L.svg(),
    layers: [grayscale, layerPolygonCurrent, layerPolygonAll] });

var toggleTooltipStatus = true;

map.attributionControl.setPrefix(false);
map.addControl(new L.Control.Fullscreen({position:'topright'})); /* https://github.com/Leaflet/Leaflet.fullscreen */
map.on('zoom', function(e){defaultMap.current_zoom = map.getZoom();});
map.on('click', onMapClick);
map.on('zoomend', showZoomLevel);
showZoomLevel();

var zoom   = L.control.zoom({position:'topright'});
var layers = L.control.layers(baseLayers, overlays,{position:'topright'});
var escala = L.control.scale({position:'bottomright',imperial: false});

var searchJurisdiction = L.control({position: 'topleft'});
searchJurisdiction.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.label     = L.DomUtil.create('label', '', this.container);
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.label     = L.DomUtil.create('label', '', this.container);
    this.checkbox  = L.DomUtil.create('input', '', this.container);

    this.label.for= 'jcover';
    this.label.innerHTML= 'with cover: ';
    this.checkbox.id = 'jcover';
    this.checkbox.type = 'checkbox';
    this.checkbox.checked = false;

    this.search.type = 'text';
    this.search.placeholder = 'e.g.: ' + defaultMap.jurisdictionPlaceholder;
    this.search.id = 'textsearchjurisdiction';
    this.button.type = 'button';
    this.button.innerHTML= "Jurisdiction";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.disableScrollPropagation(this.search);
    L.DomEvent.disableClickPropagation(this.search);
    L.DomEvent.disableScrollPropagation(this.checkbox);
    L.DomEvent.disableClickPropagation(this.checkbox);
    L.DomEvent.on(this.button, 'click', searchDecodeJurisdiction, this.container);
    L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchDecodeJurisdiction(data);}}, this.container);

    return this.container; };

var searchDecode = L.control({position: 'topleft'});
searchDecode.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.search.type = 'text';
    this.search.placeholder = 'geocode, e.g.: ' + defaultMap.bases[defaultMap.defaultBase].placeholderDecode;
    this.search.id = 'textsearchbar';
    this.button.type = 'button';
    this.button.innerHTML= "Decode";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.disableScrollPropagation(this.search);
    L.DomEvent.disableClickPropagation(this.search);
    L.DomEvent.on(this.button, 'click', searchDecodeGgeocode, this.container);
    L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchDecodeGgeocode(data);}}, this.container);

    return this.container; };

var searchDecodeList = L.control({position: 'topleft'});
searchDecodeList.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.search    = L.DomUtil.create('textarea', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.search.placeholder = 'list geocodes, e.g.: ' + defaultMap.bases[defaultMap.defaultBase].placeholderList;
    this.search.id = 'listtextsearchbar';
    this.button.type = 'button';
    this.button.innerHTML= "Decode";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.disableScrollPropagation(this.search);
    L.DomEvent.disableClickPropagation(this.search);
    L.DomEvent.on(this.button, 'click', searchDecodeListGgeocode, this.container);
    //L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchDecodeListGgeocode(data);}}, this.container);

    return this.container; };

var searchEncode = L.control({position: 'topleft'});
searchEncode.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.search.type = 'text';
    this.search.placeholder = 'lat,lng, e.g.: ' + defaultMap.bases[defaultMap.defaultBase].placeholderEncode;
    this.search.id = 'latlngtextbar';
    this.button.type = 'button';
    this.button.innerHTML= "Encode";

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);
    L.DomEvent.on(this.button, 'click', searchEncodeGgeocode, this.container);
    L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchEncodeGgeocode(data);}}, this.container);

    return this.container; };

var country = L.control({position: 'topleft'});
country.onAdd = function (map) {
    this.container      = L.DomUtil.create('div');
    this.label_country  = L.DomUtil.create('label', '', this.container);
    this.select_country = L.DomUtil.create('select', '', this.container);

    this.label_country.for = 'country';
    this.label_country.innerHTML = 'Country: ';
    this.select_country.id = 'country';
    this.select_country.name = 'country';
    this.select_country.innerHTML = selectCountries;

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);
    L.DomEvent.on(this.select_country, 'change', toggleCountry, this.container);

    return this.container; };

var level = L.control({position: 'topleft'});
level.onAdd = function (map) {
    this.container     = L.DomUtil.create('div');
    this.label_level   = L.DomUtil.create('label', '', this.container);
    this.select_level  = L.DomUtil.create('select', '', this.container);
    this.label_grid    = L.DomUtil.create('label', '', this.container);
    this.select_grid   = L.DomUtil.create('select', '', this.container);

    this.label_grid.for = 'grid';
    this.label_grid.innerHTML = ' with grid: ';
    this.select_grid.id = 'grid';
    this.select_grid.name = 'grid';
    this.select_grid.innerHTML = defaultMap.bases[defaultMap.defaultBase].selectGrid

    this.label_level.for = 'level';
    this.label_level.innerHTML = 'Level: ';
    this.select_level.id = 'level_size';
    this.select_level.name = 'level';
    this.select_level.innerHTML = defaultMap.bases[defaultMap.defaultBase].selectLevel;

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);

    return this.container; };

var baseLevel = L.control({position: 'topleft'});
baseLevel.onAdd = function (map) {
    this.container     = L.DomUtil.create('div');
    this.select_base   = L.DomUtil.create('select', '', this.container);

    this.select_base.id = 'base';
    this.select_base.name = 'base';
    this.select_base.innerHTML = defaultMap.selectBases;

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);
    L.DomEvent.on(this.select_base, 'change', toggleLevelBase, this.container);

    return this.container; };

var clear = L.control({position: 'topleft'});
clear.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.button.type = 'button';
    this.button.innerHTML= "Clear all";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.on(this.button, 'click', clearAll, this.container);

    return this.container; };

var fitBounds = L.control({position: 'topleft'});
fitBounds.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.label     = L.DomUtil.create('label', '', this.container);
    this.checkbox  = L.DomUtil.create('input', '', this.container);

    this.label.for= 'fitbounds';
    this.label.innerHTML= 'Fit bounds: ';
    this.checkbox.id = 'fitbounds';
    this.checkbox.type = 'checkbox';
    this.checkbox.checked = false;

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);

    return this.container; };

var fitCenter = L.control({position: 'topleft'});
fitCenter.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.label     = L.DomUtil.create('label', '', this.container);
    this.checkbox  = L.DomUtil.create('input', '', this.container);

    this.label.for= 'fitcenter';
    this.label.innerHTML= 'Fit center: ';
    this.checkbox.id = 'fitcenter';
    this.checkbox.type = 'checkbox';
    this.checkbox.checked = true;

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);

    return this.container; };

var toggleTooltip = L.control({position: 'topleft'});
toggleTooltip.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.button.type = 'button';
    this.button.innerHTML= "Toggle tooltip";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.on(this.button, 'click', toggleTooltipLayers, this.container);

    return this.container; };

var zoomAll = L.control({position: 'topleft'});
zoomAll.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.button.type = 'button';
    this.button.innerHTML= "Zoom all";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.on(this.button, 'click', function(e){map.fitBounds(layerPolygonAll.getBounds())}, this.container);

    return this.container; };

zoom.addTo(map);
layers.addTo(map);
escala.addTo(map);
country.addTo(map);
searchJurisdiction.addTo(map);
searchDecode.addTo(map);
searchEncode.addTo(map);
baseLevel.addTo(map);
level.addTo(map);
clear.addTo(map);
fitBounds.addTo(map);
fitCenter.addTo(map);
toggleTooltip.addTo(map);
searchDecodeList.addTo(map);
zoomAll.addTo(map);

var a = document.getElementById('custom-map-controls');
a.appendChild(country.getContainer());
a.appendChild(searchJurisdiction.getContainer());
a.appendChild(searchDecode.getContainer());
a.appendChild(searchEncode.getContainer());
a.appendChild(baseLevel.getContainer());
a.appendChild(level.getContainer());
a.appendChild(clear.getContainer());
a.appendChild(fitBounds.getContainer());
a.appendChild(fitCenter.getContainer());
a.appendChild(toggleTooltip.getContainer());
a.appendChild(searchDecodeList.getContainer());
a.appendChild(zoomAll.getContainer());

function clearAllLayers()
{
    layerPolygonCurrent.clearLayers();
    layerPolygonAll.clearLayers();
    layerMarkerCurrent.clearLayers();
    layerMarkerAll.clearLayers();
}

function clearAll()
{
    clearAllLayers();

    map.setView(defaultMap.center, defaultMap.zoom);

    document.getElementById('listtextsearchbar').value = '';
    document.querySelector('#base').value = defaultMap.defaultBase;
    document.querySelector('#country').value = defaultMap.isocode;
    document.querySelector('#grid').value = '';
    document.getElementById('base').innerHTML = defaultMap.selectBases;
    toggleLevelBase()
}

function toggleCountry()
{
    document.getElementById('listtextsearchbar').value = '';

    clearAllLayers();

    let countryValue = document.getElementById('country').value;

    map.setView(countries[countryValue].center, countries[countryValue].zoom);
    document.getElementById('base').innerHTML = countries[countryValue].selectBases;
    document.getElementById('base').value = countries[countryValue].defaultBase;

    document.getElementById('textsearchjurisdiction').placeholder = 'e.g.: ' + countries[countryValue].jurisdictionPlaceholder;

    toggleLevelBase();
}

function toggleLevelBase()
{
    let countryValue = document.getElementById('country').value;
    let baseValue = document.getElementById('base').value;

    document.getElementById('level_size').innerHTML = countries[countryValue].bases[baseValue].selectLevel;
    document.getElementById('grid').innerHTML = countries[countryValue].bases[baseValue].selectGrid;

    document.getElementById('textsearchbar').placeholder = 'geocode, e.g.: ' + countries[countryValue].bases[baseValue].placeholderDecode;
    document.getElementById('listtextsearchbar').placeholder = 'list geocodes, e.g.: ' + countries[countryValue].bases[baseValue].placeholderList;
    document.getElementById('latlngtextbar').placeholder = 'lat,lng, e.g.: ' + countries[countryValue].bases[baseValue].placeholderEncode;
}

function toggleTooltipLayers()
{
    map.eachLayer(function(l)
    {
        if (l.getTooltip())
        {
            var tooltip = l.getTooltip();
            l.unbindTooltip();
            toggleTooltipStatus ? tooltip.options.permanent = false : tooltip.options.permanent = true
            l.bindTooltip(tooltip)
        }
    })

    toggleTooltipStatus ? toggleTooltipStatus = false : toggleTooltipStatus = true;
}

function searchDecodeGgeocode(data)
{
    let input = document.getElementById('textsearchbar').value

    if(input !== null && input !== '')
    {
        var uri = uri_base + "/geo:osmcodes:" + input.toUpperCase() + ".json"

        loadGeojson(uri,[layerPolygonCurrent,layerPolygonAll],loadGeojsonFitCenter);
        document.getElementById('textsearchbar').value = '';
    }
}

function searchDecodeListGgeocode(data)
{
    let input = document.getElementById('listtextsearchbar').value;
    let countryValue = document.getElementById('country').value;
    let baseValue = document.getElementById('base').value;

    console.log(input);
    if(input !== null && input !== '')
    {
        var uri = uri_base + "/geo:osmcodes:" + countryValue.toUpperCase() + countries[countryValue].bases[baseValue].symbol + sortAndRemoveDuplicates(input.toUpperCase()) + ".json"

        loadGeojson(uri,[layerPolygonCurrent,layerPolygonAll],loadGeojsonFitCenter);
        document.getElementById('listtextsearchbar').value = '';

        checkCountry(input);
    }
}

function searchDecodeJurisdiction(data)
{
    let input = document.getElementById('textsearchjurisdiction').value
    let jcover = document.getElementById('jcover')

    if(input !== null && input !== '')
    {
        var uri = uri_base + "/geo:iso_ext:" + input + ".json" + (jcover.checked ? '/cover' : '') + (document.getElementById('base').value == 'base16h' ? '/base16h' : '')

        loadGeojson(uri,[layerPolygonCurrent,layerPolygonAll],loadGeojsonFitCenter);
        document.getElementById('textsearchjurisdiction').value = '';

        checkCountry(input);
    }
}

function searchEncodeGgeocode(data)
{
    let input = document.getElementById('latlngtextbar').value

    if(input !== null && input !== '')
    {
        let level = document.getElementById('level_size').value
        let grid = document.getElementById('grid')
        let base = document.getElementById('base')
        var uri = uri_base + "/geo:" + (input.match(/.*;u=.*/) ? input : input + ";u=" + level ) + ".json" + (base.value != 'base32' ? '/' + base.value : '') + (grid.value ? '/' + grid.value : '')

        var popupContent = "latlng: " + input;
        layerPolygonCurrent.clearLayers();
        layerMarkerCurrent.clearLayers();
        L.marker(input.split(/[;,]/,2)).addTo(layerMarkerCurrent).bindPopup(popupContent);
        L.marker(input.split(/[;,]/,2)).addTo(layerMarkerAll).bindPopup(popupContent);
        loadGeojson(uri,[layerPolygonCurrent,layerPolygonAll],loadGeojsonFitCenter)
        document.getElementById('latlngtextbar').value = '';
    }
}

function sortAndRemoveDuplicates(value) {

    let listValues = [...new Set(value.trim().split(/[\n,]+/).map(i => i.trim().substring(0,11)))];

    return listValues.sort().join(",");
}

function onEachFeature(feature,layer)
{
    if (feature.properties.osm_id)
    {
        var popupContent = "";
        popupContent += "osm_id: " + feature.properties.osm_id + "<br>";
        popupContent += "jurisd_base_id: " + feature.properties.jurisd_base_id + "<br>";
        popupContent += "jurisd_local_id: " + feature.properties.jurisd_local_id + "<br>";
        popupContent += "parent_id: " + feature.properties.parent_id + "<br>";
        popupContent += "admin_level: " + feature.properties.admin_level + "<br>";
        popupContent += "name: " + feature.properties.name + "<br>";
        popupContent += "parent_abbrev: " + feature.properties.parent_abbrev + "<br>";
        popupContent += "abbrev: " + feature.properties.abbrev + "<br>";
        popupContent += "wikidata_id: " + feature.properties.wikidata_id + "<br>";
        popupContent += "lexlabel: " + feature.properties.lexlabel + "<br>";
        popupContent += "isolabel_ext: " + feature.properties.isolabel_ext + "<br>";
        popupContent += "lex_urn: " + feature.properties.lex_urn + "<br>";
        popupContent += "name_en: " + feature.properties.name_en + "<br>";
        popupContent += "isolevel: " + feature.properties.isolevel + "<br>";
        popupContent += "area: " + feature.properties.area + "<br>";
        popupContent += "jurisd_base_id: " + feature.properties.jurisd_base_id + "<br>";

        layer.bindPopup(popupContent);
    }
    else
    {
        sufix_area =(feature.properties.area<1000000)? 'm2': 'km2';
        value_area =(feature.properties.area<1000000)? feature.properties.area: Math.round((feature.properties.area*100/1000000))/100;
        sufix_side =(feature.properties.side<1000)? 'm': 'km';
        value_side =(feature.properties.side<1000)? Math.round(feature.properties.side*100.0)/100 : Math.round(feature.properties.side*100.0/1000)/100;

        var popupContent = "";
        popupContent += "Code: " + feature.properties.code + "<br>";
        popupContent += "Area: " + value_area + " " + sufix_area + "<br>";
        popupContent += "Side: " + value_side + " " + sufix_side + "<br>";

        if(feature.properties.short_code )
        {
            popupContent += "Short code: " + feature.properties.short_code + "<br>";
        }

        if(feature.properties.prefix )
        {
            popupContent += "Prefix: " + feature.properties.prefix + "<br>";
        }

        if(feature.properties.code_subcell )
        {
            popupContent += "Code_subcell: " + feature.properties.code_subcell + "<br>";
        }

        layer.bindPopup(popupContent);

        if(feature.properties.code_subcell)
        {
            var layerTooltip = feature.properties.code_subcell;
        }
        else if(feature.properties.short_code)
        {
            var layerTooltip = '.' + feature.properties.short_code.split(/[~]/)[1];
        }
        else if(feature.properties.index)
        {
            var layerTooltip = '.' + feature.properties.index
        }
        else
        {
            var layerTooltip = feature.properties.code;
        }
        layer.bindTooltip(layerTooltip,{permanent:toggleTooltipStatus,direction:'center',className:'tooltip' + feature.properties.base});
    }

    if(!feature.properties.code_subcell && !feature.properties.osm_id)
    {
        let listBar = document.getElementById('listtextsearchbar');

        listBar.value = sortAndRemoveDuplicates((listBar.value ? listBar.value + ',': '') + feature.properties.code)
    }

    layer.on({click: onFeatureClick});
}

function style(feature)
{
    let grid = document.getElementById('grid')

    if(grid.value.match(/^grid(3|5|9|17|33)$/))
    {
        if (feature.properties.code_subcell)
        {
            return {color: 'deeppink'};
        }
        else
        {
            return {color: 'deeppink', fillColor: 'none'};
        }
    }
    else
    {
        if (feature.properties.osm_id)
        {
            return {color: 'red', fillColor: 'none', fillOpacity: 0.1};
        }
        else
        {
            return {color: 'black', fillColor: 'black', fillOpacity: 0.1};
        }
    }
}

function pointToLayer(feature,latlng)
{
    return L.circleMarker(latlng,{
        radius: 3,
        weight: 1,
        opacity: 0.8,
        fillOpacity: 0.6,
    });
}

function onFeatureClick(feature)
{
    //console.log(feature);
    //var label = feature.sourceTarget.feature.properties.label;
}

function loadGeojsonFitCenterlayerCurrent(featureGroup)
{
    map.fitBounds(featureGroup.getBounds());
}

function loadGeojsonFitCenter(featureGroup)
{
    let fitbd = document.getElementById('fitbounds')
    let fitce = document.getElementById('fitcenter')
    fitbd.checked ? map.fitBounds(featureGroup.getBounds()) : (fitce.checked ? map.setView(featureGroup.getBounds().getCenter()) : '')
}

function loadGeojson(uri,arrayLayer,afterLoad)
{
    fetch(uri)
    .then(response => {return response.json()})
    .then(data =>
    {
        arrayLayer[0].clearLayers();

        for (i=0; i < arrayLayer.length; i++)
        {
            arrayLayer[i].addData(data.features);
        }

        afterLoad(arrayLayer[0]);
    })
    .catch(err => {})
}

function onMapClick(e)
{
    let level = document.getElementById('level_size').value
    let grid = document.getElementById('grid')
    let base = document.getElementById('base')
    var uri = uri_base + "/geo:" + e.latlng['lat'] + "," + e.latlng['lng'] + ";u=" + level + ".json" + (base.value != 'base32' ? '/' + base.value : '') + (grid.value ? '/' + grid.value : '')
    var popupContent = "latlng: " + e.latlng['lat'] + "," + e.latlng['lng'];

    layerMarkerCurrent.clearLayers();

    L.marker(e.latlng).addTo(layerMarkerCurrent).bindPopup(popupContent);
    L.marker(e.latlng).addTo(layerMarkerAll).bindPopup(popupContent);

    loadGeojson(uri,[layerPolygonCurrent,layerPolygonAll],loadGeojsonFitCenter)
}

function showZoomLevel()
{
    document.getElementById('zoom').innerHTML = map.getZoom();
}

function checkCountry(string)
{
    for(var key in countries)
    {
        let regex = new RegExp("^/?" + key + ".*","i");

        if(regex.test(string))
        {
            document.getElementById('country').value = key;
            toggleCountry();
            break;
        }
    }
}

var uri = window.location.href;
let pathname = window.location.pathname;

function checkBase(string)
{
    for(var key in countries)
    {
        let regex = new RegExp("^/?" + key + ".*","i");

        if(regex.test(string))
        {
            let regex2 = /\+/;

            if(regex2.test(string))
            {
                document.getElementById('base').value = countries[key].scientificBase;
            }
            else
            {
                document.getElementById('base').value = countries[key].postalcodeBase;
            }
            toggleLevelBase();
            break;
        }
    }
}

if(pathname !== "/view/")
{
    if (pathname.match(/\/base16\/grid/))
    {
        var uriApi = uri.replace(/(\/base16\/grid)/, ".json$1");
    }
    else if (pathname.match(/(\/base16h)?\/grid/))
    {
        var uriApi = uri.replace(/((\/base16h)?\/grid)/, ".json$1");
    }
    else if (pathname.match(/\/[A-Z]{2}~[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+(,[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+)*$/i))
    {
        var uriApi = uri.replace(/\/([A-Z]{2}~[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+(,[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+)*)$/i, "/geo:osmcodes:$1.json");
    }
    else if (pathname.match(/\/[A-Z]{2}\+[0123456789ABCDEF]+([GHJKLMNPQRSTVZ])?$/i))
    {
        var uriApi = uri.replace(/\/([A-Z]{2}\+[0123456789ABCDEF]+([GHJKLMNPQRSTVZ])?)$/i, "/geo:osmcodes:$1.json");
    }
    else if (pathname.match(/\/CO-\d+$/i))
    {
        var uriApi = uri.replace(/\/CO-(\d+)$/i, "/geo:co-divipola:$1.json");
    }
    else if (pathname.match(/^\/([A-Z]{2})-\d+(~|-)[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+$/i))
    {
        var uriApi = uri.replace(/\/(([A-Z]{2})-\d+(~|-)[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+)$/i, "/geo:osmcodes:$1.json");
    }
    else if (pathname.match(/\/BR-\d+$/i))
    {
        var uriApi = uri.replace(/\/BR-(\d+)$/i, "/geo:br-geocodigo:$1.json");
    }
    else if (pathname.match(/^\/[A-Z]{2}(-[A-Z]{1,3}-[A-Z]+)(~|-)[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+$/i))
    {
        var uriApi = uri.replace(/\/([A-Z]{2}(-[A-Z]{1,3}-[A-Z]+)(~|-)[0123456789BCDFGHJKLMNPQRSTUVWXYZ]+)$/i, "/geo:osmcodes:$1.json");
    }
    else if (pathname.match(/^\/[A-Z]{2}-[A-Z]{1,3}-[A-Z]+$/i))
    {
        var uriApi = uri + '.json/cover';
    }
    else
    {
        var uriApi = uri + '.json';
    }
    loadGeojson(uriApi,[layerPolygonCurrent,layerPolygonAll],loadGeojsonFitCenterlayerCurrent);

    checkCountry(pathname);
    checkBase(pathname);
}
