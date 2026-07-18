//
//  FullPlayerView.swift
//  Distributed-Social
//
//  Full-screen overlay above the TabView (covers the tab bar). Dismiss via
//  the chevron or by swiping down. Swiping horizontally slides the whole
//  song card (cover, title, artist) carousel-style into the neighbor song —
//  but only when the drag starts on the card itself, so drags near the
//  scrubber and controls can't change tracks by accident.
//

import SwiftUI

struct FullPlayerView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var mediaLibraryService: MediaLibraryService
    @EnvironmentObject var themeStore: ThemeStore
    @State private var itemForPlaylist: MediaItem?
    @State private var showQueue = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipeOffset: CGFloat = 0
    /// Card width measured by the carousel — used by the swipe gesture so
    /// it doesn't depend on the deprecated UIScreen.main.
    @State private var carouselWidth: CGFloat = 0

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
                    .onAppear { carouselWidth = width }
                    .onChange(of: width) { _, newWidth in carouselWidth = newWidth }
                }
                .frame(height: 430)
                .clipped()
                // Track-change swipes only start inside the song card (cover
                // + title/artist); everywhere else only pull-down works.
                .contentShape(Rectangle())
                .gesture(playerGesture)
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
        .gesture(dismissGesture)
        .animation(.spring(duration: 0.3), value: dragOffset)
        .onChange(of: playerVM.currentItem?.id) { _, _ in
            // Track changed (next button, song ended, lock screen…): any
            // leftover carousel offset — e.g. from a drag the system
            // cancelled without onEnded — would show the new cover
            // off-center with the neighbor card peeking in.
            resetSwipeOffset()
        }
        .onChange(of: scenePhase) { _, phase in
            // The app-switcher gesture (bottom-edge swipe) starts as a drag
            // in the app, then the system steals it without onEnded — the
            // app resigns active at that moment, so reset here.
            if phase != .active { resetSwipeOffset() }
        }
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

    /// Pull-down-to-dismiss for everywhere outside the song card. Horizontal
    /// movement is deliberately ignored so a drag near the scrubber can
    /// never switch tracks.
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if abs(value.translation.height) > abs(value.translation.width) {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 90 {
                    playerVM.isFullPlayerPresented = false
                }
                dragOffset = 0
            }
    }

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
                    let width = carouselWidth > 0 ? carouselWidth : 393
                    if horizontal < -60, playerVM.nextItem != nil {
                        commitSwipe(to: -width) { playerVM.nextTrack() }
                    } else if horizontal > 60, playerVM.previousItem != nil {
                        commitSwipe(to: width) { playerVM.swipeToPreviousTrack() }
                    } else {
                        withAnimation(.spring(duration: 0.25)) { swipeOffset = 0 }
                    }
                } else {
                    if vertical > 90 {
                        playerVM.isFullPlayerPresented = false
                    }
                    // A mixed drag can set swipeOffset before turning
                    // vertical — clear it or the card sticks off-center.
                    withAnimation(.spring(duration: 0.25)) { swipeOffset = 0 }
                }
                dragOffset = 0
            }
    }

    /// Snaps the carousel back to center without animating.
    private func resetSwipeOffset() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            swipeOffset = 0
            dragOffset = 0
        }
    }

    /// Deletes the playing song: playback advances to the next track (or
    /// stops and closes the player when nothing is left), then the file and
    /// library entry are removed.
    private func deleteCurrentSong(_ item: MediaItem) {
        playerVM.removeFromPlayback(item)
        if playerVM.currentItem == nil {
            playerVM.isFullPlayerPresented = false
        }
        mediaLibraryService.deleteMediaItem(item, in: modelContext)
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

                if let item = playerVM.currentItem {
                    Divider()
                    Button(role: .destructive) {
                        deleteCurrentSong(item)
                    } label: {
                        Label("Delete Song", systemImage: "trash")
                    }
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
