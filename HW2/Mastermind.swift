#!/usr/bin/env swift
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation
import Dispatch

struct NewGameResponse: Codable { let game_id: String }
struct GuessResult: Codable { let black: Int; let white: Int }
struct APIErrorResponse: Codable { let error: String }

enum APIError: Error {
    case invalidURL, network(String), decoding(String), server(String)
}

final class APIClient {
    private let base = "https://mastermind.darkube.app"
    private let session: URLSession
    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 20
        session = URLSession(configuration: cfg)
    }
    private func syncRequest(path: String, method: String, body: Data?) throws -> Data {
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let b = body {
            req.httpBody = b
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let sem = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?
        
        session.dataTask(with: req) { data, response, error in
            if let error {
                result = .failure(error)
            } else if let data {
                result = .success(data)
            } else {
                result = .failure(NSError(domain: "NetworkError", code: -1, userInfo: nil))
            }
            sem.signal()
        }.resume()
        
        _ = sem.wait(timeout: .now() + 20)
        guard let r = result else {
            throw APIError.network("empty response or timeout")
        }
        switch r {
        case .success(let d): return d
        case .failure(let e): throw APIError.network(e.localizedDescription)
        }
    }
    func createGame(retries: Int = 2) throws -> String {
        var last: Error?
        for _ in 0...retries {
            do {
                let d = try syncRequest(path: "/game", method: "POST", body: nil)
                if let g = try? JSONDecoder().decode(NewGameResponse.self, from: d) { return g.game_id }
                if let err = try? JSONDecoder().decode(APIErrorResponse.self, from: d) { throw APIError.server(err.error) }
                throw APIError.decoding("create game")
            } catch {
                last = error
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        throw last ?? APIError.network("unknown")
    }
    func submitGuess(gameID: String, guess: String) throws -> GuessResult {
        let payload = ["game_id": gameID, "guess": guess]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let d = try syncRequest(path: "/guess", method: "POST", body: body)
        if let gr = try? JSONDecoder().decode(GuessResult.self, from: d) { return gr }
        if let err = try? JSONDecoder().decode(APIErrorResponse.self, from: d) { throw APIError.server(err.error) }
        throw APIError.decoding("guess response")
    }
    func deleteGame(gameID: String) throws {
        _ = try syncRequest(path: "/game/\(gameID)", method: "DELETE", body: nil)
    }
}

final class StatsStore {
    private let path: String
    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.path
        path = dir + "/.mastermind_stats.json"
    }
    func load() -> [String:Any] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else { return [:] }
        return obj
    }
    func save(_ obj: [String:Any]) {
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            try? d.write(to: URL(fileURLWithPath: path))
        }
    }
}

final class Engine {
    private let api = APIClient()
    private let stats = StatsStore()
    private var gameID: String?
    private var roundStart: Date?
    private var attempts = 0
    private var history: [(String, Int, Int)] = []
    private var isOnline = false
    private let bold = "\u{001B}[1m"
    private let reset = "\u{001B}[0m"
    private let cyan = "\u{001B}[36m"
    private let green = "\u{001B}[32m"
    private let yellow = "\u{001B}[33m"
    private let magenta = "\u{001B}[35m"
    private let red = "\u{001B}[31m"
    
    func start() {
        showBanner()
        mainLoop()
    }
    private func showBanner() {
        print("""
\(bold)\(magenta)╔══════════════════════════════════════════╗\(reset)
\(bold)\(cyan)   ✨ Mastermind Pro — Ultimate Terminal ✨   \(reset)
\(bold)\(magenta)╚══════════════════════════════════════════╝\(reset)
""")
    }
    private func mainLoop() {
        while true {
            print("\nChoose: 1) Online  2) Local  3) Stats  4) Help  5) Quit  → ", terminator: "")
            guard let c = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            if c == "1" { startOnline(); continue }
            if c == "2" { startLocal(); continue }
            if c == "3" { showStats(); continue }
            if c == "4" { showHelp(); continue }
            if c == "5" || c.lowercased() == "quit" || c.lowercased() == "exit" { farewell(); break }
            print("\(red)Invalid option\(reset)")
        }
    }
    private func showHelp() {
        print("""
Commands during game:
\(bold)hint\(reset) \(yellow)- smart suggestion
\(bold)giveup\(reset) \(yellow)- reveal & end
\(bold)history\(reset) \(yellow)- show past guesses
\(bold)restart\(reset) \(yellow)- start new game
\(bold)menu\(reset) \(yellow)- return main menu
\(bold)exit\(reset) \(yellow)- quit entirely
""")
    }
    private func showStats() {
        let s = stats.load()
        if s.isEmpty { print("\(yellow)No stats yet\(reset)"); return }
        print("\n\(bold)Local Stats:\(reset)")
        for (k,v) in s { print("- \(k): \(v)") }
    }
    private func startOnline() {
        print("\n\(cyan)Connecting to server...\(reset)")
        do {
            let id = try api.createGame()
            gameID = id
            isOnline = true
            startGame()
        } catch {
            print("\(red)Failed to create online game: \(error)\(reset)")
        }
    }
    private func startLocal() {
        print("\nEnter secret for local game (4 digits 1..6): ", terminator: "")
        guard let s = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), validate(s) else {
            print("\(red)Invalid secret\(reset)"); return
        }
        isOnline = false
        gameID = nil
        startGame(secret: s)
    }
    private func startGame(secret: String? = nil) {
        attempts = 0
        history.removeAll()
        roundStart = Date()
        bannerRound()
        gameLoop(secret: secret)
    }
    private func bannerRound() {
        print("\n\(bold)\(green)— New Round Started —\(reset) \(yellow)\(Date())\(reset)")
        print("\(cyan)Type a 4-digit guess (1..6). Type \(bold)help\(reset) for commands.\(reset)")
    }
    private func gameLoop(secret: String?) {
        while true {
            attempts += 1
            print("\n\(bold)Attempt \(attempts)\(reset) -> ", terminator: "")
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { attempts -= 1; continue }
            if handleGlobal(line) { if line.lowercased() == "restart" { return } else { continue } }
            if !validate(line) { print("\(red)Guess must be 4 digits 1..6\(reset)"); attempts -= 1; continue }
            do {
                let (b,w) = try playMove(secret: secret, guess: line)
                history.append((line,b,w))
                printResult(b,w)
                if b == 4 {
                    recordWin()
                    postRoundOptions()
                    break
                }
            } catch {
                print("\(red)Error: \(error)\(reset)")
            }
        }
    }
    private func playMove(secret: String?, guess: String) throws -> (Int,Int) {
        if isOnline {
            guard let id = gameID else { throw APIError.network("no game id") }
            let res = try api.submitGuess(gameID: id, guess: guess)
            return (res.black, res.white)
        } else {
            guard let sec = secret else { throw APIError.network("no secret") }
            return localEval(secret: sec, guess: guess)
        }
    }
    private func localEval(secret: String, guess: String) -> (Int,Int) {
        var black = 0
        var sRem: [Character] = []
        var gRem: [Character] = []
        for (sc,gc) in zip(secret, guess) { if sc==gc { black+=1 } else { sRem.append(sc); gRem.append(gc) } }
        var freq: [Character:Int] = [:]
        for c in sRem { freq[c, default: 0] += 1 }
        var white = 0
        for c in gRem { if let cnt = freq[c], cnt>0 { white += 1; freq[c]! = cnt - 1 } }
        return (black, white)
    }
    private func printResult(_ black: Int, _ white: Int) {
        let pegs = String(repeating: "⬛", count: black) + String(repeating: "⚪", count: white)
        print("\(bold)\(green)Result:\(reset) \(pegs)  (B=\(black), W=\(white))")
    }
    private func handleGlobal(_ input: String) -> Bool {
        let cmd = input.lowercased()
        if cmd == "exit" || cmd == "quit" { farewell(); exit(0) }
        if cmd == "menu" { return true }
        if cmd == "history" { showHistory(); return true }
        if cmd == "giveup" { giveUp(); return true }
        if cmd == "restart" { print("\(yellow)Restarting...\(reset)"); return true }
        if cmd == "hint" { printHint(); return true }
        if cmd == "help" { showHelp(); return true }
        return false
    }
    private func showHistory() {
        if history.isEmpty { print("\(yellow)No guesses yet\(reset)"); return }
        print("\n\(bold)Guess History:\(reset)")
        for (i,h) in history.enumerated() { print("\(i+1). \(h.0) -> B:\(h.1) W:\(h.2)") }
    }
    private func giveUp() {
        if isOnline, let id = gameID { try? api.deleteGame(gameID: id) ; print("\(red)Online game terminated.\(reset)") }
        else { print("\(red)You gave up the local game.\(reset)") }
    }
    private func printHint() {
        let suggestion = smartHint()
        print("\(green)🔎 Suggestion: try \(bold)\(suggestion)\(reset)")
    }
    private func smartHint() -> String {
        var mustExclude: Set<Character> = []
        var positional: [Int:Character] = [:]
        for (g,b,w) in history {
            if b + w == 0 { for ch in g { mustExclude.insert(ch) } }
            if b > 0 {
                for (i,ch) in Array(g).enumerated() {
                    var countSamePos = 0
                    for h in history { if Array(h.0)[i] == ch { countSamePos += 1 } }
                    if countSamePos > 1 { positional[i] = ch }
                }
            }
        }
        var pool = Array("123456").filter { !mustExclude.contains($0) }
        if pool.isEmpty { pool = Array("123456") }
        var out = ""
        for i in 0..<4 {
            if let p = positional[i] { out.append(p); continue }
            out.append(pool.randomElement()!)
        }
        return out
    }
    private func recordWin() {
        let elapsed = Int(Date().timeIntervalSince(roundStart ?? Date()))
        var s = stats.load()
        var games = (s["games"] as? Int) ?? 0
        games += 1
        s["games"] = games
        let best = (s["best_attempts"] as? Int) ?? 9999
        if attempts < best { s["best_attempts"] = attempts }
        s["last_time"] = elapsed
        stats.save(s)
        print("\(bold)\(magenta)✅ Round complete! Stats updated.\(reset)")
    }
    private func postRoundOptions() {
        while true {
            print("\nChoose: 1) Play again  2) Main menu  3) Quit  → ", terminator: "")
            guard let c = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            if c == "1" { if isOnline { try? api.deleteGame(gameID: gameID ?? "") ; startOnline() } else { startLocal() }; break }
            if c == "2" { return }
            if c == "3" { farewell(); exit(0) }
            print("\(red)Invalid option\(reset)")
        }
    }
    private func farewell() {
        if let id = gameID { try? api.deleteGame(gameID: id) }
        print("\n\(bold)\(cyan)👋 Thanks for playing Mastermind Pro!\(reset)")
    }
    private func validate(_ s: String) -> Bool {
        guard s.count == 4 else { return false }
        for ch in s { if !"123456".contains(ch) { return false } }
        return true
    }
}

let engine = Engine()
engine.start()