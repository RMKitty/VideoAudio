//
//  ViewController.swift
//  SwiftVideo
//
//  Created by Kitty on 2017/4/23.
//  Copyright © 2017年 RM. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    /// 输出video队列
    fileprivate lazy var outVideoQueue = DispatchQueue.global()
    /// 输出AudioQueue
    fileprivate lazy var audioQueue = DispatchQueue.global()
    /// CaptureSession
    fileprivate lazy var session: AVCaptureSession = {
        let session = AVCaptureSession()
        if UIDevice.current.userInterfaceIdiom == .phone {
            session.sessionPreset = AVCaptureSessionPreset640x480
        } else {
            session.sessionPreset = AVCaptureSessionPresetPhoto
        }
        return session
    }()
    /// PreviewLayer
    fileprivate lazy var previewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
    /// VideoOutput
    fileprivate var videoOutput: AVCaptureVideoDataOutput?
    ///
    fileprivate var videoInput: AVCaptureDeviceInput?
    ///
    fileprivate var movieOutput: AVCaptureMovieFileOutput?
    
    @IBOutlet weak var changeSceneBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}
//  MARK: -
extension ViewController {
    
    @IBAction func startCapture() {
        
        setupVideo()
        
        setupAudio()
        
        setMovieOutput()
        
        // 设置预览图层
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        //开始采集
        session.startRunning()
        writeFile()
        changeSceneBtn.isHidden = false
    }
    
    
    @IBAction func stopCapture() {
        session.stopRunning()
        movieOutput?.stopRecording()
        
        if let inputs = session.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                session.removeInput(input)
            }
        }
        if let outputs = session.outputs as? [AVCaptureVideoDataOutput] {
            for output in outputs {
                session.removeOutput(output)
            }
        }
        previewLayer.removeFromSuperlayer()
        print("停止采集----")
        changeSceneBtn.isHidden = true
    }
    
    @IBAction func changeScene() {
        
        print("切换镜头---")
        guard var position = videoInput?.device.position else { return }
        
        position = position == .front ? .back : .front
        print(position.rawValue)
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice]
        guard let device = devices?.filter({ $0.position == position }).first else {
            return
        }
        guard let videoInput = try? AVCaptureDeviceInput(device: device) else {
            return
        }
//        movieOutput?.stopRecording()
        if (movieOutput?.isRecording)! {
            print("正在运行---B")
        }
        session.beginConfiguration()
        session.removeInput(self.videoInput)
        if (movieOutput?.isRecording)! {
            print("正在运行---M")
        }
//        movieOutput?.stopRecording()

        session.addInput(videoInput)
        session.commitConfiguration()
        if (movieOutput?.isRecording)! {
            print("正在运行---F")
        }
//        self.writeFile()
        self.videoInput = videoInput
        
        
    }
    
}

//  MARK: - Video&Audio
extension ViewController {
    
    /// 设置视频输入&输出
    fileprivate func setupVideo() {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else {
            print("摄像头不可用")
            return
        }
        /*
         var device : AVCaptureDevice!
         for d in devices {
         if d.position == .front {
         device = d
         break
         }
         }
         let device = devices.filter { (device:AVCaptureDevice) -> Bool in
         return device.position == .front
         }.first
         let device = devices.first { (device :AVCaptureDevice) -> Bool in
         
         return device.position == .front
         }
         */
        if  devices.count < 1 {
            print("摄像头不可用---")
            return
        }
        guard let device = devices.filter({ $0.position  == .front}).first else { return }
        
        
        guard let videoInput = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            self.videoInput = videoInput
        }
        

        
        
        // 设置输出源
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: outVideoQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        // 视频输出的方向
        // 注意: 设置方向, 必须在将output添加到session之后
        guard let videoConnection = videoOutput.connection(withMediaType: AVMediaTypeVideo) else {return}
        videoConnection.isEnabled = false

        if videoConnection.isVideoOrientationSupported {
            print("---,", videoConnection.videoOrientation.rawValue, "---方向" )
            videoConnection.videoOrientation = .portrait
        } else {
            print("不支持方向设置")
        }
       
    }
    ///设置音频输入输出
    fileprivate func setupAudio() {
        
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) else{
            print("麦克风不可用")
            return
        }
        guard let audioInput = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)

        }
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
    }
    fileprivate func setMovieOutput() {
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.movieOutput = movieOutput
        }
        // 设置文件的稳定性
        let connection = movieOutput.connection(withMediaType: AVMediaTypeVideo)
        connection?.preferredVideoStabilizationMode = .auto

    }
    fileprivate func writeFile()  {
      
        let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/myVideo.mp4"
        let fileDefault = FileManager.default
        if fileDefault.fileExists(atPath: filePath) {
            guard let _ = try? fileDefault.removeItem(atPath: filePath)  else {
                print("删除已存在文件异常----")
                return
            }
            print("成功删除已存在文件")
        }
        
        let url = URL(fileURLWithPath: filePath)
        movieOutput?.startRecording(toOutputFileURL: url, recordingDelegate: self)
       
        
    }
}
//  MARK: - AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("开始采集")
        if connection == self.videoOutput?.connection(withMediaType: AVMediaTypeVideo) {
            print("采集视频")
        } else {
            print("采集音频")
        }
    }
}
// MARK: -AVCaptureFileOutputRecordingDelegate
extension ViewController: AVCaptureFileOutputRecordingDelegate {
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        
        print("开始写入---视频")
    }
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        
        print("结束写入---视频")
    }
}
