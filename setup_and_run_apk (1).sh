#!/bin/bash

# Path to the APK file
APK_PATH="Last_version_mod_v2_86.apk"

# Check if the APK file exists
if [ ! -f "$APK_PATH" ]; then
    echo "APK file not found: $APK_PATH"
    exit 1
fi

# Function to install necessary tools
install_tools() {
    echo "Checking for necessary tools..."
    if ! command -v wget &> /dev/null; then
        echo "Installing wget..."
        sudo apt-get update
        sudo apt-get install -y wget
    fi
    if ! command -v unzip &> /dev/null; then
        echo "Installing unzip..."
        sudo apt-get install -y unzip
    fi
    if ! command -v adb &> /dev/null; then
        echo "Installing adb..."
        sudo apt-get install -y adb
    fi
    if ! command -v java &> /dev/null; then
        echo "Installing Java..."
        sudo apt-get install -y default-jre
    fi
    if ! command -v apktool &> /dev/null; then
        echo "Installing APKTool..."
        wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.6.0.jar -O apktool.jar
        wget https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
        chmod +x apktool
        sudo mv apktool /usr/local/bin/
        sudo mv apktool.jar /usr/local/bin/apktool.jar
    fi
    if ! command -v emulator &> /dev/null; then
        echo "Installing Android SDK tools..."
        mkdir -p "$HOME/Android/Sdk"
        cd "$HOME/Android/Sdk" || exit
        wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip -O commandlinetools.zip
        unzip commandlinetools.zip -d cmdline-tools
        rm commandlinetools.zip
        mv cmdline-tools/cmdline-tools cmdline-tools/latest
        export ANDROID_HOME="$HOME/Android/Sdk"
        export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
        export PATH="$ANDROID_HOME/platform-tools:$PATH"
        yes | sdkmanager --licenses
        sdkmanager "platform-tools" "platforms;android-30" "emulator" "system-images;android-30;google_apis;x86_64"
    fi
}

# Install necessary tools if not already installed
install_tools

# Decompile the APK to access the AndroidManifest.xml file
apktool d "$APK_PATH" -o decompiled_apk

# Extract the package name and main activity from AndroidManifest.xml
PACKAGE_NAME=$(grep -oP '(?<=package=")[^"]*' decompiled_apk/AndroidManifest.xml)
MAIN_ACTIVITY=$(grep -oP '(?<=android:name=")[^"]*(?=")' decompiled_apk/AndroidManifest.xml | grep -m 1 'MainActivity')

# Check if an AVD exists, create one if necessary
if ! avdmanager list avd | grep -q "test_avd"; then
    echo "Creating AVD..."
    echo "no" | avdmanager create avd -n test_avd -k "system-images;android-30;google_apis;x86_64" --device "pixel"
fi

# Start the Android emulator
EMULATOR_ID=$(adb devices | grep emulator | cut -f1)
if [ -z "$EMULATOR_ID" ]; then
    echo "Starting Android emulator..."
    emulator -avd test_avd &  # Replace 'test_avd' with the name of your AVD
    sleep 30  # Wait for the emulator to start
    EMULATOR_ID=$(adb devices | grep emulator | cut -f1)
    if [ -z "$EMULATOR_ID" ]; then
        echo "Failed to start the emulator."
        exit 1
    fi
fi

# Install the APK on the emulator
echo "Installing APK on emulator..."
adb -s $EMULATOR_ID install -r "$APK_PATH"

# Launch the main activity of the app
echo "Launching the app..."
adb -s $EMULATOR_ID shell am start -n "$PACKAGE_NAME/$MAIN_ACTIVITY"

echo "App launched successfully."