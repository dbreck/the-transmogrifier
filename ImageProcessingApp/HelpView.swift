import SwiftUI
import MarkdownUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory? = .gettingStarted
    @State private var selectedTopic: HelpTopic?
    
    private var filteredTopics: [HelpTopic] {
        if !searchText.isEmpty {
            return HelpContent.search(searchText)
        } else if let category = selectedCategory {
            return HelpContent.topics(for: category)
        } else {
            return HelpContent.allTopics
        }
    }
    
    // Helper function to create styled markdown view
    private func styledMarkdownView(for content: String) -> some View {
        Markdown(content)
            .markdownTextStyle {
                ForegroundColor(.white)
                FontSize(14)
            }
            .markdownBlockStyle(\.heading1) { configuration in
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(.white)
                        FontWeight(.semibold)
                        FontSize(24)
                    }
            }
            .markdownBlockStyle(\.heading2) { configuration in
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(.white)
                        FontWeight(.medium)
                        FontSize(18)
                    }
            }
            .markdownBlockStyle(\.heading3) { configuration in
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(Color.gray)
                        FontWeight(.medium)
                        FontSize(16)
                    }
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.95))
                ForegroundColor(.blue)
            }
            .markdownTextStyle(\.strong) {
                ForegroundColor(.white)
                FontWeight(.semibold)
            }
            .markdownTextStyle(\.emphasis) {
                ForegroundColor(Color.gray)
            }
            .markdownBlockStyle(\.paragraph) { configuration in
                configuration.label
                    .markdownMargin(top: 8, bottom: 8)
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                configuration.label
                    .padding(Spacing.md)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
                    .markdownMargin(top: 12, bottom: 12)
            }
            .markdownBlockStyle(\.listItem) { configuration in
                configuration.label
                    .markdownMargin(top: 4, bottom: 4)
            }
            .markdownBlockStyle(\.blockquote) { configuration in
                HStack(alignment: .top, spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 4)
                    configuration.label
                        .padding(.leading, Spacing.md)
                }
                .markdownMargin(top: 12, bottom: 12)
            }
    }
    
    var body: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            navigationSplitView
        } else {
            // Fallback for older OS versions
            HSplitView {
                sidebarContent
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
                detailContent
            }
            .onAppear {
                // Auto-select first topic on appear
                if selectedTopic == nil {
                    selectedTopic = HelpContent.allTopics.first
                }
            }
        }
    }
    
    @available(macOS 13.0, iOS 16.0, *)
    private var navigationSplitView: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .onAppear {
            // Auto-select first topic on appear
            if selectedTopic == nil {
                selectedTopic = HelpContent.allTopics.first
            }
        }
    }
    
    private var sidebarContent: some View {
        // Sidebar: Categories and Topics List
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.gray)
                TextField("Search help...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.sm)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(6)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            
            Divider()
                .background(Color.gray)
                .padding(.vertical, Spacing.xs)
            
            // Category/Topic List
            List(selection: $selectedTopic) {
                if searchText.isEmpty {
                    // Show categories when not searching
                    ForEach(HelpCategory.allCases, id: \.self) { category in
                        Section(header: Text(category.rawValue)
                            .font(.caption)
                            .foregroundColor(Color.gray)
                            .textCase(nil)
                        ) {
                            ForEach(HelpContent.topics(for: category)) { topic in
                                HelpTopicRow(topic: topic)
                                    .tag(topic)
                            }
                        }
                    }
                } else {
                    // Show search results
                    Section(header: Text("\(filteredTopics.count) results")
                        .font(.caption)
                        .foregroundColor(Color.gray)
                        .textCase(nil)
                    ) {
                        ForEach(filteredTopics) { topic in
                            HelpTopicRow(topic: topic)
                                .tag(topic)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
        .background(Color.gray.opacity(0.2))
    }
    
    private var detailContent: some View {
        Group {
            if let topic = selectedTopic {
                // Content area: Selected topic detail
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        // Topic header
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: topic.icon)
                                .font(.title)
                                .foregroundColor(.blue)
                            Text(topic.title)
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, Spacing.sm)
                        
                        // Render markdown content
                        styledMarkdownView(for: topic.content)
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: 800, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.9))
            } else {
                // Empty state
                VStack(spacing: Spacing.md) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color.gray)
                    Text("Select a topic to view help")
                        .font(.title3)
                        .foregroundColor(Color.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.9))
            }
        }
    }
}

struct HelpTopicRow: View {
    let topic: HelpTopic
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: topic.icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(topic.title)
                .font(.body)
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HelpView()
        .frame(width: 900, height: 600)
}
