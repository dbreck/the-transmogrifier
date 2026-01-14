import SwiftUI

struct OnboardingTourView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @Namespace private var animation

    private let tourSteps: [TourStep] = [
        TourStep(
            title: "Welcome to The Transmogrifier",
            description:
                "Let's walk through a quick workflow for processing your images. Click next to continue, or ESC to skip the tour.",
            highlightArea: nil,
            position: .center
        ),
        TourStep(
            title: "1. Add Images",
            description:
                "Drag and drop image files or folders here, or click Browse Files. You can select multiple images at once for batch processing.",
            highlightArea: .fileSelection,
            position: .trailing
        ),
        TourStep(
            title: "2. Adjust Settings & Output",
            description:
                "Set your output format (JPG, PNG, WebP), dimensions, resolution, and compression level. Choose your output folder and optionally save these settings as a Preset for reuse.",
            highlightArea: .processingSettings,
            position: .bottom
        ),
        TourStep(
            title: "3. Preview & Test",
            description:
                "Click the Process arrow in the Preview section to test your settings on one image. Then click the preview image to open it full-size and inspect quality. Adjust compression until you're happy.",
            highlightArea: .preview,
            position: .center
        ),
        TourStep(
            title: "4. Process All Images",
            description:
                "When you're satisfied with your settings, click Process Images to convert all selected files. You'll see progress at the top of this section.",
            highlightArea: .processControls,
            position: .center
        ),
        TourStep(
            title: "You're All Set!",
            description:
                "That's it! You can now start processing images. Press ESC or click Done to close this tour. Access it again anytime from Help menu → Show Tour.",
            highlightArea: nil,
            position: .center
        ),
    ]

    var body: some View {
        ZStack {
            // Semi-transparent overlay - only show on welcome/done screens (no highlight)
            if tourSteps[currentStep].highlightArea == nil {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Tap outside to dismiss
                        isPresented = false
                    }
            } else {
                // Light overlay for steps with highlights
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Tap outside to dismiss
                        isPresented = false
                    }
            }

            // Highlight cutout (if applicable for current step)
            if let highlightArea = tourSteps[currentStep].highlightArea {
                HighlightCutout(area: highlightArea)
            }

            // Tooltip
            TourTooltip(
                step: tourSteps[currentStep],
                stepNumber: tourSteps[currentStep].highlightArea != nil ? currentStep : nil,
                totalSteps: tourSteps.filter { $0.highlightArea != nil }.count,
                currentStepIndex: currentStep,
                totalStepsCount: tourSteps.count,
                onNext: {
                    if currentStep < tourSteps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    } else {
                        isPresented = false
                    }
                },
                onSkip: {
                    isPresented = false
                }
            )
            .transition(.opacity)
        }
        .onAppear {
            // Mark tour as shown
            UserDefaults.standard.set(true, forKey: "hasShownOnboardingTour")
        }
    }
}

struct TourStep {
    let title: String
    let description: String
    let highlightArea: HighlightArea?
    let position: TooltipPosition
}

enum HighlightArea {
    case fileSelection
    case preview
    case processingSettings
    case processControls
    case selectedFiles
    case historyTab
}

enum TooltipPosition {
    case top
    case bottom
    case leading
    case trailing
    case center
}

struct HighlightCutout: View {
    let area: HighlightArea

    var body: some View {
        GeometryReader { geometry in
            let frame = highlightFrame(for: area, in: geometry)

            // Create cutout shape
            Rectangle()
                .fill(Color.black.opacity(0.001))  // Nearly transparent to allow interaction
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue600, lineWidth: 3)
                        .shadow(color: .blue600.opacity(0.5), radius: 8)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                )
        }
        .allowsHitTesting(false)
    }

    private func highlightFrame(for area: HighlightArea, in geometry: GeometryProxy) -> CGRect {
        let size = geometry.size

        // Approximate positions based on ContentView layout
        // These are rough estimates - adjust based on actual layout
        switch area {
        case .fileSelection:
            return CGRect(x: 24, y: 70 + 60, width: (size.width - 380 - 88) / 2, height: 265)
        case .preview:
            // Right next to File Selection, same Y position and height
            let fileSelectionWidth = (size.width - 380 - 88) / 2
            return CGRect(
                x: 24 + fileSelectionWidth + 24, y: 70 + 60, width: fileSelectionWidth, height: 265)
        case .processingSettings:
            // Below File Selection/Preview, spans full width (minus sidebar)
            let topCardsHeight: CGFloat = 265  // Same height as File Selection/Preview
            let yPosition: CGFloat = 25 + topCardsHeight + 124  // Below top cards + gap
            return CGRect(x: 24, y: yPosition, width: size.width - 380 - 64, height: 290)
        case .processControls:
            return CGRect(x: 24, y: size.height - 230, width: size.width - 380 - 68, height: 110)
        case .selectedFiles:
            return CGRect(
                x: size.width - 380 - 24, y: 24 + 60, width: 380, height: size.height - 48 - 60)
        case .historyTab:
            return CGRect(x: size.width / 2 - 50, y: 24, width: 100, height: 40)
        }
    }
}

struct TourTooltip: View {
    let step: TourStep
    let stepNumber: Int?
    let totalSteps: Int
    let currentStepIndex: Int
    let totalStepsCount: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        if let stepNumber = stepNumber {
                            Text("Step \(stepNumber) of \(totalSteps)")
                                .font(.caption)
                                .foregroundColor(.gray400)
                        }
                    }

                    Spacer()

                    Button(action: onSkip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray400)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                // Description
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.gray300)
                    .fixedSize(horizontal: false, vertical: true)

                // Actions
                HStack(spacing: Spacing.sm) {
                    Button("Skip Tour") {
                        onSkip()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(.gray700)
                    .foregroundColor(.gray300)
                    .cornerRadius(6)

                    Spacer()

                    TransmogrifierButton(
                        currentStepIndex == totalStepsCount - 1 ? "Done" : "Next",
                        icon: "arrow.right"
                    ) {
                        onNext()
                    }
                    .frame(width: 120)
                }
            }
            .padding(Spacing.lg)
            .frame(width: 400)
            .background(.gray800)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
            .position(tooltipPosition(for: step.position, in: geometry))
        }
    }

    private func tooltipPosition(for position: TooltipPosition, in geometry: GeometryProxy)
        -> CGPoint
    {
        let size = geometry.size

        switch position {
        case .center:
            return CGPoint(x: size.width / 2, y: size.height / 2)
        case .top:
            return CGPoint(x: size.width / 2, y: 150)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height - 150)
        case .leading:
            return CGPoint(x: 250, y: size.height / 2)
        case .trailing:
            // Position closer to the highlights (File Selection, Preview)
            return CGPoint(x: 700, y: 260)
        }
    }
}

extension View {
    func onboardingTour(isPresented: Binding<Bool>) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                OnboardingTourView(isPresented: isPresented)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
    }
}

#Preview {
    ZStack {
        // Mock ContentView background
        Color.gray900
            .ignoresSafeArea()

        OnboardingTourView(isPresented: .constant(true))
    }
}
