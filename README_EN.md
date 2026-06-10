# MahjongVisionSync

A multi-stream Mahjong tournament state recognition, audience data display, and replay system.

This project is intended for tournament staff, referees, broadcast data operators, and viewers. It does not provide real-time decision advice to players. The goal is not merely tile recognition; the system turns recognition results from multiple competition video streams or capture devices into structured match events for tournament records, broadcast overlays, referee review, and post-match replay.

The current codebase comes from `MahjongTing` and already includes manual hand input, ready-hand / winning-hand calculation, camera scanning, and CoreML tile recognition. The graduation-project direction is to connect these base capabilities to tournament workflows: multi-stream regional input, recognition events, match-state reconstruction, audience-facing analysis, and replay records.

## Current Scope

- Rule engine: Guangdong, Sichuan, Seven Pairs, Thirteen Orphans for Guangdong, Dingque for Sichuan
- Hand operations: tile input, tile removal, clear, pong, kong, concealed kong, exposed kong
- Scan entry: AVCapture scan page with CoreML row recognition
- Test tools: development dataset export code has been moved to root `TestCode.swift`

## Tournament Positioning

- Inputs: four player-hand video streams first; the discard area can be a video stream, manual input, or correction source.
- Use cases: tournament records, referee checks, broadcast data display, and post-match replay.
- Audience: tournament staff, broadcast data operators, and viewers. Players do not receive real-time decision information.
- Technical focus: regional video perception, recognition-event synchronization, match-state reconstruction, legality checks, and data visualization.

## Project Structure

- `App.swift`: app entry and orientation control
- `MainView.swift`: main UI
- `ViewModel.swift`: hand state and calculation flow
- `Engine.swift`: hand evaluation and wait calculation
- `ScanView.swift`, `Camera.swift`, `CameraPreview.swift`: scan UI and camera capture
- `Recognizer.swift`: CoreML recognition
- `TestCode.swift`: development / test utilities, outside app runtime logic

## Model and Recognition

The repository includes `TileModel.mlpackage`. The scan page loads `TileModel.mlmodelc` through `Recognizer.swift`.

The current single-tile classifier uses a 34-class mapping. See `CATEGORY_MAPPING_EN.md`.

## Data and References

See `THIRD_PARTY_NOTICES_EN.md` for data sources, third-party references, weight notes, and the data cleaning / annotation / refactoring record.

## Next

- Support public tournament video splitting, fixed-camera clips, and later real-time iOS capture
- Wrap recognition output as timestamped regional events with confidence scores
- Reconstruct hands, discards, melds, visible tiles, and legality conflicts
- Display ready-hand, effective tiles, remaining effective tiles, and trend snapshots for staff and viewers
- Save events, manual confirmations, and state snapshots for replay

## License

This repository is released under `CC BY 4.0`. See `LICENSE` in the project root.
