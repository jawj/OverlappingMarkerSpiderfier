###* @preserve OverlappingMarkerSpiderfier
https://github.com/jawj/OverlappingMarkerSpiderfier
Copyright (c) 2011 - 2017 George MacKerron
Released under the MIT licence: http://opensource.org/licenses/mit-license
###

# NB. string literal properties -- object['key'] -- are for Closure Compiler ADVANCED_OPTIMIZATION

class @['OverlappingMarkerSpiderfier']
  p = @::  # this saves a lot of repetition of .prototype that isn't optimized away
  x['VERSION'] = '1.0.3' for x in [@, p]  # better on @, but defined on p too for backward-compat
  twoPi = Math.PI * 2
  gm = ge = mt = null  # for scoping purposes
  
  @['markerStatus'] = 
    # universal status
    'SPIDERFIED':     'SPIDERFIED'
    # statuses reported under standard regine
    'SPIDERFIABLE':   'SPIDERFIABLE'
    'UNSPIDERFIABLE': 'UNSPIDERFIABLE'
    # status reported under simple status update regime only
    'UNSPIDERFIED':   'UNSPIDERFIED'

  # Note: it's OK that this constructor comes after the properties, because a function defined by a 
  # function declaration can be used before the function declaration itself

  constructor: (@map, opts = {}) ->

    # initialize prototype variables only on first construction, 
    # because some rely on GMaps properties that may not be available on script load

    unless @constructor.hasInitialized?
      @constructor.hasInitialized = yes

      gm = google.maps
      ge = gm.event
      mt = gm.MapTypeId

      p['keepSpiderfied']  = no          # yes -> don't unspiderfy when a spiderfied marker is selected
      p['ignoreMapClick']  = no          # yes -> don't unspiderfy when the map is clicked
      p['markersWontHide'] = no          # yes -> a promise you won't hide markers, so we needn't check
      p['markersWontMove'] = no          # yes -> a promise you won't move markers, so we needn't check
      p['basicFormatEvents'] = no        # yes -> save some computation by receiving only SPIDERFIED | UNSPIDERFIED format updates 
                                         # (not SPIDERFIED | SPIDERFIABLE | UNSPIDERFIABLE)

      p['nearbyDistance'] = 20           # spiderfy markers within this range of the one clicked, in px
      
      p['circleSpiralSwitchover'] = 9    # show spiral instead of circle from this marker count upwards
                                         # 0 -> always spiral; Infinity -> always circle
      p['circleFootSeparation'] = 23     # related to circumference of circle
      p['circleStartAngle'] = twoPi / 12
      p['spiralFootSeparation'] = 26     # related to size of spiral (experiment!)
      p['spiralLengthStart'] = 11        # ditto
      p['spiralLengthFactor'] = 4        # ditto
      
      p['spiderfiedZIndex']     = gm.Marker.MAX_ZINDEX + 20000  # ensure spiderfied markers are on top
      p['highlightedLegZIndex'] = gm.Marker.MAX_ZINDEX + 10000  # ensure highlighted leg is always on top
      p['usualLegZIndex']       = gm.Marker.MAX_ZINDEX + 1      # for legs (doesn't work?)
      
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

      # the ProjHelper object is just used to get the map's projection
      @constructor.ProjHelper = (map) -> @setMap(map)
      @constructor.ProjHelper:: = new gm.OverlayView()
      @constructor.ProjHelper::['draw'] = ->  # dummy function

    (@[k] = v) for own k, v of opts
    @projHelper = new @constructor.ProjHelper(@map)
    @initMarkerArrays()
    @listeners = {}
    @formatIdleListener = @formatTimeoutId = null

    @addListener 'click', (marker, e) -> ge.trigger(marker, 'spider_click', e)  # new-style events, easier to integrate
    @addListener 'format', (marker, status) -> ge.trigger(marker, 'spider_format', status)

    unless @['ignoreMapClick']
      ge.addListener @map, 'click', => @['unspiderfy']()
    ge.addListener @map, 'maptypeid_changed', => @['unspiderfy']()
    ge.addListener @map, 'zoom_changed', =>
      @['unspiderfy']()
      if not @['basicFormatEvents'] then @formatMarkers()

  p.initMarkerArrays = ->
    @markers = []
    @markerListenerRefs = []
  
  p['addMarker'] = (marker, spiderClickHandler) ->
    marker.setMap(@map)
    @['trackMarker'](marker, spiderClickHandler)

  p['trackMarker'] = (marker, spiderClickHandler) ->
    return @ if marker['_oms']?
    marker['_oms'] = yes
    # marker.setOptions optimized: no  # 'optimized' rendering is sometimes buggy, but seems mainly OK on current GMaps
    listenerRefs = [ge.addListener(marker, 'click', (e) => @spiderListener(marker, e))]
    unless @['markersWontHide']
      listenerRefs.push ge.addListener(marker, 'visible_changed', => @markerChangeListener(marker, no))
    unless @['markersWontMove']
      listenerRefs.push ge.addListener(marker, 'position_changed', => @markerChangeListener(marker, yes))
    if spiderClickHandler?
      listenerRefs.push ge.addListener(marker, 'spider_click', spiderClickHandler)
    @markerListenerRefs.push(listenerRefs)
    @markers.push(marker)

    if @['basicFormatEvents']  # if using basic events, just format this marker as unspiderfied
      @trigger('format', marker, @constructor['markerStatus']['UNSPIDERFIED'])
    else  # otherwise, format as unspiderfiable now, and recalculate all marker formatting at end of run loop
      @trigger('format', marker, @constructor['markerStatus']['UNSPIDERFIABLE'])
      @formatMarkers()
    
    @  # return self, for chaining

  p.markerChangeListener = (marker, positionChanged) ->
    return if @spiderfying or @unspiderfying

    if marker['_omsData']? and (positionChanged or not marker.getVisible())
      @['unspiderfy'](if positionChanged then marker else null)

    @formatMarkers()
      
  p['getMarkers'] = -> @markers[..]  # returns a copy, preventing funny business

  p['removeMarker'] = (marker) ->
    @['forgetMarker'](marker)
    marker.setMap(null)

  p['forgetMarker'] = (marker) ->
    @['unspiderfy']() if marker['_omsData']?  # otherwise it'll be stuck there forever!
    i = @arrIndexOf(@markers, marker)
    return @ if i < 0

    listenerRefs = @markerListenerRefs.splice(i, 1)[0]
    ge.removeListener(listenerRef) for listenerRef in listenerRefs
    delete marker['_oms']
    @markers.splice(i, 1)
    
    @formatMarkers()

    @  # return self, for chaining
  
  p['removeAllMarkers'] = p['clearMarkers'] = ->  # much quicker than calling removeMarker for each marker; clearMarkers is deprecated as unclear
    markers = @['getMarkers']()
    @['forgetAllMarkers']()
    marker.setMap(null) for marker in markers
    @

  p['forgetAllMarkers'] = ->
    @['unspiderfy']()
    for marker, i in @markers
      listenerRefs = @markerListenerRefs[i]
      ge.removeListener(listenerRef) for listenerRef in listenerRefs
      delete marker['_oms']

    @initMarkerArrays()
    @  # return self, for chaining
        
  # available listeners: click(marker), spiderfy(markers), unspiderfy(markers)
  p['addListener'] = (eventName, func) ->
    (@listeners[eventName] ?= []).push(func)
    @  # return self, for chaining
    
  p['removeListener'] = (eventName, func) ->
    i = @arrIndexOf(@listeners[eventName], func)
    @listeners[eventName].splice(i, 1) unless i < 0
    @  # return self, for chaining
  
  p['clearListeners'] = (eventName) ->
    @listeners[eventName] = []
    @  # return self, for chaining
  
  p.trigger = (eventName, args...) ->
    func(args...) for func in (@listeners[eventName] ? [])
  
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
  
  p.spiderListener = (marker, e) ->
    markerSpiderfied = marker['_omsData']?
    @['unspiderfy']() unless markerSpiderfied and @['keepSpiderfied']
    if markerSpiderfied or @map.getStreetView().getVisible() or @map.getMapTypeId() is 'GoogleEarthAPI'  # don't spiderfy in Street View or GE Plugin!
      @trigger('click', marker, e)
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
        @trigger('click', marker, e)
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
  
  p.markerProximityData = ->
    unless @projHelper.getProjection()?
      throw "Must wait for 'idle' event on map before calling markersNearAnyOtherMarker"
    nDist = @['nearbyDistance']
    pxSq = nDist * nDist
    mData = for m in @markers
      {pt: @llToPt(m['_omsData']?.usualPosition ? m.position), willSpiderfy: no}
    for m1, i1 in @markers
      continue unless m1.getMap()? and m1.getVisible()  # marker not visible: ignore
      m1Data = mData[i1]
      continue if m1Data.willSpiderfy  # true in the case that we've assessed an earlier marker that was near this one
      for m2, i2 in @markers
        continue if i2 is i1  # markers cannot be near themselves: ignore
        continue unless m2.getMap()? and m2.getVisible()  # marker not visible: ignore
        m2Data = mData[i2]
        continue if i2 < i1 and not m2Data.willSpiderfy  # if i2 < i1, m2 has already been checked for proximity to any other marker; 
                                                         # so if willSpiderfy is false, it cannot be near any other marker, including this one (m1)
        if @ptDistanceSq(m1Data.pt, m2Data.pt) < pxSq
          m1Data.willSpiderfy = m2Data.willSpiderfy = yes
          break
    mData

  p['markersNearAnyOtherMarker'] = ->  # *very* much quicker than calling markersNearMarker in a loop
    mData = @markerProximityData()
    m for m, i in @markers when mData[i].willSpiderfy
  
  # 'format' (on OMS instance) and 'spider_format' (per marker) will be called:
  # * on spiderfy, for all markers that spiderfy (status: SPIDERFIED)
  # * on unspiderfy, for all markers that unspiderfy (status: SPIDERFIABLE — or UNSPIDERFIED, if opted out of advanced updates)
  # * on map zoom and on marker add, remove, position_changed, visible_changed, for all markers (status: SPIDERFIABLE | UNSPIDERFIABLE — or UNSPIDERFIED, if opted out of advanced updates)

  p.setImmediate = (func) -> window.setTimeout func, 0

  p.formatMarkers = ->
    if @['basicFormatEvents'] then return
    if @formatTimeoutId? then return  # only format markers once per run loop (in case e.g. being called repeatedly from addMarker)
    @formatTimeoutId = @setImmediate =>
      @formatTimeoutId = null
      if @projHelper.getProjection()?
        @_formatMarkers()
      else
        if @formatIdleListener? then return  # if the map is not yet ready, and we're not already waiting, wait until it is ready
        @formatIdleListener = ge.addListenerOnce @map, 'idle', => @_formatMarkers()

  p._formatMarkers = ->  # only formatMarkers is allowed to call this directly 
    if @['basicFormatEvents']
      for marker in markers
        status = if marker['_omsData']? then 'SPIDERFIED' else 'UNSPIDERFIED'
        @trigger('format', marker, @constructor['markerStatus'][status])
    else
      proximities = @markerProximityData()  # {pt, willSpiderfy}[]
      for marker, i in @markers
        status = if marker['_omsData']? then 'SPIDERFIED'
        else if proximities[i].willSpiderfy then 'SPIDERFIABLE' 
        else 'UNSPIDERFIABLE'
        @trigger('format', marker, @constructor['markerStatus'][status])

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
        usualPosition: marker.getPosition()
        usualZIndex: marker.getZIndex()
        leg: leg
      unless @['legColors']['highlighted'][@map.mapTypeId] is
             @['legColors']['usual'][@map.mapTypeId]
        highlightListenerFuncs = @makeHighlightListenerFuncs(marker)
        marker['_omsData'].hightlightListeners =
          highlight:   ge.addListener(marker, 'mouseover', highlightListenerFuncs.highlight)
          unhighlight: ge.addListener(marker, 'mouseout',  highlightListenerFuncs.unhighlight)
      @trigger('format', marker, @constructor['markerStatus']['SPIDERFIED'])
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
        marker.setZIndex(marker['_omsData'].usualZIndex)
        listeners = marker['_omsData'].hightlightListeners
        if listeners?
          ge.removeListener(listeners.highlight)
          ge.removeListener(listeners.unhighlight)
        delete marker['_omsData']
        unless marker is markerNotToMove  # if marker is markerNotToMove, formatMarkers is about to be called anyway
          status = if @['basicFormatEvents'] then 'UNSPIDERFIED' else 'SPIDERFIABLE'  # unspiderfying? must be spiderfiable
          @trigger('format', marker, @constructor['markerStatus'][status])
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


# callbacks for async loading

# callback specified in script src (e.g. <script src="oms.js?spiderfier_callback=myCallback">), like GMaps itself uses
callbackRegEx = /(\?.*(&|&amp;)|\?)spiderfier_callback=(\w+)/
scriptTag = document.currentScript
scriptTag ?= (tag for tag in document.getElementsByTagName('script') when tag.getAttribute('src')?.match(callbackRegEx))[0]
if scriptTag?
  callbackName = scriptTag.getAttribute('src')?.match(callbackRegEx)?[3]
  if callbackName then window[callbackName]?()

# or you can use fixed name callback if this is easier
window['spiderfier_callback']?()


