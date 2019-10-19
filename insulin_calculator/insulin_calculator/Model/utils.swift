//
//  utils.swift
//  insulin_calculator
//
//  Created by 李灿晨 on 10/11/19.
//  Copyright © 2019 李灿晨. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMotion
import CoreML

/**
 Save the peripheral objects captured along with image as a temporary JSON file. The data includes session token
 of a capture, the depth map, food segmentation mask, camera calibration data, device attitude, and the image crop
 rect.
 
 - Parameters:
    - depthMap: The depth map captured along with the image, represente as `[[Float32]]`.
    - calibration: The calibration data of the camera when capturing the image.
    - attitude: The device attitude when capturing the image.
    - cropRect: The rect that represents how the image is cropped. See [metadataOutputRectConverted](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/1623495-metadataoutputrectconverted)
        for details.
    - completion: The completion handler. This closure will be called once the saving process finished, the
        parameter is the URL of the saved temporary file.
 */
func cacheEstimateImageCaptureData(
    depthMap: [[Float32]],
    calibration: AVCameraCalibrationData,
    attitude: CMAttitude,
    cropRect: CGRect,
    completion: @escaping ((URL) -> ())
) {
    let dataManager = DataManager.shared
    let jsonDict: [String : Any] = [
        "calibration_data" : [
            "intrinsic_matrix" : (0 ..< 3).map{ x in
                (0 ..< 3).map{ y in calibration.intrinsicMatrix[x][y]}
            },
            "pixel_size" : calibration.pixelSize,
            "intrinsic_matrix_reference_dimensions" : [
                calibration.intrinsicMatrixReferenceDimensions.width,
                calibration.intrinsicMatrixReferenceDimensions.height
            ],
            "lens_distortion_center" : [
                calibration.lensDistortionCenter.x,
                calibration.lensDistortionCenter.y
            ]
        ],
        "device_attitude" : [
            "pitch" : attitude.pitch,
            "roll" : attitude.roll,
            "yaw" : attitude.yaw
        ],
        "crop_rect" : [
            "origin" : [
                "x" : cropRect.origin.x,
                "y" : cropRect.origin.y
            ],
            "size" : [
                "width" : cropRect.size.width,
                "height" : cropRect.size.height
            ]
        ],
        "depth_data" : depthMap
    ]
    let jsonStringData = try! JSONSerialization.data(
        withJSONObject: jsonDict,
        options: .prettyPrinted
    )
    dataManager.saveTemporaryFile(data: jsonStringData, extensionName: "json", completion: completion)
}


/**
 Convert the depth data from `AVDepthData` to `[[Float32]]`, then crop the data with `rect` to obtain
 a square depth map.
 
 - Parameters:
    - depthData: The captured depth data.
    - rect: The rect that represents the region to preserve in the image. See [metadataOutputRectConverted](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/1623495-metadataoutputrectconverted)
    for details.
 */
func convertAndCropDepthData(depthData: AVDepthData, rect: CGRect) -> [[Float32]] {
    let disparityData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    let width = CVPixelBufferGetWidth(disparityData.depthDataMap)
    let height = CVPixelBufferGetHeight(disparityData.depthDataMap)
    let startRow = Int(rect.origin.y * CGFloat(height))
    let endRow = Int((rect.origin.y + rect.size.height) * CGFloat(height))
    let startCol = Int(rect.origin.x * CGFloat(width))
    let endCol = Int((rect.origin.x + rect.size.width) * CGFloat(width))
    var depthMap: [[Float32]] = Array(
        repeating: Array(repeating: 0, count: endCol - startCol),
        count: endRow - startRow
    )
    CVPixelBufferLockBaseAddress(
        disparityData.depthDataMap,
        CVPixelBufferLockFlags(rawValue: 0)
    )
    let floatBuffer = unsafeBitCast(
        CVPixelBufferGetBaseAddress(disparityData.depthDataMap),
        to: UnsafeMutablePointer<Float32>.self
    )
    var realRow = 0, realCol = 0
    for row in startRow ..< endRow {
        for col in startCol ..< endCol {
            depthMap[realRow][realCol] = 1.0 / floatBuffer[width * row + col]
            realCol += 1
        }
        realRow += 1
        realCol = 0
    }
    CVPixelBufferUnlockBaseAddress(
        disparityData.depthDataMap,
        CVPixelBufferLockFlags(rawValue: 0)
    )
    return depthMap
}


/**
 Crop the `AVCapturePhoto` with `rect`.
 
 - Parameters:
    - photo: The image to crop, represented as `AVCapturePhoto`.
    - rect: The rect that represents the region to preserve in the image. See [metadataOutputRectConverted](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/1623495-metadataoutputrectconverted)
    for details.
 
 - Returns:
    The `CGImage` object cropped from `photo` with `rect`.
 */
func cropImage(photo: AVCapturePhoto, rect: CGRect) throws -> CGImage {
    let image = photo.cgImageRepresentation()!.takeUnretainedValue()
    let croppedImage = image.cropping(to: CGRect(
        x: rect.origin.x * CGFloat(image.width),
        y: rect.origin.y * CGFloat(image.height),
        width: rect.size.width * CGFloat(image.width),
        height: rect.size.height * CGFloat(image.height)
    ))
    guard croppedImage != nil else {throw ValueError.shapeMismatch}
    return croppedImage!
}


/**
 Convert the `MLMultiArray` object to a 2d `Float32` array. Note that the `MLMultiArray` object have to
 have shape 1 * w * h.
 
 - Parameters:
    - multiArray: The multiarray to be converted.
 
 - Returns:
    A 2d `Float32` array converted from `multiArray` with shape w * h.
 */
func convertSegmentMaskData(multiArray: MLMultiArray) throws -> [[Float32]] {
    let totalValues = multiArray.count
    let area = Int(truncating: multiArray.shape[1]) * Int(truncating: multiArray.shape[2])
    guard multiArray.shape.count == 3 && area == totalValues else {throw ValueError.shapeMismatch}
    let floatMutablePointer = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: multiArray.count)
    let floatArray = Array(UnsafeBufferPointer(start: floatMutablePointer, count: multiArray.count))
    var float2dArray: [[Float32]] = Array(
        repeating: Array(repeating: 0, count: multiArray.shape[1] as! Int),
        count: multiArray.shape[2] as! Int
    )
    for row in 0 ..< (multiArray.shape[1] as! Int) {
        for col in 0 ..< (multiArray.shape[2] as! Int) {
            float2dArray[row][col] = floatArray[row * col + col]
        }
    }
    return float2dArray
}
