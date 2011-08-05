###* @preserve OverlappingMarkerSpiderfier
https://github.com/jawj/OverlappingMarkerSpiderfier
Copyright (c) 2011 George MacKerron
Released under the MIT licence: http://opensource.org/licenses/mit-license 
###

# NB. string literal properties -- object['key'] -- are for Closure Compiler ADVANCED_OPTIMIZATION

class this['OverlappingMarkerSpiderfier']
  p = @::  # this saves a lot of repetition of .prototype that isn't optimized away
  p['VERSION'] = '0.1.3'
  
  ###* @const ### gm = google.maps
  ###* @const ### mt = gm.MapTypeId
  ###* @const ### twoPi = Math.PI * 2

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
  constructor: (@map) ->
    @projHelper = new @constructor.ProjHelper(@map)
    @markerListenerRefs = []
    @markers = []
    @listeners = {}
    for e in ['click', 'zoom_changed', 'maptypeid_changed']
      gm.event.addListener(@map, e, => @['unspiderfy']()) 

  p['addMarker'] = (marker) ->
    listenerRef = gm.event.addListener(marker, 'click', => @spiderListener(marker))
    @markerListenerRefs.push(listenerRef)
    @markers.push(marker)
    this  # return self, for chaining
    
  p['removeMarker'] = (marker) ->
    @['unspiderfy']() if marker.omsData?  # otherwise it'll be stuck there forever!
    i = @arrIndexOf(@markers, marker)
    return if i < 0
    listenerRef = @markerListenerRefs.splice(i, 1)[0]
    gm.event.removeListener(listenerRef)
    @markers.splice(i, 1)
    this  # return self, for chaining
        
  # available listeners: click(marker), spiderfy(markers), unspiderfy(markers)
  p['addListener'] = (event, func) ->
    (@listeners[event] ?= []).push(func)
    this  # return self, for chaining
  
  p.trigger = (event, args...) ->
    func(args...) for func in (@listeners[event] ? [])
  
  p.nearbyMarkerData = (marker, px) ->
    nearby = []
    pxSq = px * px
    markerPt = @llToPt(marker.position)
    for m in @markers
      mPt = @llToPt(m.position)
      if @ptDistanceSq(mPt, markerPt) < pxSq
        nearby.push(marker: m, markerPt: mPt)
    nearby
  
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
    markerSpiderfied = marker.omsData?
    @['unspiderfy']()
    if markerSpiderfied
      @trigger('click', marker)
    else
      nearbyMarkerData = @nearbyMarkerData(marker, @['nearbyDistance'])
      if nearbyMarkerData.length == 1  # 1 => the one clicked => none nearby
        @trigger('click', marker)
      else
        @spiderfy(nearbyMarkerData)
  
  p.makeHighlightListeners = (marker) ->
    highlight: 
      => marker.omsData.leg.setOptions
        strokeColor: @['legColors']['highlighted'][@map.mapTypeId]
        zIndex: @['highlightedLegZIndex']
    unhighlight: 
      => marker.omsData.leg.setOptions
        strokeColor: @['legColors']['usual'][@map.mapTypeId]
        zIndex: @['usualLegZIndex']
  
  p.spiderfy = (markerData) ->
    @spiderfied = yes
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
      marker.omsData = 
        usualPosition: marker.position
        leg: leg
      unless @['legColors']['highlighted'][@map.mapTypeId] ==
             @['legColors']['usual'][@map.mapTypeId]
        listeners = @makeHighlightListeners(marker)
        gm.event.addListener(marker, 'mouseover', listeners.highlight)
        gm.event.addListener(marker, 'mouseout', listeners.unhighlight)
        marker.omsData.hightlightListeners = listeners
      marker.setPosition(footLl)
      marker.setZIndex(Math.round(@['spiderfiedZIndex'] + footPt.y))  # so lower markers cover higher ones
      marker
    @trigger('spiderfy', spiderfiedMarkers)
  
  p['unspiderfy'] = ->
    return unless @spiderfied?
    delete @spiderfied
    unspiderfiedMarkers = []
    for marker in @markers
      if marker.omsData?
        marker.omsData.leg.setMap(null)
        marker.setPosition(marker.omsData.usualPosition)
        marker.setZIndex(null)
        listeners = marker.omsData.hightlightListeners
        if listeners?
          gm.event.clearListeners(marker, 'mouseover', listeners.highlight)
          gm.event.clearListeners(marker, 'mouseout', listeners.unhighlight)
        delete marker.omsData
        unspiderfiedMarkers.push(marker)
    @trigger('unspiderfy', unspiderfiedMarkers)
  
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
