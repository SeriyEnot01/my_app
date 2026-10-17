#!/usr/bin/env python3
"""Adjusts the platform folders that `flutter create` generates in CI.

usage: python tool/patch_platforms.py android|windows

Android: app name, permissions and receivers for scheduled notifications, release signing
from android/key.properties (written by CI from secrets), core library desugaring,
compileSdk 35, newer Kotlin/AGP/Gradle, notification icon, R8 keep rules.
Windows: window title.
Every edit checks that it applied, so a changed Flutter template fails loudly.
"""
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8")
    print("patched", p.relative_to(ROOT))


def must_sub(pattern, repl, text, what, count=1, flags=0):
    new, n = re.subn(pattern, repl, text, count=count, flags=flags)
    if n == 0:
        sys.exit(f"patch_platforms: could not apply '{what}'. The Flutter template may have changed.")
    return new


def android():
    a = ROOT / "android"
    manifest = a / "app/src/main/AndroidManifest.xml"
    m = read(manifest)
    if "POST_NOTIFICATIONS" not in m:
        perms = (
            '    <uses-permission android:name="android.permission.INTERNET"/>\n'
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
            '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
            '    <uses-permission android:name="android.permission.VIBRATE"/>\n'
        )
        m = must_sub(r"(\n\s*<application)", "\n" + perms + r"\1", m, "permissions")
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
        m = must_sub(r"(\s*</application>)", "\n" + receivers.rstrip("\n") + r"\1", m, "notification receivers")
    m = must_sub(r'android:label="[^"]*"', 'android:label="workflows"', m, "app label")
    # Never copy app data (decrypted cache, sign-in token) to Google Drive backups or device transfers.
    if "allowBackup" not in m:
        m = must_sub(
            r"<application\b",
            '<application\n        android:allowBackup="false"\n        android:fullBackupContent="false"\n'
            '        android:dataExtractionRules="@xml/data_extraction_rules"',
            m,
            "disable backups",
        )
    if "REQUEST_INSTALL_PACKAGES" not in m:
        m = must_sub(
            r"(\n\s*<application)",
            '\n    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>' + r"\1",
            m,
            "install permission",
        )
    if "UpdateFileProvider" not in m:
        provider = (
            '        <provider\n'
            '            android:name=".UpdateFileProvider"\n'
            '            android:authorities="${applicationId}.updates"\n'
            '            android:exported="false"\n'
            '            android:grantUriPermissions="true">\n'
            '            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/update_paths" />\n'
            '        </provider>\n'
        )
        m = must_sub(r"(\s*</application>)", lambda mo: "\n" + provider.rstrip("\n") + mo.group(1), m, "update file provider")
    write(manifest, m)

    # in-app updates: MainActivity with an install channel + FileProvider for the downloaded APK
    activities = list((a / "app/src/main/kotlin").rglob("MainActivity.kt"))
    if len(activities) != 1:
        sys.exit("patch_platforms: expected one MainActivity.kt, found %d" % len(activities))
    act = activities[0]
    pkg = re.search(r"^package\s+([\w.]+)", read(act), re.M).group(1)
    for name in ["MainActivity.kt", "UpdateFileProvider.kt"]:
        write(act.parent / name, read(ROOT / "tool/android" / name).replace("__PACKAGE__", pkg))
    xml_dir = a / "app/src/main/res/xml"
    xml_dir.mkdir(parents=True, exist_ok=True)
    domains = "".join(f'        <exclude domain="{d}" path="." />\n' for d in ["root", "file", "database", "sharedpref", "external"])
    write(
        xml_dir / "data_extraction_rules.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n<data-extraction-rules>\n'
        f'    <cloud-backup>\n{domains}    </cloud-backup>\n'
        f'    <device-transfer>\n{domains}    </device-transfer>\n'
        '</data-extraction-rules>\n',
    )
    write(
        xml_dir / "update_paths.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<paths>\n    <cache-path name="updates" path="updates/" />\n</paths>\n',
    )

    gradle = a / "app/build.gradle"
    if not gradle.exists():
        sys.exit("patch_platforms: android/app/build.gradle not found (Kotlin DSL template?). Use the Flutter version pinned in the workflow.")
    g = read(gradle)
    if "keystoreProperties" not in g:
        g = must_sub(
            r"\nandroid \{",
            "\ndef keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\nandroid {",
            g,
            "keystore properties",
        )
        g = must_sub(r"compileSdk\s*=?\s*flutter\.compileSdkVersion", "compileSdk = 35", g, "compileSdk")
        g = must_sub(r"(compileOptions \{)", r"\1\n        coreLibraryDesugaringEnabled true", g, "desugaring flag")
        g = must_sub(
            r"(\n\s*buildTypes \{)",
            "\n    signingConfigs {\n"
            "        release {\n"
            "            if (keystorePropertiesFile.exists()) {\n"
            "                keyAlias keystoreProperties['keyAlias']\n"
            "                keyPassword keystoreProperties['keyPassword']\n"
            "                storeFile file(keystoreProperties['storeFile'])\n"
            "                storePassword keystoreProperties['storePassword']\n"
            "            }\n"
            "        }\n"
            "    }\n"
            r"\1",
            g,
            "signing configs",
        )
        g = must_sub(
            r"signingConfig\s*=?\s*signingConfigs\.debug",
            "signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug\n"
            "            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'",
            g,
            "release signing",
        )
        g = g.rstrip() + "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n    implementation 'androidx.core:core:1.12.0'\n}\n"
    write(gradle, g)

    settings = a / "settings.gradle"
    if settings.exists():
        s = read(settings)
        s = must_sub(r'(id "org\.jetbrains\.kotlin\.android" version )"[^"]+"', r'\1"1.9.24"', s, "kotlin version")
        s = must_sub(r'(id "com\.android\.application" version )"[^"]+"', r'\1"8.3.2"', s, "AGP version")
        write(settings, s)

    wrapper = a / "gradle/wrapper/gradle-wrapper.properties"
    w = read(wrapper)
    w = must_sub(r"gradle-[\d.]+-(all|bin)\.zip", "gradle-8.7-all.zip", w, "gradle version")
    write(wrapper, w)

    props = a / "gradle.properties"
    p = read(props)
    for line in ["android.suppressUnsupportedCompileSdk=35", "kotlin.jvm.target.validation.mode=warning"]:
        if line not in p:
            p = p.rstrip() + "\n" + line + "\n"
    write(props, p)

    write(
        a / "app/proguard-rules.pro",
        "# flutter_local_notifications stores scheduled notifications with Gson\n"
        "-keep class com.dexterous.** { *; }\n"
        "-keepattributes Signature\n"
        "-keepattributes *Annotation*\n"
        "-keep class com.google.gson.reflect.TypeToken { *; }\n"
        "-keep class * extends com.google.gson.reflect.TypeToken\n"
        "-dontwarn com.google.android.play.core.**\n",
    )

    res = a / "app/src/main/res"
    (res / "drawable").mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / "assets/ic_stat_notify.png", res / "drawable/ic_stat_notify.png")
    print("copied notification icon")
    (res / "raw").mkdir(parents=True, exist_ok=True)
    write(
        res / "raw/keep.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_notify" />\n',
    )


def windows():
    main_cpp = ROOT / "windows/runner/main.cpp"
    c = read(main_cpp)
    title = 'L"workflows"'
    if 'L"zadachnik"' not in c:
        sys.exit("patch_platforms: could not apply 'window title'. The Flutter template may have changed.")
    write(main_cpp, c.replace('L"zadachnik"', title))


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else ""
    if target == "android":
        android()
    elif target == "windows":
        windows()
    else:
        sys.exit("usage: patch_platforms.py android|windows")
