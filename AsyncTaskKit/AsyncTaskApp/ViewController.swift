//
//  ViewController.swift
//  AsyncTaskApp
//
//  Created by Michal Zaborowski on 2022-01-02.
//

import UIKit
import AsyncTaskKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func alertButtonTapped(_ sender: Any) {
        let alert = AlertTask.alert(title: "Alert 1", actions: [], presentationContext: self)

        let action = AlertTask.Action(title: "First Action", style: .destructive)
        let alert2 = AlertTask.alert(title: "Alert 2", actions: [action], presentationContext: nil)
        
        Task {
            try await alert.run()
            print("Alert 1 finished")
        }
        Task {
            try await alert2.run()
            print("Alert 2 finished")
        }
    }

}

