import SwiftUI

struct TaskDateTimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("选择时间")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TaskDesignTokens.ink)
                .frame(maxWidth: .infinity, minHeight: 42)

            Divider()

            HStack(spacing: 0) {
                timeColumn(values: Array(0...23), selection: $hour, unit: "小时")
                Divider()
                timeColumn(values: Array(0...59), selection: $minute, unit: "分钟")
            }
        }
    }

    private func timeColumn(
        values: [Int],
        selection: Binding<Int>,
        unit: String
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 4) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            selection.wrappedValue = value
                        } label: {
                            Text(String(format: "%02d", value))
                                .font(.system(
                                    size: 13,
                                    weight: selection.wrappedValue == value ? .semibold : .regular
                                ).monospacedDigit())
                                .foregroundStyle(TaskDesignTokens.muted)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(
                                    selection.wrappedValue == value ? TaskDesignTokens.sidebar : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(value)
                        .accessibilityLabel("\(unit) \(value)")
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(selection.wrappedValue, anchor: .center)
            }
            .onChange(of: selection.wrappedValue) { _, value in
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }
}
