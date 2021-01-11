//
//  ItemSelectionViewController.swift
//  FMAVCam
//
//  Created by yfm on 2021/1/4.
//  Copyright © 2021 yfm. All rights reserved.
//

import UIKit
import AVFoundation

protocol ItemSelectionViewControllerDelegate: class {
    func itemSelectionViewController(_ itemSelectionViewController: ItemSelectionViewController,
                                     didFinishSelectingItems selectedItems: [AVSemanticSegmentationMatte.MatteType])
}

class ItemSelectionViewController: UITableViewController {
    
    weak var delegate: ItemSelectionViewControllerDelegate?
    
    let identifer: String
    
    let allItems: [AVSemanticSegmentationMatte.MatteType]
    
    var selectedItems: [AVSemanticSegmentationMatte.MatteType]
    
    let allowsMultipleSelection: Bool
    
    private let itemCellIdentifier = "Item"

    init(delegate: ItemSelectionViewControllerDelegate,
         identifier: String,
         allItems: [AVSemanticSegmentationMatte.MatteType],
         selectedItems: [AVSemanticSegmentationMatte.MatteType],
         allowsMultipleSelection: Bool) {
        
        self.delegate = delegate
        self.identifer = identifier
        self.allItems = allItems
        self.selectedItems = selectedItems
        self.allowsMultipleSelection = allowsMultipleSelection
        
        super.init(style: .grouped)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: itemCellIdentifier)

        view.tintColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func done() {
        delegate?.itemSelectionViewController(self, didFinishSelectingItems: selectedItems)
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let ssmType = allItems[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: itemCellIdentifier, for: indexPath)
        
        switch ssmType {
        case .hair:
            cell.textLabel?.text = "Hair"
        case .teeth:
            cell.textLabel?.text = "Teeth"
        case .skin:
            cell.textLabel?.text = "Skin"
        default:
            fatalError("UnKnown matte type specified.")
        }
        
        cell.accessoryType = selectedItems.contains(ssmType) ? .checkmark : .none
        return cell
    }

}
