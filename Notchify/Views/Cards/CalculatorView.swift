import SwiftUI
import AppKit

// MARK: - Calculator View
struct CalculatorView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var showCopiedCheck: Bool = false
    
    let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    let buttons = [
        ["7", "8", "9", "÷"],
        ["4", "5", "6", "×"],
        ["1", "2", "3", "-"],
        ["C", "0", "=", "+"]
    ]
    
    var body: some View {
        VStack(spacing: 6) {
            // Expression Bar & Quick Actions
            HStack {
                Text(viewModel.calcExpression)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                
                Spacer()
                
                // Backspace button
                Button(action: handleBackspace) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Delete last digit"))
                
                // Copy button
                Button(action: copyResult) {
                    HStack(spacing: 3) {
                        Image(systemName: showCopiedCheck ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .bold))
                        if showCopiedCheck {
                            Text(LanguageManager.tr("Copied!"))
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(showCopiedCheck ? .green : .white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(showCopiedCheck ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Copy result"))
            }
            .frame(height: 18)
            .padding(.horizontal, 4)
            
            // Main Number Display
            Button(action: copyResult) {
                Text(viewModel.calcInput)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: 32)
            }
            .buttonStyle(PlainButtonStyle())
            .help(LanguageManager.tr("Click to copy"))
            
            // Buttons Grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(buttons.flatMap { $0 }, id: \.self) { btn in
                    let isActiveOp = viewModel.calcOperator == btn && viewModel.calcIsNewInput
                    Button(action: { handlePress(btn) }) {
                        Text(btn)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isActiveOp ? .white : (isOperator(btn) ? .orange : .white))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                isActiveOp ? Color.orange : (isOperator(btn) ? Color.orange.opacity(0.2) : Color.white.opacity(0.12))
                            )
                            .cornerRadius(8)
                            .shadow(color: isActiveOp ? Color.orange.opacity(0.4) : .clear, radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func isOperator(_ btn: String) -> Bool {
        ["÷", "×", "-", "+", "="].contains(btn)
    }
    
    private func handleBackspace() {
        guard !viewModel.calcIsNewInput else { return }
        if viewModel.calcInput.count > 1 {
            viewModel.calcInput.removeLast()
        } else {
            viewModel.calcInput = "0"
        }
    }
    
    private func copyResult() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(viewModel.calcInput, forType: .string)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            showCopiedCheck = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedCheck = false }
        }
    }
    
    private func handlePress(_ btn: String) {
        if let num = Int(btn) {
            if viewModel.calcIsNewInput || viewModel.calcInput == "0" {
                viewModel.calcInput = "\(num)"
                viewModel.calcIsNewInput = false
            } else {
                viewModel.calcInput += "\(num)"
            }
        } else if btn == "C" {
            viewModel.calcInput = "0"
            viewModel.calcPrevious = nil
            viewModel.calcOperator = nil
            viewModel.calcExpression = ""
            viewModel.calcIsNewInput = false
        } else if btn == "=" {
            if let op = viewModel.calcOperator, let prev = viewModel.calcPrevious, let current = Double(viewModel.calcInput) {
                viewModel.calcExpression = "\(formatDouble(prev)) \(op) \(formatDouble(current)) ="
                calculate()
                viewModel.calcOperator = nil
                viewModel.calcIsNewInput = true
            }
        } else {
            // Operator pressed (+, -, ×, ÷)
            if viewModel.calcOperator != nil && !viewModel.calcIsNewInput {
                calculate()
            } else {
                viewModel.calcPrevious = Double(viewModel.calcInput)
            }
            viewModel.calcOperator = btn
            viewModel.calcExpression = "\(viewModel.calcInput) \(btn)"
            viewModel.calcIsNewInput = true
        }
    }
    
    private func formatDouble(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 && abs(val) < 1e12 {
            return "\(Int(val))"
        } else {
            return String(format: "%g", val)
        }
    }
    
    private func calculate() {
        guard let op = viewModel.calcOperator, let prev = viewModel.calcPrevious, let current = Double(viewModel.calcInput) else { return }
        var result: Double = 0
        switch op {
        case "+": result = prev + current
        case "-": result = prev - current
        case "×": result = prev * current
        case "÷": result = current != 0 ? prev / current : 0
        default: break
        }
        viewModel.calcInput = formatDouble(result)
        viewModel.calcPrevious = result
    }
}

// MARK: - Media Card View
