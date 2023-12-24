//
//  completedQuestViewController.swift
//  ColumbiaGO
//
//  Created by Samantha Burak on 12/2/23.
//

import UIKit
import SAConfettiView

class completedQuestViewController: UIViewController {
    var currentQuest: String?
    @IBOutlet weak var completedQuestView: UIView!
    
    @IBOutlet weak var questName: UILabel!
    
    @IBAction func finishQuest(_ sender: Any) {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        questName.text = currentQuest
        
        completedQuestView.layer.cornerRadius = 5
        completedQuestView.layer.masksToBounds = true
        
        let confettiView = SAConfettiView(frame: self.view.bounds)
        confettiView.isUserInteractionEnabled = false
        self.view.addSubview(confettiView)
        confettiView.startConfetti()
    }

}
