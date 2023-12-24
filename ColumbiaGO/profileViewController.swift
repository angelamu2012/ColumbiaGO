//
//  profileViewController.swift
//  ColumbiaGO
//
//  Created by Allison Liu on 11/13/23.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase

class customQuestTrophyCell: UITableViewCell {
    
    @IBOutlet weak var emoji: UIImageView!
    @IBOutlet weak var questLabel: UILabel!
    @IBOutlet weak var trophiesCollectionView: UICollectionView!
    
}

class customTrophyCell: UICollectionViewCell {
    
    @IBOutlet weak var trophyImage: UIImageView!
    @IBOutlet weak var trophyLabel: UILabel!
}

class profileViewController: UIViewController {
    
    let usersDB = UsersDB()
    var ref: DatabaseReference!
    
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var rank: UILabel!

    @IBOutlet weak var tableView: UITableView!
    
    var questLabels: [String] = []
    var questEmojis: [UIImage] = []
    var emojiMap =  [String:UIImage]()

    var trophyLabels: [[String]] = []
    
    var trophyImage: UIImage = UIImage(named: "trophy")!
    
    var allTrophies: [String: [String]] = [:] //questName:[list of trophies collected]
    
    @IBAction func logoutButtonTapped(_ sender: UIBarButtonItem) {
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.set(false, forKey: "isSignIn")
            Switcher.updateRootViewController()
        } catch(let error) {
            print(error.localizedDescription)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        
        retrieveUserInfo()
        retrieveQuestEmoji()
        displayTable()
        tableView.dataSource = self
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapChangeProfilePic))
        self.profilePicture.isUserInteractionEnabled = true
        self.profilePicture.addGestureRecognizer(tapGestureRecognizer)
        self.profilePicture.layer.cornerRadius = 70
        self.profilePicture.layer.masksToBounds = true
        self.profilePicture.layer.borderWidth = 1
        self.profilePicture.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        retrieveUserInfo()
        retrieveQuestEmoji()
        displayTable()
    }

    func displayTable() {
        retrieveTrophies { allQuestsTrophies in
            self.allTrophies = allQuestsTrophies
            
            if self.allTrophies.count == 0 {
                self.emptyStateView.isHidden = false
            } else {
                self.emptyStateView.isHidden = true
            }

            self.questLabels = Array(allQuestsTrophies.keys).sorted { $0.lowercased() < $1.lowercased()}
            
            self.trophyLabels = []
            for q in self.questLabels {
                self.trophyLabels.append(Array(allQuestsTrophies[q]!.sorted { $0.lowercased() < $1.lowercased()}))
            }

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func didTapChangeProfilePic() {
        presentPhotoActionSheet()
    }
  
    func retrieveUserInfo() {
        let userID = Auth.auth().currentUser?.uid
        ref.child("users").child(userID!).observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                DispatchQueue.main.async {
                    if value["profileImageUrl"] != nil {
                        self.usersDB.loadImageFromURL(urlString: value["profileImageUrl"] as! String, imageViewtoSet: self.profilePicture)
                    }
                    let name = value["username"] as? String
                    self.username.text = "@" + name!
                    
                    self.getRank(forUser: userID!) { rank in
                        if let userRank = rank {
                            var strUserRank: String
                            if value["score"] as! Double == 0.0 {
                                strUserRank = "--"
                            } else {
                                strUserRank = "#" + String(userRank)
                            }
                            self.rank.text = "Rank: " + strUserRank
                        } else {
                            print("User not found or an error occurred")
                        }
                    }
                }
            }
        }) { error in
            print(error.localizedDescription)
        }

    }
    
    func retrieveQuestEmoji() {
        retrieveQuestInfo {questNamesList in
            for quest in questNamesList {
                self.emojiMap[quest.0] = quest.2
            }
        }
    }
    
    func retrieveQuestInfo(completion: @escaping ([(String, UIImage?, UIImage?)]) -> Void) {
        var questNamesList: [(String, UIImage?, UIImage?)] = []
        ref.child("quests").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (questName, questInfo) in value {
                    if let questInfoDict = questInfo as? [String: Any],
                       let imgName = questInfoDict["img"] as? String,
                       let emoji = questInfoDict["emoji"] as? String {
                        questNamesList.append((questName, UIImage(named: imgName), UIImage(named: emoji)))
                    }
                }
                questNamesList = questNamesList.sorted { $0.0.lowercased() < $1.0.lowercased() }
                completion(questNamesList)
            }
        }) { error in
            print(error.localizedDescription)
            completion([])
        }
    }
    
    func getOrderedUsers(completion: @escaping ([String], [Double]) -> Void) {
        var sortedUsersKeys: [String] = []
        var sortedUsersScores: [Double] = []
        ref.child("users").observeSingleEvent(of: .value, with: { snapshot in
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
                sortedUsersKeys = sortedUsers.map { $0.key }
                sortedUsersScores = sortedUsers.map {$0.value["score"] as! Double}
            }
            completion(sortedUsersKeys, sortedUsersScores)
        }) { (error) in
            print(error.localizedDescription)
            completion([], [])
        }
    }
    
    func getRank(forUser playerID: String, completion: @escaping (Int?) -> Void) {
        print("for user: ", playerID)
        getOrderedUsers {sortedUsersKeys, sortedUsersScores in
            for (index, userID) in sortedUsersKeys.enumerated() {
                print(index, userID, sortedUsersScores[index])
                if playerID == userID {
                    let rank = index + 1 // Adding 1 because rank starts from 1, not 0
                    completion(rank)
                }
            }
            // If the specified user is not found
            completion(nil)
        }
    }
    
    func retrieveTrophies(completion: @escaping ([String:[String]]) -> Void) {
        let userID = Auth.auth().currentUser?.uid
        var questsTrophiesCompleted: [String: [String]] = [:]
        var questsTrophiesStarted: [String: [String]] = [:]

        let dispatchGroup = DispatchGroup()
        let dispatchQueue = DispatchQueue.global(qos: .userInitiated)

        // get all completed quests
        dispatchGroup.enter()
        dispatchQueue.async {
            self.ref.child("users").child(userID!).child("questsCompleted").observeSingleEvent(of: .value, with: { snapshot in
                if let value = snapshot.value as? [String: Any] {
                    for (questName, _) in value {
                        questsTrophiesCompleted[questName] = []
                    }
                }
                dispatchGroup.leave()
            }) { error in
                print(error.localizedDescription)
                dispatchGroup.leave()
            }
        }

        // get all trophies in completed quests
        dispatchGroup.notify(queue: dispatchQueue) {
            for quest in questsTrophiesCompleted.keys {
                dispatchGroup.enter()
                self.ref.child("quests").child(quest).child("locations").observeSingleEvent(of: .value, with: { snapshot in
                    if let value = snapshot.value as? [String: Any] {
                        for (_, trophyInfo) in value {
                            if let trophyInfoDict = trophyInfo as? [String: Any], let trophyName = trophyInfoDict["trophyName"] as? String {
                                questsTrophiesCompleted[quest]?.append(trophyName)
                            }
                        }
                    }
                    dispatchGroup.leave()
                }) { error in
                    print(error.localizedDescription)
                    dispatchGroup.leave()
                }
            }
        }
        
        // get all started quests
        dispatchGroup.enter()
        dispatchQueue.async {
            self.ref.child("users").child(userID!).child("questsStarted").observeSingleEvent(of: .value, with: { snapshot in
                if let value = snapshot.value as? [String: Any] {
                    for (questName, _) in value {
                        questsTrophiesStarted[questName] = []
                    }
                }
                dispatchGroup.leave()
            }) { error in
                print(error.localizedDescription)
                dispatchGroup.leave()
            }
        }

        // get all trophies in started quests
        dispatchGroup.notify(queue: dispatchQueue) {
            for quest in questsTrophiesStarted.keys {
                dispatchGroup.enter()
                self.ref.child("users").child(userID!).child("questsStarted").child(quest).observeSingleEvent(of: .value, with: { snapshot in
                    if let value = snapshot.value as? [String: Any] {
                        //get corresponding trophy names from trophyIDs
                        let group = DispatchGroup()
                        for trophyID in value.keys {
                            group.enter()
                            self.ref.child("quests").child(quest).child("locations").child(trophyID).observeSingleEvent(of: .value, with: { snapshot in
                                if let value = snapshot.value as? [String: Any] {
                                    questsTrophiesStarted[quest]?.append(value["trophyName"] as! String)
                                }
                                group.leave()
                            }) { error in
                                print(error.localizedDescription)
                                group.leave()
                            }
                        }
                        group.notify(queue: dispatchQueue) {
                            // Leave the outer dispatchGroup once all Task 5 operations are complete
                            dispatchGroup.leave()
                        }
                    }
                }) { error in
                    print(error.localizedDescription)
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(questsTrophiesCompleted.merging(questsTrophiesStarted) { (_, new) in new })
            }
        }
    }

}

extension profileViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return trophyLabels[collectionView.tag].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "trophyTableCell", for: indexPath) as! customTrophyCell

        cell.trophyLabel.text = trophyLabels[collectionView.tag][indexPath.row]
        cell.trophyImage.image = trophyImage

        return cell
    }
}

extension profileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return questLabels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "questTrophyCell", for: indexPath) as! customQuestTrophyCell
        
        cell.questLabel.text = questLabels[indexPath.row]
        cell.emoji.image = emojiMap[questLabels[indexPath.row]]
        cell.trophiesCollectionView.tag = indexPath.row
        cell.trophiesCollectionView.dataSource = self
        cell.trophiesCollectionView.reloadData()
        
        return cell
    }
}

extension profileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func presentPhotoActionSheet() {
        let actionSheet = UIAlertController(title: "Profile Picture", message: "How would you like to select a picture?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actionSheet.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { [weak self] _ in
            self?.presentCamera()
        }))
        actionSheet.addAction(UIAlertAction(title: "Choose Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoPicker()
        }))
        
        present(actionSheet, animated: true)
    }
    
    func presentCamera() {
        let imagePickerVC = UIImagePickerController()
        imagePickerVC.sourceType = .camera
        imagePickerVC.delegate = self
        imagePickerVC.allowsEditing = true
        present(imagePickerVC, animated: true)
    }
    
    func presentPhotoPicker() {
        let imagePickerVC = UIImagePickerController()
        imagePickerVC.sourceType = .photoLibrary
        imagePickerVC.delegate = self
        imagePickerVC.allowsEditing = true
        present(imagePickerVC, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        self.profilePicture.image = selectedImage

        usersDB.uploadImageToFirebaseStorage(image: selectedImage) { (downloadURL) in
            if let url = downloadURL {
                let userID = Auth.auth().currentUser?.uid
                let databaseRef = self.ref.child("users").child(userID!)
                databaseRef.child("profileImageUrl").setValue(url.absoluteString)
            } else {
                print("Failed to upload image.")
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
