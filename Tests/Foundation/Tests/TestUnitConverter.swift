// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestUnitConverter: XCTestCase {
    
    static var allTests: [(String, (TestUnitConverter) -> () throws -> Void)] {
        return [
            ("test_baseUnit", test_linearity),
            ("test_linearity", test_linearity),
            ("test_bijectivity", test_bijectivity),
            ("test_equality", test_equality),
        ]
    }
    
    func test_baseUnit() {
        XCTAssertEqual(UnitAcceleration.baseUnit().symbol,
                       UnitAcceleration.metersPerSecondSquared.symbol)
        XCTAssertEqual(UnitAngle.baseUnit().symbol,
                       UnitAngle.degrees.symbol)
        XCTAssertEqual(UnitArea.baseUnit().symbol,
                       UnitArea.squareMeters.symbol)
        XCTAssertEqual(UnitConcentrationMass.baseUnit().symbol,
                       UnitConcentrationMass.gramsPerLiter.symbol)
        XCTAssertEqual(UnitDispersion.baseUnit().symbol,
                       UnitDispersion.partsPerMillion.symbol)
        XCTAssertEqual(UnitDuration.baseUnit().symbol,
                       UnitDuration.seconds.symbol)
        XCTAssertEqual(UnitElectricCharge.baseUnit().symbol,
                       UnitElectricCharge.coulombs.symbol)
        XCTAssertEqual(UnitElectricCurrent.baseUnit().symbol,
                       UnitElectricCurrent.amperes.symbol)
        XCTAssertEqual(UnitElectricPotentialDifference.baseUnit().symbol,
                       UnitElectricPotentialDifference.volts.symbol)
        XCTAssertEqual(UnitElectricResistance.baseUnit().symbol,
                       UnitElectricResistance.ohms.symbol)
        XCTAssertEqual(UnitEnergy.baseUnit().symbol,
                       UnitEnergy.joules.symbol)
        XCTAssertEqual(UnitFrequency.baseUnit().symbol,
                       UnitFrequency.hertz.symbol)
        XCTAssertEqual(UnitFuelEfficiency.baseUnit().symbol,
                       UnitFuelEfficiency.litersPer100Kilometers.symbol)
        XCTAssertEqual(UnitLength.baseUnit().symbol,
                       UnitLength.meters.symbol)
        XCTAssertEqual(UnitIlluminance.baseUnit().symbol,
                       UnitIlluminance.lux.symbol)
        XCTAssertEqual(UnitMass.baseUnit().symbol,
                       UnitMass.kilograms.symbol)
        XCTAssertEqual(UnitPower.baseUnit().symbol,
                       UnitPower.watts.symbol)
        XCTAssertEqual(UnitPressure.baseUnit().symbol,
                       UnitPressure.newtonsPerMetersSquared.symbol)
        XCTAssertEqual(UnitSpeed.baseUnit().symbol,
                       UnitSpeed.metersPerSecond.symbol)
        XCTAssertEqual(UnitTemperature.baseUnit().symbol,
                       UnitTemperature.kelvin.symbol)
        XCTAssertEqual(UnitVolume.baseUnit().symbol,
                       UnitVolume.liters.symbol)
    }
    
    func test_linearity() {
        let coefficient = 7.0
        let baseUnitConverter = UnitConverterLinear(coefficient: coefficient)
        XCTAssertEqual(baseUnitConverter.value(fromBaseUnitValue: coefficient), 1.0)
        XCTAssertEqual(baseUnitConverter.baseUnitValue(fromValue: 1), coefficient)
    }
    
    func test_bijectivity() {
        let delta = 1e-9
        let testIdentity: (Dimension) -> Double = { dimension in
            let converter = dimension.converter
            return converter.value(fromBaseUnitValue: converter.baseUnitValue(fromValue: 1))
        }
        
        XCTAssertEqual(testIdentity(UnitAcceleration.metersPerSecondSquared), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitAcceleration.gravity), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitAngle.degrees), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitAngle.arcMinutes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitAngle.arcSeconds), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitAngle.radians), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitAngle.gradians), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitAngle.revolutions), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitArea.squareMegameters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareKilometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareMeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareCentimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareMillimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareMicrometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareNanometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareInches), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareFeet), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareYards), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.squareMiles), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.acres), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.ares), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitArea.hectares), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitConcentrationMass.gramsPerLiter), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitConcentrationMass.milligramsPerDeciliter), 1, accuracy: delta)
        XCTAssertEqual(
            testIdentity(UnitConcentrationMass.millimolesPerLiter(withGramsPerMole: 1)), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitDispersion.partsPerMillion), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitDuration.seconds), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitDuration.minutes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitDuration.hours), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitElectricCharge.coulombs), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCharge.megaampereHours), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCharge.kiloampereHours), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCharge.ampereHours), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCharge.milliampereHours), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCharge.microampereHours), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitElectricCurrent.megaamperes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCurrent.kiloamperes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCurrent.amperes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCurrent.milliamperes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricCurrent.microamperes), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitElectricPotentialDifference.megavolts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricPotentialDifference.kilovolts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricPotentialDifference.volts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricPotentialDifference.millivolts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricPotentialDifference.microvolts), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitElectricResistance.megaohms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricResistance.kiloohms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricResistance.ohms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricResistance.milliohms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitElectricResistance.microohms), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitEnergy.kilojoules), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitEnergy.joules), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitEnergy.kilocalories), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitEnergy.calories), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitEnergy.kilowattHours), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitFrequency.terahertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.gigahertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.megahertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.kilohertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.hertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.millihertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.microhertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.nanohertz), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFrequency.framesPerSecond), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitFuelEfficiency.litersPer100Kilometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFuelEfficiency.milesPerImperialGallon), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitFuelEfficiency.milesPerGallon), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitInformationStorage.bytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.bits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.nibbles), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.yottabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.zettabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.exabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.petabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.terabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.gigabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.megabytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.kilobytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.yottabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.zettabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.exabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.petabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.terabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.gigabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.megabits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.kilobits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.yobibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.zebibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.exbibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.pebibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.tebibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.gibibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.mebibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.kibibytes), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.yobibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.zebibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.exbibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.pebibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.tebibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.gibibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.mebibits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitInformationStorage.kibibits), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitLength.megameters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.kilometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.hectometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.decameters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.meters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.decimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.centimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.millimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.micrometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.nanometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.picometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.inches), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.feet), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.yards), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.miles), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.scandinavianMiles), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.nauticalMiles), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.fathoms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.furlongs), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.astronomicalUnits), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitLength.parsecs), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitIlluminance.lux), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitMass.kilograms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.grams), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.decigrams), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.milligrams), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.nanograms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.picograms), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.ounces), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.pounds), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.stones), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.metricTons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.carats), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.ouncesTroy), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitMass.slugs), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitPower.terawatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.gigawatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.megawatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.kilowatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.watts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.milliwatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.microwatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.nanowatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.picowatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.femtowatts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPower.horsepower), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitPressure.newtonsPerMetersSquared), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.gigapascals), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.megapascals), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.kilopascals), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.hectopascals), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.inchesOfMercury), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.bars), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.millibars), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.millimetersOfMercury), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitPressure.poundsForcePerSquareInch), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitSpeed.metersPerSecond), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitSpeed.kilometersPerHour), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitSpeed.milesPerHour), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitSpeed.knots), 1, accuracy: delta)
        
        XCTAssertEqual(testIdentity(UnitTemperature.kelvin), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitTemperature.celsius), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitTemperature.fahrenheit), 1, accuracy: delta)

        XCTAssertEqual(testIdentity(UnitVolume.megaliters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.kiloliters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.liters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.deciliters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.milliliters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicKilometers), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicMeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicDecimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicCentimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicMillimeters), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicInches), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicFeet), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicYards), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cubicMiles), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.acreFeet), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.bushels), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.teaspoons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.tablespoons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.fluidOunces), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.cups), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.pints), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.quarts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.gallons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.imperialTeaspoons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.imperialTablespoons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.imperialFluidOunces), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.imperialPints), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.imperialQuarts), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.imperialGallons), 1, accuracy: delta)
        XCTAssertEqual(testIdentity(UnitVolume.metricCups), 1, accuracy: delta)
    }

    func test_equality() {
        let u1 = UnitConverterLinear(coefficient: 1, constant: 2)
        let u2 = UnitConverterLinear(coefficient: 1, constant: 2)
        XCTAssertEqual(u1, u2)
        XCTAssertEqual(u2, u1)

        let u3 = UnitConverterLinear(coefficient: 1, constant: 3)
        XCTAssertNotEqual(u1, u3)
        XCTAssertNotEqual(u3, u1)

        let u4 = UnitConverterLinear(coefficient: 2, constant: 2)
        XCTAssertNotEqual(u1, u4)
        XCTAssertNotEqual(u4, u1)

        // Cannot test NSUnitConverterReciprocal due to no support for @testable import.
    }
    
}
