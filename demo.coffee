
window.useMapData = (mapData) -> window.mapData = mapData
window.onload = ->
  gm = google.maps
  map = new gm.Map(
    document.getElementById('map_canvas'), 
    mapTypeId: gm.MapTypeId.SATELLITE,
    center: new gm.LatLng(50, 0), zoom: 6  # whatevs: fitBounds will override
  )
  iw = new gm.InfoWindow()
  bounds = new gm.LatLngBounds()
  
  oms = new OverlappingMarkerSpiderfier(map)
  oms.addListener 'click', (marker) ->
    iw.setContent(marker.desc)
    iw.open(map, marker)
  oms.addListener 'spiderfy', (markers) -> 
    iw.close()
  
  for datum in window.mapData
    loc = new gm.LatLng(datum.lat, datum.lon)
    bounds.extend(loc)
    marker = new gm.Marker 
      position: loc
      title: datum.h
      animation: gm.Animation.DROP
    marker.desc = datum.d
    oms.addMarker(marker)
    
  map.fitBounds(bounds)
  
  markerIndex = oms.markers.length
  chunkSize = Math.ceil(markerIndex / 20)
  showNextMarker = ->
    for i in [0...chunkSize]
      markerIndex -= 1
      return if markerIndex < 0
      oms.markers[markerIndex].setMap(map)
    setTimeout(arguments.callee, 1)
    
  showNextMarker()

  # for debugging use in console
  window.map = map
  window.oms = oms