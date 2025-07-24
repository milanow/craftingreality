//
//  CommandDisplayView.swift
//  CraftingReality
//
//  Created for Mobile Demo Adaptation
//

import SwiftUI

struct CommandDisplayView: View {
    @Environment(MobileEntityMaker.self) var mobileEntityMaker
    @State private var showingDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header with current active entity
                activeEntitySection
                
                // System status
                systemStatusSection
                
                // Command history
                commandHistorySection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Voice Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        mobileEntityMaker.clearHistory()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }
    
    private var activeEntitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Entity")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if let activeEntity = mobileEntityMaker.activeEntityDescription {
                Text(activeEntity)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No entity selected")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var systemStatusSection: some View {
        HStack {
            Text("System Status:")
                .font(.headline)
            
            Text(mobileEntityMaker.systemStatus ? "Active" : "Inactive")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(mobileEntityMaker.systemStatus ? .green : .orange)
            
            Spacer()
            
            Circle()
                .fill(mobileEntityMaker.systemStatus ? .green : .orange)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var commandHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Command History")
                    .font(.headline)
                
                Spacer()
                
                Text("\(mobileEntityMaker.commandHistory.count) commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if mobileEntityMaker.commandHistory.isEmpty {
                Text("No commands yet. Try saying something like 'Create a red cube' or 'Make a blue sphere'")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(mobileEntityMaker.commandHistory.reversed()) { command in
                            CommandRowView(command: command)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
}

struct CommandRowView: View {
    let command: CommandResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Command type icon
                Image(systemName: iconForCommandType(command.type))
                    .foregroundStyle(command.success ? .green : .red)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.displayText)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    Text(command.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !command.originalCommand.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            if isExpanded && !command.originalCommand.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Command:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text("\"\(command.originalCommand)\"")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .italic()
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func iconForCommandType(_ type: String) -> String {
        switch type.lowercased() {
        case "creation":
            return "plus.circle.fill"
        case "movement":
            return "arrow.up.down.left.right"
        case "scaling":
            return "arrow.up.left.and.arrow.down.right"
        case "modification":
            return "paintbrush.fill"
        case "system":
            return "gear.circle.fill"
        case "error":
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

#Preview {
    CommandDisplayView()
        .environment(MobileEntityMaker())
} 