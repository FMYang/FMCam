//
//  ItemSelectionViewController.swift
//  FMAVCam
//
//  Created by yfm on 2021/1/4.
//  Copyright © 2021 yfm. All rights reserved.
//

import UIKit

class ItemSelectionViewController: UITableViewController {

    init() {
        super.init(style: .grouped)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        view.tintColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func done() {
        dismiss(animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
