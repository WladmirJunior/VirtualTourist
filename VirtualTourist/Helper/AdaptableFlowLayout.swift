//
//  AdaptableFlowLayout.swift
//  VirtualTourist
//
//  Created by Wladmir  on 26/02/20.
//  Copyright © 2020 Wladmir . All rights reserved.
//

import UIKit

class AdaptableFlowLayout: UICollectionViewFlowLayout {
    var previousWidth: CGFloat?

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let newWidth = newBounds.width
        let shouldIvalidate = newWidth != self.previousWidth
        if shouldIvalidate {
            collectionView?.collectionViewLayout.invalidateLayout()
        }
        self.previousWidth = newWidth
        return false
    }
}

