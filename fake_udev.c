/*
 * fake_udev.c — stub udev library for Vivado inside Docker.
 *
 * Vivado's license manager and webtalk system call udev functions to
 * fingerprint the host machine. In Docker, libudev crashes because the udev
 * data from the host kernel doesn't match what Ubuntu 22.04's libudev expects.
 *
 * Vivado's webtalk uses dlopen("libudev.so.1") with a private namespace,
 * bypassing LD_PRELOAD. The fix is to replace the system libudev.so.1
 * entirely with this stub so all callers get safe no-op implementations.
 *
 * Compile:  gcc -shared -fPIC -o libudev.so.1 fake_udev.c
 * Install:  cp libudev.so.1 /lib/x86_64-linux-gnu/libudev.so.1
 */

#include <stdlib.h>
#include <stddef.h>

typedef struct udev           udev;
typedef struct udev_enumerate udev_enumerate;
typedef struct udev_list_entry udev_list_entry;
typedef struct udev_device    udev_device;

struct udev           { int _dummy; };
struct udev_enumerate { int _dummy; };

udev* udev_new(void) {
    return calloc(1, sizeof(udev));
}

udev* udev_ref(udev* u) {
    return u;
}

udev* udev_unref(udev* u) {
    free(u);
    return NULL;
}

udev_enumerate* udev_enumerate_new(udev* u) {
    return calloc(1, sizeof(udev_enumerate));
}

int udev_enumerate_scan_devices(udev_enumerate* ue) {
    return 0;
}

udev_list_entry* udev_enumerate_get_list_entry(udev_enumerate* ue) {
    return NULL;
}

udev_enumerate* udev_enumerate_unref(udev_enumerate* ue) {
    free(ue);
    return NULL;
}

int udev_enumerate_add_match_subsystem(udev_enumerate* ue, const char* subsystem) {
    return 0;
}

int udev_enumerate_add_match_property(udev_enumerate* ue, const char* property, const char* value) {
    return 0;
}

int udev_enumerate_add_match_sysattr(udev_enumerate* ue, const char* sysattr, const char* value) {
    return 0;
}

int udev_enumerate_scan_subsystems(udev_enumerate* ue) {
    return 0;
}

udev_list_entry* udev_list_entry_get_next(udev_list_entry* le) {
    return NULL;
}

const char* udev_list_entry_get_name(udev_list_entry* le) {
    return NULL;
}
