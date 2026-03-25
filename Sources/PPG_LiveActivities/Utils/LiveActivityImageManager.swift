//
//  LiveActivityImageManager.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 25/03/2026.
//

import Foundation
import UIKit
import CryptoKit

@available(iOS 17.2, *)
public class LiveActivityImageManager {
    
    public static let shared = LiveActivityImageManager()
    
    private var appGroupId: String?
    private let fileManager = FileManager.default
    private let imageDirectoryName = "ppg_live_activity_images"
    
    /// Maximum age for cached images before cleanup (default: 24 hours)
    public var maxAssetAge: TimeInterval = 24 * 60 * 60
    
    private init() {}
    
    /// Configure the manager with your App Group identifier.
    /// Must be called before any image operations.
    /// - Parameter appGroupId: The App Group ID shared between main app and widget extension
    public func configure(appGroupId: String) {
        self.appGroupId = appGroupId
        createImageDirectoryIfNeeded()
    }
    
    // Public API
    
    /// Download an image from a remote URL and save it to the shared container.
    /// Call this from the main app before starting a Live Activity.
    /// - Parameter url: Remote image URL string
    /// - Returns: `true` if the image was saved successfully
    @discardableResult
    public func prefetch(from urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            LiveActivityLogger.shared.error("Invalid image URL: \(urlString)")
            return false
        }
        
        // Skip if already cached and not expired
        if let existing = localPath(for: urlString),
           fileManager.fileExists(atPath: existing.path),
           !isExpired(at: existing) {
            LiveActivityLogger.shared.debug("Image already cached: \(fileName(for: urlString))")
            return true
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                LiveActivityLogger.shared.error("Failed to download image: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return false
            }
            
            guard UIImage(data: data) != nil else {
                LiveActivityLogger.shared.error("Downloaded data is not a valid image")
                return false
            }
            
            return saveImage(data: data, for: urlString)
        } catch {
            LiveActivityLogger.shared.error("Image download failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Prefetch multiple images concurrently.
    /// - Parameter urls: Array of remote image URL strings
    /// - Returns: Dictionary mapping URL to success/failure
    @discardableResult
    public func prefetch(from urls: [String]) async -> [String: Bool] {
        var results: [String: Bool] = [:]
        await withTaskGroup(of: (String, Bool).self) { group in
            for urlString in urls {
                group.addTask {
                    let success = await self.prefetch(from: urlString)
                    return (urlString, success)
                }
            }
            for await (url, success) in group {
                results[url] = success
            }
        }
        return results
    }
    
    /// Load an image from the shared container. Used by widget views.
    /// - Parameter urlString: The original remote URL string (used as cache key)
    /// - Returns: UIImage if found and valid, nil otherwise
    public func loadImage(for urlString: String?) -> UIImage? {
        guard let urlString = urlString,
              let path = localPath(for: urlString) else {
            return nil
        }
        
        return UIImage(contentsOfFile: path.path)
    }
    
    /// Remove all cached images that are older than `maxAssetAge`.
    /// Call this on app launch (e.g. in `application(_:didFinishLaunchingWithOptions:)`).
    public func cleanExpiredAssets() {
        guard let directory = imageDirectory() else { return }
        
        var cleanedCount = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            for fileURL in files {
                if isExpired(at: fileURL) {
                    try fileManager.removeItem(at: fileURL)
                    cleanedCount += 1
                }
            }
            if cleanedCount > 0 {
                LiveActivityLogger.shared.info("Cleaned \(cleanedCount) expired image asset(s)")
            }
        } catch {
            LiveActivityLogger.shared.error("Failed to clean expired assets: \(error.localizedDescription)")
        }
    }
    
    /// Remove all cached images immediately.
    public func clearAll() {
        guard let directory = imageDirectory() else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for fileURL in files {
                try fileManager.removeItem(at: fileURL)
            }
            LiveActivityLogger.shared.info("Cleared all cached image assets")
        } catch {
            LiveActivityLogger.shared.error("Failed to clear assets: \(error.localizedDescription)")
        }
    }
    
    // Internal Helpers
    
    private func imageDirectory() -> URL? {
        guard let appGroupId = appGroupId, !appGroupId.isEmpty,
              let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        return containerURL.appendingPathComponent(imageDirectoryName)
    }
    
    private func createImageDirectoryIfNeeded() {
        guard let directory = imageDirectory() else {
            LiveActivityLogger.shared.error("App Group not configured. Call configure(appGroupId:) first.")
            return
        }
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                LiveActivityLogger.shared.error("Failed to create image directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func localPath(for urlString: String) -> URL? {
        guard let directory = imageDirectory() else { return nil }
        return directory.appendingPathComponent(fileName(for: urlString))
    }
    
    private func fileName(for urlString: String) -> String {
        let hash = SHA256.hash(data: Data(urlString.utf8))
        let hashString = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        
        // Preserve original file extension if present
        let ext = URL(string: urlString)?.pathExtension ?? "png"
        return "\(hashString).\(ext.isEmpty ? "png" : ext)"
    }
    
    private func saveImage(data: Data, for urlString: String) -> Bool {
        guard let path = localPath(for: urlString) else {
            LiveActivityLogger.shared.error("Cannot determine save path — is App Group configured?")
            return false
        }
        
        do {
            try data.write(to: path)
            LiveActivityLogger.shared.debug("Saved image: \(fileName(for: urlString))")
            return true
        } catch {
            LiveActivityLogger.shared.error("Failed to save image: \(error.localizedDescription)")
            return false
        }
    }
    
    private func isExpired(at fileURL: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modDate = attributes[.modificationDate] as? Date else {
            return true
        }
        return Date().timeIntervalSince(modDate) > maxAssetAge
    }
}
