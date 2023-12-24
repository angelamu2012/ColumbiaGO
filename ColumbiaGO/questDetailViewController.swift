//
//  questDetailViewController.swift
//  ColumbiaGO
//
//  Created by Allison Liu on 11/13/23.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseDatabase
import FirebaseStorage

class questDetailViewController: UIViewController {

    @IBOutlet weak var questTitle: UILabel!
    @IBOutlet weak var questImage: UIImageView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var emoji: UIImageView!
    
    var name: String = ""
    var img: UIImage? = nil
    var ref: DatabaseReference!
    var progress: String = ""
    var questEmoji: UIImage? = nil
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ref = Database.database().reference()

        self.questTitle.text = name
        self.questImage.image = img
        self.emoji.image = questEmoji
        
        if progress == "Completed" {
            startButton.isEnabled = false
            startButton.setTitle("Completed", for: .normal)
        } else if progress == "In Progress" {
            startButton.setTitle("Continue", for: .normal)
        }
    }
    
    func trophiesUserShouldCollect(questInProgress: String, completion: @escaping ([String:Any]) -> Void) {
        var collectedTrophies = Set<String>()
        var trophiesToBeCollected: [String: Any] = [:]
        let userID = Auth.auth().currentUser?.uid
        
        let group = DispatchGroup()
        group.enter()
        self.ref.child("users").child(userID!).child("questsStarted").child(questInProgress).observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (trophyID, _) in value {
                    collectedTrophies.insert(trophyID)
                }
            }
            group.leave()
        }) { error in
            print(error.localizedDescription)
            group.leave()
        }
        group.enter()
        self.ref.child("quests").child(questInProgress).child("locations").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (trophyID, trophyInfo) in value {
                    if let trophyInfoDict = trophyInfo as? [String: Any], !collectedTrophies.contains(trophyID) {
                        trophiesToBeCollected[trophyID] = trophyInfoDict
                    }
                }
            }
            group.leave()
        }) { error in
            print(error.localizedDescription)
            group.leave()
        }
        group.notify(queue: .main) {
            // called when both asynchronous operations are complete
            completion(trophiesToBeCollected)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        let destVC = segue.destination as! mapViewController
        destVC.currentQuest = self.questTitle.text!
    }

}
