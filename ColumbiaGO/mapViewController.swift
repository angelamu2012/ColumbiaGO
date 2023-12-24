//
//  mapViewController.swift
//  ColumbiaGO
//
//  Created by Samantha Burak on 11/6/23.
//

import UIKit
import CoreLocation
import MapKit
import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseDatabase
import FirebaseStorage

class mapViewController: UIViewController, CLLocationManagerDelegate,
                         MKMapViewDelegate {
     
    var ref: DatabaseReference!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var questView: UIView!
    @IBOutlet weak var questViewLabel: UILabel!
    @IBOutlet weak var hintView: UIView!
    @IBOutlet weak var hintViewLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var hideShowHintButton: UIButton!
    @IBOutlet weak var closeToLocationPopup: UIView!
    
    var locationManager = CLLocationManager()
    var currentQuest = ""
    var questTotalLocations = 0
    var hintTextStored = ""
    var trophyID = ""
    
    // params for segue to ARView
    var locNameToPass: String?
    
    func refreshMap(completion: @escaping (Bool) -> Void) {
        setCampusZoom()
        
        // Reset monitored region
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        if (currentQuest == "Visitor Tour") {
            mapView.removeAnnotations(mapView.annotations)
            renderVisitorTourStart()
            completion(true)
        } else {
            renderRegularQuestStart()
            completion(true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        ref = Database.database().reference()

        // Do any additional setup after loading the view.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        // Check if user is already inside region
        for region in locationManager.monitoredRegions {
            locationManager.requestState(for: region)
        }

        mapView.delegate = self
        mapView.showsUserLocation = true
        
        questView.layer.cornerRadius = 5
        questViewLabel.text = "In Progress: " + currentQuest
        
        setCampusZoom()

        if (currentQuest == "Visitor Tour") {
            renderVisitorTourStart()
        } else {
            renderRegularQuestStart()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch state {
        case .inside:
            print("User is inside the region: \(region.identifier)")
            if region is CLCircularRegion {
                DispatchQueue.main.async {
                    self.closeToLocationPopup.isHidden = false
                }
            }
        case .outside:
            print("User is outside the region: \(region.identifier)")
        case .unknown:
            print("Unknown state for region: \(region.identifier)")
        }
    }
    
    func renderVisitorTourStart() {
        let tourPathDB = TourPathDB()
        tourPathDB.createTourPathDB()
        
        self.getAllLocationCoords(questName: self.currentQuest) {visitorTourCoords, visitorTourNames in
            self.questTotalLocations = visitorTourNames.count
            let visitorTourDict = Dictionary(uniqueKeysWithValues: zip(visitorTourNames, visitorTourCoords))

            for (name, coords) in visitorTourDict {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coords
                annotation.title = name
                self.mapView.addAnnotation(annotation)
            }
            
            let tourPathDB = TourPathDB()
            tourPathDB.createTourPathDB()

            self.getAllTourCoords() {tourCoords in
                var modifiedTourCoords: [CLLocationCoordinate2D] = []
                for coord in tourCoords {
                    modifiedTourCoords.append(CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1]))
                }
                let polyline = MKPolyline(coordinates: modifiedTourCoords, count: modifiedTourCoords.count)
                self.mapView.addOverlay(polyline)
                
                self.checkIfJustStartedQuest(questName: self.currentQuest) { justStartedQuest in
                    if justStartedQuest {
                        self.renderHintAndProgressBarAndMonitoringRegion(orderNum: 1, coordinates: modifiedTourCoords)
                    } else {
                        self.getVisitedLocationIDs(questName: self.currentQuest) { visitedLocationIDs in
                            self.renderHintAndProgressBarAndMonitoringRegion(orderNum: visitedLocationIDs.count + 1, coordinates: modifiedTourCoords)
                        }
                    }
                }
            }
        }
    }
    
    func renderRegularQuestStart() {
        getAllLocationCoords(questName: currentQuest) {locationCoords, locationNames in
            self.questTotalLocations = locationNames.count
            
            self.checkIfJustStartedQuest(questName: self.currentQuest) { justStartedQuest in
                if justStartedQuest {
                    self.renderHintAndProgressBarAndMonitoringRegion(orderNum: 1, coordinates: locationCoords)
                } else {
                    self.getVisitedLocationCoords(questName: self.currentQuest) {visitedLocationCoords, visitedLocationNames in
                        let questDict = Dictionary(uniqueKeysWithValues: zip(visitedLocationNames, visitedLocationCoords))
                                                
                        for (name, coords) in questDict {
                            let annotation = MKPointAnnotation()
                            annotation.coordinate = coords
                            annotation.title = name
                            self.mapView.addAnnotation(annotation)
                        }
                        
                        let usersDB = UsersDB()
                        let userID = Auth.auth().currentUser?.uid
                        let questTrophiesPath = "users/" + userID! + "/questsStarted/" + self.currentQuest
                        usersDB.numEntriesAtPath(path: questTrophiesPath) { countTrophies in
                            self.renderHintAndProgressBarAndMonitoringRegion(orderNum: countTrophies+1, coordinates: locationCoords)
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func hideShowHint(_ sender: Any) {
        if self.hintViewLabel.text == "" {
            hintViewLabel.text = self.hintTextStored
            hideShowHintButton.setTitle("Hide Hint", for: .normal)
            if let image = UIImage(systemName: "eye.slash") {
                let scaledImage = image.withConfiguration(UIImage.SymbolConfiguration(scale: .small))
                hideShowHintButton.setImage(scaledImage, for: .normal)
            }
        } else {
            hintViewLabel.text = ""
            hideShowHintButton.setTitle("Show Hint", for: .normal)
            if let image = UIImage(systemName: "eye") {
                let scaledImage = image.withConfiguration(UIImage.SymbolConfiguration(scale: .small))
                hideShowHintButton.setImage(scaledImage, for: .normal)
            }
        }
    }
    
    func renderHintAndProgressBarAndMonitoringRegion(orderNum: Int, coordinates: [CLLocationCoordinate2D]) {
        getLocationData(questName: currentQuest, orderNum: orderNum) {trophyID, locationName, locationCoords, locationHint in
            self.trophyID = trophyID
            self.hintTextStored = "Location \(orderNum)/\(self.questTotalLocations): \(locationHint)"
            
            self.hintViewLabel.text = self.hintTextStored
            self.hintViewLabel.numberOfLines = 0;
            
            self.progressBar.progress = Float(orderNum - 1) / Float(self.questTotalLocations)
            
            // Setup monitoring region for next location
            self.setupRegions(with: locationCoords, name: locationName)
        }
    }
                                                
    func setCampusZoom() {
        let campusCoords = CLLocationCoordinate2D(latitude: 40.8078, longitude: -73.9621)
        let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        let region = MKCoordinateRegion(center: campusCoords, span: span)
                
        mapView.setRegion(region, animated: true)
    }
    
    func setupRegions(with coordinate: CLLocationCoordinate2D, name: String) {
        let region = CLCircularRegion(center: coordinate, radius: 10, identifier: String(coordinate.latitude)) // region: 10m
        region.notifyOnEntry = true // notif when user enters region
        region.notifyOnExit = false // no notif when the user exits the region
        self.locNameToPass = name
            
        locationManager.startMonitoring(for: region)
    }
    
    // Shows ARView when user enters a region
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLCircularRegion {
            self.closeToLocationPopup.isHidden = false
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let routePolyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: routePolyline)
            renderer.strokeColor = UIColor.black.withAlphaComponent(0.8)
            renderer.lineWidth = 5
            return renderer
        }
        
       return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "coord")

        if currentQuest == "Visitor Tour" {
            getVisitedLocationCoords(questName: currentQuest) {visitedLocationCoords, visitedLocationNames in
                if (visitedLocationNames.contains(annotation.title!!)) {
                    annotationView.markerTintColor = .purple
                } else {
                    annotationView.markerTintColor = .black
                }
            }
        } else {
            annotationView.markerTintColor = .purple
        }
        
        if annotation.title == "My Location" {
            return nil
        }
    
        return annotationView
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        if status == .notDetermined || status == .denied {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // If testing on laptop, set location to campus
        let currentLatitute = locations.first!.coordinate.latitude
        let currentLongitude = locations.first!.coordinate.longitude
    }
    
    func checkIfJustStartedQuest(questName: String, completion: @escaping (Bool) -> Void) {
        let userID = Auth.auth().currentUser?.uid
        ref.child("users").child(userID!).child("questsStarted").child(questName).observeSingleEvent(of: .value, with: { snapshot in
            if (snapshot.exists()) {
                completion(false)
            } else {
                completion(true)
            }
        });
    }

    func getAllLocationCoords(questName: String, completion: @escaping ([CLLocationCoordinate2D], [String]) -> Void) {
        var locationNames: [String] = []
        var locationCoords: [CLLocationCoordinate2D] = []
        self.ref.child("quests").child(questName).child("locations").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (_, trophyInfo) in value {
                    if let trophyInfoDict = trophyInfo as? [String: Any],
                       let lat = trophyInfoDict["lat"] as? Double,
                       let long = trophyInfoDict["long"] as? Double,
                       let trophyName = trophyInfoDict["trophyName"] as? String {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                        locationCoords.append(coordinate)
                        locationNames.append(trophyName)
                    }
                }
                completion(locationCoords, locationNames)
            }
        }
    )}
    
    func getLocationData(questName: String, orderNum: Int, completion: @escaping (String, String, CLLocationCoordinate2D, String) -> Void) {
        self.ref.child("quests").child(questName).child("locations").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? [String: Any] {
                for (trophyID, trophyInfo) in value {
                    if let trophyInfoDict = trophyInfo as? [String: Any],
                       let order = trophyInfoDict["order"] as? Int,
                       order == orderNum,
                       let lat = trophyInfoDict["lat"] as? Double,
                       let long = trophyInfoDict["long"] as? Double,
                       let trophyName = trophyInfoDict["trophyName"] as? String,
                       let hint = trophyInfoDict["hint"] as? String {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                        completion(trophyID, trophyName, coordinate, hint)
                        }
                }
            }
        }) { error in
            print(error.localizedDescription)
        }
    }
    
    func getVisitedLocationIDs(questName: String, completion: @escaping ([String]) -> Void) {
            var visitedLocationIDs: [String] = []
            let userID = Auth.auth().currentUser?.uid
            ref.child("users").child(userID!).child("questsStarted").child(questName).observeSingleEvent(of: .value, with: { snapshot in
                if (snapshot.exists()) {
                    if let value = snapshot.value as? [String: Bool] {
                        for (trophyID, _) in value {
                            visitedLocationIDs.append(trophyID)
                        }
                        completion(visitedLocationIDs)
                    }
                } else {
                    // Returning [] because snapshot doesn't exist
                    completion([])
                }
            }) { error in
                print(error.localizedDescription)
                completion([])
            }
        }
    
    func getVisitedLocationCoords(questName: String, completion: @escaping ([CLLocationCoordinate2D], [String]) -> Void) {
        var visitedLocationNames: [String] = []
        var visitedLocationCoords: [CLLocationCoordinate2D] = []
        getVisitedLocationIDs(questName: questName) { visitedLocationIDs in
            self.ref.child("quests").child(questName).child("locations").observeSingleEvent(of: .value, with: { snapshot in
                if let value = snapshot.value as? [String: Any] {
                    for (trophyID, trophyInfo) in value {
                        if let trophyInfoDict = trophyInfo as? [String: Any],
                           visitedLocationIDs.contains(trophyID),
                           let lat = trophyInfoDict["lat"] as? Double,
                           let long = trophyInfoDict["long"] as? Double,
                           let trophyName = trophyInfoDict["trophyName"] as? String {
                            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                            visitedLocationCoords.append(coordinate)
                            visitedLocationNames.append(trophyName)
                            }
                    }
                    completion(visitedLocationCoords, visitedLocationNames)
                }
            }) { error in
                print(error.localizedDescription)
                completion([], [])
            }
        }
    }
    
    func getAllTourCoords(completion: @escaping ([[Double]]) -> Void) {
        ref.child("tour_path").observeSingleEvent(of: .value) { snapshot in
            if let tourCoords = snapshot.value as? [[Double]] {
                // Use the arrayFromFirebase as needed
                completion(tourCoords)
            }
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "openARView" {
            self.closeToLocationPopup.isHidden = true
            if let destinationVC = segue.destination as? ARViewController {
                destinationVC.locName = self.locNameToPass
                destinationVC.trophyID = self.trophyID
                destinationVC.currentQuest = self.currentQuest
            }
        }
    }

}
