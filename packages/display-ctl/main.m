// display-ctl: Toggle auto-brightness and True Tone on macOS
// Uses private CoreBrightness/DisplayServices framework APIs via dlopen/dlsym.
// Written in Objective-C to avoid Swift module version compatibility issues.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

// MARK: - DisplayServices function types (auto-brightness)

typedef Boolean (*DSHasAmbientLightCompensation)(CGDirectDisplayID display);
typedef int32_t (*DSEnableAmbientLightCompensation)(CGDirectDisplayID display, Boolean enable);

// MARK: - True Tone

static BOOL setTrueTone(BOOL enabled) {
    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
        RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "error: could not load CoreBrightness.framework\n");
        return NO;
    }

    Class clientClass = NSClassFromString(@"CBTrueToneClient");
    if (!clientClass) {
        fprintf(stderr, "error: CBTrueToneClient class not found\n");
        dlclose(handle);
        return NO;
    }

    id client = [[clientClass alloc] init];

    SEL selSupported = NSSelectorFromString(@"supported");
    SEL selAvailable = NSSelectorFromString(@"available");
    SEL selSetEnabled = NSSelectorFromString(@"setEnabled:");

    if (![client respondsToSelector:selSupported] ||
        ![client respondsToSelector:selAvailable] ||
        ![client respondsToSelector:selSetEnabled]) {
        fprintf(stderr, "error: CBTrueToneClient missing expected methods\n");
        dlclose(handle);
        return NO;
    }

    // Use IMP casting for reliable method dispatch
    typedef BOOL (*BoolMethod)(id, SEL);
    typedef BOOL (*SetEnabledMethod)(id, SEL, BOOL);

    BoolMethod supportedFunc = (BoolMethod)[client methodForSelector:selSupported];
    if (!supportedFunc(client, selSupported)) {
        fprintf(stderr, "error: True Tone is not supported on this hardware\n");
        dlclose(handle);
        return NO;
    }

    BoolMethod availableFunc = (BoolMethod)[client methodForSelector:selAvailable];
    if (!availableFunc(client, selAvailable)) {
        fprintf(stderr, "error: True Tone is not available\n");
        dlclose(handle);
        return NO;
    }

    SetEnabledMethod setEnabledFunc = (SetEnabledMethod)[client methodForSelector:selSetEnabled];
    BOOL result = setEnabledFunc(client, selSetEnabled, enabled);

    if (result) {
        fprintf(stderr, "True Tone %s successfully\n", enabled ? "enabled" : "disabled");
    } else {
        fprintf(stderr, "error: failed to %s True Tone\n", enabled ? "enable" : "disable");
    }

    dlclose(handle);
    return result;
}

// MARK: - Auto-Brightness

static BOOL setAutoBrightness(BOOL enabled) {
    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "error: could not load DisplayServices.framework\n");
        return NO;
    }

    DSHasAmbientLightCompensation hasALC = dlsym(handle, "DisplayServicesHasAmbientLightCompensation");
    DSEnableAmbientLightCompensation enableALC = dlsym(handle, "DisplayServicesEnableAmbientLightCompensation");

    if (!hasALC || !enableALC) {
        fprintf(stderr, "error: DisplayServices ambient light functions not found\n");
        dlclose(handle);
        return NO;
    }

    CGDirectDisplayID displayID = CGMainDisplayID();

    if (!hasALC(displayID)) {
        fprintf(stderr, "error: ambient light compensation not available on this display\n");
        dlclose(handle);
        return NO;
    }

    int32_t result = enableALC(displayID, enabled);
    dlclose(handle);

    if (result == 0) {
        fprintf(stderr, "Auto-brightness %s successfully\n", enabled ? "enabled" : "disabled");
        return YES;
    } else {
        fprintf(stderr, "error: failed to %s auto-brightness (code: %d)\n",
                enabled ? "enable" : "disable", result);
        return NO;
    }
}

// MARK: - Main

static void printUsage(void) {
    fprintf(stderr,
        "Usage: display-ctl [options]\n"
        "\n"
        "Options:\n"
        "  --auto-brightness on|off    Enable or disable automatic brightness\n"
        "  --true-tone on|off          Enable or disable True Tone\n"
        "  --help                      Show this help message\n"
        "\n"
        "Examples:\n"
        "  display-ctl --auto-brightness off --true-tone off\n"
        "  display-ctl --auto-brightness on\n"
        "  display-ctl --true-tone off\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL success = YES;
        BOOL didSomething = NO;

        if (argc < 2) {
            printUsage();
            return 1;
        }

        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
                printUsage();
                return 0;
            } else if (strcmp(argv[i], "--auto-brightness") == 0) {
                if (i + 1 >= argc) {
                    fprintf(stderr, "error: --auto-brightness requires on|off\n");
                    return 1;
                }
                i++;
                if (strcmp(argv[i], "on") == 0) {
                    success = setAutoBrightness(YES) && success;
                } else if (strcmp(argv[i], "off") == 0) {
                    success = setAutoBrightness(NO) && success;
                } else {
                    fprintf(stderr, "error: --auto-brightness requires on|off, got '%s'\n", argv[i]);
                    return 1;
                }
                didSomething = YES;
            } else if (strcmp(argv[i], "--true-tone") == 0) {
                if (i + 1 >= argc) {
                    fprintf(stderr, "error: --true-tone requires on|off\n");
                    return 1;
                }
                i++;
                if (strcmp(argv[i], "on") == 0) {
                    success = setTrueTone(YES) && success;
                } else if (strcmp(argv[i], "off") == 0) {
                    success = setTrueTone(NO) && success;
                } else {
                    fprintf(stderr, "error: --true-tone requires on|off, got '%s'\n", argv[i]);
                    return 1;
                }
                didSomething = YES;
            } else {
                fprintf(stderr, "error: unknown option '%s'\n", argv[i]);
                printUsage();
                return 1;
            }
        }

        if (!didSomething) {
            printUsage();
            return 1;
        }

        return success ? 0 : 1;
    }
}
