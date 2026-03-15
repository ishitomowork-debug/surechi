//
//  RealMatchingUITests.swift
//  RealMatchingUITests
//

import XCTest

final class RealMatchingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Group A: Auth Screen (no backend required)

    /// 認証画面にメール・パスワードフィールドとログインボタンが表示される
    @MainActor
    func testAuthScreenShowsFields() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--resetAuth"]
        app.launch()

        XCTAssertTrue(app.textFields["メール"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["パスワード"].exists)
        XCTAssertTrue(app.buttons.matching(identifier: "submitButton").firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(identifier: "toggleModeButton").firstMatch.exists)
    }

    /// 登録モードへ切替するとSubmitボタンのラベルが「登録」に変わる
    @MainActor
    func testSwitchToRegisterMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--resetAuth"]
        app.launch()

        let submitButton = app.buttons.matching(identifier: "submitButton").firstMatch
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3))
        XCTAssertTrue(submitButton.label.contains("ログイン"))

        app.buttons.matching(identifier: "toggleModeButton").firstMatch.tap()

        XCTAssertTrue(submitButton.label.contains("登録"))
    }

    /// 登録モードに生年月日ピッカーが表示される（年齢Stepperではなく）
    @MainActor
    func testRegisterModeShowsBirthDatePicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--resetAuth"]
        app.launch()

        // 登録モードに切替
        XCTAssertTrue(app.buttons.matching(identifier: "toggleModeButton").firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "toggleModeButton").firstMatch.tap()

        // 「生年月日」ラベルが表示される
        XCTAssertTrue(app.staticTexts["生年月日"].waitForExistence(timeout: 3))
        // 年齢Stepperは存在しない
        let ageStepper = NSPredicate(format: "label CONTAINS %@", "年齢")
        XCTAssertFalse(app.steppers.matching(ageStepper).firstMatch.exists)
    }

    // MARK: - Group B: MainTabView (--skipAuth)

    /// MainTabView の4タブが全て表示される
    @MainActor
    func testFourTabsExist() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skipAuth"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["ライク"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["いいねした"].exists)
        XCTAssertTrue(app.tabBars.buttons["マッチング"].exists)
        XCTAssertTrue(app.tabBars.buttons["プロフィール"].exists)
    }

    /// タブを切り替えるとそれぞれのタブが選択状態になる
    @MainActor
    func testTabSwitching() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skipAuth"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["ライク"].waitForExistence(timeout: 5))

        app.tabBars.buttons["マッチング"].tap()
        XCTAssertTrue(app.tabBars.buttons["マッチング"].isSelected)

        app.tabBars.buttons["プロフィール"].tap()
        XCTAssertTrue(app.tabBars.buttons["プロフィール"].isSelected)

        app.tabBars.buttons["ライク"].tap()
        XCTAssertTrue(app.tabBars.buttons["ライク"].isSelected)
    }

    /// いいねしたタブに遷移するとナビゲーションタイトルが表示される
    @MainActor
    func testLikedMeTabNavigates() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skipAuth"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["いいねした"].waitForExistence(timeout: 5))
        app.tabBars.buttons["いいねした"].tap()

        // ナビゲーションタイトル「いいねした」が表示される
        XCTAssertTrue(app.navigationBars["いいねした"].waitForExistence(timeout: 3))
    }

    /// プロフィールタブにプロフィール画面が表示される
    @MainActor
    func testProfileTabShowsContent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skipAuth"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["ライク"].waitForExistence(timeout: 5))
        app.tabBars.buttons["プロフィール"].tap()

        let pred = NSPredicate(format: "label CONTAINS %@", "テストユーザー")
        XCTAssertTrue(app.staticTexts.matching(pred).firstMatch.waitForExistence(timeout: 3))
    }

    /// プロフィール編集画面に趣味セクションが表示される
    @MainActor
    func testProfileEditShowsInterestsSection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skipAuth"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["プロフィール"].waitForExistence(timeout: 5))
        app.tabBars.buttons["プロフィール"].tap()

        let editButton = app.buttons["プロフィール編集"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        // 趣味・興味セクションが表示される
        XCTAssertTrue(app.staticTexts["趣味・興味"].waitForExistence(timeout: 3))
        // 自己紹介セクションも表示される
        XCTAssertTrue(app.staticTexts["自己紹介"].exists)
    }
}
