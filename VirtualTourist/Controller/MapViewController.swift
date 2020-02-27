//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Wladmir  on 26/02/20.
//  Copyright © 2020 Wladmir . All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var deleteViewHeight: NSLayoutConstraint!
    
    var dataController: DataController!
    var isDeletingMode = false
    var annotations: [Annotation] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configMapView()
        fetchLastLocation()
        fetchAnnotations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let coordinate = mapView.region.center
        let span = mapView.region.span
        
        let lastLocation = LastLocation(context: dataController.viewContext)
        lastLocation.lat = coordinate.latitude
        lastLocation.long = coordinate.longitude
        lastLocation.latitudeDelta = span.latitudeDelta
        lastLocation.longitudeDelta = span.longitudeDelta
        try? dataController.viewContext.save()
    }
    
    private func configMapView() {
        mapView.delegate = self
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotation(gestureRecognizer:)))
        
        mapView.addGestureRecognizer(recognizer)
    }
    
    fileprivate func fetchLastLocation() {
        let fetchRequest: NSFetchRequest<LastLocation> = LastLocation.fetchRequest()
        if let result = try? dataController.viewContext.fetch(fetchRequest) {
            if result.count > 0 {
                let coordinate = CLLocationCoordinate2D(latitude: result[0].lat, longitude: result[0].long)
                let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: result[0].latitudeDelta, longitudeDelta: result[0].longitudeDelta))
                mapView.setRegion(region, animated: false)
            }
        }
    }
    
    fileprivate func fetchAnnotations() {
        let fetchRequest: NSFetchRequest<Annotation> = Annotation.fetchRequest()
        if let result = try? dataController.viewContext.fetch(fetchRequest) {
            annotations = result
            addAnnotations()
        }
    }
    
    func addAnnotations() {
        var mapAnnotations = [MKPointAnnotation]()
        
        for item in self.annotations {

            let lat = CLLocationDegrees(item.lat)
            let long = CLLocationDegrees(item.long)
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapAnnotations.append(annotation)
        }
        
        DispatchQueue.main.async {
            self.mapView.addAnnotations(mapAnnotations)
        }
    }
    
    @objc func addAnnotation(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizer.State.began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            let modelAnnotation = Annotation(context: dataController.viewContext)
            modelAnnotation.lat =  newCoordinates.latitude
            modelAnnotation.long = newCoordinates.longitude
            modelAnnotation.page = 1
            try? dataController.viewContext.save()
            
            fetchAnnotations()
        }
    }
    
    @IBAction func editTapped(_ sender: UIBarButtonItem) {
        if sender.style == .plain {
            sender.title = "Done"
            sender.style = .done
            isDeletingMode = true
            UIView.animate(withDuration: 1) {
                self.deleteViewHeight.constant = 100
            }
            
        } else {
            sender.title = "Edit"
            sender.style = .plain
            isDeletingMode = false
            UIView.animate(withDuration: 1) {
                self.deleteViewHeight.constant = 0
            }
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPin" {
            guard let sender = sender as? Annotation else {
                return
            }
            
            let viewController = segue.destination as! AnnotationDetailViewController
            viewController.annotationData = sender
            viewController.dataController = dataController
        }
    }
}


extension MapViewController: MKMapViewDelegate {
    
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
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let annotationData = annotations.first(where: { $0.lat == Double(view.annotation!.coordinate.latitude) })
        
        if isDeletingMode {
            dataController.viewContext.delete(annotationData!)
            try? dataController.viewContext.save()
            mapView.removeAnnotation(view.annotation!)
        } else {
            performSegue(withIdentifier: "showPin", sender: annotationData)
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
    }
}
