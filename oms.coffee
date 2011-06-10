###

OverlappingMarkerSpiderfier
Copyright (c) 2011 George MacKerron

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

###

gm = google.maps
twoPi = Math.PI * 2

class OverlappingMarkerSpiderfier
  
  nearbyDistance: 20           # spiderfy markers within this range of the one clicked, in px
  
  circleFootSeparation: 23     # related to circumference of circle
  circleStartAngle: twoPi / 12
  
  spiralFootSeparation: 26     # related to size of spiral (experiment!)
  spiralLengthStart: 11        # ditto
  spiralLengthFactor: 4        # ditto
  
  circleSpiralSwitchover: 9    # show spiral instead of circle from this marker count upwards
                               # 0 -> always spiral; Infinity -> always circle
  
  usualZIndex: 10
  spiderfiedZIndex: 10000      # ensure spiderfied markers are on top
  
  usualLegZIndex: 9
  highlightedLegZIndex: 9999   # ensure highlighted legs are on top
  legWeight: 1.5
  legColors: 
    usual: {}                  # set at bottom, owing to use of non-literal keys
    highlighted: {}            # ditto
    
  constructor: (@map) ->
    @projHelper = new @constructor.ProjHelper(@map)
    @markers = []
    @listeners = {}
    gm.event.addListener(@map, e, => @unspiderfy()) for e in ['click', 'zoom_changed', 'maptypeid_changed']
    
  addListener: (event, func) ->  # available listeners: click(marker), spiderfy(markers), unspiderfy(markers)
    (@listeners[event] ?= []).push(func)
    this  # return self, for chaining
    
  trigger: (event, args...) ->
    func(args...) for func in (@listeners[event] ? [])
    this  # return self, for chaining
    
  addMarker: (marker) ->
    gm.event.addListener(marker, 'click', => @spiderListener(marker))
    marker.setZIndex(@usualZIndex)
    @markers.push(marker)
    this  # return self, for chaining
    
  nearbyMarkerData: (marker, px) ->
    nearby = []
    pxSq = px * px
    markerPt = @llToPt(marker.position)
    for m in @markers
      mPt = @llToPt(m.position)
      if @ptDistanceSq(mPt, markerPt) < pxSq
        nearby.push(marker: m, markerPt: mPt)
    nearby
    
  generatePtsCircle: (count, centerPt) ->
    circumference = @circleFootSeparation * (2 + count)
    legLength = circumference / twoPi  # = radius from circumference
    angleStep = twoPi / count
    for i in [0...count]
      angle = @circleStartAngle + i * angleStep
      new gm.Point(centerPt.x + legLength * Math.cos(angle), centerPt.y + legLength * Math.sin(angle))
    
  generatePtsSpiral: (count, centerPt) ->
    legLength = @spiralLengthStart
    angle = 0
    for i in [0...count]
      angle += @spiralFootSeparation / legLength + i * 0.0005
      pt = new gm.Point(centerPt.x + legLength * Math.cos(angle), centerPt.y + legLength * Math.sin(angle))
      legLength += twoPi * @spiralLengthFactor / angle
      pt
    
  spiderListener: (marker) ->
    markerSpiderfied = marker.omsData?
    @unspiderfy()
    if markerSpiderfied
      @trigger('click', marker)
    else
      nearbyMarkerData = @nearbyMarkerData(marker, @nearbyDistance)
      if nearbyMarkerData.length == 1  # 1 => the one clicked => none nearby
        @trigger('click', marker)
      else
        @spiderfy(nearbyMarkerData)
  
  makeHighlightListeners: (marker) ->
    highlight: 
      => marker.omsData.leg.setOptions(strokeColor: @legColors.highlighted[@map.mapTypeId], zIndex: @highlightedLegZIndex)
    unhighlight: 
      => marker.omsData.leg.setOptions(strokeColor: @legColors.usual[@map.mapTypeId], zIndex: @usualLegZIndex)
  
  spiderfy: (markerData) ->
    @spiderfied = yes
    numFeet = markerData.length
    bodyPt = @ptAverage(md.markerPt for md in markerData)
    footPts = if numFeet >= @circleSpiralSwitchover 
      @generatePtsSpiral(numFeet, bodyPt).reverse()  # match spiral points from outside in -> less criss-crossing
    else
      @generatePtsCircle(numFeet, bodyPt)
    spiderfiedMarkers = []
    for footPt in footPts
      footLl = @ptToLl(footPt)
      nearestMarkerDatum = @minExtract(markerData, (md) => @ptDistanceSq(md.markerPt, footPt))
      marker = nearestMarkerDatum.marker
      leg = new gm.Polyline
        map: @map
        path: [marker.position, footLl]
        strokeColor: @legColors.usual[@map.mapTypeId]
        strokeWeight: @legWeight
        zIndex: @usualLegZIndex
      marker.omsData = 
        usualPosition: marker.position
        leg: leg
      unless @legColors.highlighted[@map.mapTypeId] == @legColors.usual[@map.mapTypeId]
        listeners = @makeHighlightListeners(marker)
        gm.event.addListener(marker, 'mouseover', listeners.highlight)
        gm.event.addListener(marker, 'mouseout', listeners.unhighlight)
        marker.omsData.hightlightListeners = listeners
      marker.setZIndex(@spiderfiedZIndex + footPt.y)  # lower markers should cover higher ones
      marker.setPosition(footLl)
      spiderfiedMarkers.push(marker)
    @trigger('spiderfy', spiderfiedMarkers)
    
  unspiderfy: ->
    return unless @spiderfied?
    delete @spiderfied
    unspiderfiedMarkers = []
    for marker in @markers
      if marker.omsData?
        marker.omsData.leg.setMap(null)
        marker.setZIndex(@usualZIndex)
        marker.setPosition(marker.omsData.usualPosition)
        listeners = marker.omsData.hightlightListeners
        if listeners?
          gm.event.clearListeners(marker, 'mouseover', listeners.highlight)
          gm.event.clearListeners(marker, 'mouseout', listeners.unhighlight)
        delete marker.omsData
        unspiderfiedMarkers.push(marker)
    @trigger('unspiderfy', unspiderfiedMarkers)
    
  ptDistanceSq: (pt1, pt2) -> 
    dx = pt1.x - pt2.x; dy = pt1.y - pt2.y
    dx * dx + dy * dy
    
  ptAverage: (pts) ->
    sumX = sumY = 0
    for pt in pts
      sumX += pt.x; sumY += pt.y
    numPts = pts.length
    new gm.Point(sumX / numPts, sumY / numPts)
    
  llToPt: (ll) -> @projHelper.getProjection().fromLatLngToDivPixel(ll)
  
  ptToLl: (ll) -> @projHelper.getProjection().fromDivPixelToLatLng(ll)
  
  minExtract: (set, func) ->  # destructive! returns minimum, and also removes it from the set
    for item, index in set
      val = func(item)
      if ! bestIndex? || val < bestVal
        bestVal = val
        bestIndex = index
    set.splice(bestIndex, 1)[0]
    
OverlappingMarkerSpiderfier.ProjHelper = (map) -> @setMap(map)  # this object is just used to get the map's projection
OverlappingMarkerSpiderfier.ProjHelper.prototype = new gm.OverlayView()
OverlappingMarkerSpiderfier.ProjHelper.prototype.draw = ->  # dummy function

mt = gm.MapTypeId
lc = OverlappingMarkerSpiderfier.prototype.legColors

lc.usual[mt.HYBRID] = lc.usual[mt.SATELLITE] = '#fff'
lc.highlighted[mt.HYBRID] = lc.highlighted[mt.SATELLITE] = '#f00'

lc.usual[mt.TERRAIN] = lc.usual[mt.ROADMAP] = '#444'
lc.highlighted[mt.TERRAIN] = lc.highlighted[mt.ROADMAP] = '#f00'

this.OverlappingMarkerSpiderfier = OverlappingMarkerSpiderfier  # export to global scope
