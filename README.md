# MovieWriter
Simple movie writing library for Swift

<!-- # Badges -->

[![Github issues](https://img.shields.io/github/issues/p-x9/MovieWriter)](https://github.com/p-x9/MovieWriter/issues)
[![Github forks](https://img.shields.io/github/forks/p-x9/MovieWriter)](https://github.com/p-x9/MovieWriter/network/members)
[![Github stars](https://img.shields.io/github/stars/p-x9/MovieWriter)](https://github.com/p-x9/MovieWriter/stargazers)
[![Github top language](https://img.shields.io/github/languages/top/p-x9/MovieWriter)](https://github.com/p-x9/MovieWriter/)

## Document
### Import and create instance of `MovieWriter`
```swift
let movieWriter = MovieWriter(
    outputUrl: outputURL, // Movie outpur URL
    size: UIScreen.main.bounds.size, // frame size
    codec: .h264,  // video codec
    audioFormatId: kAudioFormatMPEG4AAC, // audio format
    audioSampleRate: 44100.0, // sample rate of audio
    audioNumberOfChannel: 2, // number of channel
    fileType: .mp4 // file type
)
```

### If You use Audio or Microphone
If you want to write audio or microphone audio, you need to configure the following settings.
```swift
movieWriter.isAudioEnabled = true
movieWriter.isMicrophoneEnabled = true
```

### Start Writing
If `waitFirstWriting` is true, align the first write with the start time of the video.
Otherwise, the time when this method is called is the start time of the video, and the video will be blank until the time of the writing.
```swift
try movieWriter.start(waitFirstWriting: true)
```

### Write Buffer
#### Video
```swift
try movieWriter.writeFrame(buffer) // write with `CMSampleBuffer`
/* or */
try movieWriter.writeFrame(buffer, at: time) // write with `CVSampleBuffer`
```
#### Audio and Microphone
```swift
try movieWriter.writeAudio(buffer) // Audio
try movieWriter.writeMicrophone(buffer) // Audio
```

### End Writing
Specify an end time to finish writing.
If `waitUntilFinish` is true, it will not return until the end process is completely finished
```swift
try movieWriter.end(at: time, waitUntilFinish: true)
```


## License

MovieWriter is released under the MIT License. See [LICENSE](./LICENSE)
