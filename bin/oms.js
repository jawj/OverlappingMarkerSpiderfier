(function() {
  /** @preserve OverlappingMarkerSpiderfier
  https://github.com/jawj/OverlappingMarkerSpiderfier
  Copyright (c) 2011 George MacKerron
  Released under the MIT licence: http://opensource.org/licenses/mit-license 
  */  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  this['OverlappingMarkerSpiderfier'] = (function() {
    var gm, lcH, lcU, mt, p, twoPi;
    p = _Class.prototype;
    p['VERSION'] = '0.1.1';
    /** @const */
    gm = google.maps;
    /** @const */
    mt = gm.MapTypeId;
    /** @const */
    twoPi = Math.PI * 2;
    p['nearbyDistance'] = 20;
    p['circleSpiralSwitchover'] = 9;
    p['circleFootSeparation'] = 23;
    p['circleStartAngle'] = twoPi / 12;
    p['spiralFootSeparation'] = 26;
    p['spiralLengthStart'] = 11;
    p['spiralLengthFactor'] = 4;
    p['spiderfiedZIndex'] = 1000;
    p['usualLegZIndex'] = 10;
    p['highlightedLegZIndex'] = 20;
    p['legWeight'] = 1.5;
    p['legColors'] = {
      'usual': {},
      'highlighted': {}
    };
    lcU = p['legColors']['usual'];
    lcH = p['legColors']['highlighted'];
    lcU[mt.HYBRID] = lcU[mt.SATELLITE] = '#fff';
    lcH[mt.HYBRID] = lcH[mt.SATELLITE] = '#f00';
    lcU[mt.TERRAIN] = lcU[mt.ROADMAP] = '#444';
    lcH[mt.TERRAIN] = lcH[mt.ROADMAP] = '#f00';
    function _Class(map) {
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
    p['addMarker'] = function(marker) {
      gm.event.addListener(marker, 'click', __bind(function() {
        return this.spiderListener(marker);
      }, this));
      this.markers.push(marker);
      return this;
    };
    p['addListener'] = function(event, func) {
      var _base, _ref;
      ((_ref = (_base = this.listeners)[event]) != null ? _ref : _base[event] = []).push(func);
      return this;
    };
    p.trigger = function() {
      var args, event, func, _i, _len, _ref, _ref2, _results;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      _ref2 = (_ref = this.listeners[event]) != null ? _ref : [];
      _results = [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        func = _ref2[_i];
        _results.push(func.apply(null, args));
      }
      return _results;
    };
    p.nearbyMarkerData = function(marker, px) {
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
    p.generatePtsCircle = function(count, centerPt) {
      var angle, angleStep, circumference, i, legLength, _results;
      circumference = this['circleFootSeparation'] * (2 + count);
      legLength = circumference / twoPi;
      angleStep = twoPi / count;
      _results = [];
      for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
        angle = this['circleStartAngle'] + i * angleStep;
        _results.push(new gm.Point(centerPt.x + legLength * Math.cos(angle), centerPt.y + legLength * Math.sin(angle)));
      }
      return _results;
    };
    p.generatePtsSpiral = function(count, centerPt) {
      var angle, i, legLength, pt, _results;
      legLength = this['spiralLengthStart'];
      angle = 0;
      _results = [];
      for (i = 0; 0 <= count ? i < count : i > count; 0 <= count ? i++ : i--) {
        angle += this['spiralFootSeparation'] / legLength + i * 0.0005;
        pt = new gm.Point(centerPt.x + legLength * Math.cos(angle), centerPt.y + legLength * Math.sin(angle));
        legLength += twoPi * this['spiralLengthFactor'] / angle;
        _results.push(pt);
      }
      return _results;
    };
    p.spiderListener = function(marker) {
      var markerSpiderfied, nearbyMarkerData;
      markerSpiderfied = marker.omsData != null;
      this.unspiderfy();
      if (markerSpiderfied) {
        return this.trigger('click', marker);
      } else {
        nearbyMarkerData = this.nearbyMarkerData(marker, this['nearbyDistance']);
        if (nearbyMarkerData.length === 1) {
          return this.trigger('click', marker);
        } else {
          return this.spiderfy(nearbyMarkerData);
        }
      }
    };
    p.makeHighlightListeners = function(marker) {
      return {
        highlight: __bind(function() {
          return marker.omsData.leg.setOptions({
            strokeColor: this['legColors']['highlighted'][this.map.mapTypeId],
            zIndex: this['highlightedLegZIndex']
          });
        }, this),
        unhighlight: __bind(function() {
          return marker.omsData.leg.setOptions({
            strokeColor: this['legColors']['usual'][this.map.mapTypeId],
            zIndex: this['usualLegZIndex']
          });
        }, this)
      };
    };
    p.spiderfy = function(markerData) {
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
      footPts = numFeet >= this['circleSpiralSwitchover'] ? this.generatePtsSpiral(numFeet, bodyPt).reverse() : this.generatePtsCircle(numFeet, bodyPt);
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
          strokeColor: this['legColors']['usual'][this.map.mapTypeId],
          strokeWeight: this['legWeight'],
          zIndex: this['usualLegZIndex']
        });
        marker.omsData = {
          usualPosition: marker.position,
          leg: leg
        };
        if (this['legColors']['highlighted'][this.map.mapTypeId] !== this['legColors']['usual'][this.map.mapTypeId]) {
          listeners = this.makeHighlightListeners(marker);
          gm.event.addListener(marker, 'mouseover', listeners.highlight);
          gm.event.addListener(marker, 'mouseout', listeners.unhighlight);
          marker.omsData.hightlightListeners = listeners;
        }
        marker.setPosition(footLl);
        marker.setZIndex(Math.round(this['spiderfiedZIndex'] + footPt.y));
        spiderfiedMarkers.push(marker);
      }
      return this.trigger('spiderfy', spiderfiedMarkers);
    };
    p.unspiderfy = function() {
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
          marker.setPosition(marker.omsData.usualPosition);
          marker.setZIndex(null);
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
    p.ptDistanceSq = function(pt1, pt2) {
      var dx, dy;
      dx = pt1.x - pt2.x;
      dy = pt1.y - pt2.y;
      return dx * dx + dy * dy;
    };
    p.ptAverage = function(pts) {
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
    p.llToPt = function(ll) {
      return this.projHelper.getProjection().fromLatLngToDivPixel(ll);
    };
    p.ptToLl = function(ll) {
      return this.projHelper.getProjection().fromDivPixelToLatLng(ll);
    };
    p.minExtract = function(set, func) {
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
    _Class.ProjHelper = function(map) {
      return this.setMap(map);
    };
    _Class.ProjHelper.prototype = new gm.OverlayView();
    _Class.ProjHelper.prototype['draw'] = function() {};
    return _Class;
  })();
}).call(this);
