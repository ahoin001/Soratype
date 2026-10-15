import Testing
@testable import SoratypeEngine

struct LayoutTests {
    @Test func letterBoardStaggersLikeNintype() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let q = layout.keys.first { $0.id == "q" }
        let a = layout.keys.first { $0.id == "a" }
        let z = layout.keys.first { $0.id == "z" }
        let shift = layout.keys.first { $0.kind == .shift }
        let backspace = layout.keys.first { $0.kind == .backspace }
        let space = layout.keys.first { $0.kind == .space }
        let comma = layout.keys.first { $0.id == "comma" }
        let period = layout.keys.first { $0.id == "period" }
        let globe = layout.keys.first { $0.kind == .nextKeyboard }
        #expect(q != nil && a != nil && z != nil)
        #expect(a!.frame.minX > q!.frame.minX)
        #expect(shift!.frame.minX < z!.frame.minX)
        #expect(backspace!.frame.minX > layout.keys.first { $0.id == "m" }!.frame.maxX)
        #expect(space != nil)
        #expect(comma != nil && period != nil)
        #expect(globe != nil)
        #expect(layout.midline == 195)
    }

    @Test func hidingTheGlobeWidensSpace() {
        let withGlobe = KeyboardLayout.letters(fitting: Size(width: 390, height: 220), showsNextKeyboard: true)
        let without = KeyboardLayout.letters(fitting: Size(width: 390, height: 220), showsNextKeyboard: false)
        let wide = without.keys.first { $0.kind == .space }!.frame.size.width
        let narrow = withGlobe.keys.first { $0.kind == .space }!.frame.size.width
        #expect(without.keys.contains { $0.kind == .nextKeyboard } == false)
        #expect(wide > narrow)
    }

    @Test func punctuationPageReturnsToLetters() {
        let page = KeyboardLayout.punctuation(fitting: Size(width: 390, height: 220))
        #expect(page.page == .punctuation)
        #expect(page.keys.contains { $0.kind == .letters })
        #expect(page.keys.contains { $0.kind == .punctuation(",") })
        #expect(page.keys.contains { $0.kind == .return })
    }
}
