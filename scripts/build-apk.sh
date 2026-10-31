#!/usr/bin/env bash
set -e

echo "🐱 Building PurrPal Android APK..."

# 1. Build web distribution
npm run build

# 2. Check if Capacitor is present or install
if [ ! -d "node_modules/@capacitor/cli" ]; then
  echo "📦 Installing Capacitor dependencies..."
  npm install --no-save --legacy-peer-deps @capacitor/core @capacitor/cli @capacitor/android
fi

# 3. Initialize Capacitor if android folder doesn't exist
if [ ! -d "android" ]; then
  echo "📱 Initializing Android platform..."
  npx cap init "BabyPurrPal" "com.babypurrpal.app" --web-dir=dist
  npx cap add android
fi

# 4. Sync web assets
npx cap sync android

# 5. Build APK via Gradle
cd android
chmod +x gradlew
./gradlew assembleDebug

echo "🎉 Android APK successfully built!"
echo "📍 APK Location: android/app/build/outputs/apk/debug/app-debug.apk"
