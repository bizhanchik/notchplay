import SwiftUI

struct NotchContainerView<Content: View>: View {
    @EnvironmentObject private var viewModel: NotchViewModel
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let radii = viewModel.currentCornerRadii

        content
            .frame(width: viewModel.notchSize.width, height: viewModel.notchSize.height)
            .background(
                NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom)
                    .fill(.black)
                    .shadow(
                        color: viewModel.isExpanded ? .black.opacity(0.2) : .clear,
                        radius: viewModel.isExpanded ? 8 : 0,
                        x: 0,
                        y: viewModel.isExpanded ? 3 : 0
                    )
                    .shadow(
                        color: viewModel.isExpanded ? .black.opacity(0.4) : .clear,
                        radius: viewModel.isExpanded ? 40 : 0,
                        x: 0,
                        y: viewModel.isExpanded ? 12 : 0
                    )
            )
            .clipShape(NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
