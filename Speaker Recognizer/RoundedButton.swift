//
//  RoundedButton.swift
//  Speaker Recognizer
//
//  Created by Jacob Gunnarsson on 11/02/16.
//  Copyright © 2016 Doberman. All rights reserved.
//

import UIKit

class RoundedButton: UIButton {

    var buttonState: String = "uncollapsed"

    private var squareLayer: CALayer?
    
    private let customFontName = "Montserrat-Regular"
    private let customContentEdgeInsets = UIEdgeInsetsMake(19, 37.0, 19, 37.0)

    private var originalWidth: CGFloat?
    private var widthConstraint: NSLayoutConstraint?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupCustomProperties()
    }
    
    override func awakeFromNib() {
        self.setupCustomProperties()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.setupPostLayoutSubviewsCustomProperties()

        self.setupConstraints()
    }
    
    
    // MARK: Public methods
    func setState(state: String) {
        switch state {
            case "collapsed":
                self.setStateCollapsed()
                break
            case "uncollapsed":
                self.setStateUncollapsed()
                break
            default: break
        }
        
        self.buttonState = state
    }
    
    // MARK: Private methods
    private func setStateCollapsed() {
        self.widthConstraint!.constant = self.layer.bounds.height + 1.0
        
        UIView.animateWithDuration(0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: .CurveEaseOut, animations: {
                self.layoutIfNeeded()
            
            self.squareLayer = CALayer()
            self.squareLayer!.frame = CGRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
            self.squareLayer!.backgroundColor = UIColor.whiteColor().CGColor
            self.squareLayer!.position = CGPoint(
                x: CGRectGetMidX(self.bounds),
                y: CGRectGetMidY(self.bounds)
            )
            self.squareLayer!.opacity = 0
            
            self.layer.addSublayer(self.squareLayer!)
            
            UIView.animateWithDuration(0.5, delay: 0.25, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .CurveEaseIn, animations: {
                self.squareLayer!.opacity = 1
                }, completion: nil)
            }, completion: nil
        )
    }

    private func setStateUncollapsed() {
        self.widthConstraint!.constant = self.originalWidth!
        
        UIView.animateWithDuration(0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, options: .CurveEaseOut, animations: {
                self.squareLayer!.removeFromSuperlayer()
                self.layoutIfNeeded()
            }, completion: nil
        )
    }
    
    private func setupCustomProperties() {
        let titleLabelText = self.titleLabel!.text!
        let attributedTitle = NSMutableAttributedString(string: titleLabelText.uppercaseString)
        
        attributedTitle.addAttribute(NSKernAttributeName, value: 2.25, range: NSRange(location: 0, length: titleLabelText.characters.count))
        
        self.setAttributedTitle(attributedTitle, forState: .Normal)

        self.titleLabel?.font = UIFont(name: self.customFontName, size: 17.0)
        self.titleLabel?.textColor = UIColor.whiteColor()
        
        self.contentEdgeInsets = self.customContentEdgeInsets
        
        self.layer.borderColor = UIColor.whiteColor().CGColor
        self.layer.borderWidth = 2
    }
    
    private func setupPostLayoutSubviewsCustomProperties() {
        self.layer.cornerRadius = self.layer.bounds.size.height / 2
    }
    
    private func setupConstraints() {
        if self.widthConstraint == nil {
            self.originalWidth = CGFloat(self.layer.bounds.width)

            self.widthConstraint = NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.Width, multiplier: 1.0, constant: self.layer.bounds.width);
            
            self.addConstraint(self.widthConstraint!);
            self.layoutIfNeeded()
        }
    }

}
