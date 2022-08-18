import XCTest
import Logging
@testable import SwiftLogConsoleColors

final class SwiftLogConsoleColorsTests: XCTestCase {
    
    // 2022-12-15 14:13:12+0100
    let fifthOfDec2022 = tm(
        tm_sec: 12,
        tm_min: 13,
        tm_hour: 14,
        tm_mday: 15,
        tm_mon: 12-1,
        tm_year: 2022-1900,
        tm_wday: 4, // thursday
        tm_yday: 349, // days since first day of the year, not sure this is correct, 365-(31-16)...
        tm_isdst: 0,
        tm_gmtoff: 0,
        tm_zone: nil
    )
    
    func testAssertLogLevelHiearchy() {
        XCTAssertGreaterThan(
            Logger.Level.critical,
            Logger.Level.error,
            "`critical` should be more serious than `error`"
        )
    }
    
    func testTimeFormatDefault() {
        let loggerDefaultTime = ColorStreamLogHandler.standardOutput(
            label: "label",
            logIconType: .rainbow
        )
        let loggerCustomTimeButUseDefault = ColorStreamLogHandler.standardOutput(
            label: "label",
            logIconType: .rainbow,
            timeformat: ColorStreamLogHandler.timeformatDefault
        )
   
        var timestamp = fifthOfDec2022
        let entryDefault = loggerDefaultTime.logEntry(message: "Foo", hardcodedTime: &timestamp)
        XCTAssertEqual(entryDefault, "2022-12-15T14:13:12+0100 🟦 info label : Foo")
        let entryCustom = loggerCustomTimeButUseDefault.logEntry(message: "Foo", hardcodedTime: &timestamp)
        XCTAssertEqual(entryDefault, entryCustom)
    }
    
    func testTimeFormatCustom() {
        let loggerDefaultTime = ColorStreamLogHandler.standardOutput(
            label: "label",
            logIconType: .rainbow
        )
        let loggerCustomTime = ColorStreamLogHandler.standardOutput(
            label: "label",
            logIconType: .rainbow,
            timeformat: "%H:%M:%S"
        )
        
        var timestamp = fifthOfDec2022
        let entryDefault = loggerDefaultTime.logEntry(message: "Foo", hardcodedTime: &timestamp)
        let entryCustom = loggerCustomTime.logEntry(message: "Foo", hardcodedTime: &timestamp)
        XCTAssertNotEqual(entryDefault, entryCustom)
        XCTAssertEqual(entryCustom, "14:13:12 🟦 info label : Foo")
    }
    
    func testExample() {
        //            LoggingSystem.bootstrap(ColorStreamLogHandler.standardOutput(label: "Label", logIconType: .cool))
        
        
        //            LoggingSystem.bootstrap(ColorStreamLogHandler.standardOutput(label: "testLabel"))
        //
        //
        //            // Create a logger (or re-use one you already have)
        //            let logger = Logger(label: "MyApp")
        //
        //            // Log!
        //            logger.trace("Testing log levels..")
        //            logger.debug("Testing log levels..", metadata: ["user-id": "testmeta"])
        //            logger.info("Testing log levels..")
        //            logger.notice("Testing log levels..")
        //            logger.warning("Testing log levels..")
        //            logger.error("Testing log levels..")
        //            logger.critical("Testing log levels..", metadata: ["user-id": "testmeta"])
    }
}
