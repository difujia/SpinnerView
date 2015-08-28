//
//  NumberSpinner.swift
//  NumberSpinner
//
//  Created by di, frank (CHE-LPR) on 8/12/15.
//  Copyright © 2015 Fujia. All rights reserved.
//

import UIKit

private let ViewDebugColor = UIColor.yellowColor()
private let SpinnerDebugColor = UIColor.greenColor()

@IBDesignable
public class NumberSpinner: UIView {
    
    private var _formatter: NSNumberFormatter = {
       let nf = NSNumberFormatter()
        nf.numberStyle = .DecimalStyle
        nf.usesGroupingSeparator = false
        return nf
        }()
    
    public var formatter: NSNumberFormatter {
        get {
            return _formatter
        }
        
        set {
            _formatter = newValue
            updateFormat()
        }
    }

    @IBInspectable
    public var value: Double = 0 {
        didSet {
            updateAgainstValue()
        }
    }
    
    @IBInspectable
    public var spinningDuration: Double = 0.5
    
    @IBInspectable
    public var alignmentDuration: Double = 0.25
    
    @IBInspectable
    public var debugEnabled: Bool = false {
        didSet {
            spinner.debugEnabled = debugEnabled
            backgroundColor = debugEnabled ? ViewDebugColor : nil
        }
    }
    
    // Autolayout is required to automatically resize this view.
    public override class func requiresConstraintBasedLayout() -> Bool {
        return true
    }
    
    // MARK: - Initializers
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        spinner.masksToBounds = true
        spinner.spinnerLayerDelegate = self
        layer.addSublayer(spinner)
        layer.masksToBounds = true
        updateAgainstValue()
    }
    
    // MARK: - Properties
    private let spinner = SpinnerLayer<StringTrackLayer>()
    private var integerLayers = [StringTrackLayer]()
    private var fractionLayers = [StringTrackLayer]()
    lazy private var separatorLayer: StringTrackLayer = {
        let decimalSeparator = self.formatter.decimalSeparator
        let separator = StringTrackLayer.trackLayerForSample(decimalSeparator)
        return separator
    }()
    
    public func updateFormat() {
        integerLayers = []
        fractionLayers = []
        separatorLayer = StringTrackLayer.trackLayerForSample(formatter.decimalSeparator)
        updateAgainstValue()
    }
    
    private func updateAgainstValue() {
        guard value.isFinite else { return }
        // Process value using its String representation
        let valueString = formatter.stringFromNumber(value)!
        let separator = Character(formatter.decimalSeparator)
        let split = valueString.characters.split(separator)
        
        // Update integer part
        var integerStrings = split.first!.map{ String($0) }
        let integerDiff = integerStrings.count - integerLayers.count
        
        if integerDiff > 0 {
            // We insert components to the head
            integerStrings.prefixUpTo(integerDiff).reverse().forEach {
                s in
                self.integerLayers.insert(StringTrackLayer.trackLayerForSample(s), atIndex: 0)
            }
        } else if integerDiff < 0 {
            integerLayers = Array(integerLayers.suffixFrom(abs(integerDiff)))
        }
        
        fixInvalidPairs(integerStrings, tracks: &integerLayers)
        
        // Update fraction part
        let fractionStrings = split.count == 2 ? split[1].map{ String($0) } : []
        let fractionDiff = fractionStrings.count - fractionLayers.count
        
        if fractionDiff > 0 {
            // We append fraction components to the trail
            fractionStrings.suffixFrom(fractionLayers.count).forEach {
                s in
                fractionLayers.append(StringTrackLayer.trackLayerForSample(s))
            }
        } else if fractionDiff < 0 {
            fractionLayers = Array(fractionLayers.prefixUpTo(fractionStrings.count))
        }
        
        fixInvalidPairs(fractionStrings, tracks: &fractionLayers)
        
        // Final composition
        let composition: [StringTrackLayer]
        if fractionLayers.count > 0 {
            composition = integerLayers + [separatorLayer] + fractionLayers
        } else {
            composition = integerLayers
        }
        
        let spinning = {
            // Animate to appropriate position
            CATransaction.begin()
            CATransaction.setAnimationDuration(self.spinningDuration)
            zip(integerStrings, self.integerLayers).forEach {
                s, aLayer in
                aLayer.scrollToUnit(s)
            }
            
            if fractionStrings.count > 0 {
                zip(fractionStrings, self.fractionLayers).forEach {
                    s, aLayer in
                    aLayer.scrollToUnit(s)
                }
            }
            CATransaction.commit()
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(alignmentDuration)
        CATransaction.setCompletionBlock(spinning)
        spinner.components = composition
        
        CATransaction.commit()
    }
    
    /**
        Some number format (e.g. CurrencyStyle) may have prefix or postfix. As the length of the formatted string changes, the prefix or postfix at previous indexex remain. They may need to be replaced with another type of track (e.g. number track).
        
        :param: values Strings that each matches a layer in the track array.
        :param: tracks Tracks that each matches a string in the string array
    */
    private func fixInvalidPairs(values: [String], inout tracks: [StringTrackLayer]) {
        zip(values, tracks).enumerate().forEach {
            e in
            let s = e.element.0
            let layer = e.element.1
            if !layer.hasUnit(s) {
                let replacement = StringTrackLayer.trackLayerForSample(s)
                integerLayers[e.index] = replacement
            }
        }
    }
    
    /// Prevent unnecessary "appearing animation"
    private var initialLayout = true
    private func layoutSpinner() {
        layoutIfNeeded()
        spinner.frame = CGRect(origin: CGPointZero, size: self.spinner.preferredSize)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        if initialLayout {
            initialLayout = false
            return
        }
        UIView.animateWithDuration(alignmentDuration) {
            self.layoutIfNeeded()
        }
    }
    
    public override func intrinsicContentSize() -> CGSize {
        return spinner.preferredSize
    }
}

extension NumberSpinner: SpinnerLayerDelegate {
    func spinnerLayer<C where C : CALayer, C : SpinnerComponent>(spinnerLayer: SpinnerLayer<C>, preferredSizeDidChange preferredSize: CGSize) {
        layoutSpinner()
    }
}

/// Implementation response to this call by adjusting the frame of the spinner.
protocol SpinnerLayerDelegate: class {
    func spinnerLayer<C where C: CALayer, C: SpinnerComponent>(spinnerLayer: SpinnerLayer<C>, preferredSizeDidChange preferredSize: CGSize)
}

class SpinnerLayer<Component where Component: CALayer, Component: SpinnerComponent>: CALayer {
    
    // Provide initializers because we make this subclass generic
    override init() {
        super.init()
    }
    
    override init(layer: AnyObject) {
        super.init(layer: layer)
    }
    
    weak var spinnerLayerDelegate: SpinnerLayerDelegate?
    
    /// Spinner components to be arranged in a row in the same order they appear in this array.
    var components: [Component]? {
        didSet {
            components?.forEach { $0.debugEnabled = self.debugEnabled }
            let componentsUpCast = components as [CALayer]?
            let componentsSet = Set(componentsUpCast ?? [])
            let sublayersSet = Set(sublayers ?? [])
            let addition = componentsSet.subtract(sublayersSet)
            addition.forEach { self.insertSublayer($0, atIndex: 0) }
            let removal = sublayersSet.subtract(componentsSet)
            removal.forEach { $0.removeFromSuperlayer() }
            arrangeComponents()
        }
    }
    
    var debugEnabled = false {
        didSet {
            components?.forEach { $0.debugEnabled = self.debugEnabled}
            masksToBounds = !debugEnabled
            backgroundColor = debugEnabled ? SpinnerDebugColor.CGColor : nil
        }
    }
    
    /// Client may be interested in observing this property to resize the layer.
    private(set) dynamic var preferredSize = CGSizeZero {
        didSet {
            if !CGSizeEqualToSize(oldValue, preferredSize) {
                spinnerLayerDelegate?.spinnerLayer(self, preferredSizeDidChange: preferredSize)
            }
        }
    }
    
    private func arrangeComponents() {
        // Re-calculate preferredSize and re-arrange x position of each components
        let preferredBounds = components?.reduce(CGRect.zeroRect) {
            previous, component in
            let thisOrigin = CGPoint(x: previous.maxX, y: previous.origin.y)
            let thisFrame = CGRect(origin: thisOrigin, size: component.unitSize)
            // Move this component
            component.position.x = thisFrame.midX
            return previous.rectByUnion(thisFrame)
        }
        preferredSize = preferredBounds?.size ?? CGSizeZero
    }
}

public protocol SpinnerComponent {
    var unitSize: CGSize { get }
    var debugEnabled: Bool { get set }
    func scrollToUnitAtIndex(index: Int)
}


public class StringTrackLayer: CALayer, SpinnerComponent {
    
    // MARK: - Defaults
    public static let defaultAttributes: [String: AnyObject] = {
        let preferredFont = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .Center
        
        return [NSFontAttributeName: preferredFont,
            NSParagraphStyleAttributeName: centerStyle]
    }()
    
    // MARK: - Properties
    private var _attributes: [String: AnyObject]?
    public var attributes: [String: AnyObject] {
        get {
            return self.dynamicType.defaultAttributes.merge(_attributes)
        }
        set {
            _attributes = newValue
            update()
        }
    }
    
    public var debugEnabled = false {
        didSet {
            if oldValue != debugEnabled {
                setNeedsDisplay()
            }
        }
    }
    
    private let drawingUnits: [String]
    
    // MARK: - Initializers
    public init(strings: [String]) {
        drawingUnits = strings
        super.init()
        update()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public convenience init(stringUnion: String) {
        let strings = stringUnion.characters.flatMap{String($0)}
        self.init(strings: strings)
    }
    
    public override init(layer: AnyObject) {
        drawingUnits = []
        super.init(layer: layer)
    }
    
    // MARK: - Convenient factory method
    public class func trackLayerForSample(sample: String) -> StringTrackLayer {
        if sample.characters.count == 1 {
            if NSCharacterSet.decimalDigitCharacterSet().characterIsMember(sample.utf16.first!) {
                return StringTrackLayer(stringUnion: "0123456789")
            }
        }
        return StringTrackLayer(strings: [sample])
    }
    
    public func hasUnit(unit: String) -> Bool {
        return drawingUnits.contains(unit)
    }
    
    private func update() {
        // Size for each unit may vary, use the largest one
        unitSize = drawingUnits.reduce(CGRectZero) {
            previous, unit in
            let unitBounds = CGRect(origin: previous.origin, size: unit.sizeWithAttributes(attributes))
            return previous.rectByUnion(unitBounds)
        }.size
        
        let frameSize = CGSize(width: unitSize.width, height: unitSize.height * CGFloat(drawingUnits.count))
        frame.size = frameSize
        setNeedsDisplay()
    }
    
    public override func drawInContext(ctx: CGContext) {
        UIGraphicsPushContext(ctx)
        let height = unitSize.height
        for (index, aString) in drawingUnits.enumerate() {
            let drawPoint = CGPointMake(0, height * CGFloat(index))
            let drawRect = CGRect(origin: drawPoint, size: unitSize)
            aString.drawInRect(drawRect, withAttributes:attributes)
            if debugEnabled {
                UIColor.redColor().setStroke()
                CGContextStrokeRectWithWidth(ctx, drawRect, 1)
            }
        }
        UIGraphicsPopContext()
    }
    
    // MARK: - SpinnerComponent Protocol
    
    public private(set) var unitSize = CGSize.zeroSize
    
    public func scrollToUnitAtIndex(index: Int) {
        let y = unitSize.height * -CGFloat(index) + bounds.height / 2
        position.y = y
    }
    
    func scrollToUnit(unit: String) {
        if let index = drawingUnits.indexOf(unit) {
            scrollToUnitAtIndex(index)
        }
    }
}

extension Dictionary {
    func merge(other: [Key: Value]?) -> [Key: Value] {
        var copy = self
        if let other = other {
            for (k, v) in other {
                copy.updateValue(v, forKey: k)
            }
        }
        return copy
    }
}