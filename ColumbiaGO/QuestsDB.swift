//
//  QuestsDB.swift
//  ColumbiaGO
//
//  Created by Angela Mu on 11/10/23.
//

import Foundation
import Firebase
import FirebaseCore
import FirebaseDatabase


let libraryQuest = [["Butler Library", 40.806519, -73.963214, "You'll stop by here very often since it's open 24 hours a day!"],
                    ["Uris Library", 40.809018, -73.961334, "Where knowledge meets commerce and ideas take flight, amidst the hub of thinkers and planners, find your next clue where business and economics converge."],
                    ["East Asian Library", 40.807142, -73.961264, "Embark on a literary journey where the dragons guard knowledge and wisdom. Seek the first clue where history meets shelves."],
                    ["Lehman Library", 40.807735, -73.959483, "Seek out the place where policy papers and academic musings intertwine. Here you'll find solitude in the pursuit of global understanding."],
                    ["Science and Engineering Library", 40.810160, -73.961908, "Embark on a quest where knowledge meets light, in a library named after a corner so bright."]]

let diningQuest = [["John Jay Dining Hall", 40.805902, -73.962412, "Come here for your traditional college dining experience!"],
                   ["Ferris Booth Commons ", 40.806794, -73.963754, "Your go-to campus eatery when you get tired of the main dining hall!"],
                   ["JJ's Place", 40.805876, -73.962193, "It's open just almost 24 hours a day!"],
                   ["Faculty House", 40.806761, -73.959274, "Pretty high quality campus food previously not open to students. Come here if you like salmon!"],
                   ["Chef Mike's", 40.808778, -73.961075, "Stop by here and try the infamous Grandma sub before you go on to study business and economics!"]]

let visitorQuest = [["Butler Library Plaza", 40.806593, -73.963041, "You'll stop by here very often since it's open 24 hours a day!"],
                    ["Hamilton Hall", 40.806801, -73.961602, "Where knowledge and history entwine, seek the heart of Columbia's academic shrine. In a hall named for a founding father's fame, find the answer to continue the game. "],
                    ["Philosophy Hall", 40.807477, -73.961070, "In Morningside Heights, where ideas take flight, near the statue that muses day and night. To continue your quest, with intellect enthrall, explore the hall by the Columbia Thinker's sprawl."],
                    ["Revson Plaza", 40.80714866666423, -73.96083942810097, "Embark on a journey across the bridge connecting Morningside Heights to law, SIPA, and East Campus. Discover a hidden haven of grass and sculptures, guiding you to the heart of knowledge along Amsterdam Avenue."],
                    ["Schermerhorn Plaza", 40.808174814001866, -73.9607123478564, "An inscription above the doorway reads \"For the advancement of natural science. Speak to the earth and it shall teach thee.\" An Extension awaits, where knowledge doesn't end."],
                    ["Mudd Building", 40.809335, -73.959939, "Navigate the academic hub where algorithms and circuits converge, where knowledge and innovation surge."],
                    ["Pupin Laboratories", 40.810059, -73.961409, "Where atoms whispered secrets in the pursuit of power, find traces of brilliance where the hidden history of the Manhattan Project at Columbia once lived."],
                    ["Northwest Corner Building", 40.810028, -73.962042, "Hunt where interdisciplinary science floats above a basketball scene. Find the building named for its corner, opposite Diana's grace."],
                    ["Havemeyer Hall", 40.809279, -73.962264, "Where chemistry and discovery intertwine, seek the clue where elements align."],
                    ["Dodge Hall", 40.807968, -73.963205, "Seek the theatrical spotlight near the main gates, where this hall stands as Columbia's artistic stage."],
                    ["Broadway Gates", 40.807931, -73.963700, "Find the starting point of Columbia's legacy, the entrance to where the journey of knowledge began."]]

let dormsQuest = [["Carman Hall", 40.806582, -73.964092, "The place known as 'the freshmen party dorm'"],
                    ["John Jay Hall", 40.805902, -73.962412, "Residents of this dorm are lucky, with access to two dining halls in the very same building."],
                    ["Furnald Hall", 40.807362, -73.963877, "While some might consider it to be the antisocial dorm, that's only a stereotype!"],
                    ["Wallach Hall", 40.806099, -73.961914, "No one knows much about this freshmen dorm, except that it's next to John Jay."],
                    ["Hartley Hall", 40.806500, -73.961700, "Come to this dorm if you lose your room key!"]]

let barnardQuest = [["Barnard Hall", 40.809117, -73.964039, "This building is used for a variety of activites. A dining hall can be found below, and classrooms can be found above."],
                    ["Milbank Hall", 40.810553, -73.962847, "This building houses a variety of classrooms, including one with a grand piano."],
                    ["The Milstein Center", 40.809635, -73.963598, "Green chairs, open space, the best library on campus, etc."],
                    ["The Diana Center", 40.809972, -73.962944, "Liz's Place, Event Oval, and Barnard Store."]]

let quests = [["Libraries", libraryQuest, "libraries", "librariesEmoji"], ["Dining Halls", diningQuest, "dining", "diningEmoji"], ["Visitor Tour", visitorQuest, "visitor", "visitorEmoji"], ["Dorms", dormsQuest], ["Barnard", barnardQuest]]

class QuestsDB {
    var ref = Database.database().reference()
    
    func deleteDB(dbname: String) {
        ref.child(dbname).removeValue { error, _ in
            if let error = error {
                print("Failed to delete data: \(error.localizedDescription)")
            } else {
                print("Data deleted successfully.")
            }
        }
        
    }
    
    func printDBContents(dbname: String) {
        ref.child(dbname).observeSingleEvent(of: .value, with: { snapshot in
            let value = snapshot.value as? NSDictionary
            print(value ?? "")
        }) { error in
            print(error.localizedDescription)
        }
    }
    
    func createQuestsDB() {
        deleteDB(dbname: "quests")
        
        for quest in quests {
            print("quest: ", quest[0])
            ref.child("quests").child(quest[0] as! String).setValue(["img": quest[2] as! String, "emoji": quest[3] as! String])
            let trophiesRef =  ref.child("quests").child(quest[0] as! String).child("locations") //.childByAutoId()
            if let questsArray = quest[1] as? [[Any]] {
                var order = 1
                for trophyData in questsArray {
                    let trophyKey = trophiesRef.childByAutoId().key!
                    trophiesRef.child(trophyKey).setValue(["trophyName": trophyData[0], "lat": trophyData[1], "long": trophyData[2], "hint": trophyData[3], "order": order]) { (error, ref) in
                        if let error = error {
                            print("Error writing to Firebase: \(error)")
                        } else {
                            print("Trophies written successfully!")
                        }
                    }
                    order += 1
                }
            }
        }
    }
}
