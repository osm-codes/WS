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

var precision = L.control({position: 'topleft'});
precision.onAdd = function (map) {
    this.container = L.DomUtil.create('div');
    this.search    = L.DomUtil.create('input', '', this.container);
    this.button    = L.DomUtil.create('button','leaflet-control-button',this.container);
    this.label     = L.DomUtil.create('label', '', this.container);
    this.select    = L.DomUtil.create('select', '', this.container);
    this.label2    = L.DomUtil.create('label', '', this.container);
    this.checkbox  = L.DomUtil.create('input', '', this.container);
    this.label3    = L.DomUtil.create('label', '', this.container);
    this.checkbox3 = L.DomUtil.create('input', '', this.container);

    this.label2.for= 'grid';
    this.label2.innerHTML= ' view child cells: ';
    this.checkbox.id = 'grid';
    this.checkbox.type = 'checkbox';
    this.checkbox.checked = false;

    this.label3.for= 'to_16h';
    this.label3.innerHTML= ' to_16h: ';
    this.checkbox3.id = 'to_16h';
    this.checkbox3.type = 'checkbox';
    this.checkbox3.checked = false;

    this.search.type = 'text';
    this.search.placeholder = 'lat,lng, e.g.: 3.5,-72.3;u=1';
    this.search.id = 'latlngtextbar';
    this.button.type = 'button';
    this.button.innerHTML= "Encode";
    this.select.id = 'digits_size';
    this.select.name = 'dig';
    this.select.innerHTML = '<option value="100000">1</option><option value="50000">2</option><option value="5000">3</option><option value="1000">4</option><option value="200">5</option><option value="40">6</option><option value="8">7</option><option value="1">8</option>';
    this.label.for= 'dig';
    this.label.innerHTML= '<br>Digits: ';

    L.DomEvent.disableScrollPropagation(this.container);
    L.DomEvent.disableClickPropagation(this.container);
    L.DomEvent.on(this.button, 'click', searchEncode, this.container);
    L.DomEvent.on(this.search, 'keyup', function(data){if(data.keyCode === 13){searchEncode(data);}}, this.container);

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
        let dig = document.getElementById('digits_size').value
        let grid = document.getElementById('grid')
        let to_16h = document.getElementById('to_16h')
        var uri = "https://osm.codes/geo:" + (input.match(/.*;u=.*/) ? input : input + ";u=" + dig ) + ".json" + (to_16h.checked ? '/to_16h' : '') + (grid.checked ? '/grid' : '')

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
            layer.bindTooltip(feature.properties.code_subcell,{permanent:toggleTooltipStatus,direction:'center'});
        }
        else if(feature.properties.short_code)
        {
            layer.bindTooltip(feature.properties.short_code,{permanent:toggleTooltipStatus,direction:'center'});
        }
        else
        {
            layer.bindTooltip(feature.properties.code,{permanent:toggleTooltipStatus,direction:'center'});
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
    let dig = document.getElementById('digits_size').value
    let grid = document.getElementById('grid')
    var uri = "https://osm.codes/geo:" + e.latlng['lat'] + "," + e.latlng['lng'] + ";u=" + dig + ".json" + (to_16h.checked ? '/to_16h' : '') + (grid.checked ? '/grid' : '')
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

layers.addTo(map);
escala.addTo(map);
zoom.addTo(map);
searchJurisdiction.addTo(map);
searchDecode.addTo(map);
precision.addTo(map);
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
}
