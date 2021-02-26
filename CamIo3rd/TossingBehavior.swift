//
//  TossingBehavior.swift
//  CamIo3rd
//
//  Created by Huiying Shen on 12/5/19.
//  Copyright © 2019 Huiying Shen. All rights reserved.
//

import Foundation
import UIKit

final class TossingBehavior: UIDynamicBehavior {
    enum Direction {
        case top, left, bottom, right
    }
    
    private let snap: UISnapBehavior
    private let item: UIDynamicItem
    private var bounds: CGRect?
    
    var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                addChildBehavior(snap)
            } else {
                removeChildBehavior(snap)
            }
        }
    }
    
    init(item: UIDynamicItem, snapTo: CGPoint) {
        self.item = item
        self.snap = UISnapBehavior(item: item, snapTo: snapTo)
        
        super.init()
        
        addChildBehavior(snap)
        
        snap.action = { [weak self] in
            guard let bounds = self?.bounds, let item = self?.item else { return }
            guard let direction = self?.direction(from: item.center, in: bounds) else { return }
            guard let vector = self?.vector(from: direction) else { return }
            
            self?.isEnabled = false
            
            let gravity = UIGravityBehavior(items: [item])
            gravity.gravityDirection = vector
            gravity.magnitude = 5
            gravity.action = {
                print("Falling")
            }
            
            self?.addChildBehavior(gravity)
        }
    }
    
    // MARK: UIDynamicBehavior
    
    override func willMove(to dynamicAnimator: UIDynamicAnimator?) {
        super.willMove(to: dynamicAnimator)
        bounds = dynamicAnimator?.referenceView?.bounds
    }
    
    // MARK: Helpers
    
    private func direction(from center: CGPoint, in bounds: CGRect) -> Direction? {
        if center.x > bounds.width * 0.99 {
            return .right
        } else if center.x < bounds.width * 0.01 {
            return .left
        } else if center.y < bounds.height * 0.01 {
            return .top
        } else if center.y > bounds.height * 0.99 {
            return .bottom
        }
        
        return nil
    }
    
    private func vector(from direction: Direction) -> CGVector {
        switch direction {
        case .top:
            return CGVector(dx: 0, dy: -1)
        case .left:
            return CGVector(dx: -1, dy: 0)
        case .bottom:
            return CGVector(dx: 0, dy: 1)
        case .right:
            return CGVector(dx: 1, dy: 0)
        }
    }
}
