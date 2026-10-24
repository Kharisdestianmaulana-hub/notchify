import SwiftUI

struct NotesCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @AppStorage("scratchpadText") private var scratchpadText: String = ""
    @AppStorage("todoTasksJSON") private var todoTasksJSON: String = "[]"
    
    @State private var subMode: NotesSubMode = .notes
    @State private var newTaskTitle: String = ""
    @State private var showCopiedCheck: Bool = false
    @State private var todoTasks: [TodoTask] = []
    
    private var wordCount: Int {
        let trimmed = scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    private var completedCount: Int {
        todoTasks.filter { $0.isDone }.count
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Mode Switcher Header
            HStack {
                HStack(spacing: 4) {
                    ForEach(NotesSubMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                subMode = mode
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode == .notes ? "note.text" : "checklist")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(mode.localizedTitle)
                                    .font(.system(size: 11, weight: subMode == mode ? .bold : .medium))
                                if mode == .todo && !todoTasks.isEmpty {
                                    Text("\(todoTasks.count - completedCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(subMode == mode ? Color.blue : Color.white.opacity(0.15)))
                                }
                            }
                            .foregroundColor(subMode == mode ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(subMode == mode ? Color.white.opacity(0.18) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                
                Spacer()
                
                if subMode == .notes {
                    // Quick Action Buttons
                    HStack(spacing: 6) {
                        Button(action: copyAllNotes) {
                            HStack(spacing: 3) {
                                Image(systemName: showCopiedCheck ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9, weight: .bold))
                                Text(showCopiedCheck ? LanguageManager.tr("Copied!") : LanguageManager.tr("Copy All"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(showCopiedCheck ? .green : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: exportToAppleNotes) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(5)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(LanguageManager.tr("Export to Notes"))
                        
                        if !scratchpadText.isEmpty {
                            Button(action: {
                                withAnimation { scratchpadText = "" }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(5)
                                    .background(Circle().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(LanguageManager.tr("Clear"))
                        }
                    }
                } else {
                    if completedCount > 0 {
                        Button(action: clearCompletedTasks) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                Text(LanguageManager.tr("Clear Completed"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(width: 336)
            
            // Content Body
            if subMode == .notes {
                notesView
                    .frame(width: 336)
            } else {
                todoView
                    .frame(width: 336)
            }
        }
        .onAppear {
            loadTasks()
        }
    }
    
    private var notesView: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                if scratchpadText.isEmpty {
                    Text(LanguageManager.tr("Type notes or paste snippets..."))
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }
                
                TextEditor(text: $scratchpadText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white)
                    .lineSpacing(3)
                    .padding(4)
                    .background(Color.clear)
            }
            .frame(height: 155)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            )
            
            // Footer Counter
            HStack {
                Text("\(scratchpadText.count) " + LanguageManager.tr("Characters") + " • \(wordCount) " + LanguageManager.tr("Words"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var todoView: some View {
        VStack(spacing: 6) {
            // Add Task Field
            HStack(spacing: 6) {
                Image(systemName: "circle")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                TextField(LanguageManager.tr("Add a task..."), text: $newTaskTitle)
                    .font(.system(size: 12))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onSubmit(addTask)
                
                if !newTaskTitle.isEmpty {
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            )
            
            // Task List
            if todoTasks.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LanguageManager.tr("No tasks yet"))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(height: 130)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(todoTasks) { task in
                            TodoRowView(task: task, onToggle: {
                                toggleTask(task)
                            }, onDelete: {
                                deleteTask(task)
                            })
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 130)
            }
            
            // Progress Footer
            HStack {
                Text("\(completedCount)/\(todoTasks.count) " + LanguageManager.tr("completed"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks.insert(TodoTask(title: trimmed), at: 0)
            newTaskTitle = ""
            saveTasks()
        }
    }
    
    private func toggleTask(_ task: TodoTask) {
        guard let idx = todoTasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks[idx].isDone.toggle()
            saveTasks()
        }
    }
    
    private func deleteTask(_ task: TodoTask) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks.removeAll { $0.id == task.id }
            saveTasks()
        }
    }
    
    private func clearCompletedTasks() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks.removeAll { $0.isDone }
            saveTasks()
        }
    }
    
    private func saveTasks() {
        if let data = try? JSONEncoder().encode(todoTasks), let str = String(data: data, encoding: .utf8) {
            todoTasksJSON = str
        }
    }
    
    private func loadTasks() {
        if let data = todoTasksJSON.data(using: .utf8), let list = try? JSONDecoder().decode([TodoTask].self, from: data) {
            todoTasks = list
        }
    }
    
    private func copyAllNotes() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(scratchpadText, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedCheck = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedCheck = false
            }
        }
    }
    
    private func exportToAppleNotes() {
        let escaped = scratchpadText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>")
        let script = """
        tell application "Notes"
            tell default account
                make new note with properties {body:"\(escaped)"}
            end tell
            activate
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
}

struct TodoRowView: View {
    let task: TodoTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.isDone ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(task.title)
                .font(.system(size: 11, weight: task.isDone ? .regular : .medium))
                .strikethrough(task.isDone, color: .gray)
                .foregroundColor(task.isDone ? .gray.opacity(0.7) : .white)
                .lineLimit(2)
            
            Spacer()
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
        )
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = h
            }
        }
    }
}
