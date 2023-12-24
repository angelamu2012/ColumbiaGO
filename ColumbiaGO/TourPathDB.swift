//
//  TourPathDB.swift
//  ColumbiaGO
//
//  Created by Samantha Burak on 11/24/23.
//

import Foundation
import Firebase
import FirebaseCore
import FirebaseDatabase

class TourPathDB {
    let tourPath = [[40.806593, -73.963041], // Butler Plaza
                    [40.806385, -73.962539],
                    [40.806908, -73.962152],
                    [40.806716, -73.961711], // Hamilton
                    [40.806908, -73.962152],
                    [40.806918, -73.962176],
                    [40.807637, -73.961573],
                    [40.807477, -73.961070],
                    [40.807264, -73.961212],
                    [40.807107, -73.960840],
                    [40.807149, -73.960839], // Revson Plaza
                    [40.807540, -73.960535],
                    [40.807688, -73.960908],
                    [40.807726, -73.960881],
                    [40.807681, -73.960750],
                    [40.807824, -73.960655],
                    [40.807870, -73.960774],
                    [40.807922, -73.960736],
                    [40.807967, -73.960856],
                    [40.808179, -73.960712], // Schermerhorn Plaza
                    [40.808394, -73.960540],
                    [40.808537, -73.960912],
                    [40.809370, -73.960341],
                    [40.809221, -73.960013], // Close to Mudd
                    [40.809370, -73.960341],
                    [40.809222, -73.960467],
                    [40.809670, -73.961735],
                    [40.809973, -73.961502], // Close to Pupin
                    [40.810086, -73.961786], // Close to Noco
                    [40.809653, -73.962103],
                    [40.809418, -73.961530],
                    [40.808968, -73.961875],
                    [40.809161, -73.962352], // Close to Havemeyer
                    [40.808730, -73.962663],
                    [40.808737, -73.962835],
                    [40.808560, -73.962983],
                    [40.808514, -73.962903],
                    [40.808095, -73.963199], // Close to Dodge Hall
                    [40.807908, -73.962689],
                    [40.807607, -73.962919],
                    [40.807931, -73.963700]]
                        
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
    
    func createTourPathDB() {
        deleteDB(dbname: "tour_path")
        ref.child("tour_path").setValue(tourPath)
    }
}

    
    
