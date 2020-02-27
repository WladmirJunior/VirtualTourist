//
//  ImageService.swift
//  VirtualTourist
//
//  Created by Wladmir  on 26/02/20.
//  Copyright © 2020 Wladmir . All rights reserved.
//

import Foundation

enum AuthenticationParameters: String {
    case apiKey = "ff9887ee312c6f05e93c376405fa0cb0"
    case authToken = "72157713266495537-775a10ab179beae7"
    
    // Key 89c0d0b3c7e7c3be1c65a3863b78506f
    // Secret 3c86c6b2a7576053
}

enum FlickrMethods: String {
    case photosForLocation = "flickr.photos.geo.photosForLocation"
    case search = "flickr.photos.search"
}

class ImageService {
    
    func getImages(latitude: Double, longitude: Double, page: Int, completion: @escaping(([Photo]?, String?) -> ())) {
        let urlString = "https://www.flickr.com/services/rest/?method=flickr.photos.search&api_key=89c0d0b3c7e7c3be1c65a3863b78506f&accuracy=16&lat=\(latitude)&lon=\(longitude)&per_page=12&page=\(page)&format=json&nojsoncallback=1"
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if let data = data {
                    do {
                        let res = try JSONDecoder().decode(PhotoResponse.self, from: data)
                        completion(res.photos.photo, nil)
                    } catch let error {
                        completion(nil, error.localizedDescription)
                    }
                } else {
                    completion(nil, error?.localizedDescription)
                }
            }.resume()
        }
    }
}
