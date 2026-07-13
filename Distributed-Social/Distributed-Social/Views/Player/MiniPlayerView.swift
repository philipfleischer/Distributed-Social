//
//  MiniPlayerView.swift
//  Distributed-Social
//
//  Collapsed playback island. Swipe left/right to change songs — the
//  neighboring song's info slides in with the drag, carousel-style.
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @EnvironmentObject var themeStore: ThemeStore
    @State private var swipeOffset: CGFloat = 0

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                if let previous = playerVM.previousItem {
                    row(for: previous)
                        .offset(x: swipeOffset - width)
                }
                if let current = playerVM.currentItem {
                    row(for: current)
                        .offset(x: swipeOffset)
                }
                if let next = playerVM.nextItem {
                    row(for: next)
                        .offset(x: swipeOffset + width)
                }
            }
            .gesture(swipeGesture(width: width))
        }
        .frame(height: 68)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(theme.textPrimary.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .shadow(color: theme.textPrimary.opacity(0.25), radius: 6, y: 2)
        .onTapGesture { playerVM.isFullPlayerPresented = true }
    }

    private func row(for item: MediaItem) -> some View {
        HStack(spacing: 14) {
            MediaArtworkView(item: item, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                MiniTimeLabel()
            }

            Spacer()

            Button { playerVM.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            Button { playerVM.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 16)
        .frame(height: 68)
        .contentShape(Rectangle())
    }

    /// Horizontal drag: slide neighbors in with the finger; commit past the
    /// threshold with a smooth roll-off, then swap tracks invisibly.
    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                var offset = value.translation.width
                // Rubber-band when there is no song in that direction.
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

/// The elapsed/total clock, isolated in its own view so the twice-a-second
/// time ticks re-render only this label instead of the whole mini player.
private struct MiniTimeLabel: View {
    @Environment(PlaybackTimeModel.self) private var timeModel
    @EnvironmentObject var themeStore: ThemeStore

    var body: some View {
        Text(timeModel.currentTime.formattedTime + " / " + timeModel.duration.formattedTime)
            .font(.subheadline)
            .foregroundStyle(themeStore.theme.textSecondary)
    }
}
