import XCTest
import CoreLocation
import Foundation
@testable import Geomagnetism

final class GeomagnetismTests: XCTestCase {
	func testWMM2020Values() throws {
		// Get the URL for the test values file from the test bundle
		guard let fileURL = Bundle.module.url(forResource: "WMM2025_TestValues", withExtension: "txt") else {
			XCTFail("Failed to locate WMM2020_TEST_VALUES.txt in test bundle")
			return
		}
		
		// Read test cases from file
		let content = try String(contentsOf: fileURL, encoding: .utf8)
		let lines = content.components(separatedBy: .newlines)
		
		// Process each line
		for line in lines {
			// Skip empty lines and comments
			let trimmedLine = line.trimmingCharacters(in: .whitespaces)
			if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
				continue
			}
			
			// Parse the line into components
			let components = trimmedLine.components(separatedBy: .whitespaces)
				.filter { !$0.isEmpty }
			
			guard components.count >= 11 else {
				continue // Skip invalid lines
			}
			
			// Extract test case values
			let year = Double(components[0])!
			let altitudeKm = Double(components[1])!
			let latitude = Double(components[2])!
			let longitude = Double(components[3])!
			let declination = Double(components[4])!
			let inclination = Double(components[5])!
			let h = Double(components[6])!
			let x = Double(components[7])!
			let y = Double(components[8])!
			let z = Double(components[9])!
			let f = Double(components[10])!
			
			// Convert decimal year to Date
			guard let date = self.parseYearDecimalToDate(yearDecimal: year) else {
				continue
			}
			
			// Convert altitude from kilometers to meters
			let altitudeMeters = altitudeKm * 1000.0
			
			let gm = Geomagnetism(longitude: longitude,
														latitude: latitude,
														altitude: altitudeMeters,
														date: date)
			
			// Test magnetic field components with 0.1 accuracy
			XCTAssertEqual(gm.declination, declination, accuracy: 0.1,
										 "Declination mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
			XCTAssertEqual(gm.inclination, inclination, accuracy: 0.1,
										 "Inclination mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
			XCTAssertEqual(gm.horizontalIntensity, h, accuracy: 1,
										 "Horizontal intensity mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
			XCTAssertEqual(gm.northIntensity, x, accuracy: 1,
										 "North intensity mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
			XCTAssertEqual(gm.eastIntensity, y, accuracy: 1,
										 "East intensity mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
			XCTAssertEqual(gm.verticalIntensity, z, accuracy: 1,
										 "Vertical intensity mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
			XCTAssertEqual(gm.intensity, f, accuracy: 1,
										 "Total intensity mismatch for coordinates (\(latitude), \(longitude)) at year \(year)")
		}
	}
	
	private func parseYearDecimalToDate(yearDecimal: Double) -> Date? {
		// Extract the year and the fractional part
		let year = Int(yearDecimal)
		let fractionalPart = yearDecimal - Double(year)
		
		// Calculate the number of days into the year based on the fractional part
		let isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
		let daysInYear = isLeapYear ? 366 : 365
		let daysOffset = Int(Double(daysInYear) * fractionalPart)
		
		// Create a DateComponents for January 1 of the given year
		var components = DateComponents()
		components.year = year
		components.day = daysOffset
		
		// Get the current calendar
		let calendar = Calendar.current
		
		// Create the date
		return calendar.date(from: components)
	}
}
