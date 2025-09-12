import Foundation

func readTrimmedLine() -> String? {
    guard let line = readLine() else { return nil }
    return line.trimmingCharacters(in: .whitespacesAndNewlines)
}

func exitIfRequested(_ s: String?) {
    if let tok = s?.lowercased() {
        if tok == "exit" {
            print("\n👋 Goodbye! Thanks for playing.")
            exit(0)
        }
    }
}

func randomSecret() -> [Int] {
    return (0..<4).map { _ in Int.random(in: 1...6) }
}

func parseDigits(_ s: String) -> [Int]? {
    if s.count != 4 { return nil }
    var out = [Int]()
    for ch in s {
        if let d = Int(String(ch)), (1...6).contains(d) {
            out.append(d)
        } else {
            return nil
        }
    }
    return out
}

func evaluate(secret: [Int], guess: [Int]) -> (black: Int, white: Int) {
    var black = 0
    var secretRemain = [Int]()
    var guessRemain = [Int]()
    for i in 0..<4 {
        if secret[i] == guess[i] {
            black += 1
        } else {
            secretRemain.append(secret[i])
            guessRemain.append(guess[i])
        }
    }
    var freq = [Int:Int]()
    for v in secretRemain { freq[v, default: 0] += 1 }
    var white = 0
    for v in guessRemain {
        if let c = freq[v], c > 0 {
            white += 1
            freq[v]! = c - 1
        }
    }
    return (black, white)
}

func pegString(black: Int, white: Int) -> String {
    return String(repeating: "⬛", count: black) + String(repeating: "⚪", count: white)
}

let bold = "\u{001B}[1m"
let reset = "\u{001B}[0m"
let blue = "\u{001B}[34m"
let green = "\u{001B}[32m"
let yellow = "\u{001B}[33m"
let cyan = "\u{001B}[36m"
let magenta = "\u{001B}[35m"

func printHeader() {
    print("""
\(bold)\(cyan)========================================\(reset)
\(bold)\(green)🎯 Mastermind — Terminal Edition\(reset)
\(cyan)========================================\(reset)
Commands: type a 4-digit guess (digits 1..6). Type \(bold)exit\(reset) to quit, \(bold)hint\(reset) for a hint, \(bold)giveup\(reset) to reveal the code.
""")
}

func chooseMode() -> Int {
    print("""
Select mode:
1) Random secret (single-player)
2) Enter secret for another player (two-player)
3) Show quick help
Enter 1/2/3 or \(bold)exit\(reset):
""", terminator: " ")
    while true {
        if let line = readTrimmedLine() {
            exitIfRequested(line)
            if line == "1" || line == "2" || line == "3" {
                return Int(line)!
            }
        }
        print("Invalid input. Please enter 1, 2 or 3: ", terminator: "")
    }
}

func readSecretFromPlayer() -> [Int] {
    print("\n🔒 Player 2: Enter a secret 4-digit code (each digit 1..6). Type \(bold)exit\(reset) to quit.")
    while true {
        if let line = readTrimmedLine() {
            exitIfRequested(line)
            if let digits = parseDigits(line) {
                for _ in 0..<30 { print("") }
                return digits
            }
        }
        print("Invalid code — exactly 4 digits from 1 to 6. Try again: ", terminator: "")
    }
}

func formatDuration(_ s: TimeInterval) -> String {
    let intS = Int(s)
    let minutes = intS / 60
    let seconds = intS % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

func printFooter() {
    print("\n✨ Thank you for playing Mastermind. See you next time! ✨")
}

func playOneRound(secret: [Int]) {
    var attempts = 0
    let start = Date()
    var history = [(guess: [Int], black: Int, white: Int)]()
    var hintGiven = 0
    let maxHints = 2
    print("\n🔐 Game started — Guess the 4-digit code (1..6).")
    while true {
        attempts += 1
        print("\n\(bold)\(magenta)Attempt \(attempts)\(reset) — enter your guess:", terminator: " ")
        guard let line = readTrimmedLine() else {
            print("No input detected. Try again.")
            continue
        }
        exitIfRequested(line)
        let lower = line.lowercased()
        if lower == "hint" {
            if hintGiven >= maxHints {
                print("\(yellow)No more hints available. Maximum \(maxHints) hints used.\(reset)")
                continue
            }
            let revealedIndex = Int.random(in: 0..<4)
            print("\(cyan)🔎 Hint: Digit at position \(revealedIndex+1) is \(secret[revealedIndex]). (\(hintGiven+1)/\(maxHints) hints used)\(reset)")
            hintGiven += 1
            continue
        }
        if lower == "giveup" {
            print("\n\(redText("⚠️ Reveal")) The secret code was \(secret.map(String.init).joined()).")
            break
        }
        if let guess = parseDigits(line) {
            let (black, white) = evaluate(secret: secret, guess: guess)
            history.append((guess, black, white))
            let peg = pegString(black: black, white: white)
            print("\(bold)Result:\(reset) \(peg)  (B=\(black), W=\(white))")
            if black == 4 {
                let elapsed = Date().timeIntervalSince(start)
                print("\n\(green)🎉 You cracked the code in \(attempts) attempts! Time: \(formatDuration(elapsed))\(reset)")
                print("\(blue)Secret: \(secret.map(String.init).joined())\(reset)")
                print("\n\(bold)History:\(reset)")
                for (i, entry) in history.enumerated() {
                    print("\(i+1). Guess: \(entry.guess.map(String.init).joined()) -> B:\(entry.black) W:\(entry.white)")
                }
                break
            } else {
                if attempts % 5 == 0 {
                    print("\(yellow)Tip: You can type \(bold)hint\(reset)\(yellow) for up to \(maxHints) hints or \(bold)giveup\(reset)\(yellow) to reveal the code.\(reset)")
                }
            }
        } else {
            print("\(redText("✖ Invalid guess")) Enter exactly 4 digits between 1 and 6, or a command like \(bold)hint\(reset).")
        }
    }
}

func redText(_ s: String) -> String {
    return "\u{001B}[31m\(s)\(reset)"
}

func mainLoop() {
    printHeader()
    outer: while true {
        let mode = chooseMode()
        switch mode {
        case 1:
            let secret = randomSecret()
            playOneRound(secret: secret)
        case 2:
            let secret = readSecretFromPlayer()
            playOneRound(secret: secret)
        case 3:
            print("""
Quick help:
• Black peg ⬛ = correct digit and position
• White peg ⚪ = correct digit wrong position
• Commands: \(bold)exit\(reset), \(bold)hint\(reset), \(bold)giveup\(reset)
Examples:
Secret 1234 -> Guess 1235 => ⬛⬛⬛
Secret 1234 -> Guess 4321 => ⚪⚪⚪⚪
""")
        default:
            break
        }
        print("\nWould you like to play again? (y/n): ", terminator: "")
        if let ans = readTrimmedLine() {
            exitIfRequested(ans)
            if ans.lowercased() == "y" || ans.lowercased() == "yes" || ans == "1" {
                continue outer
            } else {
                printFooter()
                break outer
            }
        } else {
            break outer
        }
    }
}

mainLoop()