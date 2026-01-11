//
// LLMMetadataSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - LLMMetadata

/// Extracted LLM metadata from a message's event tags
struct LLMMetadata {
    /// All extracted metadata as key-value pairs
    var values: [String: String] = [:]

    var hasAnyMetadata: Bool { !values.isEmpty }

    // Model Information
    var model: String? { values["model"] }
    var provider: String? { values["provider"] }
    var apiVersion: String? { values["api-version"] }
    var systemFingerprint: String? { values["system-fingerprint"] }

    // Generation Parameters
    var temperature: String? { values["temperature"] }
    var maxTokens: String? { values["max-tokens"] }
    var topP: String? { values["top-p"] }
    var frequencyPenalty: String? { values["frequency-penalty"] }
    var presencePenalty: String? { values["presence-penalty"] }

    // Token Usage
    var promptTokens: String? { values["prompt-tokens"] }
    var completionTokens: String? { values["completion-tokens"] }
    var totalTokens: String? { values["total-tokens"] }
    var reasoningTokens: String? { values["reasoning-tokens"] }
    var cachedInputTokens: String? { values["cached-input-tokens"] }

    // Performance
    var responseTime: String? { values["response-time"] }
    var finishReason: String? { values["finish-reason"] }
    var costUsd: String? { values["cost-usd"] }

    // Group checks
    var hasModelInfo: Bool {
        model != nil || provider != nil || apiVersion != nil || systemFingerprint != nil
    }

    var hasParameters: Bool {
        temperature != nil || maxTokens != nil || topP != nil ||
            frequencyPenalty != nil || presencePenalty != nil
    }

    var hasUsage: Bool {
        promptTokens != nil || completionTokens != nil || totalTokens != nil ||
            reasoningTokens != nil || cachedInputTokens != nil
    }

    var hasPerformance: Bool {
        responseTime != nil || finishReason != nil || costUsd != nil
    }

    /// Parse LLM metadata from raw event JSON
    static func from(rawEventJSON: String?) -> Self {
        guard let json = rawEventJSON,
              let data = json.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tags = event["tags"] as? [[String]]
        else {
            return Self()
        }

        var values: [String: String] = [:]

        for tag in tags where tag.count >= 2 {
            let tagName = tag[0]
            let tagValue = tag[1]

            if tagName.hasPrefix("llm-") {
                let key = String(tagName.dropFirst(4))
                values[key] = tagValue
            }
        }

        return Self(values: values)
    }

    /// Generate JSON representation
    func toJSON() -> String {
        if let data = try? JSONSerialization.data(withJSONObject: values, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
}

// MARK: - LLMMetadataSheet

/// Sheet displaying LLM metadata extracted from a message
struct LLMMetadataSheet: View {
    @Binding var isPresented: Bool
    let metadata: LLMMetadata

    var body: some View {
        NavigationStack {
            Group {
                if metadata.hasAnyMetadata {
                    metadataContent
                } else {
                    emptyState
                }
            }
            .navigationTitle("LLM Metadata")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            isPresented = false
                        }
                    }

                    if metadata.hasAnyMetadata {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                copyToClipboard(metadata.toJSON())
                            } label: {
                                Label("Copy JSON", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No LLM Metadata")
                .font(.headline)

            Text("Metadata is typically attached by AI agents when generating responses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metadataContent: some View {
        List {
            if metadata.hasModelInfo {
                ModelInfoSection(metadata: metadata)
            }

            if metadata.hasParameters {
                ParametersSection(metadata: metadata)
            }

            if metadata.hasUsage {
                UsageSection(metadata: metadata)
            }

            if metadata.hasPerformance {
                PerformanceSection(metadata: metadata)
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Section Views

private struct ModelInfoSection: View {
    let metadata: LLMMetadata

    var body: some View {
        Section {
            MetadataRow(label: "Model", value: metadata.model)
            MetadataRow(label: "Provider", value: metadata.provider)
            MetadataRow(label: "API Version", value: metadata.apiVersion)
            MetadataRow(label: "System Fingerprint", value: metadata.systemFingerprint)
        } header: {
            Label("Model Information", systemImage: "cpu")
        }
    }
}

private struct ParametersSection: View {
    let metadata: LLMMetadata

    var body: some View {
        Section {
            MetadataRow(label: "Temperature", value: metadata.temperature)
            MetadataRow(label: "Max Tokens", value: metadata.maxTokens)
            MetadataRow(label: "Top P", value: metadata.topP)
            MetadataRow(label: "Frequency Penalty", value: metadata.frequencyPenalty)
            MetadataRow(label: "Presence Penalty", value: metadata.presencePenalty)
        } header: {
            Label("Generation Parameters", systemImage: "slider.horizontal.3")
        }
    }
}

private struct UsageSection: View {
    let metadata: LLMMetadata

    var body: some View {
        Section {
            MetadataRow(label: "Prompt Tokens", value: metadata.promptTokens)
            MetadataRow(label: "Completion Tokens", value: metadata.completionTokens)
            MetadataRow(label: "Total Tokens", value: metadata.totalTokens)
            MetadataRow(label: "Reasoning Tokens", value: metadata.reasoningTokens)
            MetadataRow(label: "Cached Input Tokens", value: metadata.cachedInputTokens)
        } header: {
            Label("Token Usage", systemImage: "chart.bar")
        }
    }
}

private struct PerformanceSection: View {
    let metadata: LLMMetadata

    var body: some View {
        Section {
            if let responseTime = metadata.responseTime {
                MetadataRow(label: "Response Time", value: "\(responseTime)ms")
            }
            MetadataRow(label: "Finish Reason", value: metadata.finishReason)
            if let cost = metadata.costUsd {
                MetadataRow(label: "Cost (USD)", value: "$\(cost)")
            }
        } header: {
            Label("Performance", systemImage: "bolt")
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }
}
