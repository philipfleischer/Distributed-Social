//
//  HomeView.swift
//  Distributed-Social
//
//  The front page: popular and recently played playlists up top, then two
//  big colored boxes leading into the Audio and Video libraries. Searching
//  filters across playlists and all songs/videos.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(ThemeStore.self) private var themeStore
    @Query private var playlists: [Playlist]
    @Query private var allItems: [MediaItem]
    @Query(filter: #Predicate<MediaItem> { $0.isFavorite }) private var favorites: [MediaItem]
    @State private var searchText = ""

    private var theme: AppTheme { themeStore.theme }

    private var recentlyPlayed: [Playlist] {
        playlists
            .filter { $0.lastPlayedDate != nil }
            .sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
            .prefix(6).map { $0 }
    }

    private var popular: [Playlist] {
        playlists
            .filter { $0.playCount > 0 }
            .sorted { $0.playCount > $1.playCount }
            .prefix(6).map { $0 }
    }

    /// Single pass through allItems to get both counts simultaneously.
    private var libraryCounts: (audio: Int, video: Int) {
        allItems.reduce(into: (audio: 0, video: 0)) { acc, item in
            if item.mediaTypeRaw == "audio" { acc.audio += 1 }
            else { acc.video += 1 }
        }
    }

    /// Fixed per app launch, so the favorites picks reshuffle on each run.
    private static let sessionSeed = Int.random(in: 1...0x7FFFFFFF)

    /// Six favorites chosen pseudo-randomly, stable within a launch but
    /// different on the next one — surfaces fresh favorites every run.
    private var favoritesPreview: [MediaItem] {
        favorites
            .sorted { sessionRank(of: $0.id) < sessionRank(of: $1.id) }
            .prefix(6).map { $0 }
    }

    private func sessionRank(of id: UUID) -> Int {
        var hash = HomeView.sessionSeed
        for scalar in id.uuidString.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0x7FFFFFFF
        }
        return hash
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if searchText.isEmpty {
                    homeContent
                } else {
                    searchResults
                }
            }
            .summerBackground()
            .navigationTitle("Home")
            .searchable(text: $searchText, prompt: "Playlists, songs, artists…")
        }
    }

    // MARK: - Default home content

    private var homeContent: some View {
        let counts = libraryCounts
        return VStack(alignment: .leading, spacing: 28) {
            if !popular.isEmpty {
                playlistRow(title: "Popular", playlists: popular)
            }
            if !recentlyPlayed.isEmpty {
                playlistRow(title: "Recently Played", playlists: recentlyPlayed)
            }
            if popular.isEmpty && recentlyPlayed.isEmpty {
                Text("Play a playlist and it will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal)
            }

            if !favorites.isEmpty {
                favoritesRow
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Your Library")
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    NavigationLink {
                        AudioLibraryView()
                    } label: {
                        libraryBox(
                            title: "Audio",
                            count: counts.audio,
                            systemImage: "music.note.list",
                            colors: [Color.skyBlue, Color.deepSky]
                        )
                    }
                    NavigationLink {
                        VideoLibraryView()
                    } label: {
                        libraryBox(
                            title: "Video",
                            count: counts.video,
                            systemImage: "film",
                            colors: [Color.sakuraPink, Color(red: 0.859, green: 0.443, blue: 0.576)]
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 120)
    }

    // MARK: - Search results

    private var searchResults: some View {
        let matchedPlaylists = playlists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        let matchedItems = allItems.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || ($0.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        return VStack(alignment: .leading, spacing: 24) {
            if matchedPlaylists.isEmpty && matchedItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .padding(.top, 60)
            }

            if !matchedPlaylists.isEmpty {
                playlistRow(title: "Playlists", playlists: matchedPlaylists)
            }

            if !matchedItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Songs & Videos")
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Button {
                            let playable = matchedItems.filter { !$0.isFileMissing }
                            if let first = playable.first {
                                playerVM.currentPlaylistID = nil
                                playerVM.play(item: first, in: playable)
                            }
                        } label: {
                            Label("Play All", systemImage: "play.circle.fill")
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                    .padding(.horizontal)

                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(matchedItems) { item in
                            Button {
                                playerVM.currentPlaylistID = nil
                                playerVM.play(item: item, in: matchedItems)
                            } label: {
                                HStack(spacing: 12) {
                                    MediaArtworkView(item: item, size: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayName)
                                            .font(.headline)
                                            .foregroundStyle(theme.textPrimary)
                                            .lineLimit(1)
                                        if let artist = item.artist {
                                            Text(artist)
                                                .font(.subheadline)
                                                .foregroundStyle(theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Text(item.duration.formattedTime)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 120)
    }

    // MARK: - Pieces

    /// Horizontal carousel of up to six per-launch random favorites.
    /// "Show More" tile only appears when there are more than 6.
    private var favoritesRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Favorites")
                .font(.title2).fontWeight(.semibold)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(favoritesPreview) { item in
                        Button {
                            playerVM.currentPlaylistID = nil
                            playerVM.play(item: item, in: favoritesPreview)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                MediaArtworkView(item: item, size: 110)
                                Text(item.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if favorites.count > 6 {
                        NavigationLink {
                            FavoritesView()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 110 * 0.21)
                                        .fill(theme.chipFill)
                                        .frame(width: 110, height: 110)
                                    VStack(spacing: 8) {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.title)
                                        Text("Show More")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(theme.textPrimary)
                                }
                                Text(" ")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func playlistRow(title: String, playlists: [Playlist]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2).fontWeight(.semibold)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            PlaylistTileView(
                                playlist: playlist,
                                size: 140,
                                isActive: playerVM.currentPlaylistID == playlist.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func libraryBox(title: String, count: Int, systemImage: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
            Spacer(minLength: 0)
            Text(title)
                .font(.title3).fontWeight(.bold)
            Text("\(count) item\(count == 1 ? "" : "s")")
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: colors[0].opacity(0.35), radius: 8, y: 4)
    }
}
