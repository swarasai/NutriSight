//
//  ViewController.swift
//  NutriSight
//
//  Created by Swarasai Mulagari on 3/22/25.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        showMainMenu()
    }

    private func showMainMenu() {
        let mainMenuView = MainMenuView()
        let hostingController = UIHostingController(rootView: mainMenuView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
