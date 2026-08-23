//
//  MiniPlayerView.swift
//  Distributed-Social
//
//  Collapsed playback island. Swipe left/right to change songs — the
//  neighboring song's info slides in with the drag, carousel-style.
//
//  The island extends past the safe area to sit flush with the iPhone screen
//  edge. It does this with a VStack: 68 pt of interactive content on top, then
//  a transparent spacer that fills the bottom safe-area inset. A negative
//  bottom padding equal to that inset shrinks the layout rect back to 68 pt so
//  the parent ZStack keeps its bottom anchor at the safe-area edge, while the
//  actual rendered view (and hit-testing area) reaches the physical screen
//  bottom. The UnevenRoundedRectangle's large bottom radii match the device
//  display corners.
//

import SwiftUI
import UIKit

struct MiniPlayerView: View {
    let artworkNamespace: Namespace.ID

    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var themeStore
    @State private var swipeOffset: CGFloat = 0

    private var theme: AppTheme { themeStore.theme }

    /// Bottom safe-area inset (home indicator height on Face ID devices).
    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .keyWindow?
            .safeAreaInsets.bottom ?? 34
    }

    /// Corner radius for the bottom edge — matches the device display curve.
    private static let screenCornerRadius: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            // ── Interactive player controls ──────────────────────────────
            GeometryReader { geo in
                let width = geo.size.width
                ZStack {
                    if let previous = playerVM.previousItem {
                        row(for: previous, isCurrent: false)
                            .offset(x: swipeOffset - width)
                    }
                    if let current = playerVM.currentItem {
                        row(for: current, isCurrent: true)
                            .offset(x: swipeOffset)
                    }
                    if let next = playerVM.nextItem {
                        row(for: next, isCurrent: false)
                            .offset(x: swipeOffset + width)
                    }
                }
                .gesture(swipeGesture(width: width))
            }
            .frame(height: 60)
            .contentShape(Rectangle())
            .onTapGesture { playerVM.isFullPlayerPresented = true }

            // ── Safe-area filler (home-indicator zone) ───────────────────
            // Smaller than the full safe-area inset so the island doesn't
            // look bottom-heavy; the negative padding below still pulls the
            // view's bottom edge all the way to the physical screen edge.
            Color.clear
                .frame(height: 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: Self.screenCornerRadius,
                bottomTrailingRadius: Self.screenCornerRadius,
                topTrailingRadius: 20,
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: Self.screenCornerRadius,
                bottomTrailingRadius: Self.screenCornerRadius,
                topTrailingRadius: 20,
                style: .continuous
            )
            .strokeBorder(theme.textPrimary.opacity(0.25), lineWidth: 1)
        )
        // Shadow sits above the island, not below (it's at the screen edge)
        .shadow(color: theme.textPrimary.opacity(0.2), radius: 8, y: -3)
        // Negative padding = layout height of 68, content height of 68+safeAreaBottom.
        // The parent ZStack keeps its bottom anchor at the safe-area edge while the
        // rendered island extends to the physical screen bottom.
        .padding(.bottom, -safeAreaBottom)
        .onChange(of: playerVM.currentItem?.id) { _, _ in
            resetSwipeOffset()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { resetSwipeOffset() }
        }
    }

    private func row(for item: MediaItem, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            if isCurrent {
                // Only participate in matchedGeometryEffect when the full player
                // is not visible. With both views in the namespace simultaneously
                // (full player open + mini at opacity-0), SwiftUI picks the wrong
                // source frame on song changes and snaps the artwork to the bottom.
                if playerVM.isFullPlayerPresented {
                    MediaArtworkView(item: item, size: 44)
                } else {
                    MediaArtworkView(item: item, size: 44)
                        .matchedGeometryEffect(id: "playerArtwork", in: artworkNamespace)
                }
            } else {
                MediaArtworkView(item: item, size: 44)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                MiniTimeLabel()
            }

            Spacer(minLength: 8)

            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            .padding(.trailing, 20)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 28)
        .frame(height: 60)
        .contentShape(Rectangle())
    }

    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                var offset = value.translation.width
                if offset < 0 && playerVM.nextItem == nil { offset /= 3 }
                if offset > 0 && playerVM.previousItem == nil { offset /= 3 }
                swipeOffset = offset
            }
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal < -50, playerVM.nextItem != nil {
                    commitSwipe(to: -width) { playerVM.nextTrack() }
                } else if horizontal > 50, playerVM.previousItem != nil {
                    commitSwipe(to: width) { playerVM.swipeToPreviousTrack() }
                } else {
                    withAnimation(.spring(duration: 0.25)) { swipeOffset = 0 }
                }
            }
    }

    private func resetSwipeOffset() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { swipeOffset = 0 }
    }

    private func commitSwipe(to target: CGFloat, change: @escaping () -> Void) {
        Haptics.medium()
        withAnimation(.spring(duration: 0.28), completionCriteria: .logicallyComplete) {
            swipeOffset = target
        } completion: {
            change()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { swipeOffset = 0 }
        }
    }
}

private struct MiniTimeLabel: View {
    @Environment(PlaybackTimeModel.self) private var timeModel
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        Text(timeModel.currentTime.formattedTime)
            .font(.subheadline)
            .foregroundStyle(themeStore.theme.textSecondary)
    }
}
