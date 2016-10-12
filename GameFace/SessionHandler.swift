//
//  SessionHandler.swift
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 15.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

import AVFoundation

class SessionHandler : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, DlibWrapperDelegate {
    var session = AVCaptureSession()
    let layer = AVSampleBufferDisplayLayer()
    let sampleQueue = dispatch_queue_create("com.zweigraf.DisplayLiveSamples.sampleQueue", DISPATCH_QUEUE_SERIAL)
    let faceQueue = dispatch_queue_create("com.zweigraf.DisplayLiveSamples.faceQueue", DISPATCH_QUEUE_SERIAL)
    let wrapper = DlibWrapper()
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    var currentMetadata: [AnyObject]
    
    override init() {
        currentMetadata = []
        super.init()
        wrapper.delegate = self
    }
    
    func openSession() {
        let device = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
            .map { $0 as! AVCaptureDevice }
            .filter { $0.position == .Front}
            .first!
        
        let input = try! AVCaptureDeviceInput(device: device)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        
        let metaOutput = AVCaptureMetadataOutput()
        metaOutput.setMetadataObjectsDelegate(self, queue: faceQueue)
        
        session.beginConfiguration()
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if session.canAddOutput(metaOutput) {
            session.addOutput(metaOutput)
        }
        session.sessionPreset = AVCaptureSessionPresetHigh
        session.commitConfiguration()
        
        let settings: [NSObject : AnyObject] = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
        output.videoSettings = settings
        
        // availableMetadataObjectTypes change when output is added to session.
        // before it is added, availableMetadataObjectTypes is empty
        metaOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
        
        wrapper.prepare()
        
        session.startRunning()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        
        if !currentMetadata.isEmpty {
            let boundsArray = currentMetadata
                .flatMap { $0 as? AVMetadataFaceObject }
                .map { NSValue(CGRect: $0.bounds) }
            
            wrapper.doWorkOnSampleBuffer(sampleBuffer, inRects: boundsArray)
        }
        
        layer.enqueueSampleBuffer(sampleBuffer)
        
        
        dispatch_async(dispatch_get_main_queue()){ [weak self] in
            if self!.appDelegate.gameState == .inPlay && ((self!.appDelegate.window?.rootViewController) as! ViewController).cameraFeed.count < 125{
                print(((self!.appDelegate.window?.rootViewController) as! ViewController).cameraFeed.count)
                ((self!.appDelegate.window?.rootViewController) as! ViewController).cameraFeed.append(self!.imageFromSampleBuffer(sampleBuffer))
                
                autoreleasepool {
//                ((self.appDelegate.window?.rootViewController) as! ViewController).gameFeed.append(
                    ((self!.appDelegate.window?.rootViewController) as! ViewController).screenshot()
//                )
                }
            }
        }
    }
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        let imageBuffer:CVImageBuffer! = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let baseAddress: UnsafeMutablePointer<Void> = CVPixelBufferGetBaseAddress(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        
        // Create a bitmap graphics context with the sample buffer data
        let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue);
        let quartzImage = CGBitmapContextCreateImage(context!)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        // Create an image object from the Quartz image
        let image = UIImage(CGImage:quartzImage!)
        
        return image
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
//        print("DidDropSampleBuffer")
    }
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        currentMetadata = metadataObjects
    }
    
    func mouthVerticePositions(vertices: NSMutableArray!) {
        //parse new mouth location and shape from nsmutable array vertices
        appDelegate.mouth = vertices.map({$0.CGPointValue()})
        
        //testing coordinates from dlib before i pass to gamescene; should be the same as gamescene sprite but more laggy
        //        (appDelegate.window?.rootViewController as! ViewController).useTemporaryLayer()
    }
}