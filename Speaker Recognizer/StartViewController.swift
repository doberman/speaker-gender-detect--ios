//
//  StartViewController.swift
//  Speaker Recognizer
//
//  Created by Erik Lindebratt on 11/02/16.
//  Copyright © 2016 Doberman. All rights reserved.
//

import UIKit

class StartViewController: UIViewController, AudioRecorderDelegate {

    let shapeLayer: CAShapeLayer = CAShapeLayer()
    
    var audioRecorder: AudioRecorder?
    var setGenderEqualityDividerTimer: NSTimer?
    var isAnimatingBackground: Bool = false
    var audioRecorderLevelNormalized: Float = 0.0
    var genderEqualityRatio: (male: Float, female: Float) = (male: 0.5, female: 0.5)
    
    @IBOutlet weak var bottomContainerView: UIView!
    @IBOutlet weak var startListeningButton: RoundedButton!
    @IBOutlet weak var femaleIconView: UIImageView!
    @IBOutlet weak var maleIconView: UIImageView!
    @IBOutlet weak var malePercentage: UILabel!
    @IBOutlet weak var femalePercentage: UILabel!
    
    
    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.runEntryAnimation()
        self.buildGenderRatioDivider()
        
        self.genderEqualityRatio = (male: 0.5, female: 0.5)
        
        self.femaleIconView.alpha = 0.0
        self.maleIconView.alpha = 0.0
        self.femalePercentage.alpha = 0.0
        self.malePercentage.alpha = 0.0
    }
    
    
    // MARK: - Custom methods
    private func runEntryAnimation() {
        let bottomContaineerViewOriginX = self.bottomContainerView.layer.position.x

        self.bottomContainerView.alpha = 0
        self.bottomContainerView.transform = CGAffineTransformMakeTranslation(0, bottomContaineerViewOriginX)
        
        UIView.animateWithDuration(0.6, delay: 0.8, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: .CurveEaseIn, animations: {
                self.bottomContainerView.alpha = 1
                self.bottomContainerView.transform = CGAffineTransformIdentity
            }, completion: nil
        )
    }
    
    
    // MARK: - Visualizations
    private func animateViewBackgroundColorDebounce() {
        if self.isAnimatingBackground {
            return
        }
        
        UIView.animateWithDuration(0.15, animations: {
            self.isAnimatingBackground = true
            self.view.backgroundColor = UIColor(red: 0.149, green: 0.316, blue: 1.0, alpha: CGFloat(self.audioRecorderLevelNormalized))
        }, completion: { finished in
            self.isAnimatingBackground = false
        })
    }
    
    private func toggleGenderRatioDivider(toOpacity: Float = 0.225, toScaleY: CGFloat = 1) {
        UIView.animateWithDuration(0.4) {
            self.shapeLayer.opacity = toOpacity
            self.femaleIconView.alpha = CGFloat(toOpacity)
            self.maleIconView.alpha = CGFloat(toOpacity)
            self.femalePercentage.alpha = CGFloat(toOpacity)
            self.malePercentage.alpha = CGFloat(toOpacity)
        }
        
        if let t = self.setGenderEqualityDividerTimer {
            t.invalidate()
        }
        
        self.setGenderEqualityDividerTimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("setGenderEqualityShape"), userInfo: nil, repeats: true)
    }
    
    private func buildGenderRatioDivider() {
        let path = self.getGenderRatioDividerPath()
        let pathWidth: CGFloat = 4
        
        self.shapeLayer.path = path
        self.shapeLayer.lineWidth = pathWidth
        self.shapeLayer.strokeColor = UIColor.whiteColor().CGColor
        self.shapeLayer.fillColor = UIColor.clearColor().CGColor
        self.shapeLayer.opacity = 0;
        
        self.view.layer.insertSublayer(self.shapeLayer, atIndex: 0)
    }
    
    private func getGenderRatioDividerPath() -> CGMutablePathRef {
        let path = CGPathCreateMutable()
        let pathPoints = self.getPathPoints()
        
        Utils.interpolatePointsWithHermite(path, interpolationPoints: pathPoints)
        
        return path
    }
    
    private func getPathPoints() -> [CGPoint] {
        let numOfPoints: Int = 5
        let x: CGFloat = self.view.bounds.width*0.2 + (self.view.bounds.width*0.6 * CGFloat(self.genderEqualityRatio.male))
        let y: CGFloat = self.view.bounds.height
        let yFraction: CGFloat = y / CGFloat(numOfPoints)
        var pathPoints: [CGPoint] = [CGPoint(x: x, y: 0), CGPoint(x: x, y: y)]
        
        for var i: Int = 1; i <= numOfPoints; i++ {
            let pointY = yFraction * CGFloat(i)
            var point = CGPoint(x: x, y: pointY)
            
            let noise = max(0, 70.0 * CGFloat(self.audioRecorderLevelNormalized))
            if i % 2 == 0 {
                point.x -= noise
            } else {
                point.x += noise
            }
            
            pathPoints.insert(point, atIndex: i)
        }
        
        return pathPoints
    }
    
    
    // MARK: - Public methods
    
    func setGenderEqualityShape() {
        let newPath = self.getGenderRatioDividerPath()
        
        let animatePath = CABasicAnimation(keyPath: "path")
        animatePath.fromValue = self.shapeLayer.path
        animatePath.toValue = newPath
        animatePath.duration = 0.1
        animatePath.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        self.shapeLayer.path = newPath
        self.shapeLayer.addAnimation(animatePath, forKey: "animatePath")
    }
    
    @IBAction func onStartListeningButtonTouchUpInside(sender: RoundedButton) {
        if sender.buttonState == "uncollapsed" {
            sender.setState("collapsed")
            
            if self.audioRecorder == nil {
                self.audioRecorder = AudioRecorder.sharedInstance
                self.audioRecorder!.delegate = self
            }
            
            self.audioRecorder!.startRecording()
            self.toggleGenderRatioDivider()
            
            // prevent app sleep
            UIApplication.sharedApplication().idleTimerDisabled = true
            
        } else if sender.buttonState == "collapsed" {
            UIView.animateWithDuration(0.4, animations: {
                self.view.backgroundColor = UIColor(red: 0.149, green: 0.316, blue: 1.0, alpha: 1.0)
            })
            
            sender.setState("uncollapsed")
            self.audioRecorder!.stopRecording()
            self.toggleGenderRatioDivider(0.0)
            
            // reset app sleep
            UIApplication.sharedApplication().idleTimerDisabled = false
        }
    }
    
    
    // MARK: - AudioRecorderDelegate methods
    
    func audioRecorder(audioRecorder: AudioRecorder?, updatedLevel: Float) {
        let audioRecorderLevelNormalized = (abs(updatedLevel) - (-11)) / ((-54) - (-11)) + 1.45
        
        self.audioRecorderLevelNormalized = audioRecorderLevelNormalized
        
        self.animateViewBackgroundColorDebounce()
    }
    
    func audioRecorder(audioRecorder: AudioRecorder?, updatedGenderEqualityRatio: (male: Float, female: Float)) {
        print("updatedGenderEqualityRatio - male: \(updatedGenderEqualityRatio.male) | female: \(updatedGenderEqualityRatio.female)")
        
        self.genderEqualityRatio = updatedGenderEqualityRatio
        self.setGenderEqualityShape()
        self.malePercentage.text = String(Int(round(updatedGenderEqualityRatio.male*100))) + "%"
        self.femalePercentage.text = String(Int(round(updatedGenderEqualityRatio.female*100))) + "%"
    }
}
