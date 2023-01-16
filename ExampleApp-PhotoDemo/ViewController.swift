//
//  ViewController.swift
//  ExampleApp-PhotoDemo
//
//  Created by Yuriy Gudimov on 16.01.2023.
//

import UIKit
import Photos
import Combine

class ViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    
    private var cancellables: Set<AnyCancellable> = []
    private var loadPhotosCancellable: AnyCancellable?
    private var loadImagesCancellable: AnyCancellable?
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, UIImage>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView, cellProvider: { collectionView, indexPath, image in
            
            let photoCell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
            photoCell.imageView.image = image
            return photoCell
        })
    }

    private func fetchPhotos() {
        let options = PHFetchOptions()
        options.fetchLimit = 50
        let fetchResult = PHAsset.fetchAssets(with: options)
        print("Fetched \(fetchResult.count) photos")
        
        let targetSize = CGSize(width: 512, height: 512)
        
        let assetSubject = PassthroughSubject<PHAsset, Never>()
        
        loadImagesCancellable = assetSubject
            .collect()
            .flatMap { $0.publisher }
            .print("ASSET ARRAY")
            .flatMap(maxPublishers: .max(2)) {
                self.imagePublisher(asset: $0, targetSize: targetSize, contentMode: .aspectFill)
                    .print("IMAGE|\($0.localIdentifier)")
            }
            .print("FLATMAP")
            .compactMap { $0 }
            .collect()
            .sink { images in
                var snapshot = NSDiffableDataSourceSnapshot<Int, UIImage>()
                snapshot.appendSections([1])
                snapshot.appendItems(images)
                self.dataSource.apply(snapshot, animatingDifferences: true, completion: nil)
            }
        
        
        
        fetchResult.enumerateObjects { asset, index, _ in
            print("Sending asset: \(asset.localIdentifier)")
            assetSubject.send(asset)
        }
        print("Done with asets")
        assetSubject.send(completion: .finished)
    }

    @IBAction func loadPhotosTapped(_ sender: UIBarButtonItem) {
        loadPhotosCancellable = authorizationStatusPublisher
            .drop(while: { $0 != .authorized })
            .sink {[weak self] _ in
                self?.fetchPhotos()
            }
    }
    
    private var authorizationStatusPublisher: AnyPublisher<PHAuthorizationStatus, Never> = {
        Deferred {
            Future { promise in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    promise(.success(status))
                }
            }
        }
        .eraseToAnyPublisher()
    }()
    
    private func imagePublisher(asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode) -> AnyPublisher<UIImage?, Never> {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .exact
        
        return Future { promise in
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: requestOptions) { image, info in
                promise(.success(image))
            }
        }
        .eraseToAnyPublisher()
    }
}
