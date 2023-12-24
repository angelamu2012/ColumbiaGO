//
//  leaderboardViewController.swift
//  ColumbiaGO
//
//  Created by Allison Liu on 11/13/23.
//

import UIKit
import Firebase
import FirebaseCore
import FirebaseDatabase

class customLeaderboardCell: UITableViewCell {
    
    @IBOutlet weak var playerName: UILabel!
    @IBOutlet weak var trophyCount: UILabel!
    
}

class leaderboardViewController: UIViewController {

    var ref: DatabaseReference!
    var playerNames: [String] = []
        
    var trophies: [String] = []
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var goldMedal: UIImageView!
    @IBOutlet weak var silverMedal: UIImageView!
    @IBOutlet weak var bronzeMedal: UIImageView!
    @IBOutlet weak var player1: UIImageView!
    @IBOutlet weak var player2: UIImageView!
    @IBOutlet weak var player3: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let usersDB = UsersDB()
        
        usersDB.getTopScoringUsers() {playerNames, scores, profileImageUrls in
            self.trophies = scores
            self.playerNames = playerNames
            
            self.goldMedal.isHidden = true
            self.silverMedal.isHidden = true
            self.bronzeMedal.isHidden = true
            
            self.player1.isHidden = true
            self.player2.isHidden = true
            self.player3.isHidden = true
            
            self.player1.layer.cornerRadius = 70
            self.player1.layer.masksToBounds = true
            self.player1.layer.borderWidth = 1
            self.player1.layer.borderColor = UIColor.lightGray.cgColor
            
            self.player2.layer.cornerRadius = 52
            self.player2.layer.masksToBounds = true
            self.player2.layer.borderWidth = 1
            self.player2.layer.borderColor = UIColor.lightGray.cgColor
            
            self.player3.layer.cornerRadius = 45
            self.player3.layer.masksToBounds = true
            self.player3.layer.borderWidth = 1
            self.player3.layer.borderColor = UIColor.lightGray.cgColor
                        
            if playerNames.count >= 1 {
                if (profileImageUrls[0].count > 0) {
                    usersDB.loadImageFromURL(urlString: profileImageUrls[0], imageViewtoSet: self.player1)
                }
                else {
                    self.player1.image = UIImage(systemName: "person.fill")
                }
                self.player1.isHidden = false
                self.goldMedal.isHidden = false
            }
            if playerNames.count >= 2 {
                if (profileImageUrls[1].count > 0) {
                    usersDB.loadImageFromURL(urlString: profileImageUrls[1], imageViewtoSet: self.player2)
                }
                else {
                    self.player2.image = UIImage(systemName: "person.fill")
                }
                self.player2.isHidden = false
                self.silverMedal.isHidden = false
            }
            if playerNames.count >= 3 {
                if (profileImageUrls[2].count > 0) {
                    usersDB.loadImageFromURL(urlString: profileImageUrls[2], imageViewtoSet: self.player3)
                }
                else {
                    self.player3.image = UIImage(systemName: "person.fill")
                }
                self.player3.isHidden = false
                self.bronzeMedal.isHidden = false
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
}

extension leaderboardViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playerNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "leaderboardCell", for: indexPath) as! customLeaderboardCell
        
        cell.playerName.text = playerNames[indexPath.row]
        cell.trophyCount.text = trophies[indexPath.row]
        
        return cell
    }
}

