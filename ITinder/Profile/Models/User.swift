import Foundation

struct User {
    enum Status: String {
        case like
        case dislike
        case match
    }
    
    let identifier: String
    let email: String
    var imageUrl: String
    var name: String
    var position: String
    var description: String?
    var birthDate: String?
    var city: String?
    var education: String?
    var company: String?
    var employment: String?
    var statusList: [String: String]
    var conversations: [String: [String: Any]]
}
