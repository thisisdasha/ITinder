import UIKit
import Firebase
import FirebaseDatabase
import FirebaseStorage

class UserService {
    private static let imageStorage = Storage.storage().reference().child(avatarsRefKey)
    private static let usersDatabase = Database.database().reference().child(usersRefKey)
    private static var lastUserId = ""
    
    static var currentUserId: String? {
        Auth.auth().currentUser.map { $0.uid }
    }
    
    static func getUserBy(id: String, completion: @escaping (User?) -> Void) {
        usersDatabase.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.childSnapshot(forPath: id).value as? [String: Any] else {
                assertionFailure()
                completion(nil)
                return
            }
            completion(User(dictionary: value))
        } withCancel: { _ in
            assertionFailure()
            completion(nil)
        }
    }
    
    static func getCurrentUser(completion: @escaping (User?) -> Void) {
        guard let currentUserId = currentUserId else {
            assertionFailure()
            completion(nil)
            return
        }
        getUserBy(id: currentUserId) { user in
            completion(user)
        }
    }
    
    static func getNextUsers(fromStart: Bool = false, usersCount: Int, completion: @escaping ([User]?) -> Void) {
        if fromStart { lastUserId = "" }
        var query = usersDatabase.queryOrderedByKey()
        
        if lastUserId != "" {
            query = query.queryEnding(beforeValue: lastUserId)
        }
        
        query.queryLimited(toLast: UInt(usersCount)).observeSingleEvent(of: .value) { snapshot in
            guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                assertionFailure()
                completion(nil)
                return
            }
            
            var users = [User]()
            
            children.forEach {
                if let value = $0.value as? [String: Any] {
                    users.append(User(dictionary: value))
                }
            }
            
            guard let lastUserId = users.first?.identifier else {
                completion(nil)
                return
            }
            Self.lastUserId = lastUserId
            users.reverse()
            
            let filteredUsers = filtered(users)
            
            if filteredUsers.isEmpty {
                getNextUsers(usersCount: usersCount) { users in
                    completion(users)
                }
            } else {
                completion(filteredUsers)
            }
        } withCancel: { _ in
            completion(nil)
        }
    }
    
    private static func filtered(_ users: [User]) -> [User] {
        users.filter {
            guard let currentUserId = currentUserId else { return false }
            return $0.identifier != currentUserId && $0.statusList[currentUserId] == nil
        }
    }
    
    static func update(by characteristics: [String: Any], withImage: UIImage?, completion: @escaping ((User?) -> Void)) {
        guard let image = withImage else {
            update(by: characteristics) { completion($0) }
            return
        }
        guard let currentUserId = currentUserId else { completion(nil); return }
        
        upload(image: image, forUserId: currentUserId) { urlString in
            guard let urlString = urlString else { completion(nil); return }
            var characteristics = characteristics
            characteristics[imageUrlKey] = urlString
            update(by: characteristics) { completion($0) }
        }
    }
    
    private static func update(by characteristics: [String: Any], completion: @escaping ((User?) -> Void)) {
        guard let currentUserId = currentUserId else { completion(nil); return }
        
        usersDatabase.child(currentUserId).updateChildValues(characteristics) { error, _ in
            guard error == nil else { completion(nil); return }
            getCurrentUser { completion($0) }
        }
    }
    
    static func persist(user: User, withImage: UIImage?, completion: @escaping ((User?) -> Void)) {
        guard let image = withImage else {
            persist(user) { user in
                completion(user)
            }
            return
        }
        
        upload(image: image, forUserId: user.identifier) { urlString in
            guard let urlString = urlString else { completion(nil); return }
            
            var newUser = user
            newUser.imageUrl = urlString
            persist(newUser) { user in
                completion(user)
            }
        }
    }
    
    private static func upload(image: UIImage, forUserId: String, completion: @escaping ((String?) -> Void)) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { completion(nil); return }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageStorage.child("\(forUserId).jpg").putData(imageData, metadata: metadata) { _, error in
            guard error == nil else { completion(nil); return }
            
            imageStorage.child("\(forUserId).jpg").downloadURL { url, error in
                guard error == nil, let urlString = url?.absoluteString else {
                    completion(nil)
                    return
                }
                completion(urlString)
            }
        }
    }
    
    private static func persist(_ user: User, completion: @escaping ((User?) -> Void)) {
        usersDatabase.child(user.identifier).setValue(user.userDictionary) { error, _ in
            guard error == nil else { completion(nil); return }
            completion(user)
        }
    }
    
    static func set(status: User.Status?, forUserId: String, completion: @escaping ((User?) -> Void)) {
        getCurrentUser {
            guard let currentUser = $0 else {
                assertionFailure()
                completion(nil)
                return
            }
            getUserBy(id: forUserId) {
                guard let user = $0 else {
                    assertionFailure()
                    completion(nil)
                    return
                }
                
                if status == .like && currentUser.statusList[user.identifier] == User.Status.like.rawValue {
                    ConversationService.createMatchConversation(currentUserId: currentUser.identifier, companionId: user.identifier)
                    setMatchStatusFor(currentUser: currentUser, with: user) { completion($0) }
                } else {
                    set(status, for: user) { completion($0) }
                }
            }
        }
    }
    
    private static func set(_ status: User.Status?, for user: User, completion: @escaping ((User?) -> Void)) {
        guard let currentUserId = currentUserId else { completion(nil); return }
        
        var user = user
        user.statusList[currentUserId] = status?.rawValue
        
        usersDatabase.child(user.identifier).updateChildValues([statusListKey: user.statusList]) { error, _ in
            guard error == nil else { completion(nil); return }
            completion(user)
        }
    }
    
    private static func setMatchStatusFor(currentUser: User, with likedUser: User, completion: @escaping ((User?) -> Void)) {
        var currentUserStatusList = currentUser.statusList
        currentUserStatusList[likedUser.identifier] = User.Status.match.rawValue
        
        usersDatabase.child(currentUser.identifier).updateChildValues([statusListKey: currentUserStatusList]) { error, _ in
            guard error == nil else { completion(nil); return }
            
            var likedUser = likedUser
            likedUser.statusList[currentUser.identifier] = User.Status.match.rawValue
            
            usersDatabase.child(likedUser.identifier).updateChildValues([statusListKey: likedUser.statusList]) { error, _ in
                guard error == nil else { completion(nil); return }
                completion(likedUser)
            }
        }
    }
    
    // reset likes and matches for current user
    static func resetUsers(completion: @escaping ((Bool) -> Void)) {
        lastUserId = ""
        usersDatabase
            .queryOrderedByKey()
            .observeSingleEvent(of: .value) { snapshot in
                guard let children = snapshot.children.allObjects as? [DataSnapshot] else { completion(false); return }
                guard let currentUserId = currentUserId else { completion(false); return }
                
                var updates = [String: Any]()
                children.forEach {
                    if let value = $0.value as? [String: Any] {
                        if let userId = value[identifierKey] as? String,
                           var statusList = value[statusListKey] as? [String: String] {
                            
                            if userId == currentUserId {
                                statusList = statusList.filter { $1 == User.Status.match.rawValue }
                                
                            } else if statusList[currentUserId] != User.Status.match.rawValue {
                                statusList[currentUserId] = nil
                            }
                            updates[userId + "/" + statusListKey] = statusList
                        }
                    }
                }
                usersDatabase.updateChildValues(updates) { error, _ in
                    guard error == nil else { completion(false); return }
                    completion(true)
                }
            }
    }
}

extension User {
    init(dictionary: [String: Any]) {
        identifier = dictionary[identifierKey] as? String ?? ""
        email = dictionary[emailKey] as? String ?? ""
        imageUrl = dictionary[imageUrlKey] as? String ?? ""
        name = dictionary[nameKey] as? String ?? ""
        position = dictionary[positionKey] as? String ?? ""
        description = dictionary[descriptionKey] as? String
        birthDate = dictionary[birthDateKey] as? String
        city = dictionary[cityKey] as? String
        education = dictionary[educationKey] as? String
        company = dictionary[companyKey] as? String
        employment = dictionary[employmentKey] as? String
        statusList = dictionary[statusListKey] as? [String: String] ?? [:]
        conversations = dictionary[conversationsKey] as? [String: [String: Any]] ?? [:]
    }
    
    var userDictionary: [String: Any] {
        [identifierKey: identifier,
         emailKey: email,
         imageUrlKey: imageUrl,
         nameKey: name,
         positionKey: position,
         descriptionKey: description ?? "",
         birthDateKey: birthDate ?? "",
         cityKey: city ?? "",
         educationKey: education ?? "",
         companyKey: company ?? "",
         employmentKey: employment ?? "",
         statusListKey: statusList,
         conversationsKey: conversations]
    }
}
