import CoreGraphics
import Darwin
import Foundation

// MARK: - Private API declarations

// CoreBrightness.framework - CBTrueToneClient
// Loaded dynamically via NSClassFromString to avoid linking issues
@objc protocol CBTrueToneClientProtocol {
    func supported() -> Bool
    func available() -> Bool
    func enabled() -> Bool
    func setEnabled(_ enabled: Bool) -> Bool
}

// DisplayServices.framework - Ambient Light Compensation (auto-brightness)
typealias DSEnableAmbientLightCompensation = @convention(c) (CGDirectDisplayID, Bool) -> Int32
typealias DSHasAmbientLightCompensation = @convention(c) (CGDirectDisplayID) -> Bool
typealias DSAmbientLightCompensationEnabled = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Bool>) -> Int32

// MARK: - True Tone

func setTrueTone(enabled: Bool) -> Bool {
    let handle = dlopen(
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY)
    guard handle != nil else {
        fputs("error: could not load CoreBrightness.framework\n", stderr)
        return false
    }
    defer { dlclose(handle) }

    guard let clientClass = NSClassFromString("CBTrueToneClient") as? NSObject.Type else {
        fputs("error: CBTrueToneClient class not found\n", stderr)
        return false
    }

    let client = clientClass.init()
    let sel_supported = NSSelectorFromString("supported")
    let sel_available = NSSelectorFromString("available")
    let sel_setEnabled = NSSelectorFromString("setEnabled:")

    guard client.responds(to: sel_supported),
        client.responds(to: sel_available),
        client.responds(to: sel_setEnabled)
    else {
        fputs("error: CBTrueToneClient missing expected methods\n", stderr)
        return false
    }

    // Use a more reliable way to call these methods
    typealias SupportedMethod = @convention(c) (AnyObject, Selector) -> Bool
    typealias SetEnabledMethod = @convention(c) (AnyObject, Selector, Bool) -> Bool

    let supportedIMP = client.method(for: sel_supported)
    let supportedFunc = unsafeBitCast(supportedIMP, to: SupportedMethod.self)
    guard supportedFunc(client, sel_supported) else {
        fputs("error: True Tone is not supported on this hardware\n", stderr)
        return false
    }

    let availableIMP = client.method(for: sel_available)
    let availableFunc = unsafeBitCast(availableIMP, to: SupportedMethod.self)
    guard availableFunc(client, sel_available) else {
        fputs("error: True Tone is not available\n", stderr)
        return false
    }

    let setEnabledIMP = client.method(for: sel_setEnabled)
    let setEnabledFunc = unsafeBitCast(setEnabledIMP, to: SetEnabledMethod.self)
    let result = setEnabledFunc(client, sel_setEnabled, enabled)

    if result {
        fputs("True Tone \(enabled ? "enabled" : "disabled") successfully\n", stderr)
    } else {
        fputs("error: failed to \(enabled ? "enable" : "disable") True Tone\n", stderr)
    }
    return result
}

// MARK: - Auto-Brightness

func setAutoBrightness(enabled: Bool) -> Bool {
    let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    guard handle != nil else {
        fputs("error: could not load DisplayServices.framework\n", stderr)
        return false
    }
    defer { dlclose(handle) }

    guard let hasALCPtr = dlsym(handle, "DisplayServicesHasAmbientLightCompensation"),
        let enableALCPtr = dlsym(handle, "DisplayServicesEnableAmbientLightCompensation")
    else {
        fputs("error: DisplayServices ambient light functions not found\n", stderr)
        return false
    }

    let hasALC = unsafeBitCast(hasALCPtr, to: DSHasAmbientLightCompensation.self)
    let enableALC = unsafeBitCast(enableALCPtr, to: DSEnableAmbientLightCompensation.self)

    let displayID = CGMainDisplayID()

    guard hasALC(displayID) else {
        fputs("error: ambient light compensation not available on this display\n", stderr)
        return false
    }

    let result = enableALC(displayID, enabled)
    if result == 0 {
        fputs("Auto-brightness \(enabled ? "enabled" : "disabled") successfully\n", stderr)
        return true
    } else {
        fputs("error: failed to \(enabled ? "enable" : "disable") auto-brightness (code: \(result))\n", stderr)
        return false
    }
}

// MARK: - Main

func printUsage() {
    let usage = """
        Usage: display-ctl [options]

        Options:
          --auto-brightness on|off    Enable or disable automatic brightness
          --true-tone on|off          Enable or disable True Tone
          --help                      Show this help message

        Examples:
          display-ctl --auto-brightness off --true-tone off
          display-ctl --auto-brightness on
          display-ctl --true-tone off
        """
    fputs(usage + "\n", stderr)
}

var args = Array(CommandLine.arguments.dropFirst())
var success = true
var didSomething = false

if args.isEmpty || args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(args.isEmpty ? 1 : 0)
}

var i = 0
while i < args.count {
    switch args[i] {
    case "--auto-brightness":
        guard i + 1 < args.count else {
            fputs("error: --auto-brightness requires on|off\n", stderr)
            exit(1)
        }
        i += 1
        switch args[i] {
        case "on": success = setAutoBrightness(enabled: true) && success
        case "off": success = setAutoBrightness(enabled: false) && success
        default:
            fputs("error: --auto-brightness requires on|off, got '\(args[i])'\n", stderr)
            exit(1)
        }
        didSomething = true

    case "--true-tone":
        guard i + 1 < args.count else {
            fputs("error: --true-tone requires on|off\n", stderr)
            exit(1)
        }
        i += 1
        switch args[i] {
        case "on": success = setTrueTone(enabled: true) && success
        case "off": success = setTrueTone(enabled: false) && success
        default:
            fputs("error: --true-tone requires on|off, got '\(args[i])'\n", stderr)
            exit(1)
        }
        didSomething = true

    default:
        fputs("error: unknown option '\(args[i])'\n", stderr)
        printUsage()
        exit(1)
    }
    i += 1
}

if !didSomething {
    printUsage()
    exit(1)
}

exit(success ? 0 : 1)
