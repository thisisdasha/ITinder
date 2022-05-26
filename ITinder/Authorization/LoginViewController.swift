import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var toSignUpLabel: UILabel!
    @IBOutlet weak var forgotPasswordLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()
        signUpLabelTapped()
        forgotPasswordLabelTapped()
    }
    
    private func signUpLabelTapped() {
        let signUpLabelTap = UITapGestureRecognizer(target: self, action: #selector(transitionToSignUpScreen))
        toSignUpLabel.isUserInteractionEnabled = true
        toSignUpLabel.addGestureRecognizer(signUpLabelTap)
    }
    
    @objc func transitionToSignUpScreen(_ sender: Any) {
        Router.transitionToSignUpVC(parent: self)
    }

    private func forgotPasswordLabelTapped() {
        let forgotPasswordTap = UITapGestureRecognizer(target: self, action: #selector(transitionToForgotPassScreen))
        forgotPasswordLabel.isUserInteractionEnabled = true
        forgotPasswordLabel.addGestureRecognizer(forgotPasswordTap)
    }
    
    @objc func transitionToForgotPassScreen(_ sender: Any) {
        print("Forgot tapped")
        let forgotPassVC = ForgotPasswordViewController()
        forgotPassVC.modalPresentationStyle = .fullScreen
        self.present(forgotPassVC, animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        Utilities.stylePrimaryButton(loginButton)
        Utilities.styleCaptionLabel(toSignUpLabel)
        Utilities.styleCaptionLabel(forgotPasswordLabel)
        Utilities.stylePrimaryTextField(emailTextField)
        Utilities.stylePrimaryTextField(passwordTextField)
    }
    @IBAction func loginButtonTapped(_ sender: Any) {
        let email = emailTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        AuthorizationService.signInUserInFirebase(email: email, password: password, vc: self)
    }
    
}
