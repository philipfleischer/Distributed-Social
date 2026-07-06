//
//  FullPlayerView.swift
//  Distributed-Social
//
//  Full-screen overlay above the TabView (covers the tab bar). Dismiss via
//  the chevron or by swiping down. Swiping horizontally slides the whole
//  song card (cover, title, artist) carousel-style into the neighbor song.
//

import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var themeStore: ThemeStore
    @State private var itemForPlaylist: MediaItem?
    @State private var showQueue = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipeOffset: CGFloat = 0

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        VStack(spacing: 16) {
            header

            if playerVM.currentItem?.mediaType == .video {
                VideoPlayerView(player: playerVM.avPlayer)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                titleBlock(for: playerVM.currentItem)
            } else {
                // Carousel: previous/current/next cards slide with the drag.
                GeometryReader { geo in
                    let width = geo.size.width
                    ZStack {
                        if let previous = playerVM.previousItem {
                            songCard(for: previous)
                                .offset(x: swipeOffset - width)
                        }
                        if let current = playerVM.currentItem {
                            songCard(for: current)
                                .offset(x: swipeOffset)
                        }
                        if let next = playerVM.nextItem {
                            songCard(for: next)
                                .offset(x: swipeOffset + width)
                        }
                    }
                    .frame(width: width)
                }
                .frame(height: 430)
                .clipped()
            }

            PlayerControlsView()

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            theme.background
                .background(theme.backgroundColors.first ?? .black)
                .ignoresSafeArea()
        )
        .offset(y: max(0, dragOffset))
        .gesture(playerGesture)
        .animation(.spring(duration: 0.3), value: dragOffset)
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
        }
    }

    // MARK: - Pieces

    private func songCard(for item: MediaItem) -> some View {
        VStack(spacing: 20) {
            MediaArtworkView(item: item, size: 330)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 7)
            titleBlock(for: item)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func titleBlock(for item: MediaItem?) -> some View {
        VStack(spacing: 4) {
            Text(item?.displayName ?? "")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let artist = item?.artist {
                Text(artist)
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Gestures

    /// Vertical pull dismisses; horizontal drag slides the song carousel.
    private var playerGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if abs(value.translation.height) > abs(value.translation.width) {
                    dragOffset = value.translation.height
                } else {
                    var offset = value.translation.width
                    // Rubber-band when there is no song in that direction.
                    if offset < 0 && playerVM.nextItem == nil { offset /= 3 }
                    if offset > 0 && playerVM.previousItem == nil { offset /= 3 }
                    swipeOffset = offset
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                if abs(horizontal) > abs(vertical) {
                    let width = UIScreen.main.bounds.width
                    if horizontal < -60, playerVM.nextItem != nil {
                        commitSwipe(to: -width) { playerVM.nextTrack() }
                    } else if horizontal > 60, playerVM.previousItem != nil {
                        commitSwipe(to: width) { playerVM.swipeToPreviousTrack() }
                    } else {
                        withAnimation(.spring(duration: 0.25)) { swipeOffset = 0 }
                    }
                } else if vertical > 90 {
                    playerVM.isFullPlayerPresented = false
                }
                dragOffset = 0
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

    /// Dismiss chevron on the left; speed, queue, and "⋮" menu on the right.
    private var header: some View {
        HStack {
            Button {
                playerVM.isFullPlayerPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            AirPlayButton(tint: theme.textPrimary)
                .frame(width: 44, height: 44)

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.number")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            // "⋮": add to playlist, playback speed, sleep timer.
            Menu {
                if let item = playerVM.currentItem {
                    Button { itemForPlaylist = item } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                }

                Menu {
                    ForEach(Constants.Playback.speeds, id: \.self) { speed in
                        Button { playerVM.setSpeed(speed) } label: {
                            if playerVM.playbackSpeed == speed {
                                Label(String(format: "%g×", speed), systemImage: "checkmark")
                            } else {
                                Text(String(format: "%g×", speed))
                            }
                        }
                    }
                } label: {
                    Label("Speed (\(String(format: "%g×", playerVM.playbackSpeed)))",
                          systemImage: "gauge.with.needle")
                }

                Menu {
                    ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                        Button { playerVM.setSleepTimer(minutes: minutes) } label: {
                            Text("\(minutes) minutes")
                        }
                    }
                    if playerVM.sleepTimerEnd != nil {
                        Divider()
                        Button(role: .destructive) {
                            playerVM.setSleepTimer(minutes: nil)
                        } label: {
                            Label("Turn Off", systemImage: "moon.zzz")
                        }
                    }
                } label: {
                    Label(
                        playerVM.sleepTimerEnd.map {
                            "Sleep Timer (until \($0.formatted(date: .omitted, time: .shortened)))"
                        } ?? "Sleep Timer",
                        systemImage: playerVM.sleepTimerEnd == nil ? "moon" : "moon.fill"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 12)
    }
}
