#!/usr/bin/env bash
set -eu

# --- PATH CONFIGURATION ---
PROJECT_ROOT="${ANDROID_PROJECT_ROOT:-$PWD/android_source}"
DEPS_ROOT="${DEPENDENCIES_ROOT:-$PWD/lib}"
OUTPUT_DEST="${OUTPUT_DIR:-$PWD/output}"
CACHE_ROOT="${CACHE_DIR:-$PWD/cache}"

# --- ENV SETUP ---
export ANDROID_HOME="$DEPS_ROOT/cmdline-tools"
export JAVA_HOME="$DEPS_ROOT/jvm/jdk-17.0.2"
export GRADLE_HOME="$DEPS_ROOT/gradle/gradle-7.4"
export GRADLE_USER_HOME="$CACHE_ROOT/.gradle-cache"
export PATH="$JAVA_HOME/bin:$GRADLE_HOME/bin:$PATH"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${BLUE}[*]${NC} $1"; }
error() { echo -e "${RED}[!]${NC} $1"; exit 1; }

if [ ! -d "$PROJECT_ROOT" ]; then
    error "Android Source directory not found at: $PROJECT_ROOT"
fi
cd "$PROJECT_ROOT"

try() {
    if ! "$@"; then
        error "Command failed: $*"
    fi
}

ensure_deps() {
    [ -d "$ANDROID_HOME" ] || error "Android SDK not found. Please run 'python setup.py' first."
    [ -x "$GRADLE_HOME/bin/gradle" ] || error "Gradle not found. Please run 'python setup.py' first."
}

detect_app_name() {
    local detected="unknown"
    if [ -f app/build.gradle ]; then
        detected=$(grep -Po '(?<=applicationId "com\.)[^.]*' app/build.gradle 2>/dev/null || true)
    fi
    if [ -z "$detected" ]; then
        detected="unknown"
    fi
    echo "$detected"
}

apk() {
    ensure_deps
    [ ! -f "app/my-release-key.jks" ] && error "Keystore not found. Run 'python setup.py'."

    local appname
    appname="$(detect_app_name)"

    rm -f app/build/outputs/apk/release/app-release.apk
    info "Building APK..."

    echo "sdk.dir=$ANDROID_HOME" > local.properties
    try gradle assembleRelease --project-cache-dir "$CACHE_ROOT/.gradle"

    if [ -f "app/build/outputs/apk/release/app-release.apk" ]; then
        log "APK Built Successfully!"
        cp "app/build/outputs/apk/release/app-release.apk" "$OUTPUT_DEST/$appname.apk"
        log "Saved to $OUTPUT_DEST/$appname.apk"
    else
        error "Build failed"
    fi
}

clean() {
    info "Cleaning build files..."
    try rm -rf app/build
}

if [ $# -eq 0 ]; then
    error "Usage: $0 {apk|clean}"
fi

case "$1" in
    apk)
        apk
        ;;
    clean)
        clean
        ;;
    *)
        error "Unknown command: $1 (expected: apk | clean)"
        ;;
esac
