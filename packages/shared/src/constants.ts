export const APP_NAME = "IITK Bicycle";
export const APP_ID = "com.sakshamm21.iitkbicycle";

/** College defaults; each college can override these in its settings. */
export const DEFAULT_MAX_RIDE_MINUTES = 240;
export const DEFAULT_STRIKE_LIMIT = 3;
export const DEFAULT_STAND_RADIUS_M = 40;

/** A location fix worse than this is rejected when starting or ending a ride. */
export const MAX_GPS_ACCURACY_M = 50;

export const LOCK_CODE_LENGTH = 4;

/** Free vector tiles, no API key. */
export const MAP_STYLE_URL = "https://tiles.openfreemap.org/styles/liberty";

/** Approximate centre of the IIT Kanpur campus. */
export const IITK_CENTER = { latitude: 26.5123, longitude: 80.2329 } as const;
