import CoreMotion
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  private func matrix(_ values: [Double]) -> CMRotationMatrix {
    CMRotationMatrix(m11: values[0], m12: values[1], m13: values[2],
      m21: values[3], m22: values[4], m23: values[5],
      m31: values[6], m32: values[7], m33: values[8])
  }

  func testCoreMotionReferenceToDeviceIsTransposedThenConvertedToEnu() {
    // NWU reference→device fixtures for screen-up phones facing N/E/S/W.
    let fixtures: [([Double], Double)] = [
      ([0, -1, 0, 1, 0, 0, 0, 0, 1], 0),
      ([-1, 0, 0, 0, -1, 0, 0, 0, 1], 90),
      ([0, 1, 0, -1, 0, 0, 0, 0, 1], 180),
      ([1, 0, 0, 0, 1, 0, 0, 0, 1], 270)
    ]
    for (raw, expected) in fixtures {
      let enu = CompassPlugin.deviceToEnu(matrix(raw))
      let heading = (atan2(enu[1], enu[4]) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
      XCTAssertEqual(heading, expected, accuracy: 0.000001)
      XCTAssertEqual(enu[8], 1)
    }
  }

  func testUprightTopIsUpAndBackFacesNorth() {
    let enu = CompassPlugin.deviceToEnu(matrix([0, -1, 0, 0, 0, 1, -1, 0, 0]))
    XCTAssertEqual(enu[7], 1) // device top → Earth up
    XCTAssertEqual(-enu[5], 1) // device back → Earth north
    XCTAssertEqual(enu[0], 1) // device right → Earth east
  }
  func testUnavailableScalarHeadingNeverBecomes359Degrees() {
    XCTAssertNil(CompassPlugin.availableMagneticHeading(-1))
    XCTAssertNil(CompassPlugin.availableMagneticHeading(360))
    XCTAssertNil(CompassPlugin.availableMagneticHeading(.nan))
    XCTAssertNil(CompassPlugin.availableMagneticHeading(.infinity))
    XCTAssertEqual(CompassPlugin.availableMagneticHeading(0), 0)
    XCTAssertEqual(CompassPlugin.availableMagneticHeading(359.9), 359.9)
  }

}
