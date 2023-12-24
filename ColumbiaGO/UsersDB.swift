//
//  UsersDB.swift
//  ColumbiaGO
//
//  Created by Angela Mu on 11/16/23.
//


import Foundation
import Firebase
import FirebaseCore
import FirebaseDatabase
import FirebaseStorage

class UsersDB {
    var ref = Database.database().reference()
    
    func addToUsersDB(email: String, username: String) {
        let userID = Auth.auth().currentUser?.uid
        self.ref.child("users").child(userID!).setValue(["username": username, "score": 0] as [String : Any])
    }
    
    func completeQuests(questName: String) {
        let userID = Auth.auth().currentUser?.uid
        self.ref.child("users").child(userID!).child("questsCompleted").child(questName).setValue(true)
        self.incrementScore(byValue: 1.0)
    }
    
    func deleteDBAtPath(path: String) {
        let reference = Database.database().reference(withPath: path)

        reference.removeValue { (error, _) in
            if let error = error {
                print("Error deleting data at \(path): \(error.localizedDescription)")
            } else {
                print("Data deleted successfully at \(path)")
            }
        }
    }
    
    func retrieveTrophy(questName: String, trophyID: String, completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            // Handle the case where userID is nil
            return
        }

        let questsStartedPath = "users/" + userID + "/questsStarted/" + questName
        let questsDBPath = "quests/" + questName + "/locations"
        
        // Fetch the number of entries at questsStartedPath
        numEntriesAtPath(path: questsStartedPath) { countquestsStartedPath in
            // Fetch the number of entries at questsDBPath
            self.numEntriesAtPath(path: questsDBPath) { countQuestsDBPath in
                print("countquestsStartedPath: ", countquestsStartedPath)
                print("countQuestsDBPath:" , countQuestsDBPath)
                if (countquestsStartedPath + 1) == countQuestsDBPath {
                    // quest completed
                    self.completeQuests(questName: questName)
                    self.deleteDBAtPath(path: questsStartedPath)
                    completion(true) // true if completed quest
                } else {
                    // add trophy to quests started
                    self.ref.child("users").child(userID).child("questsStarted").child(questName).child(trophyID).setValue(true) { (error, _) in
                        if let error = error {
                            print("Error setting value: \(error.localizedDescription)")
                        } else {
                            print("Value set successfully")
                            self.incrementScore(byValue: 0.5)
                        }
                        completion(false)
                    }
                }
            }
        }
    }

    func incrementScore(byValue: Double) {
        let userID = Auth.auth().currentUser?.uid
        self.ref.child("users").child(userID!).child("score").observeSingleEvent(of: .value) { (snapshot) in
            if var currentScore = snapshot.value as? Double {
                // Increment the score by 0.5
                currentScore += byValue
                
                // Update the score in the database
                self.ref.child("users").child(userID!).child("score").setValue(currentScore) { (error, _) in
                    if let error = error {
                        print("Failed to update score: \(error.localizedDescription)")
                    } else {
                        print("Score updated successfully to \(currentScore)")
                    }
                }
            } else {
                print("Failed to retrieve current score.")
            }
        }
    }
    
    func setScore(score: Double) {
        let userID = Auth.auth().currentUser?.uid
        self.ref.child("users").child(userID!).child("score").setValue(score)
    }
    
    func numEntriesAtPath(path: String, completion: @escaping (Int) -> Void) {
        let reference = Database.database().reference(withPath: path)

        reference.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                let count = Int(snapshot.childrenCount)
                print("snapshot children count: ", count)
                completion(count)
            } else {
                completion(0)
                print("No data found at \(path)")
            }
        }
    }
    
    func getTopScoringUsers(completion: @escaping ([String], [String], [String]) -> Void) {
        let topScoresQuery = self.ref.child("users").queryOrdered(byChild: "score").queryLimited(toLast: 10)
        
        topScoresQuery.observeSingleEvent(of: .value, with: { (snapshot) in
            if let usersDict = snapshot.value as? [String: [String: Any]] {
                let sortedUsers = usersDict.sorted { (pair1, pair2) in
                    guard let score1 = (pair1.value["score"] as? Double),
                          let score2 = (pair2.value["score"] as? Double) else {
                        return false
                    }
                    if score1 != score2 {
                        return score1 > score2
                    } else {
                        // If scores are equal, sort by username alphabetically
                        guard let username1 = pair1.value["username"] as? String,
                              let username2 = pair2.value["username"] as? String else {
                            return false
                        }
                        return username1 < username2
                    }
                }
                let playerNames = sortedUsers.compactMap { ($0.value["username"] as? String ?? "") }
                let scores = sortedUsers.compactMap { String($0.value["score"] as? Double ?? 0) }
                let profileImgUrls = sortedUsers.compactMap { String($0.value["profileImageUrl"] as? String ?? "") }

                completion(playerNames, scores, profileImgUrls)
            }
        }) { (error) in
            print(error.localizedDescription)
            completion([], [], [])
        }

    }
    
    func uploadImageToFirebaseStorage(image: UIImage, completion: @escaping (URL?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }

        let storage = Storage.storage()
        let storageRef = storage.reference()

        // Create a reference to the "images" folder
        let imagesRef = storageRef.child("images")

        // Create a unique identifier for the image
        let imageName = UUID().uuidString
        let imageRef = imagesRef.child(imageName)

        imageRef.putData(imageData, metadata: nil) { (metadata, error) in
            guard error == nil else {
                print("Error uploading image to Firebase Storage: \(error!.localizedDescription)")
                completion(nil)
                return
            }

            imageRef.downloadURL { (url, error) in
                guard let downloadURL = url, error == nil else {
                    print("Error getting download URL: \(error!.localizedDescription)")
                    completion(nil)
                    return
                }

                completion(downloadURL)
            }
        }
    }
    
    func loadImageFromURL(urlString: String, imageViewtoSet: UIImageView) {
        // Check if the URL is valid
        guard let url = URL(string: urlString) else {
            print("Invalid URL string.")
            return
        }

        // Fetch image data from the URL
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching image data: \(error.localizedDescription)")
                return
            }

            // Check if data is valid
            if let data = data, let image = UIImage(data: data) {
                // Update the UI on the main thread
                DispatchQueue.main.async {
                    imageViewtoSet.image = image
                }
            } else {
                print("Failed to convert image data to UIImage.")
            }
        }.resume()
    }
    
}

