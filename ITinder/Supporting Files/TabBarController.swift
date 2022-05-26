import UIKit

final class TabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.tintColor = Colors.primary
        addUserProfileViewController()
        
        viewControllers?.forEach({
            if let navigationVC = $0 as? UINavigationController {
                navigationVC.viewControllers.forEach { _ = $0.view }
            }
        })
    }
    
    private func addUserProfileViewController() {
        guard var viewControllers = viewControllers else { return }
        
        let userProfileVC = UserProfileViewController(user: nil)
        viewControllers.append(userProfileVC)
        self.viewControllers = viewControllers
        
        UserService.getCurrentUser { user in
            userProfileVC.user = user
        }
    }
}
