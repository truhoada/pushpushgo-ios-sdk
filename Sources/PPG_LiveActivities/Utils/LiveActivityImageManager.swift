//
//  LiveActivityImageManager.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 25/03/2026.
//

import Foundation
import UIKit
import CryptoKit

/// `ActivityAttributes` types whose payload carries remote image URLs that
/// widget views render from the shared image cache. The SDK prefetches these
/// images when an activity appears via push-to-start — that path has no REST
/// bootstrap, so the host app never gets a chance to download them and the
/// widget would otherwise show placeholder badges for the whole campaign.
@available(iOS 17.2, *)
public protocol PPGLiveActivityImagePrefetchable {
    /// Campaign id used to scope cached files — must match the `campaignId`
    /// widget views pass to `loadImage(imageType:campaignId:)`.
    var imageCampaignId: String { get }
    /// Remote URLs keyed by their image role.
    var prefetchableImages: [PPGLiveActivityImageType: String] { get }
}

@available(iOS 17.2, *)
public class LiveActivityImageManager {
    
    public static let shared = LiveActivityImageManager()
    
    private var appGroupId: String?
    private let fileManager = FileManager.default
    private let imageDirectoryName = "ppg_live_activity_images"

    /// In-memory cache for downsampled badges. Widget `body` evaluations call
    /// `loadImage(...targetSize:)` on every render — without this cache each
    /// render pays a directory scan + disk read + bitmap redraw per badge.
    /// Only hits are cached (misses retry disk so a just-prefetched file is
    /// picked up on the next render).
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
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
    
    /// Prefetch an image identified by its backend `imageType` and scope it to a campaign.
    /// The file is stored with a deterministic name `<campaignId>_<imageType>.<ext>`
    /// so both the main app and widget extension can locate it without sharing the URL.
    /// - Parameters:
    ///   - urlString: Remote image URL
    ///   - imageType: Logical role of the image (from backend DTO)
    ///   - campaignId: Live Notification / campaign identifier
    /// - Returns: `true` if the image was saved successfully
    @discardableResult
    public func prefetch(from urlString: String, imageType: PPGLiveActivityImageType, campaignId: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            LiveActivityLogger.shared.error("Invalid image URL: \(urlString)")
            return false
        }
        
        let targetPath = scopedLocalPath(imageType: imageType, campaignId: campaignId, ext: url.pathExtension)
        if let targetPath = targetPath,
           fileManager.fileExists(atPath: targetPath.path),
           !isExpired(at: targetPath) {
            LiveActivityLogger.shared.debug("Image already cached: \(targetPath.lastPathComponent)")
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
            guard let targetPath = targetPath else {
                LiveActivityLogger.shared.error("Cannot build image path — is App Group configured?")
                return false
            }
            // .atomic — the widget process may read the file at any moment;
            // a partial write would render as a permanent placeholder.
            try data.write(to: targetPath, options: .atomic)
            LiveActivityLogger.shared.debug("Saved image: \(targetPath.lastPathComponent)")
            return true
        } catch {
            LiveActivityLogger.shared.error("Image download failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Load an image by its backend `imageType` within a campaign scope.
    public func loadImage(imageType: PPGLiveActivityImageType, campaignId: String) -> UIImage? {
        guard let directory = imageDirectory() else { return nil }
        let prefix = "\(campaignId)_\(imageType.rawValue)"
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return nil }
        guard let match = files.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(match).path)
    }

    /// Load an image by its backend `imageType`, downsampled to `targetSize`
    /// (in points). The Dynamic Island compact presentation silently drops
    /// `Image` views whose backing bitmap is much larger than the slot —
    /// `.resizable().frame(...)` is not enough there — so widget views must
    /// request a thumbnail no larger than what they actually render.
    public func loadImage(
        imageType: PPGLiveActivityImageType,
        campaignId: String,
        targetSize: CGSize
    ) -> UIImage? {
        let cacheKey = "\(campaignId)_\(imageType.rawValue)_\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = loadImage(imageType: imageType, campaignId: campaignId) else { return nil }
        let thumbnail = downsampled(image, to: targetSize)
        thumbnailCache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }

    private func downsampled(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let scale: CGFloat = 3 // render @3x so badges stay sharp on all devices
        let maxPixels = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        let srcPixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard srcPixels.width > maxPixels.width || srcPixels.height > maxPixels.height else {
            return image
        }
        let ratio = min(maxPixels.width / srcPixels.width, maxPixels.height / srcPixels.height)
        let newSize = CGSize(width: srcPixels.width * ratio, height: srcPixels.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // newSize is already in pixels
        format.opaque = false
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Remove all cached images that belong to a given campaign.
    public func removeAssets(forCampaign campaignId: String) {
        guard let directory = imageDirectory() else { return }
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return }
        for name in files where name.hasPrefix("\(campaignId)_") {
            deleteImage(at: directory.appendingPathComponent(name))
        }
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
                    deleteImage(at: fileURL)
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
                deleteImage(at: fileURL)
            }
        } catch {
            LiveActivityLogger.shared.error("Failed to clear all assets: \(error.localizedDescription)")
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
    
    private func scopedLocalPath(imageType: PPGLiveActivityImageType, campaignId: String, ext: String?) -> URL? {
        guard let directory = imageDirectory() else { return nil }
        let safeExt = (ext?.isEmpty == false) ? ext! : "png"
        return directory.appendingPathComponent("\(campaignId)_\(imageType.rawValue).\(safeExt)")
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
            try data.write(to: path, options: .atomic)
            LiveActivityLogger.shared.debug("Saved image: \(fileName(for: urlString))")
            return true
        } catch {
            LiveActivityLogger.shared.error("Failed to save image: \(error.localizedDescription)")
            return false
        }
    }

    private func deleteImage(at path: URL) {
        do {
            try fileManager.removeItem(at: path)
            LiveActivityLogger.shared.debug("Deleted image: \(path.lastPathComponent)")
        } catch {
            LiveActivityLogger.shared.error("Failed to delete image: \(error.localizedDescription)")
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
