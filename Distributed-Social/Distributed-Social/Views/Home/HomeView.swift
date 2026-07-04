//
//  HomeView.swift
//  Distributed-Social
//
//  The front page: popular and recently played playlists up top, then two
//  big colored boxes leading into the Audio and Video libraries.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var playlists: [Playlist]
    @Query private var allItems: [MediaItem]

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

    private var audioCount: Int { allItems.filter { $0.mediaType == .audio }.count }
    private var videoCount: Int { allItems.filter { $0.mediaType == .video }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !popular.isEmpty {
                        playlistRow(title: "Popular", playlists: popular)
                    }
                    if !recentlyPlayed.isEmpty {
                        playlistRow(title: "Recently Played", playlists: recentlyPlayed)
                    }
                    if popular.isEmpty && recentlyPlayed.isEmpty {
                        Text("Play a playlist and it will show up here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    // Library boxes
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Your Library")
                            .font(.title2).fontWeight(.semibold)
                            .padding(.horizontal)

                        HStack(spacing: 16) {
                            NavigationLink {
                                AudioLibraryView()
                            } label: {
                                libraryBox(
                                    title: "Audio",
                                    count: audioCount,
                                    systemImage: "music.note.list",
                                    colors: [Color.skyBlue, Color.deepSky]
                                )
                            }
                            NavigationLink {
                                VideoLibraryView()
                            } label: {
                                libraryBox(
                                    title: "Video",
                                    count: videoCount,
                                    systemImage: "film",
                                    colors: [Color.sakuraPink, Color(red: 0.859, green: 0.443, blue: 0.576)]
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 120) // clear the mini player
            }
            .summerBackground()
            .navigationTitle("Home")
        }
    }

    private func playlistRow(title: String, playlists: [Playlist]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2).fontWeight(.semibold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            PlaylistTileView(playlist: playlist, size: 140)
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
