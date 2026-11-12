"""Patches the Android/iOS folders that `flutter create` generates in CI.

Adds notification permissions/receivers, core library desugaring (needed by
flutter_local_notifications), app display names and iOS deployment target.
Safe to run more than once.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_NAME = "Bills O9 Time"


def patch_gradle():
    groovy = ROOT / "android/app/build.gradle"
    kts = ROOT / "android/app/build.gradle.kts"
    if groovy.exists():
        p, s = groovy, groovy.read_text()
        if "coreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
            s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    elif kts.exists():
        p, s = kts, kts.read_text()
        if "isCoreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
            s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    else:
        sys.exit("android/app build file not found")
    p.write_text(s)
    print("patched", p.name)

    for name in ("settings.gradle", "settings.gradle.kts"):
        f = ROOT / "android" / name
        if f.exists():
            t = f.read_text()
            t2 = re.sub(r'(org\.jetbrains\.kotlin\.android"?\)?\s+version\s+")1\.[0-8]\.\d+', r"\g<1>1.9.24", t)
            if t2 != t:
                f.write_text(t2)
                print("bumped kotlin in", name)


def patch_manifest():
    f = ROOT / "android/app/src/main/AndroidManifest.xml"
    s = f.read_text()
    if "POST_NOTIFICATIONS" not in s:
        perms = (
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
            '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
            '    <uses-permission android:name="android.permission.VIBRATE"/>\n'
        )
        s = re.sub(r"(<manifest[^>]*>\n)", r"\g<1>" + perms, s, count=1)
        receivers = (
            '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
            '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
            '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
            '            </intent-filter>\n'
            '        </receiver>\n'
        )
        s = s.replace("    </application>", receivers + "    </application>", 1)
    s = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', s, count=1)
    f.write_text(s)
    print("patched AndroidManifest.xml")


def patch_ios():
    podfile = ROOT / "ios/Podfile"
    if podfile.exists():
        t = podfile.read_text()
        t = re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '13.0'", t, flags=re.M)
        podfile.write_text(t)
        print("patched Podfile")
    plist = ROOT / "ios/Runner/Info.plist"
    if plist.exists():
        t = plist.read_text()
        t = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
                   rf"\g<1>{APP_NAME}\g<2>", t)
        plist.write_text(t)
        print("patched Info.plist")
    pbx = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    if pbx.exists():
        t = pbx.read_text()
        t = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 13.0;", t)
        pbx.write_text(t)
        print("patched deployment target")


def patch_web():
    import json
    man = ROOT / "web/manifest.json"
    if man.exists():
        m = json.loads(man.read_text())
        m.update({
            "name": APP_NAME,
            "short_name": "Bills O9",
            "description": "Bill organizer, expense tracker and budget planner",
            "start_url": ".",
            "display": "standalone",
            "background_color": "#0F766E",
            "theme_color": "#0F766E",
            "orientation": "portrait",
        })
        man.write_text(json.dumps(m, indent=2))
        print("patched manifest.json")
    idx = ROOT / "web/index.html"
    if idx.exists():
        t = idx.read_text()
        t = re.sub(r"<title>[^<]*</title>", f"<title>{APP_NAME}</title>", t)
        t = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', rf"\g<1>Bills O9", t)
        if 'name="theme-color"' not in t:
            t = t.replace("</head>", '  <meta name="theme-color" content="#0F766E">\n</head>', 1)
        idx.write_text(t)
        print("patched index.html")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    if target in ("android", "all") and (ROOT / "android").exists():
        patch_gradle()
        patch_manifest()
    if target in ("ios", "all") and (ROOT / "ios").exists():
        patch_ios()
    if target in ("web", "all") and (ROOT / "web").exists():
        patch_web()
