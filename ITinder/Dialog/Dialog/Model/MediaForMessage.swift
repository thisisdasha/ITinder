import Foundation
import MessageKit

struct MediaForMessage: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
    
    init(image: UIImage, placeholderImage: UIImage, size: CGSize) {
        self.image = image
        self.placeholderImage = placeholderImage
        self.size = size
    }
}
