//
//  StatisticsRespondsWithSkeletonUITests.swift
//  YalaUITests
//
//  G1 de la decisión 28 (revisión 2.3, Estadísticas con diez años): al tocar «Estadísticas» la pestaña cambia en el
//  acto, con la barra de chips y un esqueleto donde irán las cifras, y las cifras llegan después. Medido en el iPhone 14
//  con diez años: el `onAppear` calculaba 7,5 s seguidos y el Panel se quedaba congelado sin señal.
//
//  `-uitest-stats-calculation-delay-seconds` alarga la espera antes de la pasada: con los datos de un test la pasada
//  dura décimas y el esqueleto no llegaría a verse. Solo cambia CUÁNTO se espera, no qué se calcula.
//
//  Discrimina: con el cálculo en el `onAppear` no hay esqueleto, y la pestaña sale ya con las cifras o no sale.
//

import XCTest

final class StatisticsRespondsWithSkeletonUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_tappingStatistics_showsChipsAndSkeletonAtOnce_thenTheFigures() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: ["-uitest-stats-calculation-delay-seconds", "4"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.selectTab(.statistics)

        // En el acto: los chips y el esqueleto, antes de que la pasada (retrasada 4 s) traiga ninguna cifra.
        let skeleton = app.descendants(matching: .any)["stats_loading_skeleton"]
        XCTAssertTrue(skeleton.waitForExistence(timeout: 2), "La pestaña no enseñó el esqueleto al tocarla.")
        XCTAssertTrue(app.buttons["detail_chip_insights"].exists, "Con el esqueleto, la barra de chips tiene que verse.")

        // Después: el esqueleto se va y llega el hero con su cifra.
        let caption = app.staticTexts["stats_hero_caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 20), "Las cifras no llegaron tras el esqueleto.")
        let gone = NSPredicate(format: "exists == false")
        let wait = XCTNSPredicateExpectation(predicate: gone, object: skeleton)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 10), .completed, "El esqueleto se quedó encima de las cifras.")
    }

    func test_returningToStatisticsWithoutChanges_showsTheFiguresWithoutSkeleton() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: ["-uitest-stats-calculation-delay-seconds", "2"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.selectTab(.statistics)
        XCTAssertTrue(app.staticTexts["stats_hero_caption"].waitForExistence(timeout: 20), "No llegaron las cifras.")

        app.selectTab(.panel)
        app.selectTab(.statistics)
        // Ya calculada y sin cambios: ni esqueleto ni espera.
        XCTAssertTrue(app.staticTexts["stats_hero_caption"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["stats_loading_skeleton"].exists,
                       "Volver sin cambios volvió a enseñar el esqueleto.")
    }
}
