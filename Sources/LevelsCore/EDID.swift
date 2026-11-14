/// What a display tells the Mac about itself over HDMI/DisplayPort that matters for sync.
public struct EDIDInfo: Equatable {
    public var productName: String?
    /// Audio latency the display declares (seconds), from the HDMI vendor block.
    public var audioLatency: Double?
    public var videoLatency: Double?

    public init(productName: String? = nil, audioLatency: Double? = nil, videoLatency: Double? = nil) {
        self.productName = productName
        self.audioLatency = audioLatency
        self.videoLatency = videoLatency
    }
}

/// Minimal EDID reader: the product name and the HDMI 1.4 latency fields
/// (CEA-861 HDMI Vendor-Specific Data Block, IEEE OUI 00-0C-03).
public enum EDID {
    private static let header: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]
    private static let hdmiOUI: [UInt8] = [0x03, 0x0C, 0x00]   // little-endian 00-0C-03

    public static func parse(_ bytes: [UInt8]) -> EDIDInfo {
        guard bytes.count >= 128, Array(bytes[0..<8]) == header else { return EDIDInfo() }
        var info = EDIDInfo(productName: productName(bytes))

        let extensionBlocks = stride(from: 128, through: bytes.count - 128, by: 128)
            .prefix(Int(bytes[126]))
            .map { Array(bytes[$0..<$0 + 128]) }
        for block in extensionBlocks where block[0] == 0x02 {     // CEA-861 extension
            if let latency = hdmiLatency(block) {
                info.videoLatency = latency.video
                info.audioLatency = latency.audio
            }
        }
        return info
    }

    /// Display name from the 0xFC monitor descriptor.
    private static func productName(_ bytes: [UInt8]) -> String? {
        for offset in stride(from: 54, to: 126, by: 18)
        where bytes[offset] == 0 && bytes[offset + 1] == 0 && bytes[offset + 3] == 0xFC {
            let text = bytes[(offset + 5)..<(offset + 18)].prefix { $0 != 0x0A }   // 0x0A ends the name
            let name = String(decoding: text, as: UTF8.self)
            let trimmed = name.drop { $0 == " " }.reversed().drop { $0 == " " }.reversed()
            return trimmed.isEmpty ? nil : String(trimmed)
        }
        return nil
    }

    private static func hdmiLatency(_ block: [UInt8]) -> (video: Double?, audio: Double?)? {
        let dataEnd = min(Int(block[2]), 127)
        var i = 4
        while i < dataEnd {
            let tag = block[i] >> 5
            let length = Int(block[i] & 0x1F)
            let data = block[(i + 1)..<min(i + 1 + length, 128)]
            if tag == 3, data.count >= 3, Array(data.prefix(3)) == hdmiOUI {
                // data[7] bit 7: latency fields present; data[8] video, data[9] audio.
                guard data.count >= 10 else { return nil }
                let d = Array(data)
                guard d[7] & 0x80 != 0 else { return nil }
                return (video: milliseconds(d[8]), audio: milliseconds(d[9]))
            }
            i += 1 + length
        }
        return nil
    }

    /// 0 = not provided, 255 = no audio/video on this sink, otherwise (value - 1) * 2 ms.
    private static func milliseconds(_ value: UInt8) -> Double? {
        guard value != 0, value != 255 else { return nil }
        return Double(Int(value) - 1) * 2 / 1000
    }
}
