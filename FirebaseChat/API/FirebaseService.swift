//
//  FirebaseService.swift
//  FirebaseChat
//
//  Created by Michał Szpyruk on 14/07/2020.
//  Copyright © 2020 Michał Szpyruk. All rights reserved.
//

import Firebase

struct FirebaseService {
    static let shared = FirebaseService()
    
    func fetchUsers(completion: @escaping([User]) -> Void) {
//        var users = [User]()
        Firestore.firestore().collection("users").getDocuments { (snapshot, error) in
            guard var users = snapshot?.documents.map({ User(dictionary: $0.data()) }) else { return }
            
            if let i = users.firstIndex(where: { $0.uid == Auth.auth().currentUser?.uid }) {
                users.remove(at: i)
            }
            completion(users)
//            snapshot?.documents.forEach({ (document) in
//
//                let dictionary = document.data()
//                let user = User(dictionary: dictionary)
//                users.append(user)
//                completion(users)
//            })
        }
    }
    
    func fetchUser(with uid: String, completion: @escaping(User) -> Void) {
        Firestore.firestore().collection("users").document(uid).getDocument { (snapshot, error) in
            guard let dictionary = snapshot?.data() else { return }
            let user = User(dictionary: dictionary)
            completion(user)
        }
    }
    
    func fetchMessages(forUser user: User, completion: @escaping([Message]) -> Void) {
        var messages = [Message]()
        guard let currentUser = Auth.auth().currentUser?.uid else { return }
        
        let query = Firestore.firestore().collection("messages").document(currentUser).collection(user.uid).order(by: "timestamp")
        
        query.addSnapshotListener { (snapshot, error) in
            snapshot?.documentChanges.forEach({ (change) in
                if change.type == .added {
                    let dictionary = change.document.data()
                    messages.append(Message(dictionary: dictionary))
                    completion(messages)
                }
            })
        }
    }
    
    func fetchChats(completion: @escaping([Chat]) -> Void) {
        var chats = [Chat]()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let query =  Firestore.firestore().collection("messages").document(uid).collection("recent-messages").order(by: "timestamp")
        
        query.addSnapshotListener { (snapshot, error) in
            snapshot?.documentChanges.forEach({ (change) in
                let dictionary = change.document.data()
                let message = Message(dictionary: dictionary)
                
                self.fetchUser(with: message.chattingWith) { (user) in
                    let chat = Chat(user: user, message: message)
                    chats.append(chat)
                    completion(chats)
                }
            })
        }
        
    }
    
    static func uploadMessage(_ message: String, user: User, completion: ((Error?) -> Void)?) {
        guard let currentUser = Auth.auth().currentUser?.uid else { return }
        
        let data = ["text": message,
                    "fromUser": currentUser,
                    "toUser": user.uid,
                    "timestamp": Timestamp(date: Date())] as [String: Any]
        
        Firestore.firestore().collection("messages").document(currentUser).collection(user.uid).addDocument(data: data) { (_) in
            Firestore.firestore().collection("messages").document(user.uid).collection(currentUser).addDocument(data: data, completion: completion)
            
            Firestore.firestore().collection("messages").document(currentUser).collection("recent-messages").document(user.uid).setData(data)
            
            Firestore.firestore().collection("messages").document(user.uid).collection("recent-messages").document(currentUser).setData(data)
            
        }
    }
}
