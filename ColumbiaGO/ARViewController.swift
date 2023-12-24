//
//  ViewController.swift
//  ColumbiaGO
//
//  Created by Angela Mu on 11/2/23.
//

import UIKit
import RealityKit
import ARKit
import Combine

class ARViewController: UIViewController {
    
    var cancellables = Set<AnyCancellable>()
    var hasShownCollectTrophyView = false
    
    // params from mapViewController
    var locName: String?
    var trophyID: String?
    var currentQuest: String?
    
    var isRotating = true
    var rotationTimer: Timer?
    let rotationDuration: TimeInterval = 3
    var trophyEntity: Entity?
    
    let usersDBRef = UsersDB()
    
    @IBOutlet weak var arView: ARView!
    @IBOutlet weak var locationName: UILabel!
    @IBOutlet weak var collectTrophyView: UIView!
    @IBOutlet weak var collectTrophyButton: UIButton!
    
    @IBAction func collectTrophyActions(_ sender: UIButton) {
        
        // Update database with new trophy
        if let currentQuest = currentQuest,
           let trophyID = trophyID,
           !currentQuest.isEmpty,
           !trophyID.isEmpty,
           !currentQuest.contains(where: { ".#$[]".contains($0) }),
           !trophyID.contains(where: { ".#$[]".contains($0) }) {


            usersDBRef.retrieveTrophy(questName: currentQuest, trophyID: trophyID) {completedQuest in
                print("Database updated with collected trophy!")
                DispatchQueue.main.async {
                    if let viewControllers = self.navigationController?.viewControllers {
                        for viewController in viewControllers {
                            if let mapVC = viewController as? mapViewController {
                                mapVC.refreshMap() { success in
                                    print("Map View Refresh was \(success ? "successful" : "unsuccessful")")
                                    if (completedQuest) {
                                        self.performSegue(withIdentifier: "showCompletedQuestView", sender: self)
                                    } else {
                                        self.navigationController?.popToViewController(mapVC, animated: true)
                                    }
                                }
                                break
                            }
                        }
                    }
                }
            }
        } else {
            print("Invalid quest name: ", currentQuest!, " or trophy ID: ", trophyID!)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initially hide collect trophy view
        collectTrophyView.isHidden = true
        
        // Make trophy icon brighter
        arView.environment.lighting.intensityExponent = 3
        
        // Display trophy
        Entity.loadModelAsync(named: "Trophy.usdz").sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                print("Error loading model: \(error.localizedDescription)")
            }
        }, receiveValue: { [weak self] entity in
            self?.trophyEntity = entity
            self?.trophyEntity?.scale = [0.06, 0.06, 0.06]

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let anchor = AnchorEntity(world: [0, -7, -70])
                anchor.addChild(entity)
                self?.arView.scene.addAnchor(anchor)

                self?.startRotation()
            }
        }).store(in: &cancellables)
        
        // Check if user is viewing entire trophy
        let checkVisibilityInterval: TimeInterval = 0.3
        Timer.scheduledTimer(withTimeInterval: checkVisibilityInterval, repeats: true) { [weak self] _ in
            self?.checkTrophyVisibility()
        }
        
        // Display "Collect Trophy" Popup
        locationName.adjustsFontSizeToFitWidth = true
        locationName.minimumScaleFactor = 0.5
        locationName.text = locName
        
        collectTrophyView.layer.cornerRadius = 5
        collectTrophyView.layer.masksToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.hidesBackButton = true
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        let configuration = ARWorldTrackingConfiguration()
        
        arView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRotation() {success in
            self.arView.session.pause()
        }
    }
    
    func checkTrophyVisibility() {
        guard let trophyEntity = trophyEntity,
              let cameraTransform = arView.session.currentFrame?.camera.transform else {
            return
        }

        let boundingBox = trophyEntity.visualBounds(relativeTo: nil)
        let min = boundingBox.min
        let max = boundingBox.max
        
        // Calculate the eight corners of the bounding box
        let corners = [
            SIMD3<Float>(min.x, min.y, min.z),
            SIMD3<Float>(max.x, min.y, min.z),
            SIMD3<Float>(min.x, max.y, min.z),
            SIMD3<Float>(max.x, max.y, min.z),
            SIMD3<Float>(min.x, min.y, max.z),
            SIMD3<Float>(max.x, min.y, max.z),
            SIMD3<Float>(min.x, max.y, max.z),
            SIMD3<Float>(max.x, max.y, max.z)
        ]

        let horizontalFOV = Float.pi / 3 // ~60 degrees
        let verticalFOV = Float.pi / 4 // ~45 degrees

        var isFullyVisible = true

        // Check each corner of the bounding box
        for corner in corners {
            let cornerPosition = SIMD4<Float>(corner.x, corner.y, corner.z, 1)
            let cameraSpacePosition = cameraTransform.inverse * cornerPosition

            let isInHorizontalFOV = abs(cameraSpacePosition.x / cameraSpacePosition.z) <= tan(horizontalFOV * 0.5)
            let isInVerticalFOV = abs(cameraSpacePosition.y / cameraSpacePosition.z) <= tan(verticalFOV * 0.5)
            let isFrontOfCamera = cameraSpacePosition.z < 0

            if !(isInHorizontalFOV && isInVerticalFOV && isFrontOfCamera) {
                isFullyVisible = false
                break
            }
        }

        DispatchQueue.main.async {
            // Keep collectTrophyView unhidden
            if !self.hasShownCollectTrophyView && isFullyVisible {
                self.collectTrophyView.isHidden = false
                self.hasShownCollectTrophyView = true
            }
        }
    }

    
    func startRotation() {
        rotateEntity()
        rotationTimer = Timer.scheduledTimer(timeInterval: rotationDuration, target: self, selector: #selector(rotateEntity), userInfo: nil, repeats: true)
    }
    
    // Animate trophy
    @objc func rotateEntity() {
        guard let entity = trophyEntity else { return }

        let rotationAngle = Float.pi / 2
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(angle: rotationAngle, axis: rotationAxis)

        var newTransform = entity.transform
        newTransform.rotation = rotation * newTransform.rotation

        entity.move(to: newTransform, relativeTo: entity.parent, duration: rotationDuration, timingFunction: .linear)
    }
    
    func stopRotation(completion: @escaping (Bool) -> Void) {
        rotationTimer?.invalidate()
        rotationTimer = nil
        completion(true)
    };
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showCompletedQuestView" {
            if let destinationVC = segue.destination as? completedQuestViewController {
                destinationVC.currentQuest = self.currentQuest
            }
        }
    }
}
