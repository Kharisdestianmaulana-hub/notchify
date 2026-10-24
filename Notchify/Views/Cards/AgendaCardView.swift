import SwiftUI


struct AgendaCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    @State private var isAdding = false
    @State private var newTitle = ""
    @State private var newMeetingURL = ""
    @State private var newTime = Date()
    @State private var newColor = "blue"
    @State private var newIsYearly = false
    @State private var hoveredEventId: UUID? = nil
    
    let colors = ["red", "blue", "green", "yellow", "purple"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAdding {
                addForm
            } else {
                listView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            viewModel.fetchAgenda()
            resetNewTime()
        }
        .onReceive(timer) { _ in
            if !isAdding { viewModel.fetchAgenda() }
        }
        .onChange(of: viewModel.agendaDateOffset) { _ in
            resetNewTime()
        }
        .onChange(of: isAdding) { newValue in
            viewModel.isPinningExpansion = newValue
        }
    }
    
    private func resetNewTime() {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day, value: viewModel.agendaDateOffset, to: Date()) ?? Date()
        newTime = target
    }
    
    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LanguageManager.tr("Add New Event"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            TextField(LanguageManager.tr("Event title..."), text: $newTitle)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.white)
                .font(.system(size: 13))
            
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 11))
                    .foregroundColor(newMeetingURL.isEmpty ? .gray : Color(red: 0.2, green: 0.9, blue: 0.45))
                TextField(LanguageManager.tr("Meeting link (Zoom, Meet, Teams)..."), text: $newMeetingURL)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            .padding(7)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            
            HStack {
                Text(LanguageManager.tr("Time:"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                DatePicker("", selection: $newTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(FieldDatePickerStyle())
            }
            
            HStack(spacing: 12) {
                Text(LanguageManager.tr("Color:"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                ForEach(colors, id: \.self) { cName in
                    Circle()
                        .fill(colorFor(cName))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.white, lineWidth: newColor == cName ? 2 : 0))
                        .onTapGesture { newColor = cName }
                }
            }
            .padding(.top, 2)
            
            Toggle(isOn: $newIsYearly) {
                Text(LanguageManager.tr("Yearly (Birthday/Anniversary)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .toggleStyle(CheckboxToggleStyle())
            
            Spacer(minLength: 0)
            
            HStack {
                Button(action: {
                    newMeetingURL = ""
                    withAnimation { isAdding = false }
                }) {
                    Text(LanguageManager.tr("Cancel"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    let ev = CustomEvent(
                        title: newTitle.isEmpty ? "Untitled" : newTitle,
                        date: newTime,
                        colorName: newColor,
                        isYearly: newIsYearly,
                        meetingURL: newMeetingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newMeetingURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    CustomAgendaManager.shared.addEvent(ev)
                    viewModel.fetchAgenda()
                    viewModel.checkUpcomingMeeting()
                    newTitle = ""
                    newMeetingURL = ""
                    withAnimation { isAdding = false }
                }) {
                    Text(LanguageManager.tr("Save"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 275)
        .onDisappear {
            isAdding = false
            newIsYearly = false
            newMeetingURL = ""
            viewModel.isPinningExpansion = false
        }
    }
    
    private var listView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                header
                Spacer()
                Button(action: {
                    withAnimation { isAdding = true }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if viewModel.agendaEvents.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "calendar.badge.minus")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LanguageManager.tr("No schedule 🎉"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.agendaEvents) { event in
                            eventRow(for: event)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(height: 130)
            }
            
            Spacer(minLength: 0)
            
            // Pagination dots
            HStack(spacing: 8) {
                Spacer()
                ForEach(-1...1, id: \.self) { offset in
                    Circle()
                        .fill(viewModel.agendaDateOffset == offset ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .onTapGesture {
                            withAnimation {
                                viewModel.agendaDateOffset = offset
                                viewModel.fetchAgenda()
                            }
                        }
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            countdownView
        }
    }
    
    private var header: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMM"
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: viewModel.agendaDateOffset, to: Date()) ?? Date()
        
        var prefix = LanguageManager.tr("Today")
        if viewModel.agendaDateOffset == -1 { prefix = "Kemarin" }
        else if viewModel.agendaDateOffset == 1 { prefix = LanguageManager.tr("Tomorrow") }
        
        return Text("\(prefix) — \(formatter.string(from: targetDate))")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
    }
    
    private func eventRow(for event: CustomEvent) -> some View {
        let isNow = event.isNow
        let isPast = event.isPast
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return HStack(spacing: 10) {
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
                .opacity(isPast ? 0.3 : 1.0)
            
            Text(formatter.string(from: event.date))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(isPast ? .gray : .white)
                .frame(width: 48, alignment: .leading)
            
            Text(event.title)
                .font(.system(size: 14, weight: isNow ? .bold : .medium))
                .foregroundColor(isPast ? .gray : .white)
                .lineLimit(1)
            
            // Direct Join pill in event row
            if let meetingURL = event.meetingLink {
                Button(action: {
                    NSWorkspace.shared.open(meetingURL)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                        Text(LanguageManager.tr("Join"))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.18, green: 0.75, blue: 0.38))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Join Now"))
            }
            
            Spacer()
            
            if hoveredEventId == event.id {
                Button(action: {
                    withAnimation {
                        CustomAgendaManager.shared.deleteEvent(id: event.id)
                        viewModel.fetchAgenda()
                        viewModel.checkUpcomingMeeting()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isNow ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovering in
            if isHovering { hoveredEventId = event.id }
            else if hoveredEventId == event.id { hoveredEventId = nil }
        }
    }
    
    private var countdownView: some View {
        Group {
            if let nextEvent = viewModel.agendaEvents.first(where: { !$0.isPast }) {
                countdownText(for: nextEvent)
            } else {
                Text(LanguageManager.tr("No upcoming schedule"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func countdownText(for event: CustomEvent) -> some View {
        let diff = Int(event.date.timeIntervalSince(Date()))
        if diff > 0 {
            let hours = diff / 3600
            let minutes = (diff % 3600) / 60
            let timeStr = hours > 0 ? "\(hours)j \(minutes)m" : "\(minutes)m"
            return HStack(spacing: 5) {
                if event.hasMeetingLink {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.45))
                }
                Text("\(LanguageManager.tr("Next:")) \(event.title) — \(timeStr) \(LanguageManager.tr("left"))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                    .lineLimit(1)
            }
        } else {
            return HStack(spacing: 5) {
                if event.hasMeetingLink {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.45))
                }
                Text("\(LanguageManager.tr("Next:")) \(event.title) — \(LanguageManager.tr("In progress"))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.45))
                    .lineLimit(1)
            }
        }
    }
    
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
}

