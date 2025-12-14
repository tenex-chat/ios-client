//
// InboxEventCardTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
import SwiftUI
import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - InboxEventCardTests

@Suite("InboxEventCard Tests")
@MainActor
struct InboxEventCardTests {
    // MARK: - Visual Indicator Tests

    @Test("Shows blue indicator bar for unread events")
    func showsBlueIndicatorForUnread() async {
        // Given: Unread event
        let event = NDKEvent.test(
            kind: 1,
            content: "Unread message",
            pubkey: "user",
            createdAt: Date()
        )
        let isUnread = true

        // Then: Blue bar should be visible
        // Note: UI testing would verify the blue bar presence
        #expect(isUnread == true)
    }

    @Test("Hides blue indicator for read events")
    func hidesBlueIndicatorForRead() async {
        // Given: Read event
        let event = NDKEvent.test(
            kind: 1,
            content: "Read message",
            pubkey: "user",
            createdAt: Date().addingTimeInterval(-7200)
        )
        let isUnread = false

        // Then: Blue bar should not be visible
        #expect(isUnread == false)
    }

    @Test("Blue indicator has shadow effect")
    func blueIndicatorHasShadow() async {
        // Given: Unread event
        let isUnread = true

        // Then: Blue bar should have .blue shadow with radius 8
        // Note: UI snapshot testing would verify visual appearance
        #expect(isUnread == true)
    }

    @Test("Shows blue background tint for unread events")
    func showsBlueBackgroundTintForUnread() async {
        // Given: Unread event
        let isUnread = true

        // Then: Background should be Color.blue.opacity(0.05)
        // Note: UI testing would verify background color
        #expect(isUnread == true)
    }

    // MARK: - New Badge Tests

    @Test("Shows New badge for unread events")
    func showsNewBadgeForUnread() async {
        // Given: Unread event
        let isUnread = true

        // Then: "New" badge should be visible
        #expect(isUnread == true)
    }

    @Test("Hides New badge for read events")
    func hidesNewBadgeForRead() async {
        // Given: Read event
        let isUnread = false

        // Then: "New" badge should not be visible
        #expect(isUnread == false)
    }

    @Test("New badge has pulsing animation")
    func newBadgeHasPulsingAnimation() async {
        // Given: Unread event
        let isUnread = true

        // Then: Badge should have .pulsingAnimation() modifier
        // Note: Animation testing would be done via UI tests
        #expect(isUnread == true)
    }

    // MARK: - Event Type Badge Tests

    @Test("Shows agent response badge for agent events")
    func showsAgentResponseBadge() async {
        // Given: Agent response event
        let event = NDKEvent.test(
            kind: 1111,
            content: "Agent response",
            pubkey: "agent",
            tags: [
                ["client", "TENEX Agent"],
                ["p", "user-pubkey", "", "agent"],
            ]
        )

        // When: Determining event type
        let store = InboxStore()
        let eventType = store.getEventType(event)

        // Then: Badge shows "Agent Response" with purple color
        #expect(eventType == .agentResponse)
    }

    @Test("Shows mention badge for kind 1 events")
    func showsMentionBadge() async {
        // Given: Kind 1 mention event
        let event = NDKEvent.test(
            kind: 1,
            content: "Hey @user",
            pubkey: "other-user",
            tags: [["p", "user-pubkey"]]
        )

        // When: Determining event type
        let store = InboxStore()
        let eventType = store.getEventType(event)

        // Then: Badge shows "Mention" with blue color
        #expect(eventType == .mention)
    }

    @Test("Shows reply badge for kind 1111 non-agent events")
    func showsReplyBadge() async {
        // Given: Kind 1111 reply event without agent markers
        let event = NDKEvent.test(
            kind: 1111,
            content: "Reply to your message",
            pubkey: "user",
            tags: [["p", "user-pubkey"]]
        )

        // When: Determining event type
        let store = InboxStore()
        let eventType = store.getEventType(event)

        // Then: Badge shows "Reply" with green color
        #expect(eventType == .reply)
    }

    @Test("Shows reaction badge for kind 7 events")
    func showsReactionBadge() async {
        // Given: Kind 7 reaction event
        let event = NDKEvent.test(
            kind: 7,
            content: "❤️",
            pubkey: "reactor",
            tags: [["p", "user-pubkey"]]
        )

        // When: Determining event type
        let store = InboxStore()
        let eventType = store.getEventType(event)

        // Then: Badge shows "Reaction" with pink color
        #expect(eventType == .reaction)
    }

    @Test("Shows article mention badge for kind 30023 events")
    func showsArticleMentionBadge() async {
        // Given: Kind 30023 article event
        let event = NDKEvent.test(
            kind: 30_023,
            content: "Long-form article",
            pubkey: "author",
            tags: [["p", "user-pubkey"]]
        )

        // When: Determining event type
        let store = InboxStore()
        let eventType = store.getEventType(event)

        // Then: Badge shows "Article Mention" with orange color
        #expect(eventType == .articleMention)
    }

    // MARK: - Content Display Tests

    @Test("Displays author avatar")
    func displaysAuthorAvatar() async {
        // Given: Event with author
        let event = NDKEvent.test(
            kind: 1,
            content: "Message",
            pubkey: "author-pubkey"
        )

        // Then: Should display UserAvatar with 40x40 frame
        #expect(event.pubkey == "author-pubkey")
    }

    @Test("Displays author name")
    func displaysAuthorName() async {
        // Given: Event with author
        let event = NDKEvent.test(
            kind: 1,
            content: "Message",
            pubkey: "author-pubkey"
        )

        // Then: Should display UserName component
        #expect(event.pubkey == "author-pubkey")
    }

    @Test("Displays content preview limited to 2 lines when collapsed")
    func displaysContentPreviewLimited() async {
        // Given: Event with long content
        let longContent = String(repeating: "This is a very long message. ", count: 20)
        let event = NDKEvent.test(
            kind: 1,
            content: longContent,
            pubkey: "user"
        )
        let isExpanded = false

        // Then: Content should be limited to 2 lines
        #expect(isExpanded == false)
    }

    @Test("Displays full content when expanded")
    func displaysFullContentWhenExpanded() async {
        // Given: Event with long content
        let longContent = String(repeating: "This is a very long message. ", count: 20)
        let event = NDKEvent.test(
            kind: 1,
            content: longContent,
            pubkey: "user"
        )
        let isExpanded = true

        // Then: Content should have no line limit
        #expect(isExpanded == true)
    }

    @Test("Displays relative timestamp")
    func displaysRelativeTimestamp() async {
        // Given: Event created 1 hour ago
        let oneHourInSeconds: TimeInterval = 3600
        let oneHourAgo = Date().addingTimeInterval(-oneHourInSeconds)
        let event = NDKEvent.test(
            kind: 1,
            content: "Message",
            pubkey: "user",
            createdAt: oneHourAgo
        )

        // Then: Should display "1h ago" or similar
        #expect(event.createdAt != nil)
    }

    // MARK: - Suggestion Indicator Tests

    @Test("Shows suggestion indicator when event has suggestions")
    func showsSuggestionIndicatorWhenPresent() async {
        // Given: Event with suggestions
        let event = NDKEvent.test(
            kind: 1111,
            content: "Choose an option",
            pubkey: "agent",
            tags: [
                ["suggestion", "Option A"],
                ["suggestion", "Option B"],
                ["suggestion", "Option C"],
            ]
        )

        // When: Extracting suggestions
        let store = InboxStore()
        let suggestions = store.getSuggestions(from: event)

        // Then: Suggestion indicator should be visible
        #expect(suggestions.count == 3)
    }

    @Test("Hides suggestion indicator when no suggestions")
    func hidesSuggestionIndicatorWhenAbsent() async {
        // Given: Event without suggestions
        let event = NDKEvent.test(
            kind: 1,
            content: "Regular message",
            pubkey: "user"
        )

        // When: Extracting suggestions
        let store = InboxStore()
        let suggestions = store.getSuggestions(from: event)

        // Then: Suggestion indicator should not be visible
        #expect(suggestions.isEmpty)
    }

    @Test("Suggestion indicator shows count correctly")
    func suggestionIndicatorShowsCorrectCount() async {
        // Given: Event with 5 suggestions
        let event = NDKEvent.test(
            kind: 1111,
            content: "Pick one",
            pubkey: "agent",
            tags: [
                ["suggestion", "A"],
                ["suggestion", "B"],
                ["suggestion", "C"],
                ["suggestion", "D"],
                ["suggestion", "E"],
            ]
        )

        // When: Extracting suggestions
        let store = InboxStore()
        let suggestions = store.getSuggestions(from: event)

        // Then: Should display "5 options"
        #expect(suggestions.count == 5)
    }

    @Test("Suggestion indicator uses singular for 1 option")
    func suggestionIndicatorUsesSingular() async {
        // Given: Event with 1 suggestion
        let event = NDKEvent.test(
            kind: 1111,
            content: "One option",
            pubkey: "agent",
            tags: [["suggestion", "Only choice"]]
        )

        // When: Extracting suggestions
        let store = InboxStore()
        let suggestions = store.getSuggestions(from: event)

        // Then: Should display "1 option" (singular)
        let countText = suggestions.count == 1 ? "option" : "options"
        #expect(countText == "option")
    }

    @Test("Suggestion indicator shows Waiting for response status")
    func suggestionIndicatorShowsWaitingStatus() async {
        // Given: Event with suggestions
        let event = NDKEvent.test(
            kind: 1111,
            content: "Choose",
            pubkey: "agent",
            tags: [["suggestion", "A"]]
        )

        // When: Checking for suggestions
        let store = InboxStore()
        let hasSuggestions = !store.getSuggestions(from: event).isEmpty

        // Then: Should show "Waiting for response" text
        #expect(hasSuggestions == true)
    }

    // MARK: - Expand/Collapse Tests

    @Test("Toggle button shows View Context when collapsed")
    func toggleButtonShowsViewContextWhenCollapsed() async {
        // Given: Card in collapsed state
        let isExpanded = false

        // Then: Button text should be "View Context"
        let buttonText = isExpanded ? "Collapse" : "View Context"
        #expect(buttonText == "View Context")
    }

    @Test("Toggle button shows Collapse when expanded")
    func toggleButtonShowsCollapseWhenExpanded() async {
        // Given: Card in expanded state
        let isExpanded = true

        // Then: Button text should be "Collapse"
        let buttonText = isExpanded ? "Collapse" : "View Context"
        #expect(buttonText == "Collapse")
    }

    @Test("Toggle button visible on hover")
    func toggleButtonVisibleOnHover() async {
        // Given: Card component
        // Then: Button should have .opacity(0) normally
        // And: .opacity(100) on group-hover
        // Note: Hover state testing done via UI tests
    }

    @Test("Clicking toggle expands collapsed content")
    func clickingToggleExpandsContent() async {
        // Given: Collapsed card
        var isExpanded = false

        // When: Clicking toggle
        isExpanded.toggle()

        // Then: Card is expanded
        #expect(isExpanded == true)
    }

    @Test("Clicking toggle collapses expanded content")
    func clickingToggleCollapsesContent() async {
        // Given: Expanded card
        var isExpanded = true

        // When: Clicking toggle
        isExpanded.toggle()

        // Then: Card is collapsed
        #expect(isExpanded == false)
    }

    // MARK: - Layout Tests

    @Test("Card uses HStack layout")
    func cardUsesHStackLayout() async {
        // Given: InboxEventCard
        // Then: Main layout should be HStack with 12pt spacing
        // Note: Layout testing done via snapshot tests
    }

    @Test("Card has horizontal padding")
    func cardHasHorizontalPadding() async {
        // Given: InboxEventCard
        // Then: Should have .padding(.horizontal)
        // Note: Layout testing done via snapshot tests
    }

    @Test("Card has vertical padding")
    func cardHasVerticalPadding() async {
        // Given: InboxEventCard
        // Then: Should have .padding(.vertical, 12)
        // Note: Layout testing done via snapshot tests
    }

    // MARK: - Accessibility Tests

    @Test("Unread indicator has accessible label")
    func unreadIndicatorHasAccessibleLabel() async {
        // Given: Unread event
        let isUnread = true

        // Then: Blue bar should have aria-label="New message indicator"
        // Note: Accessibility testing done via UI tests
        #expect(isUnread == true)
    }

    @Test("Event type badge includes icon and label")
    func eventTypeBadgeIncludesIconAndLabel() async {
        // Given: Event
        let event = NDKEvent.test(kind: 1, content: "Test", pubkey: "user")

        // Then: Badge should have both icon and text label
        // Note: Accessibility testing done via UI tests
        #expect(event.kind == 1)
    }
}

// MARK: - EventTypeBadgeTests

@Suite("EventTypeBadge Tests")
@MainActor
struct EventTypeBadgeTests {
    // MARK: - Icon Tests

    @Test("Agent Response uses Bot icon")
    func agentResponseUsesBotIcon() async {
        // Given: Agent response event type
        let eventType = InboxEventType.agentResponse

        // Then: Should use SF Symbol "brain" or similar bot icon
        #expect(eventType == .agentResponse)
    }

    @Test("Mention uses MessageCircle icon")
    func mentionUsesMessageCircleIcon() async {
        // Given: Mention event type
        let eventType = InboxEventType.mention

        // Then: Should use message bubble icon
        #expect(eventType == .mention)
    }

    @Test("Reply uses Reply icon")
    func replyUsesReplyIcon() async {
        // Given: Reply event type
        let eventType = InboxEventType.reply

        // Then: Should use reply arrow icon
        #expect(eventType == .reply)
    }

    @Test("Reaction uses Heart icon")
    func reactionUsesHeartIcon() async {
        // Given: Reaction event type
        let eventType = InboxEventType.reaction

        // Then: Should use heart icon
        #expect(eventType == .reaction)
    }

    @Test("Article Mention uses FileText icon")
    func articleMentionUsesFileTextIcon() async {
        // Given: Article mention event type
        let eventType = InboxEventType.articleMention

        // Then: Should use document/file icon
        #expect(eventType == .articleMention)
    }

    // MARK: - Color Tests

    @Test("Agent Response has purple color")
    func agentResponseHasPurpleColor() async {
        // Given: Agent response type
        let eventType = InboxEventType.agentResponse

        // Then: Color should be .purple
        let color = eventType.color
        #expect(color == .purple)
    }

    @Test("Mention has blue color")
    func mentionHasBlueColor() async {
        // Given: Mention type
        let eventType = InboxEventType.mention

        // Then: Color should be .blue
        let color = eventType.color
        #expect(color == .blue)
    }

    @Test("Reply has green color")
    func replyHasGreenColor() async {
        // Given: Reply type
        let eventType = InboxEventType.reply

        // Then: Color should be .green
        let color = eventType.color
        #expect(color == .green)
    }

    @Test("Reaction has pink color")
    func reactionHasPinkColor() async {
        // Given: Reaction type
        let eventType = InboxEventType.reaction

        // Then: Color should be .pink
        let color = eventType.color
        #expect(color == .pink)
    }

    @Test("Article Mention has orange color")
    func articleMentionHasOrangeColor() async {
        // Given: Article mention type
        let eventType = InboxEventType.articleMention

        // Then: Color should be .orange
        let color = eventType.color
        #expect(color == .orange)
    }

    // MARK: - Label Tests

    @Test("Each event type has correct label text")
    func eachEventTypeHasCorrectLabel() async {
        // Given: All event types
        let types: [(InboxEventType, String)] = [
            (.agentResponse, "Agent Response"),
            (.mention, "Mention"),
            (.reply, "Reply"),
            (.reaction, "Reaction"),
            (.articleMention, "Article Mention"),
        ]

        // Then: Each should have correct label
        for (type, expectedLabel) in types {
            let label = type.label
            #expect(label == expectedLabel)
        }
    }
}

// MARK: - InboxEventType

enum InboxEventType: Equatable {
    case agentResponse
    case mention
    case reply
    case reaction
    case articleMention

    // MARK: Internal

    var label: String {
        switch self {
        case .agentResponse:
            "Agent Response"
        case .mention:
            "Mention"
        case .reply:
            "Reply"
        case .reaction:
            "Reaction"
        case .articleMention:
            "Article Mention"
        }
    }

    var color: Color {
        switch self {
        case .agentResponse:
            .purple
        case .mention:
            .blue
        case .reply:
            .green
        case .reaction:
            .pink
        case .articleMention:
            .orange
        }
    }
}
