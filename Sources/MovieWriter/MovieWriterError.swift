//
//  MovieWriterError.swift
//  
//
//  Created by p-x9 on 2023/05/20.
//  
//

import Foundation

enum MovieWriterError: LocalizedError {
    case notStarted
    case alreadyRunning
    case failedToStart
    case failedToAppendBuffer
    case invalidTime
    case notReadyForWriteMoreData

    var errorDescription: String? {
        switch self {
        case .notStarted:
            return "Recording has not started yet."
        case .alreadyRunning:
            return "Recording has already started."
        case .failedToStart:
            return "Failed to start recording."
        case .failedToAppendBuffer:
            return "Buffer write failed"
        case .invalidTime:
            return "Trying to write at an incorrect time."
        case .notReadyForWriteMoreData:
            return "Not yet ready to write the next buffer"
        }
    }
}
