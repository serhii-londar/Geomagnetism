/*	License Statement from the NOAA
	The WMM source code is in the public domain and not licensed or
	under copyright. The information and software may be used freely
	by the public. As required by 17 U.S.C. 403, third parties producing
	copyrighted works consisting predominantly of the material produced
	by U.S. government agencies must provide notice with such work(s)
	identifying the U.S. Government material incorporated and stating
	that such material is not subject to copyright protection.*/

import Foundation

// Add vars to convert to degrees/radians
extension FloatingPoint {
	/** Convert to degrees from radians*/
	var toDegrees:Self { return self * 180 / .pi }
	/** Convert to radians from degrees*/
	var toRadians:Self { return self * .pi / 180 }
}

/** Class to calculate magnetic declination, magnetic field strength,
inclination etc. for any point on the earth.

Adapted from the geomagc software and World Magnetic Model of the NOAA
Satellite and Information Service, National Geophysical Data Center

http://www.ngdc.noaa.gov/geomag/WMM/DoDWMM.shtml

© Deep Pradhan, 2017*/
class Geomagnetism {

	/** Initializes the instance without calculations*/
	init() {
		// Initialize constants
		maxord = Geomagnetism.MAX_DEG
		sp[0] = 0
		cp[0] = 1
		snorm[0] = 1
		pp[0] = 1
		dp[0][0] = 0

		c[0][0] = 0
		cd[0][0] = 0

		epoch = Double(Geomagnetism.WMM_COF[0].trimmingCharacters(in: .whitespaces).split(separator: " ")[0])!

		var tokens:[String.SubSequence], n:Int, m:Int, gnm:Double, hnm:Double, dgnm:Double, dhnm:Double

		for i in (1...Geomagnetism.WMM_COF.count - 1) {
			tokens = Geomagnetism.WMM_COF[i].trimmingCharacters(in: .whitespaces).split(separator: " ")
			n = Int(tokens[0])!
			m = Int(tokens[1])!
			gnm = Double(tokens[2])!
			hnm = Double(tokens[3])!
			dgnm = Double(tokens[4])!
			dhnm = Double(tokens[5])!
			if m <= n {
				c[m][n] = gnm
				cd[m][n] = dgnm
				if m != 0 {
					c[n][m-1] = hnm
					cd[n][m-1] = dhnm
				}
			}
		}
		// Convert schmidt normalized gauss coefficients to unnormalized
		snorm[0] = 1
		var flnmj:Double, j:Int
		for n in (1...maxord) {
			snorm[n] = snorm[n - 1] * Double(2 * n - 1) / Double(n)
			j = 2
			var m:Int = 0, d1:Int = 1, d2:Int = (n - m + d1) / d1
			while d2 > 0 {
				k[m][n] = Double(((n - 1) * (n - 1)) - (m * m)) / Double((2 * n - 1) * (2 * n - 3))
				if m > 0 {
					flnmj = Double((n - m + 1) * j) / Double(n + m)
					snorm[n + m * 13] = snorm[n + (m - 1) * 13] * sqrt(flnmj)
					j = 1
					c[n][m - 1] = snorm[n + m * 13] * c[n][m - 1]
					cd[n][m - 1] = snorm[n + m * 13] * cd[n][m - 1]
				}
				c[m][n] = snorm[n + m * 13] * c[m][n]
				cd[m][n] = snorm[n + m * 13] * cd[m][n]
				d2 -= 1
				m += d1
			}
			fn[n] = Double(n + 1)
			fm[n] = Double(n)
		}
		k[1][1] = 0
		fm[0] = 0
		otime = -1000
		oalt = -1000
		olat = -1000
		olon = -1000
	}

	/** Initialise the instance and calculate for given location and date
	- parameters:
		- longitude: Longitude in decimal degrees
		- latitude: Latitude in decimal degrees
		- altitude: Altitude in metres
		- date: Date of the calculation*/
	convenience init(longitude:Double, latitude:Double, altitude:Double? = 0, date:Date? = Date.init()) {
		self.init()
		calculate(longitude: longitude, latitude: latitude, altitude: altitude!, date: date!)
	}

	/** Calculate for given location and date
	- parameters:
		- longitude: Longitude in decimal degrees
		- latitude: Latitude in decimal degrees
		- altitude: Altitude in metres
		- date: Date of the calculation*/
	func calculate(longitude:Double, latitude:Double, altitude:Double? = 0, date:Date? = Date.init()) {
		let rlon:Double = longitude.toRadians,
				rlat:Double = latitude.toRadians,
				altitudeKm:Double = altitude! / 1000,
				calendar:Calendar = Calendar.current,
				yearFraction:Double = Double(calendar.component(.year, from: date!))
					+ Double(calendar.ordinality(of: .day, in: .year, for: date!)!)
					/ Double(calendar.range(of: .day, in: .year, for: date!)!.count),
				dt:Double = yearFraction - epoch,
				srlon:Double = sin(rlon),
				srlat:Double = sin(rlat),
				crlon:Double = cos(rlon),
				crlat:Double = cos(rlat),
				srlat2:Double = srlat * srlat,
				crlat2:Double = crlat * crlat,
				a2:Double = Geomagnetism.WGS84_A * Geomagnetism.WGS84_A,
				b2:Double = Geomagnetism.WGS84_B * Geomagnetism.WGS84_B,
				c2:Double = a2 - b2,
				a4:Double = a2 * a2,
				b4:Double = b2 * b2,
				c4:Double = a4 - b4

		sp[1] = srlon
		cp[1] = crlon

		// Convert from geodetic coords. to spherical coords.
		if altitudeKm != oalt || latitude != olat {
			let q:Double = sqrt(a2 - c2 * srlat2),
					q1:Double = altitudeKm * q,
					q2:Double = ((q1 + a2) / (q1 + b2)) * ((q1 + a2) / (q1 + b2)),
					r2:Double = ((altitudeKm * altitudeKm) + 2 * q1 + (a4 - c4 * srlat2) / (q * q))
			ct = srlat / sqrt(q2 * crlat2 + srlat2)
			st = sqrt(1 - (ct * ct))
			r = sqrt(r2)
			d = sqrt(a2 * crlat2 + b2 * srlat2)
			ca = (altitudeKm + d) / r
			sa = c2 * crlat * srlat / (r * d)
		}
		if longitude != olon {
			for m in (2...maxord) {
				sp[m] = sp[1] * cp[m-1] + cp[1] * sp[m-1]
				cp[m] = cp[1] * cp[m-1] - sp[1] * sp[m-1]
			}
		}
		let aor:Double = Geomagnetism.IAU66_RADIUS / r
		var ar:Double = aor * aor,
				br:Double = 0, bt:Double = 0, bp:Double = 0, bpp:Double = 0,
				par:Double, parp:Double, temp1:Double, temp2:Double

		for n in (1...maxord) {
			ar = ar * aor
			var m:Int = 0, d3:Int = 1, d4:Int = (n + m + d3) / d3
			while d4 > 0 {

				// Compute unnormalized associated legendre polynomials and derivatives via recursion relations
				if altitudeKm != oalt || latitude != olat {
					if n == m {
						snorm[n + m * 13] = st * snorm[n - 1 + (m - 1) * 13];
						dp[m][n] = st * dp[m - 1][n - 1] + ct * snorm[n - 1 + (m - 1) * 13]
					}
					if n == 1 && m == 0 {
						snorm[n + m * 13] = ct * snorm[n - 1 + m * 13]
						dp[m][n] = ct * dp[m][n - 1] - st * snorm[n - 1 + m * 13]
					}
					if n > 1 && n != m {
						if m > n - 2 {
							snorm[n - 2 + m * 13] = 0
						}
						if m > n - 2 {
							dp[m][n - 2] = 0
						}
						snorm[n + m * 13] = ct * snorm[n - 1 + m * 13] - k[m][n] * snorm[n - 2 + m * 13]
						dp[m][n] = ct * dp[m][n - 1] - st * snorm[n - 1 + m * 13] - k[m][n] * dp[m][n - 2]
					}
				}

				// Time adjust the gauss coefficients
				if yearFraction != otime {
					tc[m][n] = c[m][n] + dt * cd[m][n]

					if m != 0 {
						tc[n][m - 1] = c[n][m - 1] + dt * cd[n][m - 1]
					}
				}

				//Accumulate terms of the spherical harmonic expansions
				par = ar * snorm[ n + m * 13]
				if m == 0 {
					temp1 = tc[m][n] * cp[m]
					temp2 = tc[m][n] * sp[m]
				}
				else {
					temp1 = tc[m][n] * cp[m] + tc[n][m - 1] * sp[m]
					temp2 = tc[m][n] * sp[m] - tc[n][m - 1] * cp[m]
				}

				bt = bt - ar * temp1 * dp[m][n]
				bp += (fm[m] * temp2 * par)
				br += (fn[n] * temp1 * par)

				// Special case: north/south geographic poles
				if st == 0 && m == 1 {
					if n == 1 {
						pp[n] = pp[n - 1]
					} else {
						pp[n] = ct * pp[n - 1] - k[m][n] * pp[n - 2]
					}
					parp = ar * pp[n]
					bpp += (fm[m] * temp2 * parp)
				}
				d4 -= 1
				m += d3
			}
		}

		if st == 0 {
			bp = bpp
		} else {
			bp /= st
		}

		// Rotate magnetic vector components from spherical to geodetic coordinates
		// bx must be the east-west field component
		// by must be the north-south field component
		// bz must be the vertical field component.
		bx = -bt * ca - br * sa
		by = bp
		bz = bt * sa - br * ca

		// Compute declination (dec), inclination (dip) and total intensity (ti)
		bh = sqrt((bx * bx)+(by * by))
		intensity = sqrt((bh * bh)+(bz * bz))
		//	Calculate the declination.
		declination = atan2(by, bx).toDegrees
		inclination = atan2(bz, bh).toDegrees

		otime = yearFraction
		oalt = altitudeKm
		olat = latitude
		olon = longitude
	}

	/** - returns: The declination in degrees*/
	func getDeclination() -> Double {
		return declination
	}

	/** - returns: The magnetic field intensity/strength in nano Tesla*/
	func getIntensity() -> Double {
		return intensity
	}

	/** - returns: The horizontal magnetic field intensity/strength in nano Tesla*/
	func getHorizontalIntensity() -> Double {
		return bh
	}

	/** - returns: The vertical magnetic field intensity/strength in nano Tesla*/
	func getVerticalIntensity() -> Double {
		return bz
	}

	/** - returns: The northerly component of the magnetic field strength in nano Tesla*/
	func getNorthIntensity() -> Double {
		return bx
	}

	/** - returns: The easterly component of the magnetic field strength in nano Tesla*/
	func getEastIntensity() -> Double {
		return by
	}

	/** - returns: The magnetic field dip angle, in degrees*/
	func getDipAngle() -> Double {
		return inclination
	}

	/**	The input string array which contains each line of input for the wmm.cof input file.
	*	The columns in this file are as follows:	n,	m,	gnm,	hnm,	dgnm,	dhnm*/
	private static let WMM_COF:[String] = ["    2015.0            WMM-2015        12/15/2014",
			"  1  0  -29438.5       0.0       10.7        0.0",
			"  1  1   -1501.1    4796.2       17.9      -26.8",
			"  2  0   -2445.3       0.0       -8.6        0.0",
			"  2  1    3012.5   -2845.6       -3.3      -27.1",
			"  2  2    1676.6    -642.0        2.4      -13.3",
			"  3  0    1351.1       0.0        3.1        0.0",
			"  3  1   -2352.3    -115.3       -6.2        8.4",
			"  3  2    1225.6     245.0       -0.4       -0.4",
			"  3  3     581.9    -538.3      -10.4        2.3",
			"  4  0     907.2       0.0       -0.4        0.0",
			"  4  1     813.7     283.4        0.8       -0.6",
			"  4  2     120.3    -188.6       -9.2        5.3",
			"  4  3    -335.0     180.9        4.0        3.0",
			"  4  4      70.3    -329.5       -4.2       -5.3",
			"  5  0    -232.6       0.0       -0.2        0.0",
			"  5  1     360.1      47.4        0.1        0.4",
			"  5  2     192.4     196.9       -1.4        1.6",
			"  5  3    -141.0    -119.4        0.0       -1.1",
			"  5  4    -157.4      16.1        1.3        3.3",
			"  5  5       4.3     100.1        3.8        0.1",
			"  6  0      69.5       0.0       -0.5        0.0",
			"  6  1      67.4     -20.7       -0.2        0.0",
			"  6  2      72.8      33.2       -0.6       -2.2",
			"  6  3    -129.8      58.8        2.4       -0.7",
			"  6  4     -29.0     -66.5       -1.1        0.1",
			"  6  5      13.2       7.3        0.3        1.0",
			"  6  6     -70.9      62.5        1.5        1.3",
			"  7  0      81.6       0.0        0.2        0.0",
			"  7  1     -76.1     -54.1       -0.2        0.7",
			"  7  2      -6.8     -19.4       -0.4        0.5",
			"  7  3      51.9       5.6        1.3       -0.2",
			"  7  4      15.0      24.4        0.2       -0.1",
			"  7  5       9.3       3.3       -0.4       -0.7",
			"  7  6      -2.8     -27.5       -0.9        0.1",
			"  7  7       6.7      -2.3        0.3        0.1",
			"  8  0      24.0       0.0        0.0        0.0",
			"  8  1       8.6      10.2        0.1       -0.3",
			"  8  2     -16.9     -18.1       -0.5        0.3",
			"  8  3      -3.2      13.2        0.5        0.3",
			"  8  4     -20.6     -14.6       -0.2        0.6",
			"  8  5      13.3      16.2        0.4       -0.1",
			"  8  6      11.7       5.7        0.2       -0.2",
			"  8  7     -16.0      -9.1       -0.4        0.3",
			"  8  8      -2.0       2.2        0.3        0.0",
			"  9  0       5.4       0.0        0.0        0.0",
			"  9  1       8.8     -21.6       -0.1       -0.2",
			"  9  2       3.1      10.8       -0.1       -0.1",
			"  9  3      -3.1      11.7        0.4       -0.2",
			"  9  4       0.6      -6.8       -0.5        0.1",
			"  9  5     -13.3      -6.9       -0.2        0.1",
			"  9  6      -0.1       7.8        0.1        0.0",
			"  9  7       8.7       1.0        0.0       -0.2",
			"  9  8      -9.1      -3.9       -0.2        0.4",
			"  9  9     -10.5       8.5       -0.1        0.3",
			" 10  0      -1.9       0.0        0.0        0.0",
			" 10  1      -6.5       3.3        0.0        0.1",
			" 10  2       0.2      -0.3       -0.1       -0.1",
			" 10  3       0.6       4.6        0.3        0.0",
			" 10  4      -0.6       4.4       -0.1        0.0",
			" 10  5       1.7      -7.9       -0.1       -0.2",
			" 10  6      -0.7      -0.6       -0.1        0.1",
			" 10  7       2.1      -4.1        0.0       -0.1",
			" 10  8       2.3      -2.8       -0.2       -0.2",
			" 10  9      -1.8      -1.1       -0.1        0.1",
			" 10 10      -3.6      -8.7       -0.2       -0.1",
			" 11  0       3.1       0.0        0.0        0.0",
			" 11  1      -1.5      -0.1        0.0        0.0",
			" 11  2      -2.3       2.1       -0.1        0.1",
			" 11  3       2.1      -0.7        0.1        0.0",
			" 11  4      -0.9      -1.1        0.0        0.1",
			" 11  5       0.6       0.7        0.0        0.0",
			" 11  6      -0.7      -0.2        0.0        0.0",
			" 11  7       0.2      -2.1        0.0        0.1",
			" 11  8       1.7      -1.5        0.0        0.0",
			" 11  9      -0.2      -2.5        0.0       -0.1",
			" 11 10       0.4      -2.0       -0.1        0.0",
			" 11 11       3.5      -2.3       -0.1       -0.1",
			" 12  0      -2.0       0.0        0.1        0.0",
			" 12  1      -0.3      -1.0        0.0        0.0",
			" 12  2       0.4       0.5        0.0        0.0",
			" 12  3       1.3       1.8        0.1       -0.1",
			" 12  4      -0.9      -2.2       -0.1        0.0",
			" 12  5       0.9       0.3        0.0        0.0",
			" 12  6       0.1       0.7        0.1        0.0",
			" 12  7       0.5      -0.1        0.0        0.0",
			" 12  8      -0.4       0.3        0.0        0.0",
			" 12  9      -0.4       0.2        0.0        0.0",
			" 12 10       0.2      -0.9        0.0        0.0",
			" 12 11      -0.9      -0.2        0.0        0.0",
			" 12 12       0.0       0.7        0.0        0.0",]

	/** Mean radius of IAU-66 ellipsoid, in km.*/
	private static let IAU66_RADIUS:Double = 6371.2

	/** Semi-major axis of WGS-84 ellipsoid, in km.*/
	private static let WGS84_A:Double = 6378.137

	/** Semi-minor axis of WGS-84 ellipsoid, in km.*/
	private static let WGS84_B:Double = 6356.7523142

	/** The maximum number of degrees of the spherical harmonic model.*/
	private static let MAX_DEG:Int = 12

	/** Geomagnetic declination in deg.
	*	East is positive, West is negative.
	*	(The negative of variation.)*/
	private var declination:Double = Double.nan

	/** Geomagnetic inclination in deg.
	*	Down is positive, up is negative.*/
	private var inclination:Double = Double.nan

	/** Geomagnetic total intensity, in nano Teslas.*/
	private var intensity:Double = Double.nan

	/** The maximum order of spherical harmonic model.*/
	private var maxord:Int

	/** The Gauss coefficients of main geomagnetic model (nt).*/
	private var c:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

	/** The Gauss coefficients of secular geomagnetic model (nt/yr).*/
	private var cd:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

	/** The time adjusted geomagnetic gauss coefficients (nt).*/
	private var tc:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

	/** The theta derivative of p(n,m) (unnormalized).*/
	private var dp:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

	/** The Schmidt normalization factors.*/
	private var snorm:[Double] = Array(repeating: Double.nan, count: 169)

	/** The sine of (m*spherical coord. longitude).*/
	private var sp:[Double] = Array(repeating: Double.nan, count: 13)

	/** The cosine of (m*spherical coord. longitude).*/
	private var cp:[Double] = Array(repeating: Double.nan, count: 13)
	private var fn:[Double] = Array(repeating: Double.nan, count: 13)
	private var fm:[Double] = Array(repeating: Double.nan, count: 13)

	/** The associated Legendre polynomials for m = 1 (unnormalized).*/
	private var pp:[Double] = Array(repeating: Double.nan, count: 13)

	private var k:[[Double]] = Array(repeating: Array(repeating: Double.nan, count: 13), count: 13)

	/** The variables otime (old time), oalt (old altitude),
	*	olat (old latitude), olon (old longitude), are used to
	*	store the values used from the previous calculation to
	*	save on calculation time if some inputs don't change.*/
	private var otime:Double, oalt:Double, olat:Double, olon:Double

	/** The date in years, for the start of the valid time of the fit coefficients*/
	private var epoch:Double

	/** bx is the north south field intensity
	*	by is the east west field intensity
	*	bz is the vertical field intensity positive downward
	*	bh is the horizontal field intensity*/
	private var bx:Double = Double.nan, by:Double = Double.nan, bz:Double = Double.nan, bh:Double = Double.nan
	private var r:Double = Double.nan, d:Double = Double.nan, ca:Double = Double.nan,
			sa:Double = Double.nan, ct:Double = Double.nan, st:Double = Double.nan
}