//
//  PRSlideView.swift
//  PRSlideView
//
//  Created by Elethom Hunter on 7/11/19.
//  Copyright © 2019 Wiredcraft. All rights reserved.
//

import UIKit

// MARK: Enums and protocols

public extension PRSlideView {
    enum ScrollDirection {
        case horizontal
        case vertical
    }
}

public protocol PRSlideViewDataSource: class {
    func numberOfPagesInSlideView(_ slideView: PRSlideView) -> Int
    func slideView(_ slideView: PRSlideView, pageAt index: Int) -> PRSlideViewPage
}

public protocol PRSlideViewDelegate : UIScrollViewDelegate {
    func slideView(_ slideView: PRSlideView, didScrollToPageAt index: Int)
    func slideView(_ slideView: PRSlideView, didClickPageAt index: Int)
}

private extension PRSlideViewDelegate {
    // Make these protocol functions optional
    func slideView(_ slideView: PRSlideView, didScrollToPageAt index: Int) {}
    func slideView(_ slideView: PRSlideView, didClickPageAt index: Int) {}
}

// MARK: - Main implementation

open class PRSlideView: UIView {
    
    // MARK: Constants
    private let bufferLength = 512
    private let pageControlHeight: CGFloat = 17.0
    
    // MARK: Protocols
    weak open var dataSource: PRSlideViewDataSource?
    weak open var delegate: PRSlideViewDelegate?
    
    // MARK: Configs
    open private(set) var scrollDirection: PRSlideView.ScrollDirection = .horizontal
    open private(set) var infiniteScrollingEnabled: Bool = false
    open var showsPageControl: Bool = true {
        didSet {
            updatePageControlHiddenStatus()
        }
    }
    
    // MARK: Private properties
    
    private var currentPagePhysicalIndex: Int = 0 {
        didSet {
            didScrollToPage(physicallyAt: currentPagePhysicalIndex)
        }
    }
    private var baseIndexOffset: Int = 0
    
    private var classForIdentifiers: [String: PRSlideViewPage.Type] = [:]
    private var reusablePages: [String: Set<PRSlideViewPage>] = [:]
    private var loadedPages: Set<PRSlideViewPage> = []
    
    // MARK: UI elements and layouts
    
    public let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.clipsToBounds = false
        view.isPagingEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.scrollsToTop = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    open var pageControl: UIPageControl = {
        let control = UIPageControl()
        control.hidesForSinglePage = true
        control.addTarget(self,
                          action: #selector(pageControlValueChanged(_:)),
                          for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private var horizontalLayout: [NSLayoutConstraint] {
        return [
            NSLayoutConstraint(item: containerView,
                               attribute: .width,
                               relatedBy: .equal,
                               toItem: scrollView,
                               attribute: .width,
                               multiplier: CGFloat(numberOfPages * (infiniteScrollingEnabled ? bufferLength : 1)),
                               constant: 0),
            NSLayoutConstraint(item: containerView,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: scrollView,
                               attribute: .height,
                               multiplier: 1,
                               constant: 0)
        ]
    }
    private var verticalLayout: [NSLayoutConstraint] {
        return [
            NSLayoutConstraint(item: containerView,
                               attribute: .width,
                               relatedBy: .equal,
                               toItem: scrollView,
                               attribute: .width,
                               multiplier: 1,
                               constant: 0),
            NSLayoutConstraint(item: containerView,
                               attribute: .height,
                               relatedBy: .equal,
                               toItem: scrollView,
                               attribute: .height,
                               multiplier: CGFloat(numberOfPages * (infiniteScrollingEnabled ? bufferLength : 1)),
                               constant: 0)
        ]
    }
    private var cachedLayout: [NSLayoutConstraint]?
    private func layoutContainerView() {
        let index = currentPagePhysicalIndex
        if let layout = cachedLayout {
            NSLayoutConstraint.deactivate(layout)
        }
        switch scrollDirection {
        case .horizontal:
            let layout = horizontalLayout
            cachedLayout = layout
            NSLayoutConstraint.activate(layout)
        case .vertical:
            let layout = verticalLayout
            cachedLayout = layout
            NSLayoutConstraint.activate(layout)
        }
        scrollToPage(physicallyAt: index, animated: false)
    }
    private var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: Access status
    
    open var currentPageIndex: Int {
        return index(forPhysical: currentPagePhysicalIndex)
    }
    
    open private(set) var numberOfPages: Int = 0 {
        didSet {
            layoutContainerView()
            updatePageControlHiddenStatus()
            pageControl.numberOfPages = numberOfPages
            baseIndexOffset = infiniteScrollingEnabled ? numberOfPages * bufferLength / 2 : 0
        }
    }
    
    // MARK: Access contents
    
    open func page(at index: Int) -> PRSlideViewPage? {
        return loadedPages.filter { $0.pageIndex == index }.first ?? nil
    }
    
    open func index(for page: PRSlideViewPage) -> Int {
        return page.pageIndex
    }
    
    open var visiblePages: [PRSlideViewPage] {
        return loadedPages.sorted { $0.pageIndex < $1.pageIndex }
    }
    
    // MARK: UI Control
    
    open func scrollToPage(at index: Int) {
        // Enable animation by default
        scrollToPage(at: index, animated: true)
    }
    
    open func scrollToPage(at index: Int, animated: Bool) {
        // Scroll to page in current loop by default
        scrollToPage(physicallyAt: physicalIndexInCurrentLoop(for: index),
                     animated: animated)
    }
    
    open func scrollToPage(at index: Int, forward: Bool, animated: Bool) {
        scrollToPage(physicallyAt: physicalIndex(for: index, forward: forward),
                     animated: animated)
    }
    
    open func scrollToPreviousPage() {
        // Enable animation by default
        scrollToPreviousPage(animated: true)
    }
    
    open func scrollToNextPage() {
        // Enable animation by default
        scrollToNextPage(animated: true)
    }
    
    open func scrollToPreviousPage(animated: Bool) {
        scrollToPage(at: currentPageIndex - 1, forward: false, animated: animated)
    }
    
    open func scrollToNextPage(animated: Bool) {
        scrollToPage(at: currentPageIndex + 1, forward: true, animated: animated)
    }
    
    // MARK: Data control
    
    open func reloadData() {
        // Check data source
        guard let dataSource = dataSource else {
            fatalError("Slide view must have a data source")
        }
        
        // Load number of pages
        numberOfPages = dataSource.numberOfPagesInSlideView(self)
        guard numberOfPages != 0 else { return }
        
        // Load pages by triggering didScrollToPage(physicallyAt:)
        if infiniteScrollingEnabled && currentPageIndex == 0 {
            // Reset position to middle if infinite scrolling is enabled and current page is the first one
            scrollToPage(physicallyAt: baseIndexOffset, animated: false) // will trigger didScrollToPage(physicallyAt:)
        } else {
            didScrollToPage(physicallyAt: currentPagePhysicalIndex)
        }
    }
    
    // MARK: Reuse
    
    open func register(_ class: PRSlideViewPage.Type, forPageReuseIdentifier identifier: String) {
        classForIdentifiers[identifier] = `class`
        reusablePages[identifier] = []
    }
    
    open func dequeueReusablePage(withIdentifier identifier: String, for index: Int) -> PRSlideViewPage {
        let page: PRSlideViewPage = {
            if let page = reusablePages[identifier]?.popFirst() {
                return page
            } else if let page = classForIdentifiers[identifier]?.init(identifier: identifier) {
                page.translatesAutoresizingMaskIntoConstraints = false
                return page
            }
            fatalError("Unable to dequeue a page with identifier, must register a class for the identifier")
        }()
        page.pageIndex = index
        loadedPages.insert(page)
        return page
    }
    
    // MARK: Layout
    
    private var firstLayout: Bool = true
    private var isChangingLayout: Bool = false
    open override func layoutSubviews() {
        if firstLayout {
            firstLayout = false
            let index = currentPageIndex
            super.layoutSubviews()
            scrollToPage(physicallyAt: baseIndexOffset + index, animated: false)
        } else {
            isChangingLayout = true
            let physicalIndex = currentPagePhysicalIndex
            super.layoutSubviews()
            scrollToPage(physicallyAt: physicalIndex, animated: false)
            isChangingLayout = false
        }
    }
    
    // MARK: Life cycle
    
    private func configure() {
        scrollView.delegate = self
        addSubview(scrollView)
        scrollView.insertSubview(containerView, at: 0)
        addSubview(pageControl)
    }
    
    private func setupLayout() {
        // Set up scroll view
        do {
            let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .leading, .trailing]
            NSLayoutConstraint.activate(attributes.map {
                return NSLayoutConstraint(item: scrollView,
                                          attribute: $0,
                                          relatedBy: .equal,
                                          toItem: self,
                                          attribute: $0,
                                          multiplier: 1,
                                          constant: 0)
            })
        }
        
        // Set up container view
        do {
            let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .leading, .trailing]
            NSLayoutConstraint.activate(attributes.map {
                NSLayoutConstraint(item: containerView,
                                   attribute: $0,
                                   relatedBy: .equal,
                                   toItem: scrollView,
                                   attribute: $0,
                                   multiplier: 1,
                                   constant: 0)
            })
        }
        
        // Set up page control
        do {
            let attributes: [NSLayoutConstraint.Attribute] = [.bottom, .leading, .trailing]
            NSLayoutConstraint.activate(attributes.map {
                return NSLayoutConstraint(item: pageControl,
                                          attribute: $0,
                                          relatedBy: .equal,
                                          toItem: self,
                                          attribute: $0,
                                          multiplier: 1,
                                          constant: 0)
                } + [
                    NSLayoutConstraint(item: pageControl,
                                       attribute: .height,
                                       relatedBy: .equal,
                                       toItem: nil,
                                       attribute: .notAnAttribute,
                                       multiplier: 1,
                                       constant: pageControlHeight)
                ])
        }
    }
    
    required public init(direction: ScrollDirection, infiniteScrolling enabled: Bool) {
        self.scrollDirection = direction
        self.infiniteScrollingEnabled = enabled
        super.init(frame: .zero)
        self.configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        // Reset first layout to true in case the new superview has not been layouted
        firstLayout = true
    }
    
    open override func didMoveToSuperview() {
        // Add constraints again when added to a superview
        //   Reference: func removeFromSuperview()
        //              > Calling this method removes any constraints that refer to the view you are removing,
        //              > or that refer to any view in the subtree of the view you are removing.
        setupLayout()
    }
    
}

// MARK: - Internal control

private extension PRSlideView {
    
    // MARK: Control pages
    
    func addPages(physicallyAt indexRange: Range<Int>) {
        // If infinite scrolling is disabled, do not add pages off the limit
        let physicalIndexRange = infiniteScrollingEnabled ? indexRange : indexRange.clamped(to: 0 ..< numberOfPages)
        
        // Add pages
        for physicalIndex in physicalIndexRange {
            let index = self.index(forPhysical: physicalIndex)
            
            // Continue if the page already exists
            guard page(at: index) == nil else { continue }
            
            // Check data source
            guard let dataSource = dataSource else {
                fatalError("Slide view must have a data source")
            }
            
            // Create page
            let page = dataSource.slideView(self, pageAt: index)
            page.pageIndex = index
            page.addTarget(self,
                           action: #selector(pageClicked(_:)),
                           for: .touchUpInside)
            
            // Add page
            loadedPages.insert(page)
            // Just in case someone inexperienced doesn't call reloadData() from main thread
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.containerView.addSubview(page)
                NSLayoutConstraint.activate([
                    NSLayoutConstraint(item: page,
                                       attribute: .width,
                                       relatedBy: .equal,
                                       toItem: self,
                                       attribute: .width,
                                       multiplier: 1,
                                       constant: 0),
                    NSLayoutConstraint(item: page,
                                       attribute: .height,
                                       relatedBy: .equal,
                                       toItem: self,
                                       attribute: .height,
                                       multiplier: 1,
                                       constant: 0),
                    NSLayoutConstraint(item: page,
                                       attribute: self.scrollDirection == .horizontal ? .centerY : .centerX,
                                       relatedBy: .equal,
                                       toItem: self.containerView,
                                       attribute: self.scrollDirection == .horizontal ? .centerY : .centerX,
                                       multiplier: 1,
                                       constant: 0),
                    NSLayoutConstraint(item: page,
                                       attribute: self.scrollDirection == .horizontal ? .centerX : .centerY,
                                       relatedBy: .equal,
                                       toItem: self.containerView,
                                       attribute: self.scrollDirection == .horizontal ? .centerX : .centerY,
                                       multiplier: self.numberOfPages == 0 ? 1 : CGFloat(physicalIndex * 2 + 1) / CGFloat(self.numberOfPages * (self.infiniteScrollingEnabled ? self.bufferLength : 1)),
                                       constant: 0)
                    ])
            }
        }
    }
    
    func removePages(physicallyOutOf indexRange: Range<Int>) {
        for page in loadedPages.filter({ !(indexRange ~= $0.pageIndex) }) {
            // Move page to reuse pool
            guard var pages = reusablePages[page.pageIdentifier] else {
                fatalError("Unable to reuse a page with identifier, must register a class for the identifier")
            }
            pages.insert(page)
            // Just in case someone inexperienced doesn't call reloadData() from main thread
            DispatchQueue.main.async {
                page.removeFromSuperview()
            }
            loadedPages.remove(page)
        }
    }
    
    func didScrollToPage(physicallyAt index: Int) {
        // Call delegate
        delegate?.slideView(self, didScrollToPageAt: self.index(forPhysical: index))
        
        // Load 3 pages: previous + current + next
        let range = index - 1 ..< index + 1 + 1
        removePages(physicallyOutOf: range)
        addPages(physicallyAt: range)
    }
    
    // MARK: Scroll
    
    func scrollToPage(physicallyAt index: Int) {
        // Enable animation by default
        scrollToPage(physicallyAt: index, animated: true)
    }
    
    func scrollToPage(physicallyAt index: Int, animated: Bool) {
        scrollView.setContentOffset(rectForPage(physicallyAt: index).origin,
                                    animated: animated)
    }
    
    // MARK: Index and frame handling
    
    func physicalIndexInCurrentLoop(for index: Int) -> Int {
        guard infiniteScrollingEnabled else {
            return index
        }
        return currentPagePhysicalIndex - currentPageIndex + index
    }
    
    func physicalIndex(for index: Int, forward: Bool) -> Int {
        guard infiniteScrollingEnabled else {
            return index
        }
        let offset = index - currentPageIndex
        let physicalIndexInLoop = currentPagePhysicalIndex + offset
        if forward && offset < 0 {
            return physicalIndexInLoop + numberOfPages
        } else if !forward && offset > 0 {
            return physicalIndexInLoop - numberOfPages
        }
        return physicalIndexInLoop
    }
    
    func index(forPhysical index: Int) -> Int {
        guard numberOfPages != 0 else {
            return 0
        }
        var index = index
        if infiniteScrollingEnabled {
            index = index % numberOfPages
            if index < 0 {
                index += numberOfPages
            }
        }
        return index
    }
    
    func rectForPage(physicallyAt index: Int) -> CGRect {
        return CGRect(origin: CGPoint(x: scrollDirection == .horizontal ? bounds.width * CGFloat(index) : 0,
                                      y: scrollDirection == .vertical ? bounds.height * CGFloat(index) : 0),
                      size: bounds.size)
    }
    
    // MARK: UI Control
    
    func updatePageControlHiddenStatus() {
        if (showsPageControl
            && scrollDirection == .horizontal
            && bounds.width <= pageControl.size(forNumberOfPages: numberOfPages).width) {
            // TODO: Shows page number instead when there are too many pages
            pageControl.isHidden = false
        } else {
            pageControl.isHidden = true
        }
    }
    
}

// MARK: - Actions

private extension PRSlideView {
    
    @objc func pageClicked(_ page: PRSlideViewPage) {
        delegate?.slideView(self, didClickPageAt: index(forPhysical: page.pageIndex))
    }
    
    @objc func pageControlValueChanged(_ pageControl: UIPageControl) {
        scrollToPage(at: pageControl.currentPage)
    }
    
}

// MARK: - Scroll view delegate

extension PRSlideView: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            guard isChangingLayout == false else { return }
            let offset = scrollView.contentOffset
            currentPagePhysicalIndex = {
                switch scrollDirection {
                case .horizontal:
                    let width = bounds.width
                    return Int((offset.x + width * 0.5) / width)
                case .vertical:
                    let height = bounds.height
                    return Int((offset.y + height * 0.5) / height)
                }
            }()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            pageControl.currentPage = currentPageIndex
        }
    }
    
}
