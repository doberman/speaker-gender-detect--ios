//
//  AudioRecorder.swift
//  Speaker Recognizer
//
//  Created by Erik Lindebratt on 11/02/16.
//  Copyright © 2016 Doberman. All rights reserved.
//

import AVFoundation
import Alamofire
import SwiftyJSON

protocol AudioRecorderDelegate {
    func audioRecorder(audioRecorder: AudioRecorder?, updatedLevel: Float)
    func audioRecorder(audioRecorder: AudioRecorder?, updatedGenderEqualityRatio: (male: Float, female: Float))
}

class AudioRecorder: NSObject {
    static let sharedInstance: AudioRecorder = AudioRecorder()
    private let kRemoteURL: NSURL = NSURL(string: "<your-upload-api-endpoint-url>")!  // change to your API endpoint URL
    private let kPostAudioInterval: NSTimeInterval = 30.0  // change to post to API more/less frequently
    
    var delegate: AudioRecorderDelegate?
    
    private let recorderSettings = [
        AVSampleRateKey: NSNumber(float: Float(16000.0)),
        AVFormatIDKey: NSNumber(int: Int32(kAudioFormatMPEG4AAC)),
        AVNumberOfChannelsKey: NSNumber(int: 1),
        AVEncoderAudioQualityKey: NSNumber(int: Int32(AVAudioQuality.High.rawValue))
    ]
    
    private var recorder: AVAudioRecorder?
    private var checkLevelsTimer: NSTimer?
    private var postTimer: NSTimer?
    
    private var maleDuration: Float = 0.0
    private var femaleDuration: Float = 0.0

    override init() {
        super.init()
        
        do {
            let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
        } catch let err as NSError {
            print("Failed to initialize AudioRecorder: \(err)")
        }
    }
    
    func startRecording() {
//        print("startRecording")
        
        if self.recorder != nil && self.recorder!.recording {
            self.stopRecording()
        }
        
        let audioURL: NSURL = self.getAudioURL()
//        print("got audioURL: '\(audioURL)'")
        
        do {
            self.recorder = try AVAudioRecorder(URL: audioURL, settings: self.recorderSettings)
            self.recorder?.meteringEnabled = true
            self.recorder?.prepareToRecord()
        } catch let err as NSError {
            print("Failed to set up AVAudioRecorder instance: \(err)")
        }
        guard self.recorder != nil else { return }
        
        self.recorder?.record()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            self.checkLevelsTimer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: "checkLevels", userInfo: nil, repeats: true)
            self.postTimer = NSTimer.scheduledTimerWithTimeInterval(kPostAudioInterval, target: self, selector: "onPostTimerTrigger", userInfo: nil, repeats: true)
        } catch let err as NSError {
            print("Failed to activate audio session (or failed to set up checkLevels timer): \(err)")
        }
    }
    
    func stopRecording(shouldSubmitAudioAfterStop: Bool = false) {
//        print("stopRecording")
        
        guard self.recorder != nil else {
            print("`self.recorder` is `nil` - no recording to stop")
            return
        }
        
        self.recorder?.stop()
        
        if let t = self.checkLevelsTimer {
            t.invalidate()
            self.checkLevelsTimer = nil
        }
        
        if let t = self.postTimer {
            t.invalidate()
            self.postTimer = nil
        }
        
        let audioURL: NSURL = self.recorder!.url
        self.recorder = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false)
            if shouldSubmitAudioAfterStop {
                self.postAudio(audioURL)
            } else {
//                print("`shouldSubmitAudioAfterStop` is `false` - I won't post audio")
            }
        } catch let err as NSError {
            print("Failed to deactivate audio session (or failed to post audio): \(err)")
        }
    }
    
    
    // MARK: -
    func checkLevels() {
        guard self.recorder != nil else {
            print("`self.recorder` is `nil` - can't check levels")
            return
        }
        
        self.recorder?.updateMeters()
        let averagePower: Float = self.recorder!.averagePowerForChannel(0)
        
        if let d = self.delegate {
            d.audioRecorder(self, updatedLevel: averagePower)
        } else {
            print("AudioRecorder - averagePower: \(averagePower)")
        }
    }
    
    func onPostTimerTrigger() {
//        print("onPostTimerTrigger")
        
        guard let r = self.recorder else {
            print("`self.recorder` is `nil` - no audio to post")
            return
        }
        
        if !r.recording {
            print("not recording - no audio to post")
        }
        
        self.stopRecording(true)
        self.startRecording()
    }
    
    
    // MARK: -
    private func getAudioURL(filename: String = "recording") -> NSURL {
        let fileManager: NSFileManager = NSFileManager.defaultManager()
        let urls: [NSURL] = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let documentDirectory: NSURL = urls[0] as NSURL
        
        let uniqueFilename = "\(filename)_\(NSDate().timeIntervalSince1970)"
        
        let audioURL: NSURL = documentDirectory.URLByAppendingPathComponent("\(uniqueFilename).m4a")
        return audioURL
    }
    
    private func postAudio(audioURL: NSURL) {
//        print("AudioRecorder.postAudio - audioURL: \(audioURL.absoluteString)")
        
        Alamofire.upload(Method.POST, kRemoteURL, multipartFormData: { multipartFormData in
            multipartFormData.appendBodyPart(fileURL: audioURL, name: "file")
        }, encodingCompletion: { encodingResult in
            switch encodingResult {
            case .Success (let upload, _, _):
                upload.responseString { response in
                    //print("response: \(response)")
                    
                    let genderEqualityRatios = self.calcGenderEquality(String(response.result.value!))
                    if let eq = genderEqualityRatios, let d = self.delegate {
                        d.audioRecorder(self, updatedGenderEqualityRatio: eq)
                    }
                }
            case .Failure(let encodingError):
                print("encodingError: \(encodingError)")
            }
        })
    }
    
    private func calcGenderEquality(response: String) -> (male: Float, female: Float)? {
        guard let dataFromString = response.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) else {
            return nil
        }
        
        let json = JSON(data: dataFromString)
        
        for selection in json["selections"].arrayValue {
            if selection["gender"] == "M" {
                self.maleDuration = self.maleDuration + (selection["endTime"].floatValue - selection["startTime"].floatValue)
            } else if selection["gender"] == "F" {
                self.femaleDuration = self.maleDuration + (selection["endTime"].floatValue - selection["startTime"].floatValue)
            }
        }
        let spokenDuration = self.maleDuration + self.femaleDuration
        let maleFactor = self.maleDuration / spokenDuration
        let femaleFactor = self.femaleDuration / spokenDuration
        
        guard !maleFactor.isNaN else {
            print("Failed to calculate gender equality (`maleFactor` is `NaN`)")
            return nil
        }
        
        guard !femaleFactor.isNaN else {
            print("Failed to calculate gender equality (`femaleFactor` is `NaN`)")
            return nil
        }
        
        return (male: maleFactor, female: femaleFactor)
    }
}
