//
//  Switcher.swift
//  ColumbiaGO
//
//  Created by Rachel Chung on 11/26/23.
//

import UIKit

class Switcher {

    static func updateRootViewController() {

        let status = UserDefaults.standard.bool(forKey: "isSignIn")
        var rootViewController : UIViewController?

        #if DEBUG
        print(status)
        #endif

        if (status == true) {
            let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
            let mainTabBarController = mainStoryBoard.instantiateViewController(withIdentifier: "mainTabBarController")
            rootViewController = mainTabBarController
        } else {
            let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
            let loginViewController = mainStoryBoard.instantiateViewController(withIdentifier: "loginViewController")
            rootViewController = loginViewController
        }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window?.rootViewController = rootViewController

    }

}

