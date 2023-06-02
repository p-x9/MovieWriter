import Foundation
import AVFoundation
import CoreVideo

public class MovieWriter {

    public struct State: Equatable {
        /// A Boolean value that indicates whether MovieWriter is recording
        public var isRunning: Bool = false

        /// Time when `func start(waitFirstWriting: Bool)` is called.
        public var startTime: CMTime = .zero

        /// Time when the last video frame was recorded
        public var lastFrameTime: CMTime = .zero

        // A Boolean value that indicates whether or not to wait for the first frame to be written.
        public var waitingForFirstWriting: Bool = false

        /// Boolean value that indicates whether to write audio or not.
        public var isAudioEnabled: Bool = false

        /// Boolean value that indicates whether to write microphone audio or not.
        public var isMicrophoneEnabled: Bool = false
    }

    /// pixel size of recording area
    public let size: CGSize

    /// output url of recorded video file
    public let outputUrl: URL

    /// file type of recorded video file
    public let fileType: AVFileType

    public let videoOutputSettings: [String: Any]
    public let sourcePixelBufferAttributes: [String: Any]
    public let audioOutputSettings: [String: Any]

    private var _state: State = .init()

    public var state: State {
        _state
    }

    /// time in a recorded  video of the last frame written.
    public var currentTime: CMTime {
        state.lastFrameTime
    }

    /// A Boolean value that indicates whether MovieWriter is recording
    public var isRunning: Bool {
        state.isRunning
    }

    /// Boolean value that indicates whether to write audio or not.
    public var isAudioEnabled: Bool {
        get {
            state.isAudioEnabled
        }
        set {
            if isRunning { print("Will not be updated as it has already started writing") }
            else { _state.isAudioEnabled = newValue }
        }
    }

    /// Boolean value that indicates whether to write microphone audio or not.
    public var isMicrophoneEnabled: Bool {
        get {
            state.isMicrophoneEnabled
        }
        set {
            if isRunning { print("Will not be updated as it has already started writing") }
            else { _state.isMicrophoneEnabled = newValue }
        }
    }

    private var assetWriter: AVAssetWriter?

    private var writerInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var audioWriterInput: AVAssetWriterInput?
    private var micWriterInput: AVAssetWriterInput?

    public init(
        outputUrl: URL,
        size: CGSize,
        codec: AVVideoCodecType = .h264,
        audioFormatId: AudioFormatID = kAudioFormatMPEG4AAC,
        audioSampleRate: Float = 44100.0,
        audioNumberOfChannel: Int = 2,
        fileType: AVFileType = .mp4
    ) {

        self.size = size
        self.outputUrl = outputUrl
        self.fileType = fileType

        self.videoOutputSettings = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]

        self.sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ]

        self.audioOutputSettings = [
            AVFormatIDKey : audioFormatId,
            AVSampleRateKey : audioSampleRate,
            AVNumberOfChannelsKey : audioNumberOfChannel
        ]
    }

    /// start video writing
    /// - Parameters:
    ///   - waitFirstWriting: If true, align the first write with the start time of the video.  
    /// If false, the time when this method is called is the start time of the video, and the video will be blank until the time of the writing.
    public func start(waitFirstWriting: Bool) throws {
        guard !isRunning else {
            throw MovieWriterError.alreadyRunning
        }

        self.assetWriter = try AVAssetWriter(url: outputUrl, fileType: fileType)

        guard let assetWriter else {
            throw MovieWriterError.failedToStart
        }

        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoOutputSettings
        )
        writerInput.expectsMediaDataInRealTime = true

        self.writerInput = writerInput

        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        assetWriter.add(writerInput)

        if isAudioEnabled {
            let audioWriterInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioOutputSettings
            )
            self.assetWriter?.add(audioWriterInput)
            self.audioWriterInput = audioWriterInput
        }

        if isMicrophoneEnabled {
            let micWriterInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioOutputSettings
            )
            self.assetWriter?.add(micWriterInput)
            self.micWriterInput = micWriterInput
        }

        if !assetWriter.startWriting() {
            throw MovieWriterError.failedToStart
        }

        _state.isRunning = true
        _state.startTime = .current

        if waitFirstWriting {
            _state.waitingForFirstWriting = true
        } else {
            assetWriter.startSession(atSourceTime: _state.startTime)
            _state.waitingForFirstWriting = false
        }
    }

    /// end video writing
    /// - Parameters:
    ///   - time: end time.
    ///   - waitUntilFinish: If true, does not return until the end process is complete
    public func end(at time: CMTime, waitUntilFinish: Bool) throws {
        guard let writerInput, let assetWriter else { return }

        guard time >= currentTime else {
            throw MovieWriterError.invalidTime
        }

        writerInput.markAsFinished()
        audioWriterInput?.markAsFinished()
        micWriterInput?.markAsFinished()

        assetWriter.endSession(atSourceTime: time)

        let semaphore = DispatchSemaphore(value: 0)

        assetWriter.finishWriting {
            semaphore.signal()
        }

        semaphore.wait()

        if !waitUntilFinish { semaphore.signal() }

        self.assetWriter = nil

        self.writerInput = nil
        self.audioWriterInput = nil
        self.micWriterInput = nil
        self.adaptor = nil

        _state.isRunning = false
        _state.waitingForFirstWriting = false
    }

    private func configureIfWaitingForFirstWriting(time: CMTime) {
        guard state.waitingForFirstWriting else { return }
        assetWriter?.startSession(atSourceTime: time)
        _state.waitingForFirstWriting = false
    }
}

extension MovieWriter {
    /// write video frame
    /// - Parameters:
    ///   - buffer: pixel buffer of frame
    ///   - time: time of frame in video.
    public func writeFrame(_ buffer: CVPixelBuffer, at time: CMTime) throws {
        guard isRunning,
              let adaptor,
              let assetWriter,
              assetWriter.status == .writing else {
            throw MovieWriterError.notStarted
        }

        guard time >= currentTime else {
            throw MovieWriterError.invalidTime
        }

        configureIfWaitingForFirstWriting(time: time)

        guard adaptor.assetWriterInput.isReadyForMoreMediaData else {
            throw MovieWriterError.notReadyForWriteMoreData
        }

        if(!adaptor.append(buffer, withPresentationTime: time)) {
            throw MovieWriterError.failedToAppendBuffer
        }

        _state.lastFrameTime = time
    }

    /// write video frame
    /// - Parameter buffer: sample buffer of frame
    public func writeFrame(_ buffer: CMSampleBuffer) throws {
        let time = CMSampleBufferGetPresentationTimeStamp(buffer)
        guard let buffer = CMSampleBufferGetImageBuffer(buffer) else { return }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }

        try writeFrame(buffer, at: time)
    }

    /// write audio buffer
    /// - Parameter buffer: sample buffer of audio
    public func writeAudio(_ buffer: CMSampleBuffer) throws {
        guard isRunning,
              isAudioEnabled,
              let audioWriterInput,
              let assetWriter,
              assetWriter.status == .writing else {
            throw MovieWriterError.notStarted
        }

        guard !state.waitingForFirstWriting else { return }

        guard audioWriterInput.isReadyForMoreMediaData else {
            throw MovieWriterError.notReadyForWriteMoreData
        }

        if(!audioWriterInput.append(buffer)) {
            throw MovieWriterError.failedToAppendBuffer
        }
    }

    /// write audio buffer of microphone
    /// - Parameter buffer: sample buffer of microphone audio
    public func writeMic(_ buffer: CMSampleBuffer) throws {
        guard isRunning,
              isMicrophoneEnabled,
              let micWriterInput,
              let assetWriter,
              assetWriter.status == .writing else {
            throw MovieWriterError.notStarted
        }

        guard !state.waitingForFirstWriting else { return }

        guard micWriterInput.isReadyForMoreMediaData else {
            throw MovieWriterError.notReadyForWriteMoreData
        }

        if(!micWriterInput.append(buffer)) {
            throw MovieWriterError.failedToAppendBuffer
        }
    }
}
