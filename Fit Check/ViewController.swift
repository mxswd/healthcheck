//
//  ViewController.swift
//  Fit Check
//
//  Created by Maxwell on 27/11/21.
//

import UIKit
import HealthKit

class ViewController: UICollectionViewController {

    let allQuantityIdentifiers: [HKQuantityTypeIdentifier] = [
//        .appleMoveTime,
//        .appleStandTime,
//        .appleExerciseTime,
//        .appleWalkingSteadiness,
        
//        .activeEnergyBurned,
        
        .bodyMass,
        .bodyMassIndex,
        .bodyTemperature,
        .bodyFatPercentage,
        
//        .basalEnergyBurned,
//        .basalBodyTemperature,
        
//        .bloodGlucose,
//        .bloodAlcoholContent,
        
        .bloodPressureSystolic,
        .bloodPressureDiastolic,
        
        .electrodermalActivity,
        .environmentalAudioExposure,
        
//        .flightsClimbed,
//        .forcedVitalCapacity,
//        .forcedExpiratoryVolume1,
        
        .height,
        .heartRate,
        .headphoneAudioExposure,
        .heartRateVariabilitySDNN,
        
//        .inhalerUsage,
//        .insulinDelivery,
        
        .leanBodyMass,
        .numberOfAlcoholicBeverages,
        
        .oxygenSaturation,
        
//        .pushCount,
//        .peripheralPerfusionIndex,
//        .peakExpiratoryFlowRate,
        
        .respiratoryRate,
        .restingHeartRate,
        
//        .stepCount,
        .uvExposure,
        
        .vo2Max,
        .waistCircumference,
        .walkingAsymmetryPercentage,
        .walkingHeartRateAverage,
        .walkingDoubleSupportPercentage,
        
    ]
    
    
    let allCategoryIdentifiers: [HKCategoryTypeIdentifier] = [
        .abdominalCramps,
        .appetiteChanges,
        .appleStandHour,
        .appleWalkingSteadinessEvent,
        
        .bloating,
        .breastPain,
        .bladderIncontinence,
        
        .chills,
        .coughing,
        .constipation,
        .contraceptive,
        .cervicalMucusQuality,
        .chestTightnessOrPain,
        
        .diarrhea,
        .dizziness,
        .drySkin,
        
        .environmentalAudioExposureEvent,
    
        .fever,
        .fatigue,
        .fainting,
        
        .generalizedBodyAche,
    
        .headache,
        .heartburn,
        .hairLoss,
        .hotFlashes,
        
        .intermenstrualBleeding,
        .irregularHeartRhythmEvent,
        
        .lactation,
        .lossOfSmell,
        .lossOfTaste,
        .lowerBackPain,
        .lowHeartRateEvent,
        .lowCardioFitnessEvent,
        
        .memoryLapse,
        .moodChanges,
        
        .nausea,
        .nightSweats,
        
        .pelvicPain,
        .progesteroneTestResult,
        .runnyNose,
        .rapidPoundingOrFlutteringHeartbeat,
        
        .soreThroat,
        .sleepChanges,
        .sleepAnalysis,
        .sexualActivity,
        .sinusCongestion,
        .skippedHeartbeat,
        .shortnessOfBreath,
        
        .vomiting,
        .wheezing
    ]
    
    let allCorrelationIdentifiers: [HKCorrelationTypeIdentifier] = [
        .bloodPressure,
//        .food,
    ]
    
    var snapshot = NSDiffableDataSourceSnapshot<String, Observation>()
    var datasource : UICollectionViewDiffableDataSource<String, Observation>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = UICollectionLayoutListConfiguration(appearance: .grouped)
          // 2
      collectionView.collectionViewLayout =
            UICollectionViewCompositionalLayout.list(using: configuration)
        
        let cellreg = UICollectionView.CellRegistration<UICollectionViewCell, Observation>() { cell, indexPath, name in
            var config = UIListContentConfiguration.valueCell()
            config.text = name.name
            config.secondaryText = name.value
            if name.status == .high {
                config.image = UIImage(systemName: "exclamationmark.triangle.fill")
            } else if name.status == .low {
                config.image = UIImage(systemName: "exclamationmark.triangle.fill")
            } else {
                config.image = nil
            }
            cell.backgroundColor = UIColor.secondarySystemGroupedBackground
            cell.contentConfiguration = config
        }
        self.datasource = UICollectionViewDiffableDataSource<String,Observation>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellreg, for: indexPath, item: item)
        }
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh(self)
    }
    
    @IBAction
    func refresh(_ sender: Any) {
        snapshot = NSDiffableDataSourceSnapshot<String, Observation>()
        
        var readList: Set<HKObjectType> = Set([
            HKElectrocardiogramType.electrocardiogramType()
        ])
        for allCategoryIdentifier in allCategoryIdentifiers {
            readList.insert(HKCategoryType(allCategoryIdentifier))
        }
        for allQuantityIdentifier in allQuantityIdentifiers {
            readList.insert(HKQuantityType(allQuantityIdentifier))
        }
        
        let store = HKHealthStore()
        store.requestAuthorization(toShare: nil, read: readList) { ok, error in
            let queries = [RestingHeartRateHigh(store),
                        RestingHeartRateLow(store),
                VO2MaxSampler(store),
                           HeartRateVariability(store),
            BMI(store),
                           SleepBreathing(store),
                           BloodOxygen(store),
            BPSystolic(store),
            BPDiastolic(store),
            ECG(store),
                           IrregHeart(store)]
            self.snapshot.appendSections(["Observations"])
            queries.forEach { $0.query { observation in
                DispatchQueue.main.async {
                    self.snapshot.appendItems([observation], toSection: nil)
                    self.datasource.apply(self.snapshot)
                }
            } }
        }
    }

}

