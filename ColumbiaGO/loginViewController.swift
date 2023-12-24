//
//  loginViewController.swift
//  ColumbiaGO
//
//  Created by Rachel Chung on 11/25/23.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseDatabase
import FirebaseStorage

class loginViewController: UIViewController {
    
    var usersDB: UsersDB!
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var usernameText: UITextField!
    @IBOutlet weak var passwordText: UITextField!
    @IBOutlet weak var confirmPasswordText: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var signupButton: UIButton!
    @IBOutlet weak var forgotPassword: UIButton!
    
    private enum PageType {
        case login
        case signup
    }
    
    private var currentPage: PageType = .login {
        didSet {
            setupViewFor(pageType: currentPage)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        usersDB = UsersDB()
        self.setupViewFor(pageType: currentPage)
    }
    
    private func setupViewFor(pageType: PageType) {
        errorLabel.text = ""
        confirmPasswordText.isHidden = pageType == .login
        signupButton.isHidden = pageType ==  .login
        forgotPassword.isHidden = pageType == .signup
        loginButton.isHidden = pageType == .signup
        usernameText.isHidden = pageType == .login
    }
    
    @IBAction func signUpButton(_ sender: Any) {
        let email = emailText.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = usernameText.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordText.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmPassword = confirmPasswordText.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if password == confirmPassword {
            Auth.auth().createUser(withEmail: email, password: password) { (result, error) in
                if error != nil {
                    let alert = UIAlertController(title: "Error", message: "\(error!.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(alert, animated: true)
                } else {
                    self.usersDB.addToUsersDB(email: email, username: username)
                    self.errorLabel.text = "Success! Return to login page."
                }
            }
        } else {
            self.errorLabel.text = "Passwords do not match."
        }
    }
    
    @IBAction func loginButton(_ sender: UIButton) {
        // clean up the user data
        let email = emailText.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordText.text!.trimmingCharacters(in: .whitespacesAndNewlines)

        // Signing in the User
        Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
            if error != nil {
                if error!.localizedDescription.contains("Network error") {
                    self.errorLabel.text = "Network error. Try again later."
                } else {
                    self.errorLabel.text = "Incorrect credentials. Please try again."
                }
            } else {
                self.performSegue(withIdentifier: "profileSegue", sender: nil)
                UserDefaults.standard.set(true, forKey: "isSignIn")
                Switcher.updateRootViewController()
            }
        }
    }
    
    @IBAction func segmentedControlChange(_ sender: UISegmentedControl) {
        currentPage = sender.selectedSegmentIndex == 0 ? .login : .signup
    }
    
    @IBAction func forgotPasswordButton(_ sender: Any) {
        let alertController = UIAlertController(title: "Forgot password", message: "Please enter your email address to receive new login credentials.", preferredStyle: .alert)
        alertController.addTextField(configurationHandler: nil)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            if let textField = alertController.textFields?.first, let email = textField.text, !email.isEmpty {
                Auth.auth().sendPasswordReset(withEmail: email) { (error) in
                    if error != nil {
                        let alert = UIAlertController(title: "Error", message: "\(error!.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(alert, animated: true)
                    } else {
                        let alert = UIAlertController(title: "Password reset successful", message: "Please check your email for further instructions.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }

}
