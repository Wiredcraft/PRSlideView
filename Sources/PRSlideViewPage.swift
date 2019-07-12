//
//  PRSlideViewPage.swift
//  PRSlideView
//
//  Created by Elethom Hunter on 7/11/19.
//  Copyright © 2019 Wiredcraft. All rights reserved.
//

import UIKit

open class PRSlideViewPage: UIControl {
    
    internal var pageIndex: Int = 0
    internal let pageIdentifier: String
    
    required public init(identifier: String) {
        self.pageIdentifier = identifier
        super.init(frame: CGRect.zero)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
