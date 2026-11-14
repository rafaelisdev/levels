import XCTest
@testable import LevelsCore

final class PlayoutTests: XCTestCase {
    private let speakers = OutputTiming(ioLatency: 0.012, bufferDuration: 0.0107, deviceLatency: 0.016)
    private let headphones = OutputTiming(ioLatency: 0.012, bufferDuration: 0.0107, deviceLatency: 0.180)   // Bluetooth

    func testDelayFollowsTheSlowestOutput() {
        let d = Playout.delay(outputs: [speakers, headphones], captureLatency: 0.011, margin: 0.005)
        XCTAssertEqual(d, 0.012 + 0.0107 + 0.180 + 0.011 + 0.005, accuracy: 1e-12)
    }

    func testEveryOutputPlaysTheSameSampleAtTheSameMoment() {
        let delay = Playout.delay(outputs: [speakers, headphones], captureLatency: 0.011, margin: 0.005)
        let captured = 100.0
        for output in [speakers, headphones] {
            // The frame this output hands to its hardware at `present` carries the sample
            // captured at `source`; it is heard `afterHardware` later.
            let present = captured + delay - output.afterHardware
            let source = Playout.sourceTime(presentTime: present, output: output, delay: delay)
            XCTAssertEqual(source, captured, accuracy: 1e-12)
            XCTAssertEqual(present + output.afterHardware, captured + delay, accuracy: 1e-12)
        }
    }

    func testEveryOutputFindsAWholeBufferAlreadyCaptured() {
        // At callback time `now`, even the last frame of the buffer an output asks for
        // must be at least `margin` older than the newest captured sample. (Forgetting
        // the buffer span made the built-in speakers drop a third of their frames.)
        let delay = Playout.delay(outputs: [speakers, headphones], captureLatency: 0.011, margin: 0.005)
        let now = 50.0
        let newestCaptured = now - 0.011
        for output in [speakers, headphones] {
            let lastFramePresent = now + output.ioLatency + output.bufferDuration
            let source = Playout.sourceTime(presentTime: lastFramePresent, output: output, delay: delay)
            XCTAssertGreaterThanOrEqual(newestCaptured - source, 0.005 - 1e-12)
        }
    }
}

final class EDIDTests: XCTestCase {
    /// The Philips TV on the development Mac (2014): HDMI block without latency fields.
    private let philips = """
    00ffffffffffff00410c00000101010104180103804024780af9aba2554a9a250f474a21080081800101010101010101010101010101023a801871382d40582c450080682100001e1b2150a051001e3048883500806821000018000000fc005048494c495053204654560a20000000fd00384c1e5311000a20202020202001cb020329714e9f10202122140513041102150601290907031507503d07c08301000067030c001000b82d023a80d072382d40102c458080682100001e011d803e73382d407e2c458080682100001e011d80d0721c1620102c258080682100009e011d00bc52d01e20b828554080682100001e000000000000000000000000000022
    """

    private func bytes(_ hex: String) -> [UInt8] {
        let clean = hex.filter(\.isHexDigit)
        return stride(from: 0, to: clean.count, by: 2).map {
            let i = clean.index(clean.startIndex, offsetBy: $0)
            return UInt8(clean[i...clean.index(after: i)], radix: 16)!
        }
    }

    func testReadsTheNameOfARealTV() {
        let info = EDID.parse(bytes(philips))
        XCTAssertEqual(info.productName, "PHILIPS FTV")
        XCTAssertNil(info.audioLatency, "this TV does not declare its latency")
    }

    func testReadsDeclaredHDMILatency() {
        var edid = [UInt8](repeating: 0, count: 256)
        edid[0..<8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]
        edid[126] = 1
        edid[54..<59] = [0, 0, 0, 0xFC, 0]
        edid[59..<72] = ArraySlice(Array("TEST TV\n     ".utf8))
        // CEA block: HDMI VSDB (tag 3, length 10) with video 21 -> 40 ms, audio 11 -> 20 ms.
        let vsdb: [UInt8] = [0x6A, 0x03, 0x0C, 0x00, 0x10, 0x00, 0x00, 0x00, 0x80, 21, 11]
        edid[128..<132] = [0x02, 0x03, UInt8(4 + vsdb.count), 0x00]
        edid[132..<(132 + vsdb.count)] = ArraySlice(vsdb)

        let info = EDID.parse(edid)
        XCTAssertEqual(info.productName, "TEST TV")
        XCTAssertEqual(try XCTUnwrap(info.videoLatency), 0.040, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(info.audioLatency), 0.020, accuracy: 1e-9)
    }

    func testIgnoresGarbage() {
        XCTAssertEqual(EDID.parse([1, 2, 3]), EDIDInfo())
        XCTAssertEqual(EDID.parse([UInt8](repeating: 0xFF, count: 256)), EDIDInfo())
    }
}
