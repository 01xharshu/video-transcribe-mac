import Foundation
import SwiftUI

@Observable
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    var isDownloading = false
    var progress: Double = 0.0
    var statusText: String = ""
    var downloadError: String? = nil
    
    private var downloadTask: URLSessionDownloadTask?
    private var completion: ((Bool) -> Void)?
    
    func downloadModel(_ model: WhisperModel, completion: @escaping (Bool) -> Void) {
        guard !isDownloading else { return }
        
        self.completion = completion
        self.isDownloading = true
        self.progress = 0.0
        self.statusText = "Starting download..."
        self.downloadError = nil
        
        let urlString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(model.modelFileName)"
        guard let url = URL(string: urlString) else {
            self.downloadError = "Invalid URL"
            self.isDownloading = false
            completion(false)
            return
        }
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    func cancel() {
        downloadTask?.cancel()
        isDownloading = false
        statusText = "Cancelled"
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        defer {
            isDownloading = false
        }
        
        guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
            downloadError = "Download failed with status: \((downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0)"
            completion?(false)
            return
        }
        
        guard let modelName = downloadTask.originalRequest?.url?.lastPathComponent else {
            downloadError = "Unknown file name"
            completion?(false)
            return
        }
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("VideoTranscribe/Models")
        
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            let destinationURL = appDir.appendingPathComponent(modelName)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            statusText = "Download complete!"
            completion?(true)
            
        } catch {
            downloadError = "Failed to save model: \(error.localizedDescription)"
            completion?(false)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            
            let downloadedMB = Double(totalBytesWritten) / 1024 / 1024
            let totalMB = Double(totalBytesExpectedToWrite) / 1024 / 1024
            
            statusText = String(format: "Downloading: %.1f MB / %.1f MB", downloadedMB, totalMB)
        } else {
            progress = 0
            statusText = "Downloading..."
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                // Cancelled manually
                return
            }
            isDownloading = false
            downloadError = "Network error: \(error.localizedDescription)"
            completion?(false)
        }
    }
}
