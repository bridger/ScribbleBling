//
//  ViewController.swift
//  GlitterDemo
//
//  Created by Raheel Ahmad on 5/14/20.
//  Copyright © 2020 Raheel Ahmad. All rights reserved.
//

import UIKit
import Glitter

class ViewController: UIViewController {
    private var glitterView: StarfieldView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlitterView()
    }

    private func setupGlitterView() {
        guard let glitterView = StarfieldView(config: .default) else {
            assertionFailure("Unable to set up a GlitterView")
            return
        }

        view.addSubview(glitterView)
        glitterView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glitterView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            glitterView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
            glitterView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            glitterView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
        self.glitterView = glitterView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        glitterView?.startMotionUpdates()
        glitterView?.startAutoShimmer()
    }
}

