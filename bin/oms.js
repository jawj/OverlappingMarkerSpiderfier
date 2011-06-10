(function() {
  /*
  
  OverlappingMarkerSpiderfier
  Copyright (c) 2011 George MacKerron
  
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
  associated documentation files (the "Software"), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute,
  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all copies or substantial
  portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
  NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  
  */  var OverlappingMarkerSpiderfier, gm, lc, mt, twoPi;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  gm = google.maps;
  twoPi = Math.PI * 2;
  OverlappingMarkerSpiderfier = (function() {
    OverlappingMarkerSpiderfier.prototype.nearbyDistance = 20;
    OverlappingMarkerSpiderfier.prototype.circleFootSeparation = 23;
    OverlappingMarkerSpiderfier.prototype.circleStartAngle = twoPi / 12;
    OverlappingMarkerSpiderfier.prototype.spiralFootSeparation = 26;
    OverlappingMarkerSpiderfier.prototype.spiralLengthStart = 11;
    OverlappingMarkerSpiderfier.prototype.spiralLengthFactor = 4;
    OverlappingMarkerSpiderfier.prototype.circleSpiralSwitchover = 9;
    OverlappingMarkerSpiderfier.prototype.usualZIndex = 10;
    OverlappingMarkerSpiderfier.prototype.spiderfiedZIndex = 10000;
    OverlappingMarkerSpiderfier.prototype.usualLegZIndex = 9;
    OverlappingMarkerSpiderfier.prototype.highlightedLegZIndex = 9999;
    OverlappingMarkerSpiderfier.prototype.legWeight = 1.5;
    OverlappingMarkerSpiderfier.prototype.legColors = {
      usual: {},
      highlighted: {}
    };
    function OverlappingMarkerSpiderfier(map) {
      var e, _i, _len, _ref;
      this.map = map;
      this.projHelper = new this.constructor.ProjHelper(this.map);
      this.markers = [];
      this.listeners = {};
      _ref = ['click', 'zoom_changed', 'maptypeid_changed'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        e = _ref[_i];
        gm.event.addListener(this.map, e, __bind(function() {
          return this.unspiderfy();
        }, this));
      }
    }
    OverlappingMarkerSpiderfier.prototype.addListener = function(event, func) {
      var _base, _ref;
      ((_ref = (_base = this.listeners)[event]) != null ? _ref : _base[event] = []).push(func);
      return this;
    };
    OverlappingMarkerSpiderfier.prototype.trigger = function() {
      var args, event, func, _i, _len, _ref, _ref2;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      _ref2 = (_ref = this.listeners[event]) != null ? _ref : [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        func = _ref2[_i];
        func.apply(null, args);
      }
      return this;
    };
    OverlappingMarkerSpiderfier.prototype.addMarker = function(marker) {
      gm.event.addListener(marker, 'click', __bind(function() {
        return this.spiderListener(marker);
      }, this));
      marker.setZIndex(this.usualZIndex);
      this.markers.push(marker);
      return this;
    };
    OverlappingMarkerSpiderfier.prototype.nearbyMarkerData = function(marker, px) {
      var m, mPt, markerPt, nearby, pxSq, _i, _len, _ref;
      nearby = [];
      pxSq = px * px;
      markerPt = this.llToPt(marker.position);
      _ref = this.markers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        m = _ref[_i];
        mPt = this.llToPt(m.position);
        if (this.ptDistanceSq(mPt, markerPt) < pxSq) {
          nearby.push({
            marker: m,
            markerPt: mPt
          });
        }
      }
      return nearby;
    };
    OverlappingMarkerSpiderfier.prototype.generatePtsCircle = function(count, centerPt) {
      var angle, angleStep, circumference, i, legLength, _results;
      circumference = this.circleFootSeparation * (2 + count);
      legLength = circumference / twoPi;
      angleStep = twoPi / count;
      _results = [];
      for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
        angle = this.circleStartAngle + i * angleStep;
        _results.push(new gm.Point(centerPt.x + legLength * Math.cos(angle), centerPt.y + legLength * Math.sin(angle)));
      }
      return _results;
    };
    OverlappingMarkerSpiderfier.prototype.generatePtsSpiral = function(count, centerPt) {
      var angle, i, legLength, pt, _results;
      legLength = this.spiralLengthStart;
      angle = 0;
      _results = [];
      for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
        angle += this.spiralFootSeparation / legLength + i * 0.0005;
        pt = new gm.Point(centerPt.x + legLength * Math.cos(angle), centerPt.y + legLength * Math.sin(angle));
        legLength += twoPi * this.spiralLengthFactor / angle;
        _results.push(pt);
      }
      return _results;
    };
    OverlappingMarkerSpiderfier.prototype.spiderListener = function(marker) {
      var markerSpiderfied, nearbyMarkerData;
      markerSpiderfied = marker.omsData != null;
      this.unspiderfy();
      if (markerSpiderfied) {
        return this.trigger('click', marker);
      } else {
        nearbyMarkerData = this.nearbyMarkerData(marker, this.nearbyDistance);
        if (nearbyMarkerData.length === 1) {
          return this.trigger('click', marker);
        } else {
          return this.spiderfy(nearbyMarkerData);
        }
      }
    };
    OverlappingMarkerSpiderfier.prototype.makeHighlightListeners = function(marker) {
      return {
        highlight: __bind(function() {
          return marker.omsData.leg.setOptions({
            strokeColor: this.legColors.highlighted[this.map.mapTypeId],
            zIndex: this.highlightedLegZIndex
          });
        }, this),
        unhighlight: __bind(function() {
          return marker.omsData.leg.setOptions({
            strokeColor: this.legColors.usual[this.map.mapTypeId],
            zIndex: this.usualLegZIndex
          });
        }, this)
      };
    };
    OverlappingMarkerSpiderfier.prototype.spiderfy = function(markerData) {
      var bodyPt, footLl, footPt, footPts, leg, listeners, marker, md, nearestMarkerDatum, numFeet, spiderfiedMarkers, _i, _len;
      this.spiderfied = true;
      numFeet = markerData.length;
      bodyPt = this.ptAverage((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = markerData.length; _i < _len; _i++) {
          md = markerData[_i];
          _results.push(md.markerPt);
        }
        return _results;
      })());
      footPts = numFeet >= this.circleSpiralSwitchover ? this.generatePtsSpiral(numFeet, bodyPt).reverse() : this.generatePtsCircle(numFeet, bodyPt);
      spiderfiedMarkers = [];
      for (_i = 0, _len = footPts.length; _i < _len; _i++) {
        footPt = footPts[_i];
        footLl = this.ptToLl(footPt);
        nearestMarkerDatum = this.minExtract(markerData, __bind(function(md) {
          return this.ptDistanceSq(md.markerPt, footPt);
        }, this));
        marker = nearestMarkerDatum.marker;
        leg = new gm.Polyline({
          map: this.map,
          path: [marker.position, footLl],
          strokeColor: this.legColors.usual[this.map.mapTypeId],
          strokeWeight: this.legWeight,
          zIndex: this.usualLegZIndex
        });
        marker.omsData = {
          usualPosition: marker.position,
          leg: leg
        };
        if (this.legColors.highlighted[this.map.mapTypeId] !== this.legColors.usual[this.map.mapTypeId]) {
          listeners = this.makeHighlightListeners(marker);
          gm.event.addListener(marker, 'mouseover', listeners.highlight);
          gm.event.addListener(marker, 'mouseout', listeners.unhighlight);
          marker.omsData.hightlightListeners = listeners;
        }
        marker.setZIndex(this.spiderfiedZIndex + footPt.y);
        marker.setPosition(footLl);
        spiderfiedMarkers.push(marker);
      }
      return this.trigger('spiderfy', spiderfiedMarkers);
    };
    OverlappingMarkerSpiderfier.prototype.unspiderfy = function() {
      var listeners, marker, unspiderfiedMarkers, _i, _len, _ref;
      if (this.spiderfied == null) {
        return;
      }
      delete this.spiderfied;
      unspiderfiedMarkers = [];
      _ref = this.markers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        marker = _ref[_i];
        if (marker.omsData != null) {
          marker.omsData.leg.setMap(null);
          marker.setZIndex(this.usualZIndex);
          marker.setPosition(marker.omsData.usualPosition);
          listeners = marker.omsData.hightlightListeners;
          if (listeners != null) {
            gm.event.clearListeners(marker, 'mouseover', listeners.highlight);
            gm.event.clearListeners(marker, 'mouseout', listeners.unhighlight);
          }
          delete marker.omsData;
          unspiderfiedMarkers.push(marker);
        }
      }
      return this.trigger('unspiderfy', unspiderfiedMarkers);
    };
    OverlappingMarkerSpiderfier.prototype.ptDistanceSq = function(pt1, pt2) {
      var dx, dy;
      dx = pt1.x - pt2.x;
      dy = pt1.y - pt2.y;
      return dx * dx + dy * dy;
    };
    OverlappingMarkerSpiderfier.prototype.ptAverage = function(pts) {
      var numPts, pt, sumX, sumY, _i, _len;
      sumX = sumY = 0;
      for (_i = 0, _len = pts.length; _i < _len; _i++) {
        pt = pts[_i];
        sumX += pt.x;
        sumY += pt.y;
      }
      numPts = pts.length;
      return new gm.Point(sumX / numPts, sumY / numPts);
    };
    OverlappingMarkerSpiderfier.prototype.llToPt = function(ll) {
      return this.projHelper.getProjection().fromLatLngToDivPixel(ll);
    };
    OverlappingMarkerSpiderfier.prototype.ptToLl = function(ll) {
      return this.projHelper.getProjection().fromDivPixelToLatLng(ll);
    };
    OverlappingMarkerSpiderfier.prototype.minExtract = function(set, func) {
      var bestIndex, bestVal, index, item, val, _len;
      for (index = 0, _len = set.length; index < _len; index++) {
        item = set[index];
        val = func(item);
        if (!(typeof bestIndex !== "undefined" && bestIndex !== null) || val < bestVal) {
          bestVal = val;
          bestIndex = index;
        }
      }
      return set.splice(bestIndex, 1)[0];
    };
    return OverlappingMarkerSpiderfier;
  })();
  OverlappingMarkerSpiderfier.ProjHelper = function(map) {
    return this.setMap(map);
  };
  OverlappingMarkerSpiderfier.ProjHelper.prototype = new gm.OverlayView();
  OverlappingMarkerSpiderfier.ProjHelper.prototype.draw = function() {};
  mt = gm.MapTypeId;
  lc = OverlappingMarkerSpiderfier.prototype.legColors;
  lc.usual[mt.HYBRID] = lc.usual[mt.SATELLITE] = '#fff';
  lc.highlighted[mt.HYBRID] = lc.highlighted[mt.SATELLITE] = '#f00';
  lc.usual[mt.TERRAIN] = lc.usual[mt.ROADMAP] = '#444';
  lc.highlighted[mt.TERRAIN] = lc.highlighted[mt.ROADMAP] = '#f00';
  this.OverlappingMarkerSpiderfier = OverlappingMarkerSpiderfier;
}).call(this);
