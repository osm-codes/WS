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

var layerPolygonCurrent = new L.LayerGroup();
var layerPolygonAll = new L.LayerGroup();
var layerMarkerCurrent = new L.LayerGroup();
var layerMarkerAll = new L.LayerGroup();

var overlays = {
    'Current polygon': layerPolygonCurrent,
    'All polygon': layerPolygonAll,
    'Current marker': layerMarkerCurrent,
    'All markers': layerMarkerAll };

var mapOptions = {
    center: [3.5,-72.3],
    zoom: 6,
    current_zoom: 6 };

var map = L.map('map',{
    center: mapOptions.center,
    zoom:   mapOptions.zoom,
    zoomControl: false,
    renderer: L.svg(),
    layers: [grayscale, layerPolygonCurrent] });

var toggleTooltipStatus = true;

map.attributionControl.setPrefix(false);
map.on('zoom', function(e){mapOptions.current_zoom = map.getZoom();});
map.on('click', onMapClick);
map.on('zoomend', showZoomLevel);
showZoomLevel();

var zoom   = L.control.zoom({position:'topleft'});
var layers = L.control.layers(baseLayers, overlays,{position:'topright'});
var escala = L.control.scale({position:'bottomright',imperial: false});

var searchJurisdiction = L.control({position: 'topleft'});
searchJurisdiction.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.label     = L.DomUtil.create('label', '', this.container);
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.search.type = 'text';
    this.search.placeholder = 'e.g.: CO-ANT-Medellin';
    this.search.id = 'textsearchjurisdiction';
    this.button.type = 'button';
    this.button.innerHTML= "Jurisdiction";

    L.DomEvent.disableScrollPropagation(this.button);
    L.DomEvent.disableClickPropagation(this.button);
    L.DomEvent.disableScrollPropagation(this.search);
    L.DomEvent.disableClickPropagation(this.search);
    L.DomEvent.on(this.button, 'click', searchDecodeJurisdiction, this.container);
    L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchDecodeJurisdiction(data);}}, this.container);

    return this.container; };

var searchDecode = L.control({position: 'topleft'});
searchDecode.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.search.type = 'text';
    this.search.placeholder = 'geocode, e.g.: CO~3D5';
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

var searchEncode = L.control({position: 'topleft'});
searchEncode.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);

    this.search.type = 'text';
    this.search.placeholder = 'lat,lng, e.g.: 3.5,-72.3;u=1';
    this.search.id = 'latlngtextbar';
    this.button.type = 'button';
    this.button.innerHTML= "Encode";

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);
    L.DomEvent.on(this.button, 'click', searchEncode, this.container);
    L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchEncode(data);}}, this.container);

    return this.container; };

var level = L.control({position: 'topleft'});
level.onAdd = function (map) {
    this.container     = L.DomUtil.create('div');
    this.select_base   = L.DomUtil.create('select', '', this.container);
    this.label_level   = L.DomUtil.create('label', '', this.container);
    this.select_level  = L.DomUtil.create('select', '', this.container);
    this.label_grid    = L.DomUtil.create('label', '', this.container);
    this.checkbox_grid = L.DomUtil.create('input', '', this.container);

    this.label_grid.for = 'grid';
    this.label_grid.innerHTML = ' with grid: ';
    this.checkbox_grid.id = 'grid';
    this.checkbox_grid.type = 'checkbox';
    this.checkbox_grid.checked = false;

    this.label_level.for = 'level';
    this.label_level.innerHTML = ' Level: ';
    this.select_level.id = 'level_size';
    this.select_level.name = 'level';
    this.select_level.innerHTML = '<option value="100000">0 (1)(+50km)</option><option value="50000">2.5 (2)(50km)</option><option value="5000">5 (3)(5km)</option><option value="1000">7.5 (4)(1km)</option><option value="200">10 (5)(200m)</option><option value="40">12.5 (6)(40m)</option><option value="8">15 (7)(8m)</option><option value="1">17.5 (8)(1m)</option>';

    this.select_base.id = 'base';
    this.select_base.name = 'base';
    this.select_base.innerHTML = '<option value="32">base32</option><option value="16">base16h</option>';

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
    L.DomEvent.on(this.button, 'click', function(e){layerPolygonCurrent.clearLayers(); layerPolygonAll.clearLayers(); layerMarkerCurrent.clearLayers(); layerMarkerAll.clearLayers(); map.setView(mapOptions.center, mapOptions.zoom);}, this.container);

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

function toggleLevelBase()
{
    if(document.getElementById('base').value == 16)
    {
        document.getElementById('level_size').innerHTML = '<option value="300000">0 (2)(+250km)</option><option value="250000">0.5 (3)(250km)</option><option value="150000">1 (3)(150km)</option><option value="100000">1.5 (3)(100km)</option><option value="75000">2 (3)(75km)</option><option value="50000">2.5 (4)(50km)</option><option value="40000">3 (4)(40km)</option><option value="25000">3.5 (4)(25km)</option><option value="20000">4 (4)(20km)</option><option value="13000">4.5 (5)(13km)</option><option value="10000">5 (5)(10km)</option><option value="7000">5.5 (5)(7km)</option><option value="5000">6 (5)(5km)</option><option value="3500">6.5 (6)(3.5km)</option><option value="2500">7 (6)(2.5km)</option><option value="1750">7.5 (6)(1750m)</option><option value="1250">8 (6)(1250m)</option><option value="900">8.5 (7)(900m)</option><option value="600">9 (7)(600m)</option><option value="450">9.5 (7)(450m)</option><option value="300">10 (7)(300m)</option><option value="200">10.5 (8)(200m)</option><option value="150">11 (8)(150m)</option><option value="100">11.5 (8)(100m)</option><option value="75">12 (8)(75m)</option><option value="50">12.5 (9)(50m)</option><option value="40">13 (9)(40m)</option><option value="25">13.5 (9)(25m)</option><option value="20">14 (9)(20m)</option><option value="15">14.5 (10)(15m)</option><option value="10">15 (10)(10m)</option><option value="7">15.5 (10)(7m)</option><option value="5">16 (10)(5m)</option><option value="3">16.5 (11)(3)</option><option value="2">17 (11)(2m)</option><option value="1">17.5 (11)(1.5m)</option><option value="0">18 (11)(1m)</option>';
    }
    else
    {
        document.getElementById('level_size').innerHTML = '<option value="100000">0 (1)(+50km)</option><option value="50000">2.5 (2)(50km)</option><option value="5000">5 (3)(5km)</option><option value="1000">7.5 (4)(1km)</option><option value="200">10 (5)(200m)</option><option value="40">12.5 (6)(40m)</option><option value="8">15 (7)(8m)</option><option value="1">17.5 (8)(1m)</option>';
    }
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
        var uri = "https://osm.codes/" + input.toUpperCase() + ".json"

        layerPolygonCurrent.clearLayers();
        loadGeojson(uri,style,onEachFeature);
        document.getElementById('textsearchbar').value = '';
    }
}

function searchDecodeJurisdiction(data)
{
    let input = document.getElementById('textsearchjurisdiction').value

    if(input !== null && input !== '')
    {
        var uri = "https://osm.codes/geo:iso_ext:" + input + ".json"

        layerPolygonCurrent.clearLayers();
        loadGeojson(uri,style,onEachFeature);
        document.getElementById('textsearchjurisdiction').value = '';
    }
}

function searchEncode(data)
{
    let input = document.getElementById('latlngtextbar').value

    if(input !== null && input !== '')
    {
        let level = document.getElementById('level_size').value
        let grid = document.getElementById('grid')
        let base = document.getElementById('base')
        var uri = "https://osm.codes/geo:" + (input.match(/.*;u=.*/) ? input : input + ";u=" + level ) + ".json" + (base.value == 16 ? '/to_16h' : '') + (grid.checked ? '/grid' : '')

        var popupContent = "latlng: " + input;
        layerPolygonCurrent.clearLayers();
        layerMarkerCurrent.clearLayers();
        L.marker(input.split(/[;,]/,2)).addTo(layerMarkerCurrent).bindPopup(popupContent);
        L.marker(input.split(/[;,]/,2)).addTo(layerMarkerAll).bindPopup(popupContent);
        loadGeojson(uri,style,onEachFeature)
        document.getElementById('latlngtextbar').value = '';
    }
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
            layer.bindTooltip(feature.properties.code_subcell,{permanent:toggleTooltipStatus,direction:'center',className:'tooltip' + feature.properties.base});
        }
        else if(feature.properties.short_code)
        {
            layer.bindTooltip(feature.properties.short_code,{permanent:toggleTooltipStatus,direction:'center',className:'tooltip' + feature.properties.base});
        }
        else
        {
            layer.bindTooltip(feature.properties.code,{permanent:toggleTooltipStatus,direction:'center',className:'tooltip' + feature.properties.base});
        }
    }
}

function style(feature)
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

function loadGeojson(uri,style,onEachFeature)
{
    fetch(uri)
    .then(response => {return response.json()})
    .then(data =>
    {
        let geojsonCurrent = L.geoJSON(data.features,{
            style: style,
            onEachFeature: onEachFeature,
        }).addTo(layerPolygonCurrent);

        let fitbd = document.getElementById('fitbounds')
        let fitce = document.getElementById('fitcenter')
        fitbd.checked ? map.fitBounds(geojsonCurrent.getBounds()) : (fitce.checked ? map.setView(geojsonCurrent.getBounds().getCenter()) : '')

        let geojsonAll = L.geoJSON(data.features,{
            style: style,
            onEachFeature: onEachFeature,
        }).addTo(layerPolygonAll);
    })
    .catch(err => {})
}

function onMapClick(e)
{
    let level = document.getElementById('level_size').value
    let grid = document.getElementById('grid')
    let base = document.getElementById('base')
    var uri = "https://osm.codes/geo:" + e.latlng['lat'] + "," + e.latlng['lng'] + ";u=" + level + ".json" + (base.value == 16 ? '/to_16h' : '') + (grid.checked ? '/grid' : '')
    var popupContent = "latlng: " + e.latlng['lat'] + "," + e.latlng['lng'];

    layerPolygonCurrent.clearLayers();
    layerMarkerCurrent.clearLayers();

    L.marker(e.latlng).addTo(layerMarkerCurrent).bindPopup(popupContent);
    L.marker(e.latlng).addTo(layerMarkerAll).bindPopup(popupContent);

    loadGeojson(uri,style,onEachFeature)
}

function showZoomLevel()
{
    document.getElementById('zoom').innerHTML = map.getZoom();
}

zoom.addTo(map);
layers.addTo(map);
escala.addTo(map);
searchJurisdiction.addTo(map);
searchDecode.addTo(map);
searchEncode.addTo(map);
level.addTo(map);
clear.addTo(map);
fitBounds.addTo(map);
fitCenter.addTo(map);
toggleTooltip.addTo(map);
//zoomAll.addTo(map);

var uri = window.location.href;
let pathname = window.location.pathname;

if(pathname !== "/view/")
{
    if (pathname.match(/\/to_16h/))
    {
        loadGeojson(uri.replace(/\/to_16h/, ".json/to_16h"),style,onEachFeature);
    }
    else if (pathname.match(/\/to_16h\/grid/))
    {
        loadGeojson(uri.replace(/\/to_16h\/grid/, ".json/to_16h/grid"),style,onEachFeature);
    }
    else if (pathname.match(/\/grid/))
    {
        loadGeojson(uri.replace(/\/grid/, ".json/grid"),style,onEachFeature);
    }
    else
    {
        loadGeojson(uri + '.json',style,onEachFeature);
    }
    var regex = /\+/;
    if(regex.test(pathname))
    {
        document.getElementById('base').value = 16;
        toggleLevelBase();
    }
}

var a = document.getElementById('custom-map-controls');
a.appendChild(searchJurisdiction.getContainer());
a.appendChild(searchDecode.getContainer());
a.appendChild(searchEncode.getContainer());
a.appendChild(level.getContainer());
a.appendChild(clear.getContainer());
a.appendChild(fitBounds.getContainer());
a.appendChild(fitCenter.getContainer());
a.appendChild(toggleTooltip.getContainer());
