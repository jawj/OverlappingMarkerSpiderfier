/**
 * @fileoverview Externs MarkerWithGhost
 * @see https://github.com/terikon/marker-animate-unobtrusive
 * @externs
 */

/**
 * @param {(google.maps.MarkerOptions|Object.<string, *>)=} opt_opts
 * @extends {SlidingMarker}
 * @constructor
 */
var MarkerWithGhost = function(opt_opts) {};

/**
 * @return {undefined}
 */
MarkerWithGhost.initializeGlobally = function () {};

/**
 * @type {google.maps.LatLng}
 */
MarkerWithGhost.prototype.ghostPosition;

/**
 * @param {google.maps.LatLng|google.maps.LatLngLiteral} position
 * @return {undefined}
 */
MarkerWithGhost.prototype.setGhostPosition = function (position) {};

/**
 * @nosideeffects
 * @return {google.maps.LatLng}
 */
MarkerWithGhost.prototype.getGhostPosition = function () {};

/**
 * @type {google.maps.LatLng}
 */
MarkerWithGhost.prototype.ghostAnimationPosition;

/**
 * @nosideeffects
 * @return {google.maps.LatLng}
 */
MarkerWithGhost.prototype.getGhostAnimationPosition = function() {};