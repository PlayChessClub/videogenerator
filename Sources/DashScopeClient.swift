import Foundation

struct APIError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

enum JSONValue {
    static func string(_ obj: Any?, _ keyPath: [String]) -> String? {
        var cur = obj
        for k in keyPath {
            guard let d = cur as? [String: Any], let v = d[k] else { return nil }
            cur = v
        }
        if let s = cur as? String { return s }
        if let n = cur as? NSNumber { return n.stringValue }
        return nil
    }
    static func dict(_ obj: Any?, _ key: String) -> [String: Any]? {
        (obj as? [String: Any])?[key] as? [String: Any]
    }
}

@MainActor
final class DashScopeClient {
    static let shared = DashScopeClient()
    private let session: URLSession
    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 3600
        session = URLSession(configuration: cfg)
    }

    private func key() throws -> String {
        let k = AppSettings.shared.apiKey.trimmingCharacters(in: .whitespaces)
        if k.isEmpty { throw APIError("请先在「设置」中填写 DashScope API Key") }
        return k
    }

    private func authHeaders(extra: [String: String] = [:]) throws -> [String: String] {
        var h = ["Authorization": "Bearer \(try key())"]
        for (k, v) in extra { h[k] = v }
        return h
    }

    // MARK: - OSS 临时上传（供 img_url / audio_url 使用）

    /// 上传本地文件到 DashScope 临时 OSS，返回 oss:// 形式的 URL
    func uploadToOSS(model: String, fileURL: URL) async throws -> String {
        // 1) getPolicy
        var comp = URLComponents(string: "\(DashScope.httpBase)/uploads")
        comp?.queryItems = [URLQueryItem(name: "action", value: "getPolicy"),
                            URLQueryItem(name: "model", value: model)]
        guard let policyURL = comp?.url else { throw APIError("uploads URL 无效") }
        var req = URLRequest(url: policyURL)
        req.httpMethod = "GET"
        for (k, v) in try authHeaders() { req.setValue(v, forHTTPHeaderField: k) }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (pdata, presp) = try await session.data(for: req)
        guard let http = presp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError("获取上传凭证失败：\(String(data: pdata, encoding: .utf8) ?? "HTTP \( (presp as? HTTPURLResponse)?.statusCode ?? -1 )")")
        }
        let policyJson = try JSONSerialization.jsonObject(with: pdata) as? [String: Any] ?? [:]
        guard let output = policyJson["data"] as? [String: Any] ?? policyJson["output"] as? [String: Any] else {
            throw APIError("上传凭证响应缺少 data 字段")
        }
        guard let host = output["upload_host"] as? String,
              let dir = output["upload_dir"] as? String,
              let policy = output["policy"] as? String,
              let sig = output["signature"] as? String,
              let ak = output["oss_access_key_id"] as? String else {
            throw APIError("上传凭证字段不完整")
        }

        // 2) POST 到 OSS
        let fileName = fileURL.lastPathComponent
        let key = dir + "/" + fileName
        guard let ossURL = URL(string: host) else { throw APIError("upload_host 无效") }
        var boundary = "----ClipForge\(UUID().uuidString)"
        let mime = mimeFor(fileURL)

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        field("OSSAccessKeyId", ak)
        field("Signature", sig)
        field("policy", policy)
        field("key", key)
        field("x-oss-object-acl", (output["x_oss_object_acl"] as? String) ?? "private")
        field("x-oss-forbid-overwrite", (output["x_oss_forbid_overwrite"] as? String) ?? "true")
        field("success_action_status", "200")
        field("x-oss-content-type", mime)
        // file field last
        let fileData = try Data(contentsOf: fileURL)
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mime)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        _ = boundary

        var oreq = URLRequest(url: ossURL)
        oreq.httpMethod = "POST"
        oreq.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        oreq.setValue("application/json", forHTTPHeaderField: "Accept")
        let (oBody, oResp) = try await session.upload(for: oreq, from: body)
        guard let ohttp = oResp as? HTTPURLResponse, (200..<300).contains(ohttp.statusCode) else {
            throw APIError("上传 OSS 失败：\(String(data: oBody, encoding: .utf8) ?? "HTTP \( (oResp as? HTTPURLResponse)?.statusCode ?? -1 )")")
        }
        return "oss://" + key
    }

    private func mimeFor(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "mp4": return "video/mp4"
        default: return "application/octet-stream"
        }
    }

    // MARK: - 声音复刻 enrollment

    func createVoice(targetModel: String, prefix: String, url: String) async throws -> String {
        let body: [String: Any] = [
            "model": FixedModel.voiceEnrollment,
            "input": ["action": "create_voice", "target_model": targetModel,
                      "prefix": prefix, "url": url],
        ]
        var extra: [String: String] = [:]
        if url.hasPrefix("oss://") { extra["X-DashScope-OssResourceResolve"] = "enable" }
        let json = try await postJSON("\(DashScope.httpBase)/services/audio/tts/customization",
                                      body: body, extra: extra)
        guard let vid = JSONValue.string(json["output"], ["voice_id"]) else {
            throw APIError("创建音色失败：\(json["code"] ?? "") \(json["message"] ?? "")")
        }
        return vid
    }

    func queryVoice(voiceId: String) async throws -> [String: Any] {
        let body: [String: Any] = [
            "model": FixedModel.voiceEnrollment,
            "input": ["action": "query_voice", "voice_id": voiceId],
        ]
        let json = try await postJSON("\(DashScope.httpBase)/services/audio/tts/customization", body: body)
        return json["output"] as? [String: Any] ?? [:]
    }

    func listVoices(prefix: String) async throws -> [[String: Any]] {
        let body: [String: Any] = [
            "model": FixedModel.voiceEnrollment,
            "input": ["action": "list_voice", "prefix": prefix, "page_index": 0, "page_size": 50],
        ]
        let json = try await postJSON("\(DashScope.httpBase)/services/audio/tts/customization", body: body)
        return (json["output"] as? [String: Any])?["voice_list"] as? [[String: Any]] ?? []
    }

    func deleteVoice(voiceId: String) async throws {
        let body: [String: Any] = [
            "model": FixedModel.voiceEnrollment,
            "input": ["action": "delete_voice", "voice_id": voiceId],
        ]
        _ = try await postJSON("\(DashScope.httpBase)/services/audio/tts/customization", body: body)
    }

    // MARK: - 视频生成任务 (wan2.6-i2v)

    struct VideoRequest {
        var model: String = FixedModel.videoI2V
        var prompt: String
        var imageURL: String?          // 文生视频(t2v)不需要首帧图
        var audioURL: String?
        var resolution: String = "720P"
        var duration: Int = 10
        var promptExtend: Bool = true
        var audioEnabled: Bool = true
        var shotType: String = "multi"
    }

    func submitVideoTask(_ r: VideoRequest) async throws -> String {
        var input: [String: Any] = ["prompt": r.prompt]
        if let img = r.imageURL, !img.isEmpty { input["img_url"] = img }
        if let a = r.audioURL { input["audio_url"] = a }
        var params: [String: Any] = [
            "resolution": r.resolution,
            "prompt_extend": r.promptExtend,
            "duration": r.duration,
            "audio": r.audioEnabled,
        ]
        if r.shotType == "multi" { params["shot_type"] = "multi" }
        let body: [String: Any] = ["model": r.model, "input": input, "parameters": params]
        let json = try await postJSON(
            "\(DashScope.httpBase)/services/aigc/video-generation/video-synthesis",
            body: body,
            extra: ["X-DashScope-Async": "enable", "X-DashScope-OssResourceResolve": "enable"])
        guard let tid = JSONValue.string(json["output"], ["task_id"]) else {
            throw APIError("提交视频任务失败：\(json["code"] ?? "") \(json["message"] ?? "")")
        }
        return tid
    }

    struct VideoStatus {
        var state: String
        var videoUrl: String?
        var message: String?
        var raw: [String: Any]
    }

    func pollVideoTask(_ taskId: String) async throws -> VideoStatus {
        let url = URL(string: "\(DashScope.httpBase)/tasks/\(taskId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in try authHeaders() { req.setValue(v, forHTTPHeaderField: k) }
        let (data, _) = try await Net.data(req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let out = json["output"] as? [String: Any] ?? [:]
        let state = (out["task_status"] as? String) ?? "UNKNOWN"
        let vurl = JSONValue.string(out, ["video_url"]) ?? JSONValue.string(out, ["results", "0", "url"])
        let msg = out["message"] as? String ?? json["message"] as? String
        return VideoStatus(state: state, videoUrl: vurl, message: msg, raw: json)
    }

    // MARK: - 文生图（同步 multimodal-generation）
    //
    // 接口：POST /services/aigc/multimodal-generation/generation
    // 请求体：{model, input:{messages:[{role:"user", content:[{text}]}]}, parameters:{size,n}}
    // 同步返回 output.choices[].message.content[].image（图片 URL，可能多张）
    // 注意：size 分隔符是「*」不是「x」，如 "1024*1024"

    struct ImageRequest {
        var prompt: String
        var model: String = FixedModel.imageDefault
        var size: String = "1024*1024"
        var n: Int = 1
        var promptExtend: Bool = true
        var watermark: Bool = false
    }

    /// 同步生成图片，返回图片 URL 数组（通常 1 张，wan 系列可能多张）
    func submitImage(_ r: ImageRequest) async throws -> [String] {
        let params: [String: Any] = [
            "size": r.size,
            "n": r.n,
            "watermark": r.watermark,
            "prompt_extend": r.promptExtend,
        ]
        let body: [String: Any] = [
            "model": r.model,
            "input": [
                "messages": [
                    ["role": "user", "content": [["text": r.prompt]]]
                ]
            ],
            "parameters": params,
        ]
        let json = try await postJSON(
            "\(DashScope.httpBase)/services/aigc/multimodal-generation/generation",
            body: body)

        // 解析 output.choices[*].message.content[*].image
        var urls: [String] = []
        if let out = json["output"] as? [String: Any],
           let choices = out["choices"] as? [[String: Any]] {
            for ch in choices {
                guard let msg = ch["message"] as? [String: Any],
                      let content = msg["content"] as? [[String: Any]] else { continue }
                for item in content {
                    if let u = item["image"] as? String, !u.isEmpty { urls.append(u) }
                }
            }
        }
        // 兼容某些模型返回 results 结构
        if urls.isEmpty {
            if let out = json["output"] as? [String: Any],
               let results = out["results"] as? [[String: Any]] {
                for item in results {
                    if let u = item["url"] as? String, !u.isEmpty { urls.append(u) }
                }
            }
        }
        if urls.isEmpty {
            throw APIError("生成失败：未返回图片地址 \(json["code"] ?? "") \(json["message"] ?? "")")
        }
        return urls
    }

    // MARK: - 下载远端资源到本地

    func download(_ remote: URL, to dest: URL) async throws {
        let (tmp, _) = try await Net.download(URLRequest(url: remote))
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tmp, to: dest)
    }

    // MARK: - 通用 POST JSON

    @discardableResult
    func postJSON(_ urlString: String, body: [String: Any], extra: [String: String] = [:]) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw APIError("URL 无效") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in try authHeaders(extra: extra) { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await Net.data(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if !(200..<300).contains(status) {
            let code = json["code"] as? String ?? ""
            let msg = json["message"] as? String ?? String(data: data, encoding: .utf8) ?? ""
            throw APIError("HTTP \(status) \(code) \(msg)".trimmingCharacters(in: .whitespaces))
        }
        return json
    }
}
