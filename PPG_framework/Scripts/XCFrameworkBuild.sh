#!/bin/sh

#  XCFrameworkBuld.sh
#  FlexiPlayer
#
#  Created by Przemyslaw Stajniak on 28/12/2020.
#  

echo "XCFrameworkBuild Script Start"
FINAL_PRODUCT_NAME="${1}"
IOS_SCHEME_NAME="${2}"

echo "XCFrameworkBuild FINAL_PRODUCT_NAME: ${FINAL_PRODUCT_NAME}"
echo "XCFrameworkBuild IOS_SCHEME_NAME: ${IOS_SCHEME_NAME}"

# Prebuild cleanup
rm -rf "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}.xcframework"
rm -rf "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Simulator.xcarchive"
rm -rf "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Device.xcarchive"

# iOS builds
xcodebuild archive -scheme "${IOS_SCHEME_NAME}" -destination "platform=iOS Simulator,name=iPhone 11" -sdk iphonesimulator -archivePath "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Simulator.xcarchive" SKIP_INSTALL=NO

xcodebuild archive -scheme "${IOS_SCHEME_NAME}" -destination "generic/platform=iOS" -archivePath "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Device.xcarchive" SKIP_INSTALL=NO

# tvOS builds

#xcodebuild -create-xcframework \
#-framework "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Device.xcarchive/Products/Library/Frameworks/${FINAL_PRODUCT_NAME}.framework" \
#-framework "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_macOS_Catalyst.xcarchive/Products/Library/Frameworks/${FINAL_PRODUCT_NAME}.framework" \
#-framework "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Simulator.xcarchive/Products/Library/Frameworks/${FINAL_PRODUCT_NAME}.framework" \
#-output "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}.xcframework"

xcodebuild -create-xcframework \
-framework "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Device.xcarchive/Products/Library/Frameworks/${FINAL_PRODUCT_NAME}.framework" \
-framework "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Simulator.xcarchive/Products/Library/Frameworks/${FINAL_PRODUCT_NAME}.framework" \
-output "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}.xcframework"

# Compressing stage
#cd Archives
#zip -r "${FINAL_PRODUCT_NAME}.xcframework.zip" "${FINAL_PRODUCT_NAME}.xcframework"
#cd ..

# Cleanup
rm -rf "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Simulator.xcarchive"
rm -rf "${PROJECT_DIR}/Archives/${FINAL_PRODUCT_NAME}_iOS_Device.xcarchive"
