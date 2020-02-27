//
//  AnnotationDetailViewModel.swift
//  VirtualTourist
//
//  Created by Wladmir  on 26/02/20.
//  Copyright © 2020 Wladmir . All rights reserved.
//

import Foundation

class AnnotationDetailViewModel {
    
    let imageService: ImageService
    
    weak var viewController: AnnotationDetailViewController?
    
    init(imageService: ImageService) {
        self.imageService = imageService
    }
    
    func getImages(forLatitude latitude: Double, andLogitude longitude: Double, andPage page: Int) {
        imageService.getImages(latitude: latitude, longitude: longitude, page: page) { [weak self] photos, error in
            if let error = error {
                print(error)
            }
            
            if let photos = photos {
                let urls = photos.compactMap {
                    URL(string: "https://live.staticflickr.com" + "/\($0.server)" + "/\($0.id)_\($0.secret).jpg")
                }
    
                DispatchQueue.main.async {
                    self?.viewController?.updateView(with: urls)
                }
            }
        }
    }
}
