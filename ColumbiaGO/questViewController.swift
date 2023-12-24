//
//  QuestViewController.swift
//  ColumbiaGO
//
//  Created by Allison Liu on 11/12/23.
//

import UIKit
import Firebase
import FirebaseCore
import FirebaseDatabase

class customQuestCell: UITableViewCell {

    @IBOutlet weak var emoji: UIImageView!
    @IBOutlet weak var progress: UILabel!
    @IBOutlet weak var questName: UILabel!
}


class questViewController: UIViewController {
    
    var ref: DatabaseReference!
    var selectedRowIndex: IndexPath? = nil
    
    @IBOutlet var tableView: UITableView!
    
    var questNames: [String] = []
    var questProgress: [String] = []
    
    var imgs: [UIImage] = []
    var emojis: [UIImage] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        
        tableView.dataSource = self
        tableView.delegate = self
        deselectCell()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.retrieveUserQuestData()
        tableView.delegate = self
        deselectCell()
    }
    
    func retrieveUserQuestData() {
        retrieveQuestInfo {questNamesList in
            self.questNames = questNamesList.map { $0.0 }
            self.imgs = questNamesList.map { $0.1! }
            self.emojis = questNamesList.map { $0.2! }
            self.questProgress = []
            self.retrieveUserProgress { inProgress, completed in
                for questName in self.questNames {
                    if inProgress.contains(questName) {
                        self.questProgress.append("In Progress")
                    }
                    else if completed.contains(questName)  {
                        self.questProgress.append("Completed")
                    }
                    else {
                        self.questProgress.append("")
                    }
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
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
    
    func retrieveUserProgress(completion: @escaping (Set<String>, Set<String>) -> Void) {
        var inProgress = Set<String>()
        var completed = Set<String>()
        let userID = Auth.auth().currentUser?.uid
        
        let group = DispatchGroup()
        group.enter()
        ref.child("users").child(userID!).child("questsCompleted").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (questName, _) in value {
                    completed.insert(questName)
                }
            }
            group.leave()
        }) { error in
            print(error.localizedDescription)
            group.leave()
        }
        
        group.enter()
        ref.child("users").child(userID!).child("questsStarted").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (questName, _) in value {
                    inProgress.insert(questName)
                }
            }
            group.leave()
        }) { error in
            print(error.localizedDescription)
            group.leave()
        }
        group.notify(queue: .main) {
            // called when both asynchronous operations are complete
            completion(inProgress, completed)
        }
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        let destVC = segue.destination as! questDetailViewController
        
        let selectedRow = self.tableView.indexPathForSelectedRow?.row
        destVC.name = self.questNames[selectedRow!]
        destVC.img = self.imgs[selectedRow!]
        destVC.progress = self.questProgress[selectedRow!]
        destVC.questEmoji = self.emojis[selectedRow!]
    }
    
    func deselectCell() {
        if let selectedRow = selectedRowIndex {
            tableView.deselectRow(at: selectedRow, animated: true)
            selectedRowIndex = nil
            
            tableView.allowsSelection = true
        }
    }
}

extension questViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return questNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "questCell", for: indexPath) as! customQuestCell
        
        cell.questName.text = questNames[indexPath.row]
        cell.progress.text = questProgress[indexPath.row]
        cell.emoji.image = emojis[indexPath.row]
        
        return cell
    }
}

extension questViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRowIndex = indexPath

        tableView.allowsSelection = false
    }
}
