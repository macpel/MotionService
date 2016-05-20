//
//  MotionService.swift
//
//  Created by MPELLUS on 4/29/16.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import CoreMotion

protocol MotionServiceDelegate: class {
    func MotionServiceisReporting(sender: MotionService, motionType: MotionType)
}

enum MotionType {
    case Unknown
    case Still
    case SlowMoving
    case FastMoving
}

class MotionService {
    
    // Public
    var staticThreshold: Double = 0.015
    var slowWalkingThreshold: Double = 0.05
    var delegate: MotionServiceDelegate?
    var accelerometerUpdateInterval: Double = 0.2
    
    // Private
    private var motionManager: CMMotionManager!
    private var roundingPrecision: Int = 3
    private var accelerometerDataCount: Double = 0
    private var accelerometerDataInEuclidianNorm: Double = 0
    private var totalAcceleration: Double = 0
    private var accelerometerDataInASecond = [Double]()
    private var lastMotionStatus: MotionType = .Unknown
    private var privateUpdateInterval: Double = 5.0
    private var timer1: NSTimer?
    private var timer2: NSTimer?
    private var pUpdateInterval: Double = 0
    private var pLengthInterval: Double = 0
    
    // Functions
    
    init() {
        motionManager = CMMotionManager()
    }
    
    deinit {
        self.stopMotionService()
        self.stopUpdateInterval()
    }
    
    func startUpdateInterval(updateInterval: Double, lengthInterval: Double) {
        print("startUpdateInterval")
        pUpdateInterval = updateInterval
        pLengthInterval = lengthInterval
        timer1 = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(MotionService.timerUpdate1), userInfo: nil, repeats: false)
    }
    
    func stopUpdateInterval() {
        print("stopUpdateInterval")
        pUpdateInterval = 0
        stopMotionService()
        timer1?.invalidate()
        timer2?.invalidate()
    }
    
    @objc private func timerUpdate1() {
        timer2 = NSTimer.scheduledTimerWithTimeInterval(pLengthInterval, target: self, selector: #selector(MotionService.timerUpdate2), userInfo: nil, repeats: false)
        self.startMotionService()
    }

    @objc private func timerUpdate2() {
        self.stopMotionService()
        self.delegate?.MotionServiceisReporting(self, motionType: lastMotionStatus)
        timer1 = NSTimer.scheduledTimerWithTimeInterval(pUpdateInterval, target: self, selector: #selector(MotionService.timerUpdate1), userInfo: nil, repeats: false)
    }
    
    func startMotionService() {
        print("startMotionService")
        motionManager.accelerometerUpdateInterval = accelerometerUpdateInterval
        motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue()) { (accelerometerData: CMAccelerometerData?, error: NSError?) -> Void in
            if((error) != nil) {
                print(error)
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.estimateStatus((accelerometerData?.acceleration)!)
                }
            }
        }
    }
    
    func stopMotionService() {
        print("stopAccelerometerUpdates")
        motionManager.stopAccelerometerUpdates()
    }
   
    private func estimateStatus(acceleration: CMAcceleration) {
        // Obtain the Euclidian Norm of the accelerometer data
        accelerometerDataInEuclidianNorm = sqrt((acceleration.x.roundTo(roundingPrecision) * acceleration.x.roundTo(roundingPrecision)) + (acceleration.y.roundTo(roundingPrecision) * acceleration.y.roundTo(roundingPrecision)) + (acceleration.z.roundTo(roundingPrecision) * acceleration.z.roundTo(roundingPrecision)))
        
        // Significant figure setting
        accelerometerDataInEuclidianNorm = accelerometerDataInEuclidianNorm.roundTo(roundingPrecision)
        
        // record 10 values
        // meaning values in a second
        // accUpdateInterval(0.1s) * 10 = 1s
        while accelerometerDataCount < accelerometerUpdateInterval*10 {
            accelerometerDataCount += accelerometerUpdateInterval
            
            accelerometerDataInASecond.append(accelerometerDataInEuclidianNorm)
            totalAcceleration += accelerometerDataInEuclidianNorm
            
            break   // required since we want to obtain data every acc cycle
        }
        
        // when acc values recorded
        // interpret them
        if accelerometerDataCount >= accelerometerUpdateInterval*10 {
            accelerometerDataCount = 0  // reset for the next round
            
            // Calculating the variance of the Euclidian Norm of the accelerometer data
            let accelerationMean = (totalAcceleration / 10).roundTo(roundingPrecision)
            var total: Double = 0.0
            
            for data in accelerometerDataInASecond {
                total += ((data-accelerationMean) * (data-accelerationMean)).roundTo(roundingPrecision)
            }
            
            total = total.roundTo(roundingPrecision)
            
            let result = (total / 10).roundTo(roundingPrecision)
            print("estimateStatus result: \(result)")
            
            if (result < staticThreshold) {
                lastMotionStatus = .Still
            } else if ((staticThreshold < result) && (result <= slowWalkingThreshold)) {
                lastMotionStatus = .SlowMoving
            } else if (slowWalkingThreshold < result) {
                lastMotionStatus = .FastMoving
            }
            
            print("estimateStatus motion Status: \(lastMotionStatus)\n---\n\n")
            if pUpdateInterval == 0 {
                self.delegate?.MotionServiceisReporting(self, motionType: lastMotionStatus)
            }
            
            // reset for the next round
            accelerometerDataInASecond = []
            totalAcceleration = 0.0
        }
    }
}

extension Double {
    func roundTo(precision: Int) -> Double {
        let divisor = pow(10.0, Double(precision))
        return round(self * divisor) / divisor
    }
}
