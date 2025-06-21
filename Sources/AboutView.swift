import SwiftUI

struct AboutView: View {
    let appName = "TabLift"
    let appDescription = "Minimized App Restorer"
    let appVersion = "Version " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    let copyright = "MIT © Mihai-Eduard Ghețu"
    let appIconName = "AppIcon"

    let aboutLinks: [AboutLink] = [
        .init(iconName: "info.circle", label: "Know more about TabLift", url: URL(string: "https://tablift.mihai.sh")!),
        .init(iconName: "cup.and.saucer", label: "Buy me a coffee", url: URL(string: "https://coff.ee/turtle.key")!),
        .init(iconName: "chevron.left.slash.chevron.right", label: "This app is fully open source", url: URL(string: "https://github.com/turtle-key/TabLift")!),
        .init(iconName: "envelope", label: "Email me", url: URL(string: "mailto:ghetumihaieduard@gmail.com")!)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 16) {
                Spacer().frame(height: 2)

                Image(appIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 4)

                Text(appName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 2)

                Text(appDescription)
                    .font(.title2)
                    .foregroundColor(.gray)

                Text(appVersion)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack {
                Spacer()
                VStack(spacing: 18) {
                    ForEach(aboutLinks) { link in
                        AboutLinkRow(link: link)
                            .frame(maxWidth: 340)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }

            Divider()

            Text(copyright)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.vertical, 18)
        }
        .frame(width: 480, height: 560)
    }
}

struct AboutLink: Identifiable {
    let id = UUID()
    let iconName: String
    let label: String
    let url: URL
}

struct AboutLinkRow: View {
    let link: AboutLink

    var body: some View {
        Link(destination: link.url) {
            HStack(spacing: 16) {
                Image(systemName: link.iconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 30, height: 30, alignment: .center)

                Text(link.label)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

