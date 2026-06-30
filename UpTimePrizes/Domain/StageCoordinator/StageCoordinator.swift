import Foundation

@MainActor
class StageCoordinator {
    enum Stage {
        case stage1 // The Invite
        case stage2 // The Nudge
        case stage3 // The Prize
        case replay
    }
    
    @Published var currentStage: Stage = .stage1
    
    func advanceStage() {
        switch currentStage {
        case .stage1: currentStage = .stage2
        case .stage2: currentStage = .stage3
        case .stage3: currentStage = .replay
        case .replay: break
        }
    }
}
