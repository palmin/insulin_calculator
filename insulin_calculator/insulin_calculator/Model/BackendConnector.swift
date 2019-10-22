//
//  BackendConnector.swift
//  insulin_calculator
//
//  Created by 李灿晨 on 10/17/19.
//  Copyright © 2019 李灿晨. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class BackendConnector: NSObject {
    
    /**
     The shared instance of object `BackendConnector`.
     */
    static var shared: BackendConnector = BackendConnector()
    
    private let backendURLString: String = "http://104.198.163.62:5000/nutritionestimation"
    
    /**
     Getting the session's recognition result.
     
     - Parameters:
        - token: The token of the user.
        - session_id: The id of the session, specified by a string.
        - jsonURL: The local URL of the JSON file which wraps the peripheral data of the capture.
        - photoURL: The local URL of the jpg image file of the color image capture.
        - completion: The completion handler.
     
     - Throws:
        Errors of type `NetworkError`(for unexpected response of backend server) or `Error`(for
            encoding problems).
     */
    func getRecognitionResult(
        token: String,
        session_id: String,
        jsonURL: URL,
        photoURL: URL,
        completion: ((SessionRecognitionResult?, Error?) -> ())?
    ) {
        let jsonData = try! Data(contentsOf: jsonURL)
        let photoData = try! Data(contentsOf: photoURL)
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(photoData, withName: "image", fileName: "image.jpg", mimeType: "image/jpg")
                multipartFormData.append(jsonData, withName: "peripheral", fileName: "peripheral.json", mimeType: "text/plain")
                multipartFormData.append(session_id.data(using: .utf8)!, withName: "session_id")
                multipartFormData.append(token.data(using: .utf8)!, withName: "token")
            },
            to: backendURLString,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseData() { dataResponse in
                        guard dataResponse.data != nil else {completion?(nil, NetworkError.unexpectedResponse);return}
                        do {
                            let json = try JSON(data: dataResponse.data!)
                            let result = try SessionRecognitionResult(json: json)
                            completion?(result, nil)
                        } catch {
                            completion?(nil, NetworkError.unexpectedResponse)
                            return
                        }
                    }
                case .failure(let encodingError):
                    completion?(nil, encodingError)
                }
            }
        )
    }
    
}