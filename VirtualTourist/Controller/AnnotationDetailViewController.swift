//
//  AnnotationDetailViewController.swift
//  VirtualTourist
//
//  Created by Wladmir  on 26/02/20.
//  Copyright © 2020 Wladmir . All rights reserved.
//

import UIKit
import MapKit
import CoreData

class AnnotationDetailViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var removePicturesButton: UIButton!
    
    private let cellSpacing: CGFloat = 1
    private let columns: CGFloat = 3
    private var cellSize: CGFloat?
    
    var urlPhotos: [URL] = []
    var photos: [PhotoData] = []
    var photosToRemove: [PhotoData] = []
    
    var annotationData: Annotation!
    var dataController: DataController!
    var viewModel: AnnotationDetailViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        addAnotation()
        setupViewModel()
        fetchPhotos()
        setupCollection()
    }
    
    fileprivate func fetchPhotos() {
        let fetchRequest: NSFetchRequest<PhotoData> = PhotoData.fetchRequest()
        let predicate = NSPredicate(format: "annotation == %@", annotationData)
        fetchRequest.predicate = predicate
        
        if let result = try? dataController.viewContext.fetch(fetchRequest) {
            photos = result
            
            if photos.count > 0 {
                collectionView.reloadData()
            } else {
                viewModel.getImages(forLatitude: annotationData.lat, andLogitude: annotationData.long, andPage: Int(annotationData.page))
            }
        }
    }
    
    fileprivate func addAnotation() {
        let annotation = MKPointAnnotation()
        let coordinate = CLLocationCoordinate2D(latitude: annotationData.lat, longitude: annotationData.long)
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        mapView.setRegion(region, animated: true)
    }
    
    fileprivate func setupViewModel() {
        viewModel = AnnotationDetailViewModel(imageService: ImageService())
        viewModel.viewController = self
    }
    
    fileprivate func setupCollection() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.collectionViewLayout = AdaptableFlowLayout()
    }
    
    fileprivate func downloadWithUrlSession(at indexPath: IndexPath) {
        URLSession.shared.dataTask(with: urlPhotos[indexPath.item]) { [weak self] (data, response, error) in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data) else {
                return
            }
            
            let photoData = PhotoData(context: self.dataController.viewContext)
            photoData.image = data
            photoData.annotation = self.annotationData
            try? self.dataController.viewContext.save()
            
            DispatchQueue.main.async {
                if let cell = self.collectionView.cellForItem(at: indexPath) as? ImageCell {
                    cell.display(image: image)
                }
            }
        }.resume()
    }
    
    @IBAction func newCollectionTapped(_ sender: UIButton) {
        annotationData.album = nil
        annotationData.page += 1
        try? dataController.viewContext.save()
//        fetchPhotos()
        viewModel.getImages(forLatitude: annotationData.lat, andLogitude: annotationData.long, andPage: Int(annotationData.page))
    }
    
    @IBAction func removeTapped(_ sender: Any) {
        for item in self.photosToRemove {
            let index = self.photos.firstIndex(of: item)!
            let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as! ImageCell
            cell.isTapped = false
            dataController.viewContext.delete(item)
        }
        self.photosToRemove.removeAll()
        newCollectionButton.isHidden = false
        removePicturesButton.isHidden = true
        
        try? dataController.viewContext.save()
        fetchPhotos()
    }
    
    public func updateView(with urlPhotos: [URL]) {
        self.urlPhotos = urlPhotos
        collectionView.reloadData()
    }
}

extension AnnotationDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if urlPhotos.count != 0 {
            return urlPhotos.count
        } else {
            return photos.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as! ImageCell
        
        if photos.count > indexPath.item {
            cell.display(image: UIImage(data: photos[indexPath.item].image!))
        } else {
            downloadWithUrlSession(at: indexPath)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! ImageCell
        let photo = photos[indexPath.item]
        
        if cell.isTapped {
            cell.isTapped = false
            if let index = self.photosToRemove.firstIndex(of: photo) {
                self.photosToRemove.remove(at: index)
                if self.photosToRemove.count == 0 {
                    newCollectionButton.isHidden = false
                    removePicturesButton.isHidden = true
                }
            }
        } else {
            cell.isTapped = true
            self.photosToRemove.append(photo)
            newCollectionButton.isHidden = true
            removePicturesButton.isHidden = false
        }
    }
}

extension AnnotationDetailViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if cellSize == nil {
            let layout = collectionViewLayout as! UICollectionViewFlowLayout
            let emptySpace = layout.sectionInset.left + layout.sectionInset.right + (columns * cellSpacing - 1)
            cellSize = (view.frame.size.width - emptySpace) / columns
        }
        
        return CGSize(width: cellSize!, height: cellSize!)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellSpacing
    }
}

extension AnnotationDetailViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView?.canShowCallout = true
            pinView?.pinTintColor  = .red
        } else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
}

extension UIViewController {
    open override func awakeFromNib() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "OK", style: .plain, target: nil, action: nil)
    }
}
