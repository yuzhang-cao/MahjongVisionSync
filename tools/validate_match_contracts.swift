import Foundation

@main
enum MatchContractsValidation {
    static func main() throws {
        guard RulesProfile.mcr.visualSemanticClassCount == 42 else {
            throw ValidationError("MCR must expose 42 visual semantic classes")
        }
        guard RulesProfile.riichiMLeague.visualSemanticClassCount == 37 else {
            throw ValidationError("M.League Riichi must expose 37 visual semantic classes")
        }
        guard TileCode.mcrFlowerCodes.count == 8 else {
            throw ValidationError("MCR must keep eight flower tiles as distinct tile codes")
        }
        guard TileCode.riichiRedFiveCodes.count == 3 else {
            throw ValidationError("Riichi must keep three red five tile codes")
        }
        let expectedMCRCodes = [
            "man_1", "man_2", "man_3", "man_4", "man_5", "man_6", "man_7", "man_8", "man_9",
            "pin_1", "pin_2", "pin_3", "pin_4", "pin_5", "pin_6", "pin_7", "pin_8", "pin_9",
            "sou_1", "sou_2", "sou_3", "sou_4", "sou_5", "sou_6", "sou_7", "sou_8", "sou_9",
            "east", "south", "west", "north", "white", "green", "red",
            "spring", "summer", "autumn", "winter", "plum", "orchid", "bamboo", "chrysanthemum"
        ]
        let expectedRiichiCodes = Array(expectedMCRCodes.prefix(34)) + [
            "red_five_man", "red_five_pin", "red_five_sou"
        ]
        guard TileCode.mcrVisualClasses.map(\.rawValue) == expectedMCRCodes else {
            throw ValidationError("Swift MCR tile codes must match the Python training dataset codes")
        }
        guard TileCode.riichiMLeagueVisualClasses.map(\.rawValue) == expectedRiichiCodes else {
            throw ValidationError("Swift Riichi tile codes must match the Python training dataset codes")
        }

        let model = RecognitionModelProfile(
            id: "riichi-v1",
            displayName: "Riichi M.League baseline",
            rulesProfile: .riichiMLeague,
            visualDomain: .riichiMLeague,
            classCount: 37,
            tileCodes: TileCode.riichiMLeagueVisualClasses
        )
        try model.validate()

        let event = TileRecognitionEvent(
            matchID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sourceID: "camera-east",
            zone: .playerHandEast,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            receivedAt: Date(timeIntervalSince1970: 1_700_000_001),
            modelID: model.id,
            tiles: [
                RecognizedTile(
                    tileCode: .redFiveMan,
                    confidence: 0.91,
                    normalizedRect: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
                )
            ]
        )
        try event.validate(against: model)

        let state = MatchGameState(
            matchID: event.matchID,
            rulesProfile: .riichiMLeague,
            capturedAt: event.capturedAt,
            players: [
                PlayerState(seat: .east, concealedTiles: [.redFiveMan], meldTiles: [], discardTiles: []),
                PlayerState(seat: .south, concealedTiles: [], meldTiles: [], discardTiles: []),
                PlayerState(seat: .west, concealedTiles: [], meldTiles: [], discardTiles: []),
                PlayerState(seat: .north, concealedTiles: [], meldTiles: [], discardTiles: [])
            ],
            visibleTiles: [.redFiveMan],
            conflicts: []
        )
        try state.validate()

        let config = SimulationConfig(
            iterations: 1_000,
            randomSeed: 42,
            algorithmVersion: "monte-carlo-v1",
            baselinePolicyVersion: "baseline-policy-v1"
        )
        let equity = EquitySnapshot(
            matchID: state.matchID,
            rulesProfile: state.rulesProfile,
            createdAt: state.capturedAt,
            config: config,
            winShares: SeatWinShares(east: 0.25, south: 0.25, west: 0.2, north: 0.2),
            drawProbability: 0.1,
            uncertainty: "fixture"
        )
        try equity.validate()

        let encoder = JSONEncoder()
        let data = try encoder.encode(equity)
        _ = try JSONDecoder().decode(EquitySnapshot.self, from: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shares = json["winShares"] as? [String: Any],
              shares["east"] != nil,
              shares["south"] != nil,
              shares["west"] != nil,
              shares["north"] != nil
        else {
            throw ValidationError("EquitySnapshot winShares must encode as an object with explicit seat keys")
        }
    }
}

struct ValidationError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
