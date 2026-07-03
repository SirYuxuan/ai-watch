//
//  ContentView.swift
//  ai-watch
//
//  Created by Sir丶雨轩 on 2026/7/2.
//

import AppKit
import Combine
import CryptoKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var monitor: QuotaMonitor
    @State private var selectedType = "all"

    private var filteredAccounts: [AccountQuota] {
        let visibleAccounts = monitor.hidesDisabledAccounts
            ? monitor.accounts.filter { !$0.disabled }
            : monitor.accounts
        if selectedType == "all" {
            return visibleAccounts
        }
        return visibleAccounts.filter { $0.type == selectedType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            Picker("", selection: $selectedType) {
                Text("全部").tag("all")
                Text("Claude").tag("claude")
                Text("Codex").tag("codex")
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 2)

            accountList

            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Watch")
                    .font(.headline)
                Text(monitor.lastUpdatedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                monitor.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("配置")

            Button {
                monitor.openDiagnosticsWindow()
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("诊断日志")

            Button {
                Task {
                    await monitor.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(monitor.isLoading)
            .help("刷新")
        }
    }

    @ViewBuilder
    private var accountList: some View {
        if monitor.isLoading && monitor.accounts.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 32)
                Spacer()
            }
        } else if let message = monitor.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label("读取失败", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if filteredAccounts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("暂无额度数据")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(filteredAccounts) { account in
                        AccountQuotaRow(account: account)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 500)
        }
    }

    private var footer: some View {
        HStack {
            if monitor.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("刷新中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(monitor.refreshClockText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(filteredAccounts.count) 个账号")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var monitor: QuotaMonitor
    @State private var baseURL = ""
    @State private var token = ""
    @State private var refreshIntervalMinutes = 5
    @State private var hidesDisabledAccounts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("配置")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            TextField("Base URL", text: $baseURL)
                .textFieldStyle(.roundedBorder)

            SecureField("Token", text: $token)
                .textFieldStyle(.roundedBorder)

            Text(monitor.tokenFingerprint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Stepper("刷新间隔：\(refreshIntervalMinutes) 分钟", value: $refreshIntervalMinutes, in: 1...60)

            Toggle("不显示禁用账号", isOn: $hidesDisabledAccounts)
                .toggleStyle(.checkbox)

            HStack {
                Spacer()

                Button {
                    monitor.saveSettings(
                        baseURL: baseURL,
                        token: token,
                        refreshIntervalMinutes: refreshIntervalMinutes,
                        hidesDisabledAccounts: hidesDisabledAccounts
                    )
                    dismiss()
                } label: {
                    Label("保存并刷新", systemImage: "checkmark.circle")
                }
            }
        }
        .padding(18)
        .frame(width: 430)
        .onAppear {
            baseURL = monitor.baseURL
            token = monitor.token
            refreshIntervalMinutes = monitor.refreshIntervalMinutes
            hidesDisabledAccounts = monitor.hidesDisabledAccounts
        }
    }
}

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var monitor: QuotaMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("诊断日志")
                    .font(.headline)

                Text("\(monitor.logs.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    monitor.clearLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.borderless)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            ScrollView {
                Text(monitor.diagnosticLogText)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
        .frame(width: 620, height: 420)
    }
}

struct AccountQuotaRow: View {
    let account: AccountQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(account.account)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(account.type.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.14))
                    .foregroundStyle(typeColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if account.disabled {
                    Circle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 6, height: 6)
                        .help("禁用账号")
                }

                Spacer()
            }

            if let errorMessage = account.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else {
                QuotaProgressRow(title: "5h", quota: account.fiveHour)
                QuotaProgressRow(title: "7d", quota: account.sevenDay)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(account.disabled ? 0.62 : 1)
    }

    private var typeColor: Color {
        account.type == "codex" ? .blue : .purple
    }

    private static func formatReset(_ date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let resetText = QuotaDateFormatter.shared.string(from: date)
        if remaining <= 0 {
            return "\(resetText) 已重置"
        }
        if hours > 0 {
            return "\(resetText) 剩 \(hours)小时\(minutes)分"
        }
        return "\(resetText) 剩 \(minutes)分"
    }
}

struct QuotaProgressRow: View {
    let title: String
    let quota: QuotaWindow

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)

            ProgressView(value: quota.progressValue)
                .tint(quota.remainingColor)
                .controlSize(.small)

            Text(quota.remainingPercentText)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(quota.remainingColor)
                .frame(width: 36, alignment: .trailing)

            Text(quota.resetClockText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 70, alignment: .trailing)
        }
    }
}

@MainActor
final class QuotaMonitor: ObservableObject {
    @Published private(set) var baseURL: String
    @Published private(set) var token: String
    @Published private(set) var refreshIntervalMinutes: Int
    @Published private(set) var hidesDisabledAccounts: Bool
    @Published private(set) var accounts: [AccountQuota] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var logs: [String] = []

    private var refreshTask: Task<Void, Never>?
    private var settingsWindow: NSWindow?
    private var diagnosticsWindow: NSWindow?

    var menuBarSymbol: String {
        if isLoading {
            return "arrow.triangle.2.circlepath"
        }
        return errorMessage == nil ? "chart.bar.xaxis" : "exclamationmark.triangle"
    }

    var lastUpdatedText: String {
        guard let lastUpdated else {
            return "尚未刷新"
        }
        return "上次刷新 \(QuotaDateFormatter.shared.string(from: lastUpdated))"
    }

    var refreshClockText: String {
        guard let lastUpdated else {
            return "刷新 --:--:--"
        }
        return "刷新 \(RefreshTimeFormatter.shared.string(from: lastUpdated))"
    }

    var tokenFingerprint: String {
        guard !token.isEmpty else {
            return "当前未保存 Token"
        }
        let digest = SHA256.hash(data: Data(token.utf8))
            .prefix(6)
            .map { String(format: "%02x", $0) }
            .joined()
        return "已保存 Token：\(token)，长度 \(token.count)，SHA256 \(digest)..."
    }

    var diagnosticLogText: String {
        logs.isEmpty ? "暂无日志" : logs.joined(separator: "\n")
    }

    init() {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: DefaultsKey.baseURL) ?? ""
        token = defaults.string(forKey: DefaultsKey.token) ?? ""
        refreshIntervalMinutes = max(1, defaults.integer(forKey: DefaultsKey.refreshIntervalMinutes))
        hidesDisabledAccounts = defaults.bool(forKey: DefaultsKey.hidesDisabledAccounts)
        if defaults.object(forKey: DefaultsKey.refreshIntervalMinutes) == nil {
            refreshIntervalMinutes = 5
        }
        appendLog("启动：baseURL=\(baseURL), \(tokenFingerprint)")
        startRefreshLoop()
    }

    deinit {
        refreshTask?.cancel()
    }

    func saveSettings(baseURL: String, token: String, refreshIntervalMinutes: Int, hidesDisabledAccounts: Bool) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.refreshIntervalMinutes = max(1, refreshIntervalMinutes)
        self.hidesDisabledAccounts = hidesDisabledAccounts

        let defaults = UserDefaults.standard
        defaults.set(self.baseURL, forKey: DefaultsKey.baseURL)
        defaults.set(self.token, forKey: DefaultsKey.token)
        defaults.set(self.refreshIntervalMinutes, forKey: DefaultsKey.refreshIntervalMinutes)
        defaults.set(self.hidesDisabledAccounts, forKey: DefaultsKey.hidesDisabledAccounts)

        appendLog("保存配置：baseURL=\(self.baseURL), \(tokenFingerprint), interval=\(self.refreshIntervalMinutes)m, hideDisabled=\(self.hidesDisabledAccounts)")
        startRefreshLoop()
    }

    func openSettingsWindow() {
        settingsWindow = showWindow(
            settingsWindow,
            title: "配置",
            size: NSSize(width: 430, height: 260),
            rootView: SettingsView().environmentObject(self)
        )
    }

    func openDiagnosticsWindow() {
        diagnosticsWindow = showWindow(
            diagnosticsWindow,
            title: "诊断日志",
            size: NSSize(width: 620, height: 420),
            rootView: DiagnosticsView().environmentObject(self)
        )
    }

    func refresh() async {
        await refresh(automatic: false)
    }

    private func refresh(automatic: Bool) async {
        guard !isLoading else {
            appendLog("跳过刷新：已有刷新任务进行中")
            return
        }
        guard !token.isEmpty else {
            errorMessage = "请先配置 AI 管理 Token"
            accounts = []
            appendLog("刷新失败：未配置 Token")
            return
        }

        appendLog("开始\(automatic ? "自动" : "手动")刷新：baseURL=\(baseURL), \(tokenFingerprint)")
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            let client = QuotaAPIClient(baseURL: baseURL, token: token) { [weak self] message in
                Task { @MainActor in
                    self?.appendLog(message)
                }
            }
            let authFiles = try await client.fetchAuthFiles()
            appendLog("账号列表：total=\(authFiles.count), supported=\(authFiles.filter { $0.type == "claude" || $0.type == "codex" }.count)")
            var nextAccounts: [AccountQuota] = []

            for file in authFiles where file.type == "claude" || file.type == "codex" {
                do {
                    appendLog("读取额度：type=\(file.type), account=\(maskAccount(file.account))")
                    let usage = try await client.fetchUsage(for: file)
                    appendLog("读取成功：type=\(file.type), account=\(maskAccount(file.account)), fiveHour=\(usage.fiveHour.logText), sevenDay=\(usage.sevenDay.logText)")
                    nextAccounts.append(AccountQuota(
                        account: file.account,
                        type: file.type,
                        disabled: file.disabled,
                        fiveHour: usage.fiveHour,
                        sevenDay: usage.sevenDay,
                        errorMessage: nil
                    ))
                } catch {
                    appendLog("读取失败：type=\(file.type), account=\(maskAccount(file.account)), error=\(error.localizedDescription)")
                    nextAccounts.append(AccountQuota(
                        account: file.account,
                        type: file.type,
                        disabled: file.disabled,
                        fiveHour: .empty,
                        sevenDay: .empty,
                        errorMessage: error.localizedDescription
                    ))
                }
            }

            accounts = nextAccounts.sorted {
                ($0.type, $0.account) < ($1.type, $1.account)
            }
            lastUpdated = Date()
            appendLog("刷新完成：accounts=\(accounts.count)")
        } catch {
            errorMessage = error.localizedDescription
            appendLog("刷新失败：\(error.localizedDescription)")
            if automatic && isAuthBlocked(error.localizedDescription) {
                refreshTask?.cancel()
                refreshTask = nil
                appendLog("已暂停自动刷新：认证失败或 IP 被封禁")
            }
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                await self.refresh(automatic: true)
                try? await Task.sleep(for: .seconds(self.refreshIntervalMinutes * 60))
            }
        }
    }

    private func isAuthBlocked(_ message: String) -> Bool {
        message.contains("invalid management key")
            || message.contains("IP banned")
            || message.contains("HTTP 401")
            || message.contains("HTTP 403")
    }

    func clearLogs() {
        logs = []
    }

    private func showWindow<Content: View>(
        _ existingWindow: NSWindow?,
        title: String,
        size: NSSize,
        rootView: Content
    ) -> NSWindow {
        let window: NSWindow
        if let existingWindow {
            window = existingWindow
            window.contentView = NSHostingView(rootView: rootView)
        } else {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = title
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: rootView)
            window.center()
        }
        window.setContentSize(size)
        NSApp.setActivationPolicy(.accessory)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }

    private func appendLog(_ message: String) {
        let line = "\(LogDateFormatter.shared.string(from: Date())) \(message)"
        print("[AI Watch] \(line)")
        logs.append(line)
        if logs.count > 80 {
            logs.removeFirst(logs.count - 80)
        }
    }

    private func maskAccount(_ account: String) -> String {
        if account.count <= 4 {
            return "****"
        }
        return "\(account.prefix(2))***\(account.suffix(2))"
    }

}

struct AccountQuota: Identifiable {
    var id: String {
        "\(type):\(account)"
    }

    let account: String
    let type: String
    let disabled: Bool
    let fiveHour: QuotaWindow
    let sevenDay: QuotaWindow
    let errorMessage: String?
}

struct AuthFile {
    let account: String
    let disabled: Bool
    let type: String
    let name: String
    let authIndex: String
    let chatgptAccountId: String?
}

struct UsageWindow {
    let fiveHour: QuotaWindow
    let sevenDay: QuotaWindow
}

struct QuotaWindow {
    let resetAt: Date?
    let utilizationPercent: Double?
    let remainingPercent: Double?
    let remainingDollars: Double?
    let limitDollars: Double?
    let usedDollars: Double?

    static let empty = QuotaWindow(
        resetAt: nil,
        utilizationPercent: nil,
        remainingPercent: nil,
        remainingDollars: nil,
        limitDollars: nil,
        usedDollars: nil
    )

    var remainingText: String {
        var parts: [String] = []
        if let remainingPercent {
            parts.append("剩余 \(formatPercent(remainingPercent))")
        }
        if let remainingDollars {
            parts.append("余额 $\(formatNumber(remainingDollars))")
        }
        return parts.isEmpty ? "剩余额度未返回" : parts.joined(separator: " · ")
    }

    var remainingCompactText: String {
        if let remainingPercent {
            return "剩 \(formatPercent(remainingPercent))"
        }
        if let remainingDollars {
            return "$\(formatNumber(remainingDollars))"
        }
        return "剩 --"
    }

    var remainingPercentText: String {
        remainingPercent.map(formatPercent) ?? "--"
    }

    var usageText: String {
        var parts: [String] = []
        if let utilizationPercent {
            parts.append("已用 \(formatPercent(utilizationPercent))")
        }
        if let usedDollars {
            parts.append("用量 $\(formatNumber(usedDollars))")
        }
        if let limitDollars {
            parts.append("上限 $\(formatNumber(limitDollars))")
        }
        return parts.isEmpty ? "用量未返回" : parts.joined(separator: " · ")
    }

    var remainingColor: Color {
        guard let remainingPercent else {
            return .secondary
        }
        if remainingPercent <= 10 {
            return .red
        }
        if remainingPercent <= 30 {
            return .orange
        }
        return .green
    }

    var progressValue: Double {
        guard let remainingPercent else {
            return 0
        }
        return min(max(remainingPercent / 100, 0), 1)
    }

    var resetCompactText: String {
        guard let resetAt else {
            return "未返回"
        }
        let remaining = max(0, Int(resetAt.timeIntervalSinceNow))
        if remaining <= 0 {
            return "已重置"
        }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var resetClockText: String {
        resetAt.map(QuotaDateFormatter.shared.string(from:)) ?? "--"
    }

    var logText: String {
        "reset=\(resetAt.map(QuotaDateFormatter.shared.string(from:)) ?? "nil"), \(remainingText), \(usageText)"
    }

    var hasData: Bool {
        resetAt != nil
            || utilizationPercent != nil
            || remainingPercent != nil
            || remainingDollars != nil
            || limitDollars != nil
            || usedDollars != nil
    }

    private func formatPercent(_ value: Double) -> String {
        "\(formatNumber(value))%"
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

struct QuotaAPIClient {
    let baseURL: String
    let token: String
    let log: (String) -> Void

    func fetchAuthFiles() async throws -> [AuthFile] {
        let json = try await send(path: "/v0/management/auth-files", method: "GET", body: nil)
        guard let files = json["files"].arrayValue else {
            throw QuotaError.message("AI 账号列表返回格式不支持")
        }

        return files.compactMap { file in
            guard
                let account = file["account"].stringValue,
                let type = file["type"].stringValue,
                let name = file["name"].stringValue,
                let authIndex = file["auth_index"].stringValue
            else {
                return nil
            }
            return AuthFile(
                account: account,
                disabled: file["disabled"].boolValue ?? false,
                type: type,
                name: name,
                authIndex: authIndex,
                chatgptAccountId: file["id_token"]["chatgpt_account_id"].stringValue
            )
        }
    }

    func fetchUsage(for file: AuthFile) async throws -> UsageWindow {
        let response = try await send(
            path: "/v0/management/api-call",
            method: "POST",
            body: try apiCallBody(for: file)
        )

        let statusCode = response["status_code"].intValue ?? 0
        log("api-call 返回：type=\(file.type), statusCode=\(statusCode), bodyType=\(response["body"].kindName)")
        if statusCode >= 400 {
            throw QuotaError.message("读取 AI 账号刷新信息失败（HTTP \(statusCode)）：\(response["body"].displayText)")
        }

        let body = try parseApiCallBody(response["body"])
        return UsageWindow(
            fiveHour: findFiveHourWindow(body),
            sevenDay: findSevenDayWindow(body)
        )
    }

    private func send(path: String, method: String, body: JSONValue?) async throws -> JSONValue {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path) else {
            throw QuotaError.message("Base URL 无效")
        }

        log("HTTP 请求：\(method) \(url.absoluteString), token=\(token), tokenLength=\(token.count), tokenSHA256=\(token.shortSHA256)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "X-Management-Key")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let responseText = String(data: data, encoding: .utf8) ?? ""
        log("HTTP 响应：\(method) \(path), status=\(statusCode), bytes=\(data.count)")
        if statusCode >= 400 {
            log("HTTP 错误体：\(String(responseText.prefix(500)))")
            throw QuotaError.message("请求失败（HTTP \(statusCode)）：\(String(responseText.prefix(500)))")
        }
        return try JSONDecoder().decode(JSONValue.self, from: data.isEmpty ? Data("{}".utf8) : data)
    }

    private func apiCallBody(for file: AuthFile) throws -> JSONValue {
        if file.type == "codex" {
            guard let accountId = file.chatgptAccountId, !accountId.isEmpty else {
                throw QuotaError.message("Codex 账号缺少 ChatGPT Account Id：\(file.account)")
            }
            return .object([
                "authIndex": .string(file.authIndex),
                "method": .string("GET"),
                "url": .string("https://chatgpt.com/backend-api/wham/usage"),
                "header": .object([
                    "Authorization": .string("Bearer $TOKEN$"),
                    "Content-Type": .string("application/json"),
                    "User-Agent": .string("codex_cli_rs/0.76.0 (Debian 13.0.0; x86_64) WindowsTerminal"),
                    "Chatgpt-Account-Id": .string(accountId)
                ])
            ])
        }

        return .object([
            "authIndex": .string(file.authIndex),
            "method": .string("GET"),
            "url": .string("https://api.anthropic.com/api/oauth/usage"),
            "header": .object([
                "Authorization": .string("Bearer $TOKEN$"),
                "Content-Type": .string("application/json"),
                "anthropic-beta": .string("oauth-2025-04-20")
            ])
        ])
    }

    private func parseApiCallBody(_ body: JSONValue) throws -> JSONValue {
        if body.objectValue != nil || body.arrayValue != nil {
            return body
        }
        guard let text = body.stringValue else {
            return .object([:])
        }
        return try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    private func findFiveHourWindow(_ node: JSONValue) -> QuotaWindow {
        let claudeWindow = quotaWindow(node["five_hour"], resetKey: "resets_at", smallPercentIsRatio: true)
        if claudeWindow.hasData {
            return claudeWindow
        }
        if let codexNode = codexRateLimitWindow(node, windowSeconds: 18_000, preferredKey: "primary_window") {
            return quotaWindow(codexNode, resetKey: "reset_at", smallPercentIsRatio: false)
        }
        for limit in node["limits"].arrayValue ?? [] {
            let kind = limit["kind"].stringValue
            let group = limit["group"].stringValue
            if kind == "session" || group == "session" {
                return quotaWindow(limit, resetKey: "resets_at", smallPercentIsRatio: false)
            }
        }
        return .empty
    }

    private func findSevenDayWindow(_ node: JSONValue) -> QuotaWindow {
        let claudeWindow = quotaWindow(node["seven_day"], resetKey: "resets_at", smallPercentIsRatio: true)
        if claudeWindow.hasData {
            return claudeWindow
        }
        if let codexNode = codexRateLimitWindow(node, windowSeconds: 604_800, preferredKey: "secondary_window") {
            return quotaWindow(codexNode, resetKey: "reset_at", smallPercentIsRatio: false)
        }
        for limit in node["limits"].arrayValue ?? [] {
            let kind = limit["kind"].stringValue
            let group = limit["group"].stringValue
            if kind == "weekly_all" || group == "weekly" {
                return quotaWindow(limit, resetKey: "resets_at", smallPercentIsRatio: false)
            }
        }
        return .empty
    }

    private func quotaWindow(_ node: JSONValue, resetKey: String, smallPercentIsRatio: Bool) -> QuotaWindow {
        let utilization = normalizePercent(firstNumber(node["utilization"]), smallValueIsRatio: true)
            ?? normalizePercent(
                firstNumber(
                    node["used_percent"],
                    node["usedPercent"],
                    node["usage_percent"],
                    node["percent_used"]
                ),
                smallValueIsRatio: smallPercentIsRatio
            )
        let explicitRemaining = normalizePercent(
            firstNumber(
                node["remaining_percent"],
                node["remainingPercent"],
                node["percent_remaining"],
                node["available_percent"]
            ),
            smallValueIsRatio: smallPercentIsRatio
        )
        let remaining = explicitRemaining ?? utilization.map { max(0, 100 - $0) }

        return QuotaWindow(
            resetAt: parseResetAt(node[resetKey])
                ?? parseResetAt(node["resets_at"])
                ?? parseResetAt(node["resetAt"])
                ?? parseResetAfterSeconds(node["reset_after_seconds"])
                ?? parseResetAfterSeconds(node["resetAfterSeconds"]),
            utilizationPercent: utilization,
            remainingPercent: remaining,
            remainingDollars: firstNumber(node["remaining_dollars"], node["remaining_usd"]),
            limitDollars: firstNumber(node["limit_dollars"], node["limit_usd"]),
            usedDollars: firstNumber(node["used_dollars"], node["used_usd"])
        )
    }

    private func codexRateLimitWindow(_ node: JSONValue, windowSeconds: Int, preferredKey: String) -> JSONValue? {
        let rateLimit = node["rate_limit"]
        let preferred = rateLimit[preferredKey]
        if windowSecondsValue(preferred) == windowSeconds {
            return preferred
        }
        for key in ["primary_window", "secondary_window", "primary", "secondary"] {
            let candidate = rateLimit[key]
            if windowSecondsValue(candidate) == windowSeconds {
                return candidate
            }
        }
        return preferred.hasData ? preferred : nil
    }

    private func parseResetAt(_ value: JSONValue) -> Date? {
        if let number = value.int64Value {
            return epochToDate(number)
        }
        guard let text = value.stringValue, !text.isEmpty else {
            return nil
        }
        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: text)
            ?? ISO8601DateFormatter.standard.date(from: text) {
            return date
        }
        return Int64(text).flatMap(epochToDate)
    }

    private func parseResetAfterSeconds(_ value: JSONValue) -> Date? {
        guard let seconds = value.doubleValue, seconds > 0 else {
            return nil
        }
        return Date().addingTimeInterval(seconds)
    }

    private func epochToDate(_ epoch: Int64) -> Date? {
        if epoch <= 0 {
            return nil
        }
        if epoch > 10_000_000_000 {
            return Date(timeIntervalSince1970: TimeInterval(epoch) / 1000)
        }
        return Date(timeIntervalSince1970: TimeInterval(epoch))
    }

    private func firstNumber(_ values: JSONValue...) -> Double? {
        for value in values {
            if let number = value.doubleValue {
                return number
            }
        }
        return nil
    }

    private func normalizePercent(_ value: Double?, smallValueIsRatio: Bool) -> Double? {
        guard let value else {
            return nil
        }
        if smallValueIsRatio, value >= 0, value <= 1 {
            return value * 100
        }
        return value
    }

    private func windowSecondsValue(_ node: JSONValue) -> Int? {
        firstNumber(node["limit_window_seconds"], node["limitWindowSeconds"], node["window_seconds"])
            .map(Int.init)
    }
}

enum JSONValue: Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue {
        objectValue?[key] ?? .null
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        int64Value.map(Int.init)
    }

    var int64Value: Int64? {
        switch self {
        case .number(let value):
            return Int64(value)
        case .string(let value):
            return Int64(value)
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var displayText: String {
        switch self {
        case .object, .array:
            let data = (try? JSONEncoder().encode(self)) ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .null:
            return ""
        }
    }

    var kindName: String {
        switch self {
        case .object:
            return "object"
        case .array:
            return "array"
        case .string:
            return "string"
        case .number:
            return "number"
        case .bool:
            return "bool"
        case .null:
            return "null"
        }
    }

    var hasData: Bool {
        switch self {
        case .object(let value):
            return !value.isEmpty
        case .array(let value):
            return !value.isEmpty
        case .string(let value):
            return !value.isEmpty
        case .number, .bool:
            return true
        case .null:
            return false
        }
    }
}

enum QuotaError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

enum DefaultsKey {
    static let baseURL = "baseURL"
    static let token = "token"
    static let refreshIntervalMinutes = "refreshIntervalMinutes"
    static let hidesDisabledAccounts = "hidesDisabledAccounts"
}

enum QuotaDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}

enum LogDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

enum RefreshTimeFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

extension String {
    var shortSHA256: String {
        SHA256.hash(data: Data(utf8))
            .prefix(6)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

#Preview {
    ContentView()
        .environmentObject(QuotaMonitor())
}
