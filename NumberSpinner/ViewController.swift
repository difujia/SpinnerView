//
//  ViewController.swift
//  NumberSpinner
//
//  Created by di, frank (CHE-LPR) on 8/12/15.
//  Copyright © 2015 Fujia. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        spinner.debugEnabled = true
        spinner.formatter.maximumFractionDigits = 2
        spinner.formatter.numberStyle = .CurrencyStyle
        let large = [NSFontAttributeName: UIFont.systemFontOfSize(20)]
        let small = [NSFontAttributeName: UIFont.systemFontOfSize(14)]
        spinner.integerTextAttributes = large
        spinner.separatorTextAttributes = large
        spinner.fractionTextAttributes = small
        spinner.updateFormat()
    }


    @IBOutlet weak var spinner: NumberSpinnerView!

    
    @IBAction func random() {
//        spinner.formatter.minimumIntegerDigits = Int(arc4random_uniform(10))
//        spinner.formatter.minimumFractionDigits = Int(arc4random_uniform(10))
//        spinner.updateFormat()
        spinner.value = Double(arc4random_uniform(10000000)) / Double(arc4random_uniform(10000))
    }
}

