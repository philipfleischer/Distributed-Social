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
    let artworkNamespace: Namespace.ID

    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(MediaLibraryService.self) private var mediaLibraryService
    @Environment(ThemeStore.self) private var themeStore
    @State private var itemForPlaylist: MediaItem?
    @State private var showQueue = false
    @State private var showFadeSheet = false
    @State private var triggerAirPlay = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipeOffset: CGFloat = 0
    @State private var carouselWidth: CGFloat = 0
    /// Drives a fade-in on the artwork when the track changes without a
    /// carousel animation (auto-advance, lock-screen skip, etc.).
    @State private var artworkOpacity: Double = 1.0

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
                .contentShape(Rectangle())
                .gesture(playerGesture)
            }

            PlayerControlsView(
                onNextTrack: {
                    guard playerVM.nextItem != nil else { return }
                    commitSwipe(to: -(carouselWidth > 0 ? carouselWidth : 393)) {
                        playerVM.nextTrack()
                    }
                },
                onPreviousTrack: {
                    guard playerVM.previousItem != nil else { return }
                    commitSwipe(to: carouselWidth > 0 ? carouselWidth : 393) {
                        playerVM.swipeToPreviousTrack()
                    }
                }
            )

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            theme.background
                .background(theme.backgroundColors.first ?? .black)
                .ignoresSafeArea()
        )
        // Hidden AirPlay trigger — lives in the view tree so AVRoutePickerView
        // is attached to the window and can present the system picker.
        .background(
            AirPlayTriggerView(trigger: $triggerAirPlay)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
        .offset(y: max(0, dragOffset))
        .gesture(dismissGesture)
        .animation(.spring(duration: 0.3), value: dragOffset)
        .onChange(of: playerVM.currentItem?.id) { _, _ in
            resetSwipeOffset()
            // Fade the artwork in so auto-advance doesn't hard-cut to the
            // new cover. Carousel swipes already provide their own visual.
            artworkOpacity = 0.0
            withAnimation(.easeIn(duration: 0.3)) { artworkOpacity = 1.0 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { resetSwipeOffset() }
        }
        .sheet(item: $itemForPlaylist) { item in
            AddToPlaylistSheet(item: item)
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
        }
        .sheet(isPresented: $showFadeSheet) {
            SongFadeSheet(
                selectedSeconds: Binding(
                    get: { playerVM.songFadeSeconds },
                    set: { playerVM.setSongFade(seconds: $0) }
                )
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Pieces

    private func songCard(for item: MediaItem) -> some View {
        let isCurrent = item.id == playerVM.currentItem?.id
        return VStack(spacing: 20) {
            if isCurrent {
                MediaArtworkView(item: item, size: 330)
                    .matchedGeometryEffect(id: "playerArtwork", in: artworkNamespace)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 7)
                    .opacity(artworkOpacity)
            } else {
                MediaArtworkView(item: item, size: 330)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 7)
            }
            titleBlock(for: item)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func titleBlock(for item: MediaItem?) -> some View {
        VStack(spacing: 4) {
            MarqueeText(
                text: item?.displayName ?? "",
                font: .title.weight(.semibold),
                color: theme.textPrimary,
                lineHeight: 36
            )
            .padding(.horizontal)
            if let artist = item?.artist {
                MarqueeText(
                    text: artist,
                    font: .title3,
                    color: theme.textSecondary,
                    lineHeight: 28
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Gestures

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

    private var playerGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if abs(value.translation.height) > abs(value.translation.width) {
                    dragOffset = value.translation.height
                } else {
                    var offset = value.translation.width
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
                    withAnimation(.spring(duration: 0.25)) { swipeOffset = 0 }
                }
                dragOffset = 0
            }
    }

    private func resetSwipeOffset() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            swipeOffset = 0
            dragOffset = 0
        }
    }

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

    // MARK: - Header

    /// Queue and "⋮" on the right; AirPlay lives inside the "⋮" menu.
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

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.number")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

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

                Button { triggerAirPlay = true } label: {
                    Label("AirPlay", systemImage: "airplayvideo")
                }

                Button { showFadeSheet = true } label: {
                    let s = playerVM.songFadeSeconds
                    Label(
                        s > 0 ? "Song Fade (\(s)s)" : "Song Fade",
                        systemImage: s > 0 ? "forward.end.fill" : "forward.end"
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

// MARK: - Song Fade Sheet

private struct SongFadeSheet: View {
    @Binding var selectedSeconds: Int
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Skip the last N seconds of every song — great for long silence or fade-outs you don't want to sit through.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Picker("Song Fade", selection: $selectedSeconds) {
                    Text("Off").tag(0)
                    ForEach(1...15, id: \.self) { s in
                        Text("\(s) sec").tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 180)

                if selectedSeconds > 0 {
                    Text("Skipping last \(selectedSeconds) second\(selectedSeconds == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text("Disabled")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Song Fade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
