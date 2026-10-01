import Flutter
import UIKit
import CoreLocation
import CoreMotion

/// Owns all sensors only while the stream has a listener. Magnetic north is
/// explicit; CLLocation's unavailable trueHeading is never sent as 359°.
final class CompassPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CLLocationManagerDelegate, FlutterSceneLifeCycleDelegate {
    private let motion = CMMotionManager()
    private let location = CLLocationManager()
    private var sink: FlutterEventSink?
    private var heading: CLHeading?
    private var usesMotion = false

    override init() {
        super.init()
        location.delegate = self
        location.headingFilter = kCLHeadingFilterNone
        location.headingOrientation = .portrait
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = CompassPlugin()
        let events = FlutterEventChannel(name: "tshk/compass/events", binaryMessenger: registrar.messenger())
        let methods = FlutterMethodChannel(name: "tshk/compass/methods", binaryMessenger: registrar.messenger())
        events.setStreamHandler(plugin)
        registrar.addMethodCallDelegate(plugin, channel: methods)
        registrar.addSceneDelegate(plugin)
        registrar.publish(plugin)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "capabilities":
            result([
                "absoluteOrientation": magneticMotionAvailable || CLLocationManager.headingAvailable(),
                "magnetometer": motion.isMagnetometerAvailable || CLLocationManager.headingAvailable(),
                "accelerometer": motion.isAccelerometerAvailable,
                "gyroscope": motion.isGyroAvailable
            ])
        case "screenAngle":
            // Flutter is portrait-up locked; sensor / UI axes coincide.
            result(0.0)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private var magneticMotionAvailable: Bool {
        motion.isDeviceMotionAvailable &&
            CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
    }

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        stop()
        sink = eventSink
        let args = arguments as? [String: Any]
        let micros = (args?["samplingMicros"] as? NSNumber)?.doubleValue ?? 40000
        let period = min(0.2, max(0.02, micros / 1000000))
        if CLLocationManager.headingAvailable() {
            location.startUpdatingHeading()
        }
        usesMotion = magneticMotionAvailable
        if usesMotion {
            motion.deviceMotionUpdateInterval = period
            motion.showsDeviceMovementDisplay = true
            motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] data, error in
                guard let self = self, self.sink != nil else { return }
                if let error = error {
                    self.sink?(FlutterError(code: "MOTION_UNAVAILABLE", message: error.localizedDescription, details: nil))
                    return
                }
                if let data = data { self.emit(data) }
            }
        } else if CLLocationManager.headingAvailable() {
            // Level-phone fallback with real heading accuracy. Gravity is
            // required so an upright top edge isn't assigned a fake azimuth.
            motion.accelerometerUpdateInterval = period
            motion.startAccelerometerUpdates()
        } else {
            eventSink(FlutterError(code: "NO_ABSOLUTE_SENSOR", message: "No absolute heading sensor", details: nil))
        }
        return nil
    }

    /// Core Motion reference→device NWU becomes device→reference ENU.
    /// Kept pure so XCTest validates the actual bridge, including the transpose.
    static func deviceToEnu(_ r: CMRotationMatrix) -> [Double] {
        return [-r.m12, -r.m22, -r.m32, r.m11, r.m21, r.m31, r.m13, r.m23, r.m33]
    }

    static func availableMagneticHeading(_ value: Double) -> Double? {
        return value.isFinite && value >= 0 && value < 360 ? value : nil
    }

    private func emit(_ data: CMDeviceMotion) {
        let r = data.attitude.rotationMatrix
        // Core Motion's magnetic reference is (north, west, up); our shared
        // facing math expects (east, north, up). Core Motion's R maps
        // reference → device (WWDC 2011 session 423: gravityDevice = R *
        // gravityReference). Transpose first to map device → reference.
        let matrix = Self.deviceToEnu(r)
        let field = data.magneticField.field
        let at = Date().timeIntervalSince1970 + data.timestamp - ProcessInfo.processInfo.systemUptime
        let recentHeading = heading.flatMap { h -> CLHeading? in
            abs(h.timestamp.timeIntervalSince1970 - at) <= 1 ? h : nil
        }
        let calibration: Int
        switch data.magneticField.accuracy {
        case .high: calibration = 3
        case .medium: calibration = 2
        case .low: calibration = 1
        default: calibration = 0
        }
        let accuracy: Any = recentHeading.map { $0.headingAccuracy as Any } ?? NSNull()
        sink?([
            "matrix": matrix,
            "reference": "magnetic",
            "screenAngle": 0.0,
            "timestampMs": at * 1000,
            "accuracy": accuracy,
            "reliability": calibration,
            "magnetic": [field.x, field.y, field.z],
            // Core Motion gravity / acceleration use downward-positive g;
            // sensors_plus and Android use the reaction to gravity in m/s².
            "gravity": [-data.gravity.x * 9.80665, -data.gravity.y * 9.80665, -data.gravity.z * 9.80665],
            "linearAcceleration": [data.userAcceleration.x * 9.80665, data.userAcceleration.y * 9.80665, data.userAcceleration.z * 9.80665],
            "gyro": [data.rotationRate.x, data.rotationRate.y, data.rotationRate.z]
        ])
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Preserve invalid accuracy for diagnostics; do not silently label it
        // unknown / good or let unavailable trueHeading enter the stream.
        heading = newHeading
        guard !usesMotion, sink != nil else { return }
        guard let acceleration = motion.accelerometerData,
            abs(acceleration.timestamp - ProcessInfo.processInfo.systemUptime) < 0.5 else { return }
        let a = acceleration.acceleration
        let gravity = [-a.x * 9.80665, -a.y * 9.80665, -a.z * 9.80665]
        let level = abs(a.x) < 0.4 && abs(a.y) < 0.4 && a.z < -0.8
        let scalarHeading = level ? Self.availableMagneticHeading(newHeading.magneticHeading) : nil
        sink?([
            "heading": scalarHeading.map { $0 as Any } ?? NSNull(),
            "reference": "magnetic",
            "screenAngle": 0.0,
            "timestampMs": newHeading.timestamp.timeIntervalSince1970 * 1000,
            "accuracy": newHeading.headingAccuracy,
            "reliability": newHeading.headingAccuracy < 0 ? 0 : 3,
            "gravity": gravity,
            "magnetic": [newHeading.x, newHeading.y, newHeading.z]
        ])
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if !usesMotion {
            sink?(FlutterError(code: "HEADING_UNAVAILABLE", message: error.localizedDescription, details: nil))
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) { stop() }

    func detachFromEngine(for registrar: FlutterPluginRegistrar) { stop() }

    func onCancel(withArguments arguments: Any?) -> FlutterError? { stop(); return nil }

    private func stop() {
        sink = nil
        motion.stopDeviceMotionUpdates()
        motion.stopAccelerometerUpdates()
        location.stopUpdatingHeading()
        heading = nil
        usesMotion = false
    }
}
