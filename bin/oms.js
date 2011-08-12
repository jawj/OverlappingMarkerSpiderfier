(function() {
  /** @preserve OverlappingMarkerSpiderfier
  https://github.com/jawj/OverlappingMarkerSpiderfier
  Copyright (c) 2011 George MacKerron
  Released under the MIT licence: http://opensource.org/licenses/mit-license
  Note: The Google Maps API v3 must be included *before* this code
  */
  var _ref;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  if (((_ref = this['google']) != null ? _ref['maps'] : void 0) == null) {
    return;
  }
  this['OverlappingMarkerSpiderfier'] = (function() {
    var ge, gm, lcH, lcU, mt, p, twoPi;
    p = _Class.prototype;
    p['VERSION'] = '0.2.1';
    /** @const */
    gm = google.maps;
    /** @const */
    ge = gm.event;
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
    function _Class(map, opts) {
      var e, _i, _len, _ref2;
      this.map = map;
      this.opts = opts != null ? opts : {};
      this.projHelper = new this.constructor.ProjHelper(this.map);
      this.initMarkerArrays();
      this.listeners = {};
      _ref2 = ['click', 'zoom_changed', 'maptypeid_changed'];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        e = _ref2[_i];
        ge.addListener(this.map, e, __bind(function() {
          return this['unspiderfy']();
        }, this));
      }
    }
    p.initMarkerArrays = function() {
      this.markers = [];
      return this.markerListenerRefs = [];
    };
    p['addMarker'] = function(marker) {
      var listenerRefs;
      listenerRefs = [
        ge.addListener(marker, 'click', __bind(function() {
          return this.spiderListener(marker);
        }, this))
      ];
      if (!this.opts['markersWontHide']) {
        listenerRefs.push(ge.addListener(marker, 'visible_changed', __bind(function() {
          return this.markerChangeListener(marker, false);
        }, this)));
      }
      if (!this.opts['markersWontMove']) {
        listenerRefs.push(ge.addListener(marker, 'position_changed', __bind(function() {
          return this.markerChangeListener(marker, true);
        }, this)));
      }
      this.markerListenerRefs.push(listenerRefs);
      this.markers.push(marker);
      return this;
    };
    p.markerChangeListener = function(marker, positionChanged) {
      if ((marker['_omsData'] != null) && (positionChanged || !marker.getVisible()) && !((this.spiderfying != null) || (this.unspiderfying != null))) {
        return this.unspiderfy(positionChanged ? marker : null);
      }
    };
    p['getMarkers'] = function() {
      return this.markers.slice(0, this.markers.length);
    };
    p['removeMarker'] = function(marker) {
      var i, listenerRef, listenerRefs, _i, _len;
      if (marker['_omsData'] != null) {
        this['unspiderfy']();
      }
      i = this.arrIndexOf(this.markers, marker);
      if (i < 0) {
        return;
      }
      listenerRefs = this.markerListenerRefs.splice(i, 1)[0];
      for (_i = 0, _len = listenerRefs.length; _i < _len; _i++) {
        listenerRef = listenerRefs[_i];
        ge.removeListener(listenerRef);
      }
      this.markers.splice(i, 1);
      return this;
    };
    p['clearMarkers'] = function() {
      var listenerRef, listenerRefs, _i, _j, _len, _len2, _ref2;
      this['unspiderfy']();
      _ref2 = this.markerListenerRefs;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        listenerRefs = _ref2[_i];
        for (_j = 0, _len2 = listenerRefs.length; _j < _len2; _j++) {
          listenerRef = listenerRefs[_j];
          ge.removeListener(listenerRef);
        }
      }
      this.initMarkerArrays();
      return this;
    };
    p['addListener'] = function(event, func) {
      var _base, _ref2;
      ((_ref2 = (_base = this.listeners)[event]) != null ? _ref2 : _base[event] = []).push(func);
      return this;
    };
    p['removeListener'] = function(event, func) {
      var i;
      i = this.arrIndexOf(this.listeners[event], func);
      if (!(i < 0)) {
        this.listeners[event].splice(i, 1);
      }
      return this;
    };
    p['clearListeners'] = function(event) {
      this.listeners[event] = [];
      return this;
    };
    p.trigger = function() {
      var args, event, func, _i, _len, _ref2, _ref3, _results;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      _ref3 = (_ref2 = this.listeners[event]) != null ? _ref2 : [];
      _results = [];
      for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
        func = _ref3[_i];
        _results.push(func.apply(null, args));
      }
      return _results;
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
      var m, mPt, markerPt, markerSpiderfied, nearbyMarkerData, nonNearbyMarkers, pxSq, _i, _len, _ref2;
      markerSpiderfied = marker['_omsData'] != null;
      this['unspiderfy']();
      if (markerSpiderfied) {
        return this.trigger('click', marker);
      } else {
        nearbyMarkerData = [];
        nonNearbyMarkers = [];
        pxSq = this['nearbyDistance'] * this['nearbyDistance'];
        markerPt = this.llToPt(marker.position);
        _ref2 = this.markers;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          m = _ref2[_i];
          if (!(m.getVisible() && (m.map != null))) {
            continue;
          }
          mPt = this.llToPt(m.position);
          if (this.ptDistanceSq(mPt, markerPt) < pxSq) {
            nearbyMarkerData.push({
              marker: m,
              markerPt: mPt
            });
          } else {
            nonNearbyMarkers.push(m);
          }
        }
        if (nearbyMarkerData.length === 1) {
          return this.trigger('click', marker);
        } else {
          return this.spiderfy(nearbyMarkerData, nonNearbyMarkers);
        }
      }
    };
    p.makeHighlightListeners = function(marker) {
      return {
        highlight: __bind(function() {
          return marker['_omsData'].leg.setOptions({
            strokeColor: this['legColors']['highlighted'][this.map.mapTypeId],
            zIndex: this['highlightedLegZIndex']
          });
        }, this),
        unhighlight: __bind(function() {
          return marker['_omsData'].leg.setOptions({
            strokeColor: this['legColors']['usual'][this.map.mapTypeId],
            zIndex: this['usualLegZIndex']
          });
        }, this)
      };
    };
    p.spiderfy = function(markerData, nonNearbyMarkers) {
      var bodyPt, footLl, footPt, footPts, leg, listeners, marker, md, nearestMarkerDatum, numFeet, spiderfiedMarkers;
      this.spiderfying = true;
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
      spiderfiedMarkers = (function() {
        var _i, _len, _results;
        _results = [];
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
          marker['_omsData'] = {
            usualPosition: marker.position,
            leg: leg
          };
          if (this['legColors']['highlighted'][this.map.mapTypeId] !== this['legColors']['usual'][this.map.mapTypeId]) {
            listeners = this.makeHighlightListeners(marker);
            ge.addListener(marker, 'mouseover', listeners.highlight);
            ge.addListener(marker, 'mouseout', listeners.unhighlight);
            marker['_omsData'].hightlightListeners = listeners;
          }
          marker.setPosition(footLl);
          marker.setZIndex(Math.round(this['spiderfiedZIndex'] + footPt.y));
          _results.push(marker);
        }
        return _results;
      }).call(this);
      delete this.spiderfying;
      this.spiderfied = true;
      return this.trigger('spiderfy', spiderfiedMarkers, nonNearbyMarkers);
    };
    p['unspiderfy'] = function(markerNotToMove) {
      var listeners, marker, nonNearbyMarkers, unspiderfiedMarkers, _i, _len, _ref2;
      if (markerNotToMove == null) {
        markerNotToMove = null;
      }
      if (this.spiderfied == null) {
        return;
      }
      this.unspiderfying = true;
      unspiderfiedMarkers = [];
      nonNearbyMarkers = [];
      _ref2 = this.markers;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        marker = _ref2[_i];
        if (marker['_omsData'] != null) {
          marker['_omsData'].leg.setMap(null);
          if (marker !== markerNotToMove) {
            marker.setPosition(marker['_omsData'].usualPosition);
          }
          marker.setZIndex(null);
          listeners = marker['_omsData'].hightlightListeners;
          if (listeners != null) {
            ge.clearListeners(marker, 'mouseover', listeners.highlight);
            ge.clearListeners(marker, 'mouseout', listeners.unhighlight);
          }
          delete marker['_omsData'];
          unspiderfiedMarkers.push(marker);
        } else {
          nonNearbyMarkers.push(marker);
        }
      }
      delete this.unspiderfying;
      delete this.spiderfied;
      this.trigger('unspiderfy', unspiderfiedMarkers, nonNearbyMarkers);
      return this;
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
    p.arrIndexOf = function(arr, obj) {
      var i, o, _len;
      if (arr.indexOf != null) {
        return arr.indexOf(obj);
      }
      for (i = 0, _len = arr.length; i < _len; i++) {
        o = arr[i];
        if (o === obj) {
          return i;
        }
      }
      return -1;
    };
    _Class.ProjHelper = function(map) {
      return this.setMap(map);
    };
    _Class.ProjHelper.prototype = new gm.OverlayView();
    _Class.ProjHelper.prototype['draw'] = function() {};
    return _Class;
  })();
}).call(this);
