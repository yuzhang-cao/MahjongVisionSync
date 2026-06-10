import Foundation
@preconcurrency import Vision
import CoreML
import CoreImage
import ImageIO

enum YOLOTileRecognizerError: LocalizedError {
    case modelMissing(name: String)
    case noDetections
    case insufficientDetections(found: Int)

    var errorDescription: String? {
        message(language: .zh)
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .modelMissing(let name):
            switch language {
            case .zh:
                return "未找到检测模型：\(name).mlmodelc（请确认模型已加入 Xcode 且勾选 Target Membership）"
            case .en:
                return "Detection model not found: \(name).mlmodelc. Confirm the model is included in Xcode and target membership is enabled."
            case .ja:
                return "検出モデルが見つかりません：\(name).mlmodelc。Xcode に追加され、Target Membership が有効か確認してください。"
            }
        case .noDetections:
            switch language {
            case .zh:
                return "没有检测到麻将牌，请调整拍摄角度、距离和光照后重试。"
            case .en:
                return "No mahjong tiles were detected. Adjust the angle, distance, and lighting, then try again."
            case .ja:
                return "麻雀牌を検出できませんでした。角度、距離、明るさを調整して再試行してください。"
            }
        case .insufficientDetections(let found):
            switch language {
            case .zh:
                return "检测到的牌数不足（\(found) 张），请确保一排摆放在框内后重试。"
            case .en:
                return "Not enough tiles detected (\(found)). Place one row inside the frame and try again."
            case .ja:
                return "検出された牌が不足しています（\(found) 枚）。一列に並べて枠内に入れてから再試行してください。"
            }
        }
    }
}

final class TileRecognizer: TileRecognizerProtocol {

    struct TileOverlay: Identifiable {
        let id: Int
        let tileIndex: Int
        let normalizedRect: CGRect
        let confidence: Float
    }

    struct OverlayResult {
        let ids: [Int]
        let normalizedRowRect: CGRect?
        let tiles: [TileOverlay]
    }

    private struct Detection {
        let id34: Int?
        let x: CGFloat
        let y: CGFloat
        let boundingBox: CGRect
        let confidence: Float
        let candidates: [Int: Float]
    }

    private struct RowCandidate {
        let detections: [Detection]
        let score: Float

        var count: Int {
            detections.count
        }
    }

    private struct WeightedDetection {
        let detection: Detection
        let frameIndex: Int
        let relativeX: CGFloat
        let weight: Float
    }

    private struct DetectionTrack {
        var items: [WeightedDetection]
        var centerX: CGFloat

        var frameSupport: Int {
            Set(items.map { $0.frameIndex }).count
        }

        var supportScore: Float {
            items.reduce(Float(0)) { $0 + $1.weight }
        }

        mutating func add(_ item: WeightedDetection) {
            let oldWeight = max(supportScore, 0.001)
            let newWeight = oldWeight + item.weight
            centerX = (centerX * CGFloat(oldWeight) + item.relativeX * CGFloat(item.weight)) / CGFloat(newWeight)
            items.append(item)
        }
    }

    private let modelName: String
    private let model: VNCoreMLModel?

    private let minConfidence: Float = 0.20
    private let candidateMinConfidence: Float = 0.04
    private let highConfidenceSingleFrameThreshold: Float = 0.58
    private let nmsIoUThreshold: CGFloat = 0.45
    private let maxTilesInRow: Int = 18

    init(modelName: String = "TileModel") {
        self.modelName = modelName

        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            self.model = nil
            return
        }

        do {
            let mlModel = try MLModel(contentsOf: url)
            self.model = try VNCoreMLModel(for: mlModel)
        } catch {
            self.model = nil
        }
    }

    func recognize(snapshots: [FrameSnapshot]) async throws -> [Int] {
        guard !snapshots.isEmpty else {
            throw YOLOTileRecognizerError.insufficientDetections(found: 0)
        }
        guard let model else {
            throw YOLOTileRecognizerError.modelMissing(name: modelName)
        }

        let result = try recognizeBestCandidate(snapshots: snapshots, model: model)
        return result.ids
    }

    func recognizeWithOverlay(snapshots: [FrameSnapshot]) async throws -> OverlayResult {
        guard !snapshots.isEmpty else {
            throw YOLOTileRecognizerError.insufficientDetections(found: 0)
        }
        guard let model else {
            throw YOLOTileRecognizerError.modelMissing(name: modelName)
        }

        return try recognizeBestCandidate(snapshots: snapshots, model: model)
    }

    func recognizeLiveOverlay(snapshot: FrameSnapshot) async throws -> OverlayResult {
        guard let model else {
            throw YOLOTileRecognizerError.modelMissing(name: modelName)
        }

        let observations = try observations(for: snapshot, model: model)
        let detections = try parseDetections(observations)
        let row = selectPrimaryRow(from: detections)
        let tiles = tileOverlays(from: row.detections)

        return OverlayResult(ids: tiles.map { $0.tileIndex },
                             normalizedRowRect: Self.unionRect(row.detections.map { $0.boundingBox }),
                             tiles: tiles)
    }

    private func recognizeBestCandidate(snapshots: [FrameSnapshot], model: VNCoreMLModel) throws -> OverlayResult {
        var rows: [RowCandidate] = []
        var bestFound = 0

        for snap in snapshots {
            let observations = try observations(for: snap, model: model)
            let detections = (try? parseDetections(observations)) ?? []
            if detections.isEmpty { continue }

            let row = selectPrimaryRow(from: detections)
            if row.detections.isEmpty { continue }
            rows.append(row)

            if row.count > bestFound {
                bestFound = row.count
            }
        }

        guard let bestSingleRow = rows.max(by: { $0.score < $1.score }) else {
            throw YOLOTileRecognizerError.insufficientDetections(found: bestFound)
        }

        let fusedRow = fuseRows(rows)
        let shouldUseFusedRow = fusedRow.count >= 13 &&
            (fusedRow.count + 1 >= bestSingleRow.count || bestSingleRow.count > 14)
        let bestRow = shouldUseFusedRow
            ? fusedRow
            : bestSingleRow.detections

        let tiles = tileOverlays(from: bestRow)
        let ids = tiles.map { $0.tileIndex }
        if ids.count < 13 {
            throw YOLOTileRecognizerError.insufficientDetections(found: max(bestFound, ids.count))
        }

        return OverlayResult(ids: ids,
                             normalizedRowRect: Self.unionRect(bestRow.map { $0.boundingBox }),
                             tiles: tiles)
    }

    private func observations(for snap: FrameSnapshot, model: VNCoreMLModel) throws -> [VNRecognizedObjectObservation] {
        let ci = CIImage(cvPixelBuffer: snap.image)
        let oriented = ci.oriented(forExifOrientation: Int32(snap.exifOrientation.rawValue))

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(ciImage: oriented, options: [:])
        try handler.perform([request])

        return (request.results as? [VNRecognizedObjectObservation]) ?? []
    }

    private func parseDetections(_ observations: [VNRecognizedObjectObservation]) throws -> [Detection] {
        guard !observations.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        var detections: [Detection] = []

        for obs in observations {
            let candidates = mappedCandidates(from: obs.labels)
            guard let best = candidates.max(by: { $0.value < $1.value }) else { continue }
            guard best.value >= minConfidence else { continue }

            let boundingBox = Self.clampedNormalizedRect(obs.boundingBox)
            guard Self.isPlausibleTileBox(boundingBox) else { continue }

            detections.append(
                Detection(
                    id34: best.key,
                    x: boundingBox.midX,
                    y: boundingBox.midY,
                    boundingBox: boundingBox,
                    confidence: best.value,
                    candidates: candidates
                )
            )
        }

        guard !detections.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        let valid = detections.compactMap { det -> Detection? in
            guard det.id34 != nil else { return nil }
            return det
        }

        guard !valid.isEmpty else {
            throw YOLOTileRecognizerError.noDetections
        }

        return nonMaximumSuppressed(valid)
    }

    private func mappedCandidates(from labels: [VNClassificationObservation]) -> [Int: Float] {
        var candidates: [Int: Float] = [:]

        for label in labels {
            guard label.confidence >= candidateMinConfidence else { continue }
            guard let idx38 = Self.parseClassIdentifier(label.identifier) else { continue }
            guard let id34 = Self.map38To34(idx38) else { continue }

            candidates[id34] = max(candidates[id34] ?? 0, label.confidence)
        }

        return candidates
    }

    private func selectPrimaryRow(from detections: [Detection]) -> RowCandidate {
        let medianHeight = Self.median(detections.map { $0.boundingBox.height }) ?? 0.12
        let band = min(CGFloat(0.22), max(CGFloat(0.12), medianHeight * 0.95))
        var bestRow: [Detection] = []
        var bestScore: Float = -1

        for center in detections {
            var row = detections.filter { abs($0.y - center.y) <= band }
            row = Self.filterRowByLineFit(row)
            row = limitedRowLength(row)
            let score = rowScore(row)

            if score > bestScore {
                bestScore = score
                bestRow = row
            }
        }

        let chosen = bestRow.isEmpty ? limitedRowLength(detections) : bestRow
        return RowCandidate(detections: chosen, score: rowScore(chosen))
    }

    private func rowScore(_ row: [Detection]) -> Float {
        guard !row.isEmpty else { return -1 }

        let avgConfidence = row.reduce(Float(0)) { $0 + $1.confidence } / Float(row.count)
        let unionWidth = Self.unionRect(row.map { $0.boundingBox })?.width ?? 0
        let medianHeight = Self.median(row.map { $0.boundingBox.height }) ?? 0.12
        let yValues = row.map { $0.y }
        let ySpread = (yValues.max() ?? 0) - (yValues.min() ?? 0)
        let spreadPenalty = Float(min(2.0, ySpread / max(medianHeight, 0.001))) * 1.5
        let countScore = Float(min(row.count, maxTilesInRow)) * 10
        let spanScore = Float(min(max(unionWidth, 0), 1)) * 2

        return countScore + avgConfidence * 4 + spanScore - spreadPenalty
    }

    private func limitedRowLength(_ row: [Detection]) -> [Detection] {
        guard row.count > maxTilesInRow else { return row }
        return Array(row.sorted(by: { $0.confidence > $1.confidence }).prefix(maxTilesInRow))
    }

    private func fuseRows(_ rows: [RowCandidate]) -> [Detection] {
        guard rows.count > 1 else {
            return rows.first?.detections ?? []
        }

        let usableRows = rows.filter { $0.count >= 10 }
        let sourceRows = usableRows.isEmpty ? rows : usableRows
        let minFrameSupport = sourceRows.count >= 3 ? 2 : 1

        var weightedDetections: [WeightedDetection] = []

        for (frameIndex, row) in sourceRows.enumerated() {
            let sorted = row.detections.sorted { $0.x < $1.x }
            guard let minX = sorted.map({ $0.x }).min(),
                  let maxX = sorted.map({ $0.x }).max() else {
                continue
            }

            let rowWidth = max(maxX - minX, 0.001)

            for detection in sorted {
                let relativeX = (detection.x - minX) / rowWidth
                weightedDetections.append(
                    WeightedDetection(
                        detection: detection,
                        frameIndex: frameIndex,
                        relativeX: relativeX,
                        weight: max(detection.confidence, 0.05)
                    )
                )
            }
        }

        guard !weightedDetections.isEmpty else { return [] }

        let medianWidth = Self.median(weightedDetections.map { $0.detection.boundingBox.width }) ?? 0.06
        let medianRowWidth = Self.median(sourceRows.compactMap { Self.unionRect($0.detections.map { $0.boundingBox })?.width }) ?? 0.75
        let tileWidthInRow = medianWidth / max(medianRowWidth, 0.001)
        let clusterTolerance = min(CGFloat(0.08), max(CGFloat(0.035), tileWidthInRow * 0.72))

        var tracks: [DetectionTrack] = []

        for item in weightedDetections.sorted(by: { $0.relativeX < $1.relativeX }) {
            if let index = tracks.indices.min(by: {
                abs(tracks[$0].centerX - item.relativeX) < abs(tracks[$1].centerX - item.relativeX)
            }), abs(tracks[index].centerX - item.relativeX) <= clusterTolerance {
                tracks[index].add(item)
            } else {
                tracks.append(DetectionTrack(items: [item], centerX: item.relativeX))
            }
        }

        var fused = tracks.compactMap { track -> Detection? in
            guard track.frameSupport >= minFrameSupport ||
                    track.supportScore >= highConfidenceSingleFrameThreshold else {
                return nil
            }
            return fusedDetection(from: track)
        }

        if fused.count > maxTilesInRow {
            fused = Array(fused.sorted(by: { $0.confidence > $1.confidence }).prefix(maxTilesInRow))
        }

        return fused.sorted { $0.x < $1.x }
    }

    private func fusedDetection(from track: DetectionTrack) -> Detection? {
        var classScores: [Int: Float] = [:]
        var totalWeight: Float = 0

        for item in track.items {
            totalWeight += item.weight

            for (id34, confidence) in item.detection.candidates {
                classScores[id34, default: 0] += confidence * item.weight
            }
        }

        guard let best = classScores.max(by: { $0.value < $1.value }) else { return nil }
        let confidence = min(Float(0.99), best.value / max(totalWeight, 0.001))
        let rect = Self.weightedAverageRect(track.items)

        return Detection(id34: best.key,
                         x: rect.midX,
                         y: rect.midY,
                         boundingBox: rect,
                         confidence: confidence,
                         candidates: classScores.mapValues { $0 / max(totalWeight, 0.001) })
    }

    private func nonMaximumSuppressed(_ detections: [Detection]) -> [Detection] {
        var kept: [Detection] = []
        let sorted = detections.sorted { $0.confidence > $1.confidence }

        for detection in sorted {
            let overlapsExisting = kept.contains { existing in
                Self.intersectionOverUnion(detection.boundingBox, existing.boundingBox) >= nmsIoUThreshold
            }

            if !overlapsExisting {
                kept.append(detection)
            }
        }

        return kept
    }

    private func tileOverlays(from detections: [Detection]) -> [TileOverlay] {
        let sorted = detections.sorted { $0.x < $1.x }
        var overlays: [TileOverlay] = []

        for detection in sorted {
            guard let id34 = detection.id34 else { continue }
            overlays.append(
                TileOverlay(id: overlays.count,
                            tileIndex: id34,
                            normalizedRect: detection.boundingBox,
                            confidence: detection.confidence)
            )
        }

        return overlays
    }

    private static func filterRowByLineFit(_ row: [Detection]) -> [Detection] {
        guard row.count >= 4 else { return row }

        let meanX = row.reduce(CGFloat(0)) { $0 + $1.x } / CGFloat(row.count)
        let meanY = row.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(row.count)
        let varianceX = row.reduce(CGFloat(0)) { sum, detection in
            let dx = detection.x - meanX
            return sum + dx * dx
        }
        guard varianceX > 0.0001 else { return row }

        let covariance = row.reduce(CGFloat(0)) { $0 + ($1.x - meanX) * ($1.y - meanY) }
        let slope = covariance / varianceX
        let intercept = meanY - slope * meanX
        let medianHeight = median(row.map { $0.boundingBox.height }) ?? 0.12
        let tolerance = min(CGFloat(0.18), max(CGFloat(0.08), medianHeight * 0.80))

        let filtered = row.filter { detection in
            let expectedY = slope * detection.x + intercept
            return abs(detection.y - expectedY) <= tolerance
        }

        return filtered.count >= 3 ? filtered : row
    }

    private static func weightedAverageRect(_ items: [WeightedDetection]) -> CGRect {
        let totalWeight = max(items.reduce(CGFloat(0)) { $0 + CGFloat($1.weight) }, 0.001)
        let x = items.reduce(CGFloat(0)) { $0 + $1.detection.boundingBox.origin.x * CGFloat($1.weight) } / totalWeight
        let y = items.reduce(CGFloat(0)) { $0 + $1.detection.boundingBox.origin.y * CGFloat($1.weight) } / totalWeight
        let width = items.reduce(CGFloat(0)) { $0 + $1.detection.boundingBox.width * CGFloat($1.weight) } / totalWeight
        let height = items.reduce(CGFloat(0)) { $0 + $1.detection.boundingBox.height * CGFloat($1.weight) } / totalWeight

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func clampedNormalizedRect(_ rect: CGRect) -> CGRect {
        let normalizedBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let standardized = rect.standardized
        let clipped = standardized.intersection(normalizedBounds)
        return clipped.isNull ? .zero : clipped
    }

    private static func isPlausibleTileBox(_ rect: CGRect) -> Bool {
        rect.width >= 0.015 &&
            rect.height >= 0.025 &&
            rect.width <= 0.36 &&
            rect.height <= 0.62
    }

    private static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }

        return sorted[mid]
    }

    private static func unionRect(_ rects: [CGRect]) -> CGRect? {
        guard var union = rects.first else { return nil }
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        return union
    }

    private static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        if intersection.isNull || intersection.isEmpty { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        if unionArea <= 0 { return 0 }

        return intersectionArea / unionArea
    }

    /// 兼容两种情况：
    /// 1. 模型直接输出 "0"..."37"
    /// 2. 模型输出类别名，如 "1m" / "0p" / "UNKNOWN"
    private static func parseClassIdentifier(_ identifier: String) -> Int? {
        if let idx = Int(identifier) {
            return idx
        }

        let key = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let table: [String: Int] = [
            "1m": 0,  "1p": 1,  "1s": 2,  "1z": 3,
            "2m": 4,  "2p": 5,  "2s": 6,  "2z": 7,
            "3m": 8,  "3p": 9,  "3s": 10, "3z": 11,
            "4m": 12, "4p": 13, "4s": 14, "4z": 15,
            "5m": 16, "5p": 17, "5s": 18, "5z": 19,
            "6m": 20, "6p": 21, "6s": 22, "6z": 23,
            "7m": 24, "7p": 25, "7s": 26, "7z": 27,
            "8m": 28, "8p": 29, "8s": 30,
            "9m": 31, "9p": 32, "9s": 33,
            "unknown": 34,
            "0m": 35, "0p": 36, "0s": 37
        ]

        return table[key]
    }

    /// 当前 app 主体逻辑还是 34 类，所以先做 38 -> 34 的临时映射
    private static func map38To34(_ idx38: Int) -> Int? {
        switch idx38 {
        case 0:  return 0
        case 1:  return 9
        case 2:  return 18
        case 3:  return 27

        case 4:  return 1
        case 5:  return 10
        case 6:  return 19
        case 7:  return 28

        case 8:  return 2
        case 9:  return 11
        case 10: return 20
        case 11: return 29

        case 12: return 3
        case 13: return 12
        case 14: return 21
        case 15: return 30

        case 16: return 4
        case 17: return 13
        case 18: return 22
        case 19: return 31

        case 20: return 5
        case 21: return 14
        case 22: return 23
        case 23: return 32

        case 24: return 6
        case 25: return 15
        case 26: return 24
        case 27: return 33

        case 28: return 7
        case 29: return 16
        case 30: return 25

        case 31: return 8
        case 32: return 17
        case 33: return 26

        case 34:
            return nil

        case 35:
            return 4
        case 36:
            return 13
        case 37:
            return 22

        default:
            return nil
        }
    }
}
