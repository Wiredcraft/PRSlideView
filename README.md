# PRSlideView [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg)](https://github.com/Carthage/Carthage) [![Language](https://img.shields.io/badge/language-Swift-orange.svg)](../../search) [![License](https://img.shields.io/github/license/Elethom/AEString.svg)](/LICENSE)

Slide view with gracefully written UIKit-like methods, delegate and data source protocol.

## Features

### Horizontal or vertical scrolling

The direction is horizontal by default.

```swift
enum ScrollDirection {
    case horizontal
    case vertical
}

open private(set) var scrollDirection: PRSlideView.ScrollDirection = .horizontal
```

### Infinite scrolling

Infinite scrolling is disabled by default.

```swift
open private(set) var infiniteScrollingEnabled: Bool = false
```

### Automatical scrolling

When automatical scrolling is enabled:

- Slide view scrolls to next page every 5 seconds by default
- It runs on default runloop mode by default, which means when main runloop enters tracking mode, the timer stops
- When user starts to scroll manually, the timer resets; when user stops scrolling, the timer starts again
- Slide view remembers time interval and runloop mode you set last time until you change them

```swift
open private(set) var isAutoScrollingEnabled: Bool = false
open var autoScrollingTimeInterval: TimeInterval = 5.0
open var autoScrollingRunLoopMode: RunLoop.Mode = .default
open func startAutoScrolling()
open func startAutoScrolling(withTimeInterval interval: TimeInterval)
open func startAutoScrolling(withRunLoopMode mode: RunLoop.Mode)
open func startAutoScrolling(withTimeInterval interval: TimeInterval, withRunLoopMode mode: RunLoop.Mode)
open func stopAutoScrolling()
```

### Page control (horizontal mode only)

The page control is enabled by default when scroll direction is horizontal.

However, when there are too many pages that there is not enough space to show page control, it will be hidden.

```swift
open var showsPageControl: Bool = true
```

### Scroll manually

You can use these methods to scroll manually. Animation is enabled by default.

When infinite scrolling is enabled, calling `scrollToPage(at:animated:)` will cause it to scroll to the target page in current loop by default. However, you can assign a direction by calling `scrollToPage(at:forward:animated:)`.

```swift
open func scrollToPage(at index: Int)
open func scrollToPage(at index: Int, animated: Bool)
open func scrollToPage(at index: Int, forward: Bool, animated: Bool)
open func scrollToPreviousPage()
open func scrollToNextPage()
open func scrollToPreviousPage(animated: Bool)
open func scrollToNextPage(animated: Bool)
```

## Installation

### Carthage

Add to your `Cartfile`:

```ogdl
github "Wiredcraft/PRSlideView" ~> 1.0
```

## Usage

### Create a Slide View

```swift
private lazy var slideView: PRSlideView = {
    let view = PRSlideView(direction: .horizontal,
                           infiniteScrolling: true)
    view.dataSource = self
    view.delegate = self
    view.register(AlbumPage.self,
                  forPageReuseIdentifier: String(describing: type(of: AlbumPage.self)))
    return view
}()
```

### Create a Subclass of Slide View Page

```swift
import UIKit
import PRSlideView

class AlbumPage: PRSlideViewPage {
    
    lazy var coverImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .leading, .trailing]
        NSLayoutConstraint.activate(attributes.map {
            return NSLayoutConstraint(item: view,
                                      attribute: $0,
                                      relatedBy: .equal,
                                      toItem: self,
                                      attribute: $0,
                                      multiplier: 1,
                                      constant: 0)
        })
        return view
    }()
    
}
```

### Use Data Source

```swift
extension AlbumViewController: PRSlideViewDataSource {
    
    func numberOfPagesInSlideView(_ slideView: PRSlideView) -> Int {
        return albumData.count
    }
    
    func slideView(_ slideView: PRSlideView, pageAt index: Int) -> PRSlideViewPage {
        let page = slideView.dequeueReusablePage(withIdentifier: String(describing: type(of: AlbumPage.self)),
                                                 for: index) as! AlbumPage
        page.coverImageView.image = UIImage(named: albumData[index] + ".jpg")
        return page
    }
    
}
```

### Use Delegate

```swift
extension AlbumViewController: PRSlideViewDelegate {
    
    func slideView(_ slideView: PRSlideView, didScrollToPageAt index: Int) {
        titleLabel.text = albumData[index]
    }
    
    func slideView(_ slideView: PRSlideView, didClickPageAt index: Int) {
        let alert = UIAlertController(title: "You clicked on an album",
                                      message: albumData[index],
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK",
                                      style: .default,
                                      handler: nil))
        self.present(alert,
                     animated: true,
                     completion: nil)
    }
    
}
```

## License

This project is released under the terms and conditions of the [MIT license](https://opensource.org/licenses/MIT). See [LICENSE](/LICENSE) for details.

## Contact

This project is designed and developed by [Elethom](https://github.com/Elethom) @ [Wiredcraft](https://wiredcraft.com). You can reach me via:

* Email: elethomhunter@gmail.com
* Telegram: [@elethom](http://telegram.me/elethom)
