#!/bin/sh

#  UniversalFramework.sh
#  SCNet-Swift
#
#  Created by pbj on 2018. 8. 30..
#  Copyright © 2018년 ijoon. All rights reserved.

if [ "true" == ${ALREADYINVOKED:-false} ]
then
echo "RECURSION: Detected, stopping"
else
export ALREADYINVOKED="true"

UNIVERSAL_OUTPUTFOLDER=${BUILD_DIR}/${CONFIGURATION}-iphoneuniversal

# make sure the output directory exists
mkdir -p "${UNIVERSAL_OUTPUTFOLDER}"

# Step 1. Build Device and Simulator versions
# => I will manually building because framework in Cocoapods
# xcodebuild -target "${TARGET_NAME}" ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} -sdk iphoneos  BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}"# clean build
# xcodebuild -target "${TARGET_NAME}" -configuration ${CONFIGURATION} -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}"# clean build

# Step 2. Copy the framework structure (from iphoneos build) to the universal folder
cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.framework" "${UNIVERSAL_OUTPUTFOLDER}/"
cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftProtobuf/SwiftProtobuf.framework" "${UNIVERSAL_OUTPUTFOLDER}/"
cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftSocket/SwiftSocket.framework" "${UNIVERSAL_OUTPUTFOLDER}/"


# Step 3. Copy Swift modules from iphonesimulator build (if it exists) to the copied framework directory
SIMULATOR_SWIFT_MODULES_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${PROJECT_NAME}.framework/Modules/${PROJECT_NAME}.swiftmodule/."
if [ -d "${SIMULATOR_SWIFT_MODULES_DIR}" ]; then
cp -R "${SIMULATOR_SWIFT_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/${PROJECT_NAME}.framework/Modules/${PROJECT_NAME}.swiftmodule"
fi
SIMULATOR_SWIFT_PROTOBUF_MODULES_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftProtobuf/SwiftProtobuf.framework/Modules/SwiftProtobuf.swiftmodule/."
if [ -d "${SIMULATOR_SWIFT_PROTOBUF_MODULES_DIR}" ]; then
cp -R "${SIMULATOR_SWIFT_PROTOBUF_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/SwiftProtobuf.framework/Modules/SwiftProtobuf.swiftmodule"
fi
SIMULATOR_SWIFT_SOCKET_MODULES_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftSocket/SwiftSocket.framework/Modules/SwiftSocket.swiftmodule/."
if [ -d "${SIMULATOR_SWIFT_SOCKET_MODULES_DIR}" ]; then
cp -R "${SIMULATOR_SWIFT_SOCKET_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/SwiftSocket.framework/Modules/SwiftSocket.swiftmodule"
fi

# Step 4. Create universal binary file using lipo and place the combined executable in the copied framework directory
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/${PROJECT_NAME}.framework/${PROJECT_NAME}" "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${PROJECT_NAME}.framework/${PROJECT_NAME}" "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.framework/${PROJECT_NAME}"
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/SwiftProtobuf.framework/SwiftProtobuf" "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftProtobuf/SwiftProtobuf.framework/SwiftProtobuf" "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftProtobuf/SwiftProtobuf.framework/SwiftProtobuf"
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/SwiftSocket.framework/SwiftSocket" "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftSocket/SwiftSocket.framework/SwiftSocket" "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftSocket/SwiftSocket.framework/SwiftSocket"
fi
