import Foundation

enum ContractValidationError: Error, CustomStringConvertible {
    case invalidValue(String)

    var description: String {
        switch self {
        case .invalidValue(let message):
            return message
        }
    }
}

enum RulesProfile: String, Codable, CaseIterable {
    case mcr
    case riichiMLeague = "riichi_mleague"

    var visualDomain: TileVisualDomain {
        switch self {
        case .mcr:
            return .mcr
        case .riichiMLeague:
            return .riichiMLeague
        }
    }

    var visualSemanticClassCount: Int {
        visualClasses.count
    }

    var visualClasses: [TileCode] {
        switch self {
        case .mcr:
            return TileCode.mcrVisualClasses
        case .riichiMLeague:
            return TileCode.riichiMLeagueVisualClasses
        }
    }
}

enum PlayerSeat: String, Codable, CaseIterable, Hashable {
    case east
    case south
    case west
    case north
}

enum TableZone: String, Codable, CaseIterable {
    case playerHandEast
    case playerHandSouth
    case playerHandWest
    case playerHandNorth
    case discardArea
    case meldArea
    case fullTable
}

enum TileVisualDomain: String, Codable, CaseIterable {
    case mcr
    case riichiMLeague = "riichi_mleague"
}

enum TileCode: String, Codable, CaseIterable, Hashable {
    case man1 = "man_1"
    case man2 = "man_2"
    case man3 = "man_3"
    case man4 = "man_4"
    case man5 = "man_5"
    case man6 = "man_6"
    case man7 = "man_7"
    case man8 = "man_8"
    case man9 = "man_9"
    case pin1 = "pin_1"
    case pin2 = "pin_2"
    case pin3 = "pin_3"
    case pin4 = "pin_4"
    case pin5 = "pin_5"
    case pin6 = "pin_6"
    case pin7 = "pin_7"
    case pin8 = "pin_8"
    case pin9 = "pin_9"
    case sou1 = "sou_1"
    case sou2 = "sou_2"
    case sou3 = "sou_3"
    case sou4 = "sou_4"
    case sou5 = "sou_5"
    case sou6 = "sou_6"
    case sou7 = "sou_7"
    case sou8 = "sou_8"
    case sou9 = "sou_9"
    case east = "east"
    case south = "south"
    case west = "west"
    case north = "north"
    case white = "white"
    case green = "green"
    case red = "red"
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
    case plum = "plum"
    case orchid = "orchid"
    case bamboo = "bamboo"
    case chrysanthemum = "chrysanthemum"
    case redFiveMan = "red_five_man"
    case redFivePin = "red_five_pin"
    case redFiveSou = "red_five_sou"

    static let base34: [TileCode] = [
        .man1, .man2, .man3, .man4, .man5, .man6, .man7, .man8, .man9,
        .pin1, .pin2, .pin3, .pin4, .pin5, .pin6, .pin7, .pin8, .pin9,
        .sou1, .sou2, .sou3, .sou4, .sou5, .sou6, .sou7, .sou8, .sou9,
        .east, .south, .west, .north, .white, .green, .red
    ]

    static let mcrFlowerCodes: [TileCode] = [
        .spring, .summer, .autumn, .winter, .plum, .orchid, .bamboo, .chrysanthemum
    ]

    static let riichiRedFiveCodes: [TileCode] = [
        .redFiveMan, .redFivePin, .redFiveSou
    ]

    static let mcrVisualClasses: [TileCode] = base34 + mcrFlowerCodes
    static let riichiMLeagueVisualClasses: [TileCode] = base34 + riichiRedFiveCodes
}

struct RecognitionModelProfile: Codable, Equatable {
    var id: String
    var displayName: String
    var rulesProfile: RulesProfile
    var visualDomain: TileVisualDomain
    var classCount: Int
    var tileCodes: [TileCode]

    func validate() throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractValidationError.invalidValue("RecognitionModelProfile.id must not be empty")
        }
        guard visualDomain == rulesProfile.visualDomain else {
            throw ContractValidationError.invalidValue("RecognitionModelProfile.visualDomain must match rulesProfile")
        }
        guard classCount == rulesProfile.visualSemanticClassCount else {
            throw ContractValidationError.invalidValue("RecognitionModelProfile.classCount must match rules profile visual class count")
        }
        guard tileCodes.count == classCount else {
            throw ContractValidationError.invalidValue("RecognitionModelProfile.tileCodes count must equal classCount")
        }
        guard Set(tileCodes).count == tileCodes.count else {
            throw ContractValidationError.invalidValue("RecognitionModelProfile.tileCodes must not contain duplicates")
        }
        guard Set(tileCodes) == Set(rulesProfile.visualClasses) else {
            throw ContractValidationError.invalidValue("RecognitionModelProfile.tileCodes must match rules profile visual classes")
        }
    }
}

struct NormalizedRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func validate() throws {
        let values = [x, y, width, height]
        guard values.allSatisfy({ $0.isFinite }) else {
            throw ContractValidationError.invalidValue("NormalizedRect values must be finite")
        }
        guard x >= 0, y >= 0, width > 0, height > 0, x + width <= 1, y + height <= 1 else {
            throw ContractValidationError.invalidValue("NormalizedRect must fit inside the normalized image bounds")
        }
    }
}

struct RecognizedTile: Identifiable, Codable, Equatable {
    var id: UUID
    var tileCode: TileCode
    var confidence: Float
    var normalizedRect: NormalizedRect

    init(id: UUID = UUID(), tileCode: TileCode, confidence: Float, normalizedRect: NormalizedRect) {
        self.id = id
        self.tileCode = tileCode
        self.confidence = confidence
        self.normalizedRect = normalizedRect
    }

    func validate(allowedTileCodes: Set<TileCode>) throws {
        guard allowedTileCodes.contains(tileCode) else {
            throw ContractValidationError.invalidValue("RecognizedTile.tileCode is not allowed by the model profile")
        }
        guard confidence.isFinite, confidence >= 0, confidence <= 1 else {
            throw ContractValidationError.invalidValue("RecognizedTile.confidence must be between 0 and 1")
        }
        try normalizedRect.validate()
    }
}

struct TileRecognitionEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var matchID: UUID
    var sourceID: String
    var zone: TableZone
    var capturedAt: Date
    var receivedAt: Date
    var modelID: String
    var tiles: [RecognizedTile]

    init(
        id: UUID = UUID(),
        matchID: UUID,
        sourceID: String,
        zone: TableZone,
        capturedAt: Date,
        receivedAt: Date,
        modelID: String,
        tiles: [RecognizedTile]
    ) {
        self.id = id
        self.matchID = matchID
        self.sourceID = sourceID
        self.zone = zone
        self.capturedAt = capturedAt
        self.receivedAt = receivedAt
        self.modelID = modelID
        self.tiles = tiles
    }

    func validate(against model: RecognitionModelProfile) throws {
        try model.validate()
        guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractValidationError.invalidValue("TileRecognitionEvent.sourceID must not be empty")
        }
        guard modelID == model.id else {
            throw ContractValidationError.invalidValue("TileRecognitionEvent.modelID must match RecognitionModelProfile.id")
        }
        guard receivedAt >= capturedAt else {
            throw ContractValidationError.invalidValue("TileRecognitionEvent.receivedAt must be at or after capturedAt")
        }
        let allowedCodes = Set(model.tileCodes)
        try tiles.forEach { try $0.validate(allowedTileCodes: allowedCodes) }
    }
}

struct PlayerState: Codable, Equatable {
    var seat: PlayerSeat
    var concealedTiles: [TileCode]
    var meldTiles: [TileCode]
    var discardTiles: [TileCode]
}

struct MatchGameState: Codable, Equatable {
    var matchID: UUID
    var rulesProfile: RulesProfile
    var capturedAt: Date
    var players: [PlayerState]
    var visibleTiles: [TileCode]
    var conflicts: [String]

    func validate() throws {
        let seats = players.map(\.seat)
        guard Set(seats) == Set(PlayerSeat.allCases), seats.count == PlayerSeat.allCases.count else {
            throw ContractValidationError.invalidValue("MatchGameState.players must contain each seat exactly once")
        }
        let allowedCodes = Set(rulesProfile.visualClasses)
        for player in players {
            let allTiles = player.concealedTiles + player.meldTiles + player.discardTiles
            guard allTiles.allSatisfy({ allowedCodes.contains($0) }) else {
                throw ContractValidationError.invalidValue("MatchGameState contains a tile outside the rules profile")
            }
        }
        guard visibleTiles.allSatisfy({ allowedCodes.contains($0) }) else {
            throw ContractValidationError.invalidValue("MatchGameState.visibleTiles contains a tile outside the rules profile")
        }
    }
}

struct SimulationConfig: Codable, Equatable {
    var iterations: Int
    var randomSeed: UInt64
    var algorithmVersion: String
    var baselinePolicyVersion: String
    var normalizationTolerance: Double

    init(
        iterations: Int,
        randomSeed: UInt64,
        algorithmVersion: String,
        baselinePolicyVersion: String,
        normalizationTolerance: Double = 0.000001
    ) {
        self.iterations = iterations
        self.randomSeed = randomSeed
        self.algorithmVersion = algorithmVersion
        self.baselinePolicyVersion = baselinePolicyVersion
        self.normalizationTolerance = normalizationTolerance
    }

    func validate() throws {
        guard iterations > 0 else {
            throw ContractValidationError.invalidValue("SimulationConfig.iterations must be positive")
        }
        guard !algorithmVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractValidationError.invalidValue("SimulationConfig.algorithmVersion must not be empty")
        }
        guard !baselinePolicyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractValidationError.invalidValue("SimulationConfig.baselinePolicyVersion must not be empty")
        }
        guard normalizationTolerance.isFinite, normalizationTolerance > 0, normalizationTolerance <= 0.01 else {
            throw ContractValidationError.invalidValue("SimulationConfig.normalizationTolerance must be in (0, 0.01]")
        }
    }
}

struct SeatWinShares: Codable, Equatable {
    var east: Double
    var south: Double
    var west: Double
    var north: Double

    var values: [Double] {
        [east, south, west, north]
    }
}

struct EquitySnapshot: Identifiable, Codable, Equatable {
    var id: UUID
    var matchID: UUID
    var rulesProfile: RulesProfile
    var createdAt: Date
    var config: SimulationConfig
    var winShares: SeatWinShares
    var drawProbability: Double
    var uncertainty: String

    init(
        id: UUID = UUID(),
        matchID: UUID,
        rulesProfile: RulesProfile,
        createdAt: Date,
        config: SimulationConfig,
        winShares: SeatWinShares,
        drawProbability: Double,
        uncertainty: String
    ) {
        self.id = id
        self.matchID = matchID
        self.rulesProfile = rulesProfile
        self.createdAt = createdAt
        self.config = config
        self.winShares = winShares
        self.drawProbability = drawProbability
        self.uncertainty = uncertainty
    }

    func validate() throws {
        try config.validate()
        let probabilities = winShares.values + [drawProbability]
        guard probabilities.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else {
            throw ContractValidationError.invalidValue("EquitySnapshot probabilities must be finite values between 0 and 1")
        }
        let total = probabilities.reduce(0, +)
        guard abs(total - 1) <= config.normalizationTolerance else {
            throw ContractValidationError.invalidValue("EquitySnapshot win shares plus draw probability must normalize to 1")
        }
        guard !uncertainty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractValidationError.invalidValue("EquitySnapshot.uncertainty must record uncertainty")
        }
    }
}
