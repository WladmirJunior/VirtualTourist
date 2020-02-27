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
    
    var photosToRemove: [PhotoData] = []
    
    var annotationData: Annotation!
    var dataController: DataController!
    var viewModel: AnnotationDetailViewModel!
    
    var fetchResultController: NSFetchedResultsController<PhotoData>!
    var blockOperations = [BlockOperation]()
     
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        addAnotation()
        setupViewModel()
        fetchPhotos()
        setupCollection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        fetchResultController = nil
    }
    
    deinit {
        for operation: BlockOperation in blockOperations {
            operation.cancel()
        }
        blockOperations.removeAll(keepingCapacity: false)
    }
    
    fileprivate func fetchPhotos() {
        let fetchRequest: NSFetchRequest<PhotoData> = PhotoData.fetchRequest()
        let predicate = NSPredicate(format: "annotation == %@", annotationData)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        fetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchResultController.delegate = self
        
        do {
            try fetchResultController.performFetch()
            if fetchResultController.fetchedObjects?.count == 0 {
                getRemotePhotos()
            }
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    fileprivate func getRemotePhotos() {
        viewModel.getImages(forLatitude: annotationData.lat, andLogitude: annotationData.long, andPage: Int(annotationData.page))
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
    
    fileprivate func downloadWithUrlSession(with url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self,
                  let data = data else {
                return
            }
            
            let backgroundContext: NSManagedObjectContext = self.dataController!.backgroundContext
            
            let annotationID = self.annotationData.objectID
            
            backgroundContext.perform {
                let backgroundAnnotation = backgroundContext.object(with: annotationID) as! Annotation
                let photoData = PhotoData(context: backgroundContext)
                photoData.image = data
                photoData.creationDate = Date()
                photoData.annotation = backgroundAnnotation
                try? self.dataController.backgroundContext.save()
            }
        }.resume()
    }
    
    @IBAction func newCollectionTapped(_ sender: UIButton) {
        annotationData.album = nil
        annotationData.page += 1
        try? dataController.viewContext.save()
        getRemotePhotos()
    }
    
    @IBAction func removeTapped(_ sender: Any) {
        for item in self.photosToRemove {
            let photoID = item.objectID
            
            let backgroundContext = dataController!.backgroundContext
            backgroundContext?.perform {
                let backgroundPhoto = backgroundContext?.object(with: photoID) as! PhotoData
                self.dataController.backgroundContext.delete(backgroundPhoto)
                try? self.dataController.backgroundContext.save()
            }
        }
        self.photosToRemove.removeAll()
        newCollectionButton.isHidden = false
        removePicturesButton.isHidden = true
    }
    
    public func updateView(with urlPhotos: [URL]) {
        for url in urlPhotos {
            downloadWithUrlSession(with: url)
        }
    }
}

extension AnnotationDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchResultController.sections?.count ?? 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResultController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as! ImageCell
        let photo = fetchResultController.object(at: indexPath)
        cell.display(image: UIImage(data: photo.image!))
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! ImageCell
        let photo = fetchResultController.object(at: indexPath)
        
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

extension AnnotationDetailViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperations.removeAll(keepingCapacity: false)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates({
            for operation in blockOperations {
                operation.start()
            }
        }, completion: { (completed) in
            self.blockOperations.removeAll(keepingCapacity: false)
        })
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.insertItems(at: [newIndexPath!])
            }))
        case .delete:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.deleteItems(at: [indexPath!])
            }))
        default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.insertSections(IndexSet(integer: sectionIndex))
            }))
        case .delete:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.deleteSections(IndexSet(integer: sectionIndex))
            }))
        default:
            break
        }
    }
}

extension UIViewController {
    open override func awakeFromNib() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "OK", style: .plain, target: nil, action: nil)
    }
}
