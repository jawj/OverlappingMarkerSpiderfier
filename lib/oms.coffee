###* @preserve OverlappingMarkerSpiderfier
https://github.com/jawj/OverlappingMarkerSpiderfier
Copyright (c) 2011 - 2012 George MacKerron
Released under the MIT licence: http://opensource.org/licenses/mit-license
Note: The Google Maps API v3 must be included *before* this code
###

# NB. string literal properties -- object['key'] -- are for Closure Compiler ADVANCED_OPTIMIZATION

return unless this['google']?['maps']?  # return from wrapper func without doing anything

class @['OverlappingMarkerSpiderfier']
  p = @::  # this saves a lot of repetition of .prototype that isn't optimized away
  p['VERSION'] = '0.2.4'
  
  ###* @const ### gm = google.maps
  ###* @const ### ge = gm.event
  ###* @const ### mt = gm.MapTypeId
  ###* @const ### twoPi = Math.PI * 2
  
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
    listenerRefs = [ge.addListener(marker, 'click', => @spiderListener(marker))]
    unless @['markersWontHide']
      listenerRefs.push(ge.addListener(marker, 'visible_changed', => @markerChangeListener(marker, no)))
    unless @['markersWontMove']
      listenerRefs.push(ge.addListener(marker, 'position_changed', => @markerChangeListener(marker, yes)))
    @markerListenerRefs.push(listenerRefs)
    @markers.push(marker)
    @  # return self, for chaining

  p.markerChangeListener = (marker, positionChanged) ->
    if marker['_omsData']? and (positionChanged or not marker.getVisible()) and not (@spiderfying? or @unspiderfying?)
      @unspiderfy(if positionChanged then marker else null)
      
  p['getMarkers'] = ->
    @markers[0...@markers.length]  # returns a copy, so no funny business

  p['removeMarker'] = (marker) ->
    @['unspiderfy']() if marker['_omsData']?  # otherwise it'll be stuck there forever!
    i = @arrIndexOf(@markers, marker)
    return if i < 0
    listenerRefs = @markerListenerRefs.splice(i, 1)[0]
    ge.removeListener(listenerRef) for listenerRef in listenerRefs
    @markers.splice(i, 1)
    @  # return self, for chaining
    
  p['clearMarkers'] = ->
    @['unspiderfy']()
    for listenerRefs in @markerListenerRefs
      ge.removeListener(listenerRef) for listenerRef in listenerRefs
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
  
  p.spiderListener = (marker) ->
    markerSpiderfied = marker['_omsData']?
    @['unspiderfy']() unless markerSpiderfied and @['keepSpiderfied']
    if markerSpiderfied
      @trigger('click', marker)
    else
      nearbyMarkerData = []
      nonNearbyMarkers = []
      pxSq = @['nearbyDistance'] * @['nearbyDistance']
      markerPt = @llToPt(marker.position)
      for m in @markers
        continue unless m.getVisible() and m.map?  # at 2011-08-12, property m.visible is undefined in API v3.5
        mPt = @llToPt(m.position)
        if @ptDistanceSq(mPt, markerPt) < pxSq
          nearbyMarkerData.push(marker: m, markerPt: mPt)
        else
          nonNearbyMarkers.push(m)
      if nearbyMarkerData.length == 1  # 1 => the one clicked => none nearby
        @trigger('click', marker)
      else
        @spiderfy(nearbyMarkerData, nonNearbyMarkers)
  
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
      unless @['legColors']['highlighted'][@map.mapTypeId] ==
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
    return unless @spiderfied?
    @unspiderfying = yes
    unspiderfiedMarkers = []
    nonNearbyMarkers = []
    for marker in @markers
      if marker['_omsData']?
        marker['_omsData'].leg.setMap(null)
        marker.setPosition(marker['_omsData'].usualPosition) unless marker == markerNotToMove
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
  p.ptToLl = (ll) -> @projHelper.getProjection().fromDivPixelToLatLng(ll)
  
  p.minExtract = (set, func) ->  # destructive! returns minimum, and also removes it from the set
    for item, index in set
      val = func(item)
      if ! bestIndex? || val < bestVal
        bestVal = val
        bestIndex = index
    set.splice(bestIndex, 1)[0]
    
  p.arrIndexOf = (arr, obj) -> 
    return arr.indexOf(obj) if arr.indexOf?
    (return i if o == obj) for o, i in arr
    -1
  
  # the ProjHelper object is just used to get the map's projection
  @ProjHelper = (map) -> @setMap(map)
  @ProjHelper:: = new gm.OverlayView()
  @ProjHelper::['draw'] = ->  # dummy function
