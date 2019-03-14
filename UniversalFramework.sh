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
if [ -e "${PROJECT_NAME}.xcworkspace" ]
then
xcodebuild -workspace ${PROJECT_NAME}.xcworkspace -scheme ${PROJECT_NAME} -sdk iphoneos ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} build CONFIGURATION_BUILD_DIR=${BUILD_DIR}/${CONFIGURATION}-iphoneos OBJROOT="${OBJROOT}/DependantBuilds"
else
echo "${PROJECT_NAME}.xcworkspace not found."
fi

if [ -e "${PROJECT_NAME}.xcworkspace" ]
then
xcodebuild -workspace ${PROJECT_NAME}.xcworkspace -scheme ${PROJECT_NAME} -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} build CONFIGURATION_BUILD_DIR=${BUILD_DIR}/${CONFIGURATION}-iphonesimulator OBJROOT="${OBJROOT}/DependantBuilds"
else
echo "${PROJECT_NAME}.xcworkspace not found."
fi

# Step 2. Copy the framework structure (from iphoneos build) to the universal folder
cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.framework" "${UNIVERSAL_OUTPUTFOLDER}/"
cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftProtobuf.framework" "${UNIVERSAL_OUTPUTFOLDER}/SwiftProtobuf"
cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftSocket.framework" "${UNIVERSAL_OUTPUTFOLDER}/SwiftSocket"


# Step 3. Copy Swift modules from iphonesimulator build (if it exists) to the copied framework directory
SIMULATOR_SWIFT_MODULES_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${PROJECT_NAME}.framework/Modules/${PROJECT_NAME}.swiftmodule/."
if [ -d "${SIMULATOR_SWIFT_MODULES_DIR}" ]; then
cp -R "${SIMULATOR_SWIFT_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/${PROJECT_NAME}.framework/Modules/${PROJECT_NAME}.swiftmodule"
fi
SIMULATOR_SWIFT_PROTOBUF_MODULES_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftProtobuf.framework/Modules/SwiftProtobuf.swiftmodule/."
if [ -d "${SIMULATOR_SWIFT_PROTOBUF_MODULES_DIR}" ]; then
cp -R "${SIMULATOR_SWIFT_PROTOBUF_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/SwiftProtobuf/SwiftProtobuf.framework/Modules/SwiftProtobuf.swiftmodule"
fi
SIMULATOR_SWIFT_SOCKET_MODULES_DIR="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftSocket.framework/Modules/SwiftSocket.swiftmodule/."
if [ -d "${SIMULATOR_SWIFT_SOCKET_MODULES_DIR}" ]; then
cp -R "${SIMULATOR_SWIFT_SOCKET_MODULES_DIR}" "${UNIVERSAL_OUTPUTFOLDER}/SwiftSocket/SwiftSocket.framework/Modules/SwiftSocket.swiftmodule"
fi

## Step 4. Create universal binary file using lipo and place the combined executable in the copied framework directory
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/${PROJECT_NAME}.framework/${PROJECT_NAME}" \
                    "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${PROJECT_NAME}.framework/${PROJECT_NAME}"\
                    "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.framework/${PROJECT_NAME}"
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/SwiftProtobuf/SwiftProtobuf.framework/SwiftProtobuf" \
                    "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftProtobuf.framework/SwiftProtobuf" \
                    "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftProtobuf.framework/SwiftProtobuf"
lipo -create -output "${UNIVERSAL_OUTPUTFOLDER}/SwiftSocket/SwiftSocket.framework/SwiftSocket" \
                    "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/SwiftSocket.framework/SwiftSocket" \
                    "${BUILD_DIR}/${CONFIGURATION}-iphoneos/SwiftSocket.framework/SwiftSocket"
fi
