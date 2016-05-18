/**
 * @fileoverview Externs SlidingMarker
 * @see https://github.com/terikon/marker-animate-unobtrusive
 * @externs
 */

/**
 * @param {(google.maps.MarkerOptions|Object.<string, *>)=} opt_opts
 * @extends {google.maps.Marker}
 * @constructor
 */
var SlidingMarker = function(opt_opts) {};

/**
 * @return {undefined}
 */
SlidingMarker.initializeGlobally = function () {};

/**
 * @param {string} key
 * @param {*} value
 * @return {undefined}
 */
SlidingMarker.prototype.originalSet = function (key, value) {};

/**
 * @param {google.maps.LatLng|google.maps.LatLngLiteral} position
 * @return {undefined}
 */
SlidingMarker.prototype._setInstancePositionAnimated = function (position) {};

/**
 * @type {google.maps.Marker}
 */
SlidingMarker.prototype._instance;

/**
 * @param {string} eventName
 * @param {!Function} handler
 * @return {google.maps.MapsEventListener}
 */
SlidingMarker.prototype.originalAddListener = function (eventName, handler) {};

/**
 * @type {google.maps.LatLng}
 */
SlidingMarker.prototype.animationPosition;

/**
 * @nosideeffects
 * @return {google.maps.LatLng}
 */
SlidingMarker.prototype.getAnimationPosition = function () {};

/**
 * @param {google.maps.LatLng|google.maps.LatLngLiteral} latlng
 * @return {undefined}
 */
SlidingMarker.prototype.setPositionNotAnimated = function (latlng) {};

/**
 * @type {number}
 */
SlidingMarker.prototype.duration;

/**
 * @param {number} duration
 * @return {undefined}
 */
SlidingMarker.prototype.setDuration = function (duration) {};

/**
 * @nosideeffects
 * @return {number}
 */
SlidingMarker.prototype.getDuration = function () {};

/**
 * @type {string}
 */
SlidingMarker.prototype.easing;

/**
 * @param {string} easing
 * @return {undefined}
 */
SlidingMarker.prototype.setEasing = function (easing) {};

/**
 * @nosideeffects
 * @return {string}
 */
SlidingMarker.prototype.getEasing = function () {};
