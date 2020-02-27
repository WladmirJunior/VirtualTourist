//
//  ImageCell.swift
//  VirtualTourist
//
//  Created by Wladmir  on 26/02/20.
//  Copyright © 2020 Wladmir . All rights reserved.
//

import UIKit

class ImageCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var hoverView: UIView!
    
    var isTapped: Bool = false {
        didSet {
            hoverView.isHidden = !isTapped
        }
    }
    
    func display(image: UIImage?) {
      imageView.image = image
    }
}
