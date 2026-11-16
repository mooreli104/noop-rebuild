public func crc8(_ bytes:[UInt8]) -> UInt8{
    let divisor: UInt8 = 0x07
    var remainder: UInt8 = 0

    for byte in bytes{
        remainder ^= byte
        for _ in 0..<8{
            if remainder & 0x80 != 0{
                remainder = (remainder << 1) ^ 0x07
            }
            else{
                remainder <<= 1
            }
        }
    }
    return remainder
}