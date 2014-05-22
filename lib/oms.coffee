###* @preserve OverlappingMarkerSpiderfier
https://github.com/jawj/OverlappingMarkerSpiderfier
Copyright (c) 2011 - 2013 George MacKerron
Released under the MIT licence: http://opensource.org/licenses/mit-license
Note: The Google Maps API v3 must be included *before* this code
###

# NB. string literal properties -- object['key'] -- are for Closure Compiler ADVANCED_OPTIMIZATION

#return unless this['google']?['maps']?  # return from wrapper func without doing anything

class @['OverlappingMarkerSpiderfier']
  p = @::  # this saves a lot of repetition of .prototype that isn't optimized away
  x['VERSION'] = '0.3.3' for x in [@, p]  # better on @, but defined on p too for backward-compat
  
  gm = google.maps
  ge = gm.event
  mt = gm.MapTypeId
  twoPi = Math.PI * 2
  
  p['keepSpiderfied']  = no          # yes -> don't unspiderfy when a marker is selected
  p['markersWontHide'] = no          # yes -> a promise you won't hide markers, so we needn't check
  p['markersWontMove'] = no          # yes -> a promise you won't move markers, so we needn't check

  p['nearbyDistance'] = 20           # spiderfy markers within this range of the one clicked, in px
  
  p['circleSpiralSwitchover'] = 9    # show spiral instead of circle from this marker count upwards
                                     # 0 -> always spiral; Infinity -> always circle
  p['circleFootSeparation'] = 23     # related to circumference of circle
  p['circleStartAngle'] = twoPi / 12
  p['spiralFootSeparation'] = 26     # related to size of spiral (experiment!)
  p['spiralLengthStart'] = 11        # ditto
  p['spiralLengthFactor'] = 4        # ditto
  
  p['spiderfiedZIndex'] = 1000       # ensure spiderfied markers are on top
  p['usualLegZIndex'] = 10           # for legs
  p['highlightedLegZIndex'] = 20     # ensure highlighted leg is always on top
  p['event'] = 'click'               # Event to use when we want to trigger spiderify
  p['minZoomLevel'] = no             # Minimum zoom level necessary to trigger spiderify
  
  p['legWeight'] = 1.5
  p['legColors'] =
    'usual': {}
    'highlighted': {}
  
  lcU = p['legColors']['usual']
  lcH = p['legColors']['highlighted']
  lcU[mt.HYBRID]  = lcU[mt.SATELLITE] = '#fff'
  lcH[mt.HYBRID]  = lcH[mt.SATELLITE] = '#f00'
  lcU[mt.TERRAIN] = lcU[mt.ROADMAP]   = '#444'
  lcH[mt.TERRAIN] = lcH[mt.ROADMAP]   = '#f00'
  
  # Note: it's OK that this constructor comes after the properties, because a function defined by a 
  # function declaration can be used before the function declaration itself
  constructor: (@map, opts = {}) ->
    (@[k] = v) for own k, v of opts
    @projHelper = new @constructor.ProjHelper(@map)
    @initMarkerArrays()
    @listeners = {}
    for e in ['click', 'zoom_changed', 'maptypeid_changed']
      ge.addListener(@map, e, => @['unspiderfy']())
    
  p.initMarkerArrays = ->
    @markers = []
    @markerListenerRefs = []
    
  p['addMarker'] = (marker) ->
    return @ if marker['_oms']?
    marker['_oms'] = yes
    listenerRefs = [ge.addListener(marker, @['event'], (event) => @spiderListener(marker, event))]
    unless @['markersWontHide']
      listenerRefs.push(ge.addListener(marker, 'visible_changed', => @markerChangeListener(marker, no)))
    unless @['markersWontMove']
      listenerRefs.push(ge.addListener(marker, 'position_changed', => @markerChangeListener(marker, yes)))
    @markerListenerRefs.push(listenerRefs)
    @markers.push(marker)
    @  # return self, for chaining

  p.markerChangeListener = (marker, positionChanged) ->
    if marker['_omsData']? and (positionChanged or not marker.getVisible()) and not (@spiderfying? or @unspiderfying?)
      @['unspiderfy'](if positionChanged then marker else null)
      
  p['getMarkers'] = -> @markers[0..]  # returns a copy, so no funny business

  p['removeMarker'] = (marker) ->
    @['unspiderfy']() if marker['_omsData']?  # otherwise it'll be stuck there forever!
    i = @arrIndexOf(@markers, marker)
    return @ if i < 0
    listenerRefs = @markerListenerRefs.splice(i, 1)[0]
    ge.removeListener(listenerRef) for listenerRef in listenerRefs
    delete marker['_oms']
    @markers.splice(i, 1)
    @  # return self, for chaining
    
  p['clearMarkers'] = ->
    @['unspiderfy']()
    for marker, i in @markers
      listenerRefs = @markerListenerRefs[i]
      ge.removeListener(listenerRef) for listenerRef in listenerRefs
      delete marker['_oms']
    @initMarkerArrays()
    @  # return self, for chaining
        
  # available listeners: click(marker), spiderfy(markers), unspiderfy(markers)
  p['addListener'] = (event, func) ->
    (@listeners[event] ?= []).push(func)
    @  # return self, for chaining
    
  p['removeListener'] = (event, func) ->
    i = @arrIndexOf(@listeners[event], func)
    @listeners[event].splice(i, 1) unless i < 0
    @  # return self, for chaining
  
  p['clearListeners'] = (event) ->
    @listeners[event] = []
    @  # return self, for chaining
  
  p.trigger = (event, args...) ->
    func(args...) for func in (@listeners[event] ? [])
  
  p.generatePtsCircle = (count, centerPt) ->
    circumference = @['circleFootSeparation'] * (2 + count)
    legLength = circumference / twoPi  # = radius from circumference
    angleStep = twoPi / count
    for i in [0...count]
      angle = @['circleStartAngle'] + i * angleStep
      new gm.Point(centerPt.x + legLength * Math.cos(angle), 
                   centerPt.y + legLength * Math.sin(angle))
  
  p.generatePtsSpiral = (count, centerPt) ->
    legLength = @['spiralLengthStart']
    angle = 0
    for i in [0...count]
      angle += @['spiralFootSeparation'] / legLength + i * 0.0005
      pt = new gm.Point(centerPt.x + legLength * Math.cos(angle), 
                        centerPt.y + legLength * Math.sin(angle))
      legLength += twoPi * @['spiralLengthFactor'] / angle
      pt
  
  p.spiderListener = (marker, event) ->
    markerSpiderfied = marker['_omsData']?
    unless markerSpiderfied and @['keepSpiderfied']
      if this['event'] is 'mouseover'
        $this = @
        clear = () -> $this['unspiderfy']()
        window.clearTimeout(p.timeout)
        p.timeout = setTimeout clear, 3000
      else
        @['unspiderfy']()
    if markerSpiderfied or @map.getStreetView().getVisible() or @map.getMapTypeId() is 'GoogleEarthAPI'  # don't spiderfy in Street View or GE Plugin!
      @trigger('click', marker, event)
    else
      nearbyMarkerData = []
      nonNearbyMarkers = []
      nDist = @['nearbyDistance']
      pxSq = nDist * nDist
      markerPt = @llToPt(marker.position)
      for m in @markers
        continue unless m.map? and m.getVisible()  # at 2011-08-12, property m.visible is undefined in API v3.5
        mPt = @llToPt(m.position)
        if @ptDistanceSq(mPt, markerPt) < pxSq
          nearbyMarkerData.push(marker: m, markerPt: mPt)
        else
          nonNearbyMarkers.push(m)
      if nearbyMarkerData.length is 1  # 1 => the one clicked => none nearby
        @trigger('click', marker, event)
      else
        @spiderfy(nearbyMarkerData, nonNearbyMarkers)
  
  p['markersNearMarker'] = (marker, firstOnly = no) ->
    unless @projHelper.getProjection()?
      throw "Must wait for 'idle' event on map before calling markersNearMarker"
    nDist = @['nearbyDistance']
    pxSq = nDist * nDist
    markerPt = @llToPt(marker.position)
    markers = []
    for m in @markers
      continue if m is marker or not m.map? or not m.getVisible()
      mPt = @llToPt(m['_omsData']?.usualPosition ? m.position)
      if @ptDistanceSq(mPt, markerPt) < pxSq
        markers.push(m)
        break if firstOnly
    markers
  
  p['markersNearAnyOtherMarker'] = ->  # *very* much quicker than calling markersNearMarker in a loop
    unless @projHelper.getProjection()?
      throw "Must wait for 'idle' event on map before calling markersNearAnyOtherMarker"
    nDist = @['nearbyDistance']
    pxSq = nDist * nDist
    mData = for m in @markers
      {pt: @llToPt(m['_omsData']?.usualPosition ? m.position), willSpiderfy: no}
    for m1, i1 in @markers
      continue unless m1.map? and m1.getVisible()
      m1Data = mData[i1]
      continue if m1Data.willSpiderfy
      for m2, i2 in @markers
        continue if i2 is i1
        continue unless m2.map? and m2.getVisible()
        m2Data = mData[i2]
        continue if i2 < i1 and not m2Data.willSpiderfy
        if @ptDistanceSq(m1Data.pt, m2Data.pt) < pxSq
          m1Data.willSpiderfy = m2Data.willSpiderfy = yes
          break
    m for m, i in @markers when mData[i].willSpiderfy
  
  p.makeHighlightListenerFuncs = (marker) ->
    highlight: 
      => marker['_omsData'].leg.setOptions
        strokeColor: @['legColors']['highlighted'][@map.mapTypeId]
        zIndex: @['highlightedLegZIndex']
    unhighlight: 
      => marker['_omsData'].leg.setOptions
        strokeColor: @['legColors']['usual'][@map.mapTypeId]
        zIndex: @['usualLegZIndex']
  
  p.spiderfy = (markerData, nonNearbyMarkers) ->
    if @['minZoomLevel'] and @map.getZoom() < @['minZoomLevel']
      return no

    @spiderfying = yes
    numFeet = markerData.length
    bodyPt = @ptAverage(md.markerPt for md in markerData)
    footPts = if numFeet >= @['circleSpiralSwitchover'] 
      @generatePtsSpiral(numFeet, bodyPt).reverse()  # match from outside in => less criss-crossing
    else
      @generatePtsCircle(numFeet, bodyPt)
    spiderfiedMarkers = for footPt in footPts
      footLl = @ptToLl(footPt)
      nearestMarkerDatum = @minExtract(markerData, (md) => @ptDistanceSq(md.markerPt, footPt))
      marker = nearestMarkerDatum.marker
      leg = new gm.Polyline
        map: @map
        path: [marker.position, footLl]
        strokeColor: @['legColors']['usual'][@map.mapTypeId]
        strokeWeight: @['legWeight']
        zIndex: @['usualLegZIndex']
      marker['_omsData'] = 
        usualPosition: marker.position
        leg: leg
      unless @['legColors']['highlighted'][@map.mapTypeId] is
             @['legColors']['usual'][@map.mapTypeId]
        highlightListenerFuncs = @makeHighlightListenerFuncs(marker)
        marker['_omsData'].hightlightListeners =
          highlight:   ge.addListener(marker, 'mouseover', highlightListenerFuncs.highlight)
          unhighlight: ge.addListener(marker, 'mouseout',  highlightListenerFuncs.unhighlight)
      marker.setPosition(footLl)
      marker.setZIndex(Math.round(@['spiderfiedZIndex'] + footPt.y))  # lower markers cover higher
      marker
    delete @spiderfying
    @spiderfied = yes
    @trigger('spiderfy', spiderfiedMarkers, nonNearbyMarkers)
  
  p['unspiderfy'] = (markerNotToMove = null) ->
    return @ unless @spiderfied?
    @unspiderfying = yes
    unspiderfiedMarkers = []
    nonNearbyMarkers = []
    for marker in @markers
      if marker['_omsData']?
        marker['_omsData'].leg.setMap(null)
        marker.setPosition(marker['_omsData'].usualPosition) unless marker is markerNotToMove
        marker.setZIndex(null)
        listeners = marker['_omsData'].hightlightListeners
        if listeners?
          ge.removeListener(listeners.highlight)
          ge.removeListener(listeners.unhighlight)
        delete marker['_omsData']
        unspiderfiedMarkers.push(marker)
      else
        nonNearbyMarkers.push(marker)
    delete @unspiderfying
    delete @spiderfied
    @trigger('unspiderfy', unspiderfiedMarkers, nonNearbyMarkers)
    @  # return self, for chaining
  
  p.ptDistanceSq = (pt1, pt2) -> 
    dx = pt1.x - pt2.x
    dy = pt1.y - pt2.y
    dx * dx + dy * dy
  
  p.ptAverage = (pts) ->
    sumX = sumY = 0
    for pt in pts
      sumX += pt.x; sumY += pt.y
    numPts = pts.length
    new gm.Point(sumX / numPts, sumY / numPts)
  
  p.llToPt = (ll) -> @projHelper.getProjection().fromLatLngToDivPixel(ll)
  p.ptToLl = (pt) -> @projHelper.getProjection().fromDivPixelToLatLng(pt)
  
  p.minExtract = (set, func) ->  # destructive! returns minimum, and also removes it from the set
    for item, index in set
      val = func(item)
      if ! bestIndex? || val < bestVal
        bestVal = val
        bestIndex = index
    set.splice(bestIndex, 1)[0]
    
  p.arrIndexOf = (arr, obj) -> 
    return arr.indexOf(obj) if arr.indexOf?
    (return i if o is obj) for o, i in arr
    -1
  
  # the ProjHelper object is just used to get the map's projection
  @ProjHelper = (map) -> @setMap(map)
  @ProjHelper:: = new gm.OverlayView()
  @ProjHelper::['draw'] = ->  # dummy function
