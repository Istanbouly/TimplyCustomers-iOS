import UIKit

final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 150
        c.totalCostLimit = 60 * 1024 * 1024 // 60 MB
        return c
    }()

    func get(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ url: URL, image: UIImage) {
        cache.setObject(image, forKey: url as NSURL, cost: image.jpegData(compressionQuality: 1)?.count ?? 0)
    }
}
