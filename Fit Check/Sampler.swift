//
//  Sampler.swift
//  Fit Check
//
//  Created by Maxwell on 27/11/21.
//

import HealthKit

class Sampler {
    fileprivate let store: HKHealthStore
    fileprivate var name: String {
        fatalError()
    }
    
    fileprivate var identifier: HKQuantityTypeIdentifier {
        fatalError()
    }
    
    init(_ store: HKHealthStore) {
        self.store = store
    }
    
    var helpURL: URL {
        fatalError()
    }
    
    func query(_ work: @escaping (Observation) -> Void) {
        let query = HKSampleQuery(queryDescriptors: [HKQueryDescriptor(sampleType: HKQuantityType(identifier), predicate: nil)], limit: 10, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { query, samples, error in
            if let s = samples, let r = self.process(s) {
                work(r)
            } else {
                work(Observation.none(self.name))
            }
        }
        store.execute(query)
    }
    
    fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            return Observation(date: sample.startDate, name: sample.sampleType.description, value: sample.description, status: nil)
        }
        return nil
    }
}

enum Status {
    case ok
    case low
    case high
}

struct Observation: Hashable {
    let date: Date?
    let name: String
    let value: String?
    let status: Status?
    
    static func none(_ name: String) -> Observation {
        return Observation(date: nil, name: name, value: nil, status: nil)
    }
}

class RestingHeartRateHigh: Sampler {
    override fileprivate var name: String {
        return "Top Resting Heart Rate"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.restingHeartRate
    }
    
    override var helpURL: URL {
        return URL(string: "https://www.mayoclinic.org/healthy-lifestyle/fitness/expert-answers/heart-rate/faq-20057979")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        // FIXME: look at the latest 10 samples and pick the worst one.
        var highestSample: HKQuantitySample?
        var highestBPM: Double?
        for sample in samples {
            if let s = sample as? HKQuantitySample {
                let bpm = s.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                if let w = highestBPM {
                    if w < bpm {
                        highestBPM = bpm
                        highestSample = s
                    }
                } else {
                    highestBPM = bpm
                    highestSample = s
                }
            }
        }
        if let worst = highestSample {
            let status = highestBPM! > 100 ? Status.high : Status.ok
            return Observation(date: worst.startDate, name: self.name, value: "\(highestBPM!)", status: status)
        } else {
            return nil
        }
    }
}

class RestingHeartRateLow: Sampler {
    override fileprivate var name: String {
        return "Bottom Resting Heart Rate"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.restingHeartRate
    }
    
    override var helpURL: URL {
        return URL(string: "https://www.mayoclinic.org/healthy-lifestyle/fitness/expert-answers/heart-rate/faq-20057979")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        // FIXME: look at the latest 10 samples and pick the worst one.
        var highestSample: HKQuantitySample?
        var highestBPM: Double?
        for sample in samples {
            if let s = sample as? HKQuantitySample {
                let bpm = s.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                if let w = highestBPM {
                    if w > bpm {
                        highestBPM = bpm
                        highestSample = s
                    }
                } else {
                    highestBPM = bpm
                    highestSample = s
                }
            }
        }
        if let worst = highestSample {
            let status = highestBPM! < 100 ? Status.low : Status.ok
            return Observation(date: worst.startDate, name: self.name, value: "\(highestBPM!)", status: status)
        } else {
            return nil
        }
    }
}

class VO2MaxSampler: Sampler {
    override fileprivate var name: String {
        return "Cardio Fitness"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.vo2Max
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            // just look at the latest measurement.
            if let s = sample as? HKDiscreteQuantitySample {
                let value = s.mostRecentQuantity.doubleValue(for: .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute()))
                return Observation(date: s.startDate, name: self.name, value: "\(value) VO2 max", status: value < 38 ? .low : .ok)
            }
        }
        return nil
    }
}

class HeartRateVariability: Sampler {
    override fileprivate var name: String {
        return "Heart Rate Variability"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.heartRateVariabilitySDNN
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            // just look at the latest measurement.
            if let s = sample as? HKDiscreteQuantitySample {
                let value = s.mostRecentQuantity.doubleValue(for: .secondUnit(with: .milli))
                return Observation(date: s.startDate, name: self.name, value: "\(value.rounded()) ms", status: value < 48 ? .low : .ok)
            }
        }
        return nil
    }
}

class BMI: Sampler {
    override fileprivate var name: String {
        return "BMI"
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    static func bmiToStatus(_ double: Double) -> Status {
        if double < 18.5 {
            return .low
        } else if double > 29.9 {
            return .high
        }
        return .ok
    }
    
    override func query(_ work: @escaping (Observation) -> Void) {
        var mass: Double?
        var height: Double?
        var failed: Bool = false
        let queryMass = HKSampleQuery(queryDescriptors: [HKQueryDescriptor(sampleType: HKQuantityType(.bodyMass), predicate: nil)], limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { query, samples, error in
            DispatchQueue.main.async {
                if let s = samples?.first, let m = s as? HKQuantitySample {
                    mass = m.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    if let height = height {
                        let bmi = mass! / height
                        work(Observation(date: s.startDate, name: self.name, value: "\(bmi.rounded())", status: Self.bmiToStatus(bmi)))
                    }
                } else {
                    if failed || height != nil {
                        work(Observation.none(self.name))
                    } else {
                        failed = true
                    }
                }
            }
        }
        let queryHeight = HKSampleQuery(queryDescriptors: [HKQueryDescriptor(sampleType: HKQuantityType(.height), predicate: nil)], limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { query, samples, error in
            DispatchQueue.main.async {
                if let s = samples?.first, let m = s as? HKQuantitySample {
                    height = pow(m.quantity.doubleValue(for: .meter()), 2)
                    if let mass = mass {
                        let bmi = mass / height!
                        work(Observation(date: s.startDate, name: self.name, value: "\(bmi.rounded())", status: Self.bmiToStatus(bmi)))
                    }
                } else {
                    if failed || mass != nil {
                        work(Observation.none(self.name))
                    } else {
                        failed = true
                    }
                }
            }
        }
        store.execute(queryMass)
        store.execute(queryHeight)
    }
    
}

class SleepBreathing: Sampler {
    override fileprivate var name: String {
        return "Sleep Respiratory Rate"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.respiratoryRate
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            // just look at the latest measurement.
            if let s = sample as? HKDiscreteQuantitySample {
                let value = s.mostRecentQuantity.doubleValue(for: .count().unitDivided(by: .minute()))
                var status = Status.ok
                if value <= 12 {
                    status = .low
                } else if value >= 18 {
                    status = .high
                }
                return Observation(date: s.startDate, name: self.name, value: "\(value.rounded()) breaths/min", status: status)
            }
        }
        return nil
    }
}

class BloodOxygen: Sampler {
    override fileprivate var name: String {
        return "Blood Oxygen"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.oxygenSaturation
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            // just look at the latest measurement.
            if let s = sample as? HKDiscreteQuantitySample {
                let value = s.mostRecentQuantity.doubleValue(for: .percent())
                var status = Status.ok
                if value < 0.95 {
                    status = .low
                }
                return Observation(date: s.startDate, name: self.name, value: "\(value)%", status: status)
            }
        }
        return nil
    }
}

class BPSystolic: Sampler {
    override fileprivate var name: String {
        return "Blood Pressure Systolic"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.bloodPressureSystolic
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            // just look at the latest measurement.
            if let s = sample as? HKDiscreteQuantitySample {
                let value = s.mostRecentQuantity.doubleValue(for: .millimeterOfMercury())
                var status = Status.ok
                if value >= 140 {
                    status = .high
                } else if value <= 90 {
                    status = .low
                }
                return Observation(date: s.startDate, name: self.name, value: "\(value)", status: status)
            }
        }
        return nil
    }
}

class BPDiastolic: Sampler {
    override fileprivate var name: String {
        return "Blood Pressure Diastolic"
    }
    
    override fileprivate var identifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.bloodPressureDiastolic
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override fileprivate func process(_ samples: [HKSample]) -> Observation? {
        for sample in samples {
            // just look at the latest measurement.
            if let s = sample as? HKDiscreteQuantitySample {
                let value = s.mostRecentQuantity.doubleValue(for: .millimeterOfMercury())
                var status = Status.ok
                if value >= 90 {
                    status = .high
                } else if value <= 60 {
                    status = .low
                }
                return Observation(date: s.startDate, name: self.name, value: "\(value)", status: status)
            }
        }
        return nil
    }
}

class ECG: Sampler {
    override fileprivate var name: String {
        return "ECG"
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override func query(_ work: @escaping (Observation) -> Void) {
        // Create the electrocardiogram sample type.
        let ecgType = HKObjectType.electrocardiogramType()

        // Query for electrocardiogram samples
        let ecgQuery = HKSampleQuery(sampleType: ecgType,
                                     predicate: nil,
                                     limit: HKObjectQueryNoLimit,
                                     sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { (query, samples, error) in
            if let error = error {
                // Handle the error here.
                fatalError("*** An error occurred \(error.localizedDescription) ***")
            }
            
            guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                fatalError("*** Unable to convert \(String(describing: samples)) to [HKElectrocardiogram] ***")
            }
            
            for sample in ecgSamples {
                if sample.classification == .atrialFibrillation {
                    work(Observation(date: sample.startDate, name: self.name, value: "AF detected", status: Status.high))
                }
            }
            work(Observation(date: Date(), name: self.name, value: "No AF detected", status: Status.ok))
        }

        store.execute(ecgQuery)
    }
}

class IrregHeart: Sampler {
    override fileprivate var name: String {
        return "Irregular Heart Rhythm"
    }
    
    override var helpURL: URL {
        return URL(string: "https://google.com")!
    }
    
    override func query(_ work: @escaping (Observation) -> Void) {
        let query = HKSampleQuery(sampleType: HKCategoryType(HKCategoryTypeIdentifier.irregularHeartRhythmEvent),
                                     predicate: nil,
                                     limit: HKObjectQueryNoLimit,
                                     sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { (query, samples, error) in
            if let error = error {
                // Handle the error here.
                fatalError("*** An error occurred \(error.localizedDescription) ***")
            }
            
            guard let samples = samples as? [HKCategorySample] else {
                fatalError()
            }
            
            for sample in samples {
                work(Observation(date: sample.startDate, name: self.name, value: "Detected", status: Status.high))
            }
            work(Observation(date: Date(), name: self.name, value: "None detected", status: Status.ok))
        }

        store.execute(query)
    }
}
